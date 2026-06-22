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

  // ---------------------------------------------------------------------------
  // Parameters (must match axi_sram instantiation)
  // ---------------------------------------------------------------------------
  localparam int unsigned SramMemSize   = 128 * 1024;
  localparam int unsigned AxiAddrOffset = $clog2(top_pkg::AxiDataWidth / 8);
  localparam int unsigned SramAddrWidth = $clog2(SramMemSize) - AxiAddrOffset;

  // ---------------------------------------------------------------------------
  // Clock and reset
  // ---------------------------------------------------------------------------
  logic clk_i  = '0;
  logic rst_ni = '0;

  always #5ns clk_i = ~clk_i;          // 100 MHz

  initial begin
    rst_ni = '0;
    repeat (10) @(posedge clk_i);
    @(negedge clk_i);
    rst_ni = '1;
  end

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
    w_if.set_data_width(top_pkg::AxiDataWidth);
    w_if.set_user_data_width(1);          // CHERI tag bit[0]
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
    r_if.set_id_r_width(top_pkg::AxiIdWidth);
    r_if.set_data_width(top_pkg::AxiDataWidth);
    r_if.set_user_data_width(1);          // CHERI tag bit[0]
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

  // ---------------------------------------------------------------------------
  // UVM entry point
  // ---------------------------------------------------------------------------
  initial begin
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
