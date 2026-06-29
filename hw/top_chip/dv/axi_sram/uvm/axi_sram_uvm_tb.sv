// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// UVM top-level testbench for axi_sram.
//
// Instantiates the five axi_agent interfaces, wires them to the DUT via
// the same always_comb / assign pattern used in the cocotb TB, then hands
// off to the UVM framework via run_test().
//
// Simulator requirement: needs a UVM-capable tool (Xcelium / VCS / Questa).
// The existing Verilator flow does not support UVM.

module axi_sram_uvm_tb;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_agent_pkg::*;
  import top_pkg::*;
  import dv_utils_pkg::Host;
  // Pull the test package into elaboration so its tests register with the UVM
  // factory (otherwise +UVM_TESTNAME=... cannot be found).
  import axi_sram_test_pkg::*;

  // ---------------------------------------------------------------------------
  // Parameters (must match axi_sram instantiation)
  // ---------------------------------------------------------------------------
  localparam int unsigned SramMemSize   = 128 * 1024;
  localparam int unsigned AxiAddrOffset = $clog2(top_pkg::AxiDataWidth / 8);
  localparam int unsigned SramAddrWidth = $clog2(SramMemSize) - AxiAddrOffset;

  // ---------------------------------------------------------------------------
  // Clock and reset
  //
  // Generated and driven by the dv_base clk_rst_if (common_ifs), so the clock
  // frequency and reset can be controlled at runtime from UVM (e.g. apply_reset
  // in the base test) rather than hard-coded here. The interface drives the
  // clk_i / rst_ni nets that the DUT, the AXI interfaces, and the TB assertions
  // already consume, so nothing downstream changes.
  // ---------------------------------------------------------------------------
  wire clk_i;
  wire rst_ni;

  clk_rst_if u_clk_rst (.clk(clk_i), .rst_n(rst_ni));

  // ---------------------------------------------------------------------------
  // AXI channel interfaces
  // ---------------------------------------------------------------------------
  axi_write_request_if  aw_if (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_data_if     w_if  (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_response_if b_if  (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_request_if   ar_if (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_data_if      r_if  (.clk_i(clk_i), .rst_ni(rst_ni));

  // Configure interface widths to match the DUT and set all to Host mode
  // (the axi_mgr_agent acts as an AXI Manager across all five channels).
  initial begin
    // AW
    aw_if.set_id_w_width(top_pkg::AxiIdWidth);
    aw_if.set_addr_width(top_pkg::AxiAddrWidth);
    aw_if.set_user_req_width(1);          // only CHERI tag bit[0] is used
    aw_if.if_mode = Host;
    // W
    // user_data_width must be set before data_width: set_data_width() enforces
    // DATA_WIDTH >= 2*USER_DATA_WIDTH, and USER_DATA_WIDTH defaults high.
    w_if.set_user_data_width(1);          // CHERI tag bit[0]
    w_if.set_data_width(top_pkg::AxiDataWidth);
    w_if.if_mode = Host;
    // B
    b_if.set_id_w_width(top_pkg::AxiIdWidth);
    b_if.set_bresp_width(2);              // AXI4 BRESP is 2 bits
    b_if.set_user_resp_width(1);
    b_if.if_mode = Host;
    // AR
    ar_if.set_id_r_width(top_pkg::AxiIdWidth);
    ar_if.set_addr_width(top_pkg::AxiAddrWidth);
    ar_if.set_user_req_width(1);
    ar_if.if_mode = Host;
    // R
    // user_data_width before data_width (see W channel note above).
    r_if.set_id_r_width(top_pkg::AxiIdWidth);
    r_if.set_user_data_width(1);          // CHERI tag bit[0]
    r_if.set_data_width(top_pkg::AxiDataWidth);
    r_if.set_rresp_width(2);              // AXI4 RRESP is 2 bits
    r_if.set_user_resp_width(1);
    r_if.if_mode = Host;
  end

  // ---------------------------------------------------------------------------
  // DUT wiring
  //
  // The DUT uses packed structs.  We build axi_req from interface wires via
  // always_comb, and feed DUT response outputs back to the interface wires via
  // assign (tri-state resolution: the interface drives 'z in Host mode for all
  // signals it does not own, so the DUT value wins).
  // ---------------------------------------------------------------------------
  top_pkg::axi_req_t  axi_req;
  wire top_pkg::axi_resp_t axi_resp;

  always_comb begin
    // AW — manager drives to DUT
    axi_req.aw.id     = top_pkg::id_t'(aw_if.awid);
    axi_req.aw.addr   = top_pkg::addr_t'(aw_if.awaddr);
    axi_req.aw.len    = axi_pkg::len_t'(aw_if.awlen);
    axi_req.aw.size   = axi_pkg::size_t'(aw_if.awsize);
    axi_req.aw.burst  = axi_pkg::burst_t'(aw_if.awburst);
    axi_req.aw.lock   = aw_if.awlock;
    axi_req.aw.cache  = axi_pkg::cache_t'(aw_if.awcache);
    axi_req.aw.prot   = axi_pkg::prot_t'(aw_if.awprot);
    axi_req.aw.qos    = axi_pkg::qos_t'(aw_if.awqos);
    axi_req.aw.region = axi_pkg::region_t'(aw_if.awregion);
    axi_req.aw.atop   = '0;              // not present in axi_write_request_if
    axi_req.aw.user   = top_pkg::user_t'(aw_if.awuser);
    axi_req.aw_valid  = aw_if.awvalid;

    // W — manager drives to DUT
    axi_req.w.data    = top_pkg::data_t'(w_if.wdata);
    axi_req.w.strb    = top_pkg::strb_t'(w_if.wstrb);
    axi_req.w.last    = w_if.wlast;
    axi_req.w.user    = top_pkg::user_t'(w_if.wuser);
    axi_req.w_valid   = w_if.wvalid;

    // B — manager drives bready, reads bvalid etc. from DUT via assign below
    axi_req.b_ready   = b_if.bready;

    // AR — manager drives to DUT
    axi_req.ar.id     = top_pkg::id_t'(ar_if.arid);
    axi_req.ar.addr   = top_pkg::addr_t'(ar_if.araddr);
    axi_req.ar.len    = axi_pkg::len_t'(ar_if.arlen);
    axi_req.ar.size   = axi_pkg::size_t'(ar_if.arsize);
    axi_req.ar.burst  = axi_pkg::burst_t'(ar_if.arburst);
    axi_req.ar.lock   = ar_if.arlock;
    axi_req.ar.cache  = axi_pkg::cache_t'(ar_if.arcache);
    axi_req.ar.prot   = axi_pkg::prot_t'(ar_if.arprot);
    axi_req.ar.qos    = axi_pkg::qos_t'(ar_if.arqos);
    axi_req.ar.region = axi_pkg::region_t'(ar_if.arregion);
    axi_req.ar.user   = top_pkg::user_t'(ar_if.aruser);
    axi_req.ar_valid  = ar_if.arvalid;

    // R — manager drives rready, reads rvalid etc. from DUT via assign below
    axi_req.r_ready   = r_if.rready;
  end

  // DUT response outputs → interface wires (interface drives 'z in Host mode)
  assign aw_if.awready = axi_resp.aw_ready;
  assign w_if.wready   = axi_resp.w_ready;

  assign b_if.bvalid = axi_resp.b_valid;
  assign b_if.bid    = 32'(axi_resp.b.id);
  assign b_if.bresp  = 3'(axi_resp.b.resp);
  assign b_if.buser  = 16'(axi_resp.b.user);

  assign ar_if.arready = axi_resp.ar_ready;

  assign r_if.rvalid = axi_resp.r_valid;
  assign r_if.rid    = 32'(axi_resp.r.id);
  assign r_if.rdata  = 1024'(axi_resp.r.data);
  assign r_if.rresp  = 3'(axi_resp.r.resp);
  assign r_if.rlast  = axi_resp.r.last;
  assign r_if.ruser  = 528'(axi_resp.r.user);

  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  axi_sram #(
    .AddrWidth (SramAddrWidth)
  ) u_dut (
    .clk_i     (clk_i   ),
    .rst_ni    (rst_ni  ),
    .axi_req_i (axi_req ),
    .axi_resp_o(axi_resp)
  );

  // 4-state simulation: pre-clear the SRAM data and CHERI tag memories at time 0.
  // The tag read-modify-write path reads the existing tag word before updating a
  // bit; if the tag RAM starts as X (Xcelium 4-state), that X flows through the
  // DUT request/response FIFOs and trips prim_fifo_sync DataKnown_A. Verilator
  // reads X as 0, so the cocotb flow never saw this. The vplan treats power-up
  // SRAM/tag contents as undefined, so zeroing here is legitimate and matches the
  // 2-state behaviour.
  initial begin
    foreach (u_dut.u_ram.mem[i])     u_dut.u_ram.mem[i]     = '0;
    foreach (u_dut.u_tag_ram.mem[i]) u_dut.u_tag_ram.mem[i] = '0;
  end

  // ---------------------------------------------------------------------------
  // Functional coverage (CHERI tag write gating + tag read/ruser).
  // ---------------------------------------------------------------------------
  axi_sram_cov u_cov (
    .clk_i   (clk_i   ),
    .rst_ni  (rst_ni  ),
    .axi_req (axi_req ),
    .axi_resp(axi_resp)
  );

  // ---------------------------------------------------------------------------
  // Static geometry checks  (vplan: interface_geometry / qohtih,
  //                                 sram_geometry      / jeluga,01skcc,u0s8nt)
  //
  // The four DUT ports (clk_i, rst_ni, axi_req_i, axi_resp_o) are structurally
  // guaranteed by the u_dut instantiation above. Here we additionally assert the
  // AXI/SRAM geometry the spec mandates: 64-bit data word, an 8-bit write strobe,
  // at least one CHERI tag bit on wuser/ruser, and the 128 KiB SRAM size.
  // ---------------------------------------------------------------------------
  initial begin : g_geometry_check
    assert (top_pkg::AxiDataWidth == 64)
      else $fatal(1, "[axi_sram_uvm_tb] AxiDataWidth must be 64, got %0d", top_pkg::AxiDataWidth);
    assert ($bits(axi_req.w.strb) == top_pkg::AxiDataWidth/8)
      else $fatal(1, "[axi_sram_uvm_tb] wstrb must be %0d bits, got %0d",
                  top_pkg::AxiDataWidth/8, $bits(axi_req.w.strb));
    assert ($bits(axi_req.w.user) >= 1)
      else $fatal(1, "[axi_sram_uvm_tb] wuser must carry at least one CHERI tag bit");
    assert ($bits(axi_resp.r.user) >= 1)
      else $fatal(1, "[axi_sram_uvm_tb] ruser must carry at least one CHERI tag bit");
    assert (SramMemSize == 128*1024)
      else $fatal(1, "[axi_sram_uvm_tb] SramMemSize must be 128 KiB, got %0d", SramMemSize);
  end

  // ---------------------------------------------------------------------------
  // Bounded response time  (vplan: bounded_response / 34ld5i)
  //
  // Every accepted request must produce its response within a bounded window.
  // Progress is measured on *valid* (the DUT presenting a response), so legal
  // master back-pressure on b/rready is never blamed on the DUT — the watchdog
  // trips only on a genuine stall. The bound is intentionally generous.
  // ---------------------------------------------------------------------------
  localparam int unsigned MaxRespLatency = 256;

  int unsigned w_outstanding, w_stall_cnt;
  int unsigned r_outstanding, r_stall_cnt;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      w_outstanding <= 0; w_stall_cnt <= 0;
      r_outstanding <= 0; r_stall_cnt <= 0;
    end else begin
      // Writes: a B response must appear within the bound after AW is accepted.
      w_outstanding <= w_outstanding
                     + ((axi_req.aw_valid && axi_resp.aw_ready) ? 1 : 0)
                     - ((axi_resp.b_valid && axi_req.b_ready  ) ? 1 : 0);
      if      (axi_resp.b_valid)    w_stall_cnt <= 0;
      else if (w_outstanding != 0)  w_stall_cnt <= w_stall_cnt + 1;
      else                          w_stall_cnt <= 0;
      assert (w_stall_cnt <= MaxRespLatency)
        else $error("[axi_sram_uvm_tb] write response exceeded %0d cycles (34ld5i)", MaxRespLatency);

      // Reads: an R beat must appear within the bound (a burst advances per beat).
      r_outstanding <= r_outstanding
                     + ((axi_req.ar_valid && axi_resp.ar_ready) ? 1 : 0)
                     - ((axi_resp.r_valid && axi_req.r_ready && axi_resp.r.last) ? 1 : 0);
      if      (axi_resp.r_valid)    r_stall_cnt <= 0;
      else if (r_outstanding != 0)  r_stall_cnt <= r_stall_cnt + 1;
      else                          r_stall_cnt <= 0;
      assert (r_stall_cnt <= MaxRespLatency)
        else $error("[axi_sram_uvm_tb] read response exceeded %0d cycles (34ld5i)", MaxRespLatency);
    end
  end

  // ---------------------------------------------------------------------------
  // CHERI tag write assertions  (vplan: assert_wuser_not_full_cap / bj8we7,
  //                                     assert_wuser_mismatch     / 9a3xf6)
  //
  // A "full capability write" is a single 2-beat (awlen==1), 8-byte (awsize==3),
  // 16-byte-aligned (awaddr[3:0]==0) burst with full write strobes on its beats.
  // The W channel carries no address, so we snoop AW attributes into a small FIFO
  // (AXI4 keeps write data in AW order) and check each W beat against the
  // governing request. These spec assertions are deliberately tripped by directed
  // tests (no_tag_*, wuser_mismatch), so their action is a non-fatal $warning.
  // ---------------------------------------------------------------------------
  localparam int unsigned AwFifoDepth = 16;

  logic [7:0]  aw_len_q  [AwFifoDepth];
  logic [2:0]  aw_size_q [AwFifoDepth];
  logic [3:0]  aw_alo_q  [AwFifoDepth];   // awaddr[3:0]
  int unsigned aw_head, aw_tail, aw_count;
  logic        w_first;                    // next W beat is the first of its burst
  logic        w_first_user;               // wuser captured on the first beat

  // Attributes of the AW governing the W beat currently on the bus.
  logic [7:0] g_len;
  logic [2:0] g_size;
  logic [3:0] g_alo;
  logic       g_valid;
  always_comb begin
    if (aw_count != 0) begin
      g_valid = 1'b1;
      g_len   = aw_len_q[aw_head];
      g_size  = aw_size_q[aw_head];
      g_alo   = aw_alo_q[aw_head];
    end else if (axi_req.aw_valid && axi_resp.aw_ready) begin
      // AW accepted on the same cycle as its first W beat.
      g_valid = 1'b1;
      g_len   = axi_req.aw.len;
      g_size  = axi_req.aw.size;
      g_alo   = axi_req.aw.addr[3:0];
    end else begin
      g_valid = 1'b0;
      g_len   = '0;
      g_size  = '0;
      g_alo   = '0;
    end
  end

  wire is_cap_shaped = g_valid && (g_len == 8'd1) && (g_size == 3'd3) && (g_alo == 4'd0);
  wire full_strobe   = &axi_req.w.strb;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_head      <= 0;
      aw_tail      <= 0;
      aw_count     <= 0;
      w_first      <= 1'b1;
      w_first_user <= 1'b0;
    end else begin
      // ---- immediate assertions for the W beat on the bus this cycle ----
      if (axi_req.w_valid && axi_resp.w_ready) begin
        // bj8we7: a tag bit may only be set as part of a full capability write.
        if (axi_req.w.user[0]) begin
          assert (is_cap_shaped && full_strobe)
            else $warning("[axi_sram_uvm_tb] wuser=1 on a write that is not a full capability write (bj8we7)");
        end
        // 9a3xf6: both halves of a capability write must agree on wuser.
        if (is_cap_shaped && !w_first) begin
          assert (axi_req.w.user[0] == w_first_user)
            else $warning("[axi_sram_uvm_tb] wuser mismatch between capability halves (9a3xf6)");
        end
      end

      // ---- AW snoop FIFO push ----
      if (axi_req.aw_valid && axi_resp.aw_ready) begin
        aw_len_q[aw_tail]  <= axi_req.aw.len;
        aw_size_q[aw_tail] <= axi_req.aw.size;
        aw_alo_q[aw_tail]  <= axi_req.aw.addr[3:0];
        aw_tail            <= (aw_tail + 1) % AwFifoDepth;
      end

      // ---- W beat tracking / FIFO pop on last beat ----
      if (axi_req.w_valid && axi_resp.w_ready) begin
        if (w_first) w_first_user <= axi_req.w.user[0];
        w_first <= axi_req.w.last;
        if (axi_req.w.last) aw_head <= (aw_head + 1) % AwFifoDepth;
      end

      // ---- outstanding-AW counter ----
      aw_count <= aw_count
                + ((axi_req.aw_valid && axi_resp.aw_ready) ? 1 : 0)
                - ((axi_req.w_valid && axi_resp.w_ready && axi_req.w.last) ? 1 : 0);
    end
  end

  // ---------------------------------------------------------------------------
  // tag_separate_memory (vplan / lzoy40): tags are stored in a memory block
  // separate from data. This is a structural property, verified by inspection of
  // the RTL — axi_sram instantiates distinct prim_ram_1p blocks u_tag_ram (tags)
  // and u_ram (data). It is not observable at the AXI boundary, so there is no
  // runtime assertion; the memory pre-clear above touches both instances by name.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // UVM entry point
  // ---------------------------------------------------------------------------
  initial begin
    // Start the clock (100 MHz) and enable reset driving before UVM runs.
    u_clk_rst.set_freq_mhz(100);
    u_clk_rst.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_rst_vif", u_clk_rst);

    uvm_config_db#(virtual axi_write_request_if)::set(
      null, "*", "write_request_vif", aw_if);
    uvm_config_db#(virtual axi_write_data_if)::set(
      null, "*", "write_data_vif", w_if);
    uvm_config_db#(virtual axi_write_response_if)::set(
      null, "*", "write_response_vif", b_if);
    uvm_config_db#(virtual axi_read_request_if)::set(
      null, "*", "read_request_vif", ar_if);
    uvm_config_db#(virtual axi_read_data_if)::set(
      null, "*", "read_data_vif", r_if);
    run_test();
  end

endmodule
