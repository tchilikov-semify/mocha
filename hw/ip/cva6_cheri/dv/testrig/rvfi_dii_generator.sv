module rvfi_dii_generator
  import ariane_pkg::*;
  import uvm_pkg::*;
  import wt_cache_pkg::*;
#(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
  parameter type icache_dreq_t = logic,
  parameter type icache_drsp_t = logic,
  parameter type exception_t = logic
) (
  input   logic         clk_i,
  input   logic         rst_ni,
  input   icache_dreq_t dreq_i,
  output  icache_drsp_t dreq_o
);

  localparam int FETCH_WORDS      = CVA6Cfg.SuperscalarEn + 1;
  localparam int FETCH_HALFWORDS  = FETCH_WORDS * 2;

  virtual cva6_dii_intf dii_vif;                                              // the DII instruction interface, passed by TB

  initial begin
    uvm_config_db#(virtual cva6_dii_intf)::wait_modified(null, "*", "dii_if");
    if (!uvm_config_db#(virtual cva6_dii_intf)::get(null, "*", "dii_if", dii_vif)) begin
      $fatal(1,"dii_if must be provided");
    end
  end


  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  logic [    CVA6Cfg.VLEN-1:0]    vaddr_ff;                                   // the virtual address of the outgoing instruction
  logic [CVA6Cfg.DIIIDLEN-1:0]    dii_id, dii_id_ff;                          // the DII ID of the current written instruction
  logic                           halt, halt_ff;                              // all instructions written, stop writing more
  logic [                 2:0]    cold_start_ff;                              // whether the core is coming out of a reset
  logic                           kill;                                       // whether a kill was issued
  logic                           flushing_ff;                                // flush after a kill until the next dreq_i.req
  logic [                15:0]    hw                  [FETCH_HALFWORDS];      // the 4 halfwords that compose the output data buffer
  logic [FETCH_HALFWORDS*32:0]    data_buffer;
  logic [FETCH_HALFWORDS*32:0]    shifted_buffer;
  logic                           is_compressed       [FETCH_HALFWORDS];      // whether the next 4 instructions in the queue are compressed
  logic [                 1:0]    buffer_shift_hw_ff;                         // which halfword slot (0–3) the first new instruction starts at in the current 64-bit fetch window
  logic [                15:0]    carry_hw_ff;                                // carry from the last fetch buffer
  logic                           carry_out;                                  // hw3 has the lower half of a split full instruction
  logic [                 2:0]    dii_advance;                                // how many DII instructions consumed (0-4)
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  int wptr, avail_hw, slots_hw, sz_hw;
  // always_comb begin
  always @(rst_ni, dii_id_ff, vaddr_ff, buffer_shift_hw_ff, carry_hw_ff) begin
    wptr = 0;
    data_buffer = '0;
    for (int i = 0; i < FETCH_HALFWORDS; i++) begin
      is_compressed[i] = dii_vif.is_compressed(dii_id_ff + i);
    end
    // take the next 2/4 instructions and build a buffer from them
    for (int i = 0; i < FETCH_HALFWORDS; i++) begin
      if(is_compressed[i]) begin
        data_buffer[(wptr*16) +: 16] = 16'(dii_vif.get_instr(dii_id_ff + i));
        wptr = wptr + 1;
      end else begin
        data_buffer[(wptr*16) +: 32] = dii_vif.get_instr(dii_id_ff + i);
        wptr = wptr + 2;
      end
    end

    shifted_buffer = (data_buffer << (buffer_shift_hw_ff*16));

    //based on the buffer we built, saturate the data output
    for (int i = 0; i < FETCH_HALFWORDS; i++) begin
      hw[i] = (i < buffer_shift_hw_ff ? carry_hw_ff : shifted_buffer[(i*16) +: 16]);
    end

    // Compute dii_advance: scan instructions in order, consuming 1 hw per C, 2 hw per F,
    // until the available halfword slots  are filled. A full instruction that straddles the
    // window boundary is still consumed (carry_out=1).
    avail_hw    = FETCH_HALFWORDS - int'(buffer_shift_hw_ff);
    slots_hw    = 0;
    dii_advance = '0;
    carry_out   = 1'b0;
    for (int i = 0; i < FETCH_HALFWORDS; i++) begin
      sz_hw = is_compressed[i] ? 1 : 2;
      if (slots_hw + sz_hw <= avail_hw) begin
        slots_hw    = slots_hw + sz_hw;
        dii_advance = 3'(i) + 3'd1;
        if (slots_hw == avail_hw) break;
      end else begin
        dii_advance = 3'(i) + 3'd1;
        carry_out   = 1'b1;
        break;
      end
    end
    dii_id  = dii_id_ff + dii_advance;
  end

  always @(dreq_o, dreq_i, dii_id) begin
    kill  = dreq_i.kill_s1 | dreq_i.kill_s2;
    halt  = (dii_id > (dii_vif.num_test_insns() + FETCH_HALFWORDS)) && dreq_o.valid;
  end

  always @(posedge clk_i, negedge rst_ni) begin
    if(~rst_ni) begin
      halt_ff             <= '0;
      cold_start_ff       <= '1;
      flushing_ff         <= '0;
      dii_id_ff           <= '0;
      buffer_shift_hw_ff  <= '0;
      vaddr_ff            <= dreq_i.vaddr;
      carry_hw_ff         <= dii_vif.get_instr(-1);
    end else begin
      halt_ff             <= (halt | halt_ff) & ~flushing_ff;
      cold_start_ff       <= {cold_start_ff[1:0], ~rst_ni};
      flushing_ff         <= kill | (flushing_ff & ~dreq_i.req);
      if(dreq_o.valid || kill)
        carry_hw_ff         <= shifted_buffer[(FETCH_WORDS*32) +: 16];
      if(dreq_o.valid || flushing_ff)
        dii_id_ff           <= flushing_ff ? dreq_i.dii_id : dii_id;
      if(dreq_i.req && !kill) begin
        vaddr_ff            <= dreq_i.vaddr;
        buffer_shift_hw_ff  <= flushing_ff || (|cold_start_ff) ? (CVA6Cfg.SuperscalarEn ? dreq_i.vaddr[2:1] : {1'b0, dreq_i.vaddr[1]}) : {1'b0, carry_out};
      end
    end
  end

  always_comb begin
    dreq_o.valid    = ~(kill | flushing_ff | halt_ff | (|cold_start_ff)) & dreq_i.req;
    dreq_o.ready    = ~kill & dreq_i.req & ~|cold_start_ff[1:0];
    dreq_o.dii_id   = dii_id_ff;
    dreq_o.data     = CVA6Cfg.SuperscalarEn ? {hw[3], hw[2], hw[1], hw[0]} : {32'b0, hw[1], hw[0]};
    dreq_o.vaddr    = vaddr_ff;
    dreq_o.ex       = '0;
    dreq_o.user     = '0;
  end

endmodule
