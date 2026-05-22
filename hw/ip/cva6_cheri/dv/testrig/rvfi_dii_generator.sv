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
  input logic clk_i,
  input logic rst_ni,
  // data requests
  input  icache_dreq_t dreq_i,
  output icache_drsp_t dreq_o
);

  virtual cva6_dii_intf dii_vif;                                              // the DII instruction interface, passed by TB

  initial begin
    uvm_config_db#(virtual cva6_dii_intf)::wait_modified(null, "*", "dii_if");
    if (!uvm_config_db#(virtual cva6_dii_intf)::get(null, "*", "dii_if", dii_vif)) begin
      $fatal(1,"dii_if must be provided");
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  logic [                31:0]    instr1, instr0, instr_ff ;                  // the current instruction frame(s)
  logic [    CVA6Cfg.VLEN-1:0]    vaddr_ff;                                   // the virtual address of the outgoing instruction
  logic [                95:0]    alignment_buf;                              // The alignment buffer to re-align instructions based on fetch offset
  logic [CVA6Cfg.DIIIDLEN-1:0]    dii_id, dii_id_ff;                          // the DII ID of the current written instruction
  logic                           is_compressed, is_compressed_next;          // whether the current/next frames are compressed
  logic                           halt, halt_ff;                              // all instructions written, stop writing more
  logic [                 2:0]    cold_start_ff;                              // whether the core is coming out of a reset
  logic                           kill;                                       // whether a kill was issued
  logic                           flushing_ff;                                // flush after a kill until the next dreq_i.req
  logic                           compress_misalign, compress_misalign_ff;    // whether an odd number of compressed instrucitons misaligned the fetch address
  logic                           fetch_misalign, fetch_misalign_ff;          // whether the PC jumped to a word misaligned address.
  logic                           word_misalign, word_misalign_ff;            // whether a fence instruction caused a word boundary misalignment (superscalar only)
  logic                           realign;                                    // realign when a compressed instruction cancels out a fetch misalign
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  always @(dii_id_ff, dreq_o.valid, dreq_i, vaddr_ff, fetch_misalign_ff) begin
    kill                    = dreq_i.kill_s1 | dreq_i.kill_s2;
    is_compressed           = dii_vif.get_instr(dii_id_ff)[1:0] != 2'b11;
    is_compressed_next      = dii_vif.get_instr(dii_id_ff+1)[1:0] != 2'b11;
    compress_misalign       = (~compress_misalign_ff & is_compressed & ~is_compressed_next) | (compress_misalign_ff & ~is_compressed);
    fetch_misalign          = |vaddr_ff[1:0] ^ fetch_misalign_ff;
    word_misalign           = vaddr_ff[2] & CVA6Cfg.SuperscalarEn;
    realign                 = is_compressed & fetch_misalign;
    dii_id                  = dii_id_ff + (is_compressed & ~compress_misalign_ff & ~((fetch_misalign ^ fetch_misalign_ff) | realign)) + (CVA6Cfg.SuperscalarEn & ~word_misalign);
    halt                    = (dii_id > (dii_vif.num_test_insns() + (fetch_misalign | compress_misalign))) && dreq_o.valid;
    instr0                  = dii_vif.get_instr(dii_id_ff);
    instr1                  = CVA6Cfg.SuperscalarEn ? dii_vif.get_instr(dii_id_ff + 1) : '0;
    if(is_compressed) begin
      instr0 = {dii_vif.get_instr(dii_id_ff + 1'b1)[15:0], dii_vif.get_instr(dii_id_ff)[15:0]};
    end
    alignment_buf = {instr1, instr0, instr_ff };
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      dii_id_ff               <= '0;
      flushing_ff             <= '0;
      halt_ff                 <= '0;
      fetch_misalign_ff       <= '0;
      word_misalign_ff        <= '0;
      compress_misalign_ff    <= '0;
      cold_start_ff           <= '1;
      vaddr_ff                <= dreq_i.vaddr;
      instr_ff                <= dii_vif.get_instr(-1);
    end else begin
      halt_ff             <= (halt | halt_ff) & ~flushing_ff;
      cold_start_ff       <= {cold_start_ff[1:0], ~rst_ni};
      flushing_ff         <= kill | (flushing_ff & ~dreq_i.req);
      if(dreq_o.valid || kill) begin
        fetch_misalign_ff       <= ~(kill | realign) ? fetch_misalign    : '0;
        word_misalign_ff        <= ~(kill | realign) ? word_misalign     : '0;
        compress_misalign_ff    <= ~(kill | realign) ? compress_misalign : '0;
        instr_ff                <= is_compressed     ? (dii_vif.get_instr(dii_id_ff+1) << (is_compressed_next * 16)) : ((word_misalign & fetch_misalign) | ~CVA6Cfg.SuperscalarEn) ? instr0 : instr1;
      end
      if(dreq_o.valid || flushing_ff) begin
        dii_id_ff <= flushing_ff ? dreq_i.dii_id : dii_id + 1'b1;
      end
      if(dreq_i.req && !kill) begin
        vaddr_ff <= dreq_i.vaddr;
      end
    end
  end

  always_comb begin
    dreq_o.valid    = ~(kill | flushing_ff | halt_ff | (|cold_start_ff)) & dreq_i.req;
    dreq_o.ready    = ~kill & dreq_i.req & ~|cold_start_ff[1:0];
    dreq_o.dii_id   = dii_id_ff;
    dreq_o.data     = ((alignment_buf << ((fetch_misalign | compress_misalign_ff) * 16)) >> (word_misalign ? 0 : 32));
    dreq_o.vaddr    = vaddr_ff;
    dreq_o.ex       = '0;
    dreq_o.user     = '0;
  end

endmodule
