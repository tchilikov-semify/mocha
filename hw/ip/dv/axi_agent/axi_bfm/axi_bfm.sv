// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Reusable AXI manager BFM: instantiates the five axi_agent channel interfaces,
// bridges them to a packed AXI req/resp struct pair, and publishes them to the
// UVM config_db as one axi_agent_cfg. Parameterized on the req/resp struct types
// and channel widths so the same BFM drives either the mocha host port
// (axi_req_t) or the axi_sram device port (axi_dev_req_t).

module axi_bfm #(
  parameter type req_t     = top_pkg::axi_req_t,
  parameter type resp_t    = top_pkg::axi_resp_t,
  parameter int  IdWidth   = top_pkg::AxiIdWidth,
  parameter int  AddrWidth = top_pkg::AxiAddrWidth,
  parameter int  DataWidth = top_pkg::AxiDataWidth,
  parameter int  UserWidth = top_pkg::AxiUserWidth
) (
  input  logic  clk_i,
  input  logic  rst_ni,
  output req_t  axi_req_o,
  input  resp_t axi_resp_i
);

  import uvm_pkg::*;
  import axi_agent_pkg::*;
  `include "uvm_macros.svh"

  clk_rst_if            u_clk_rst_if  (.clk  (clk_i), .rst_n (rst_ni));
  axi_write_request_if  aw_if         (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_data_if     w_if          (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_response_if b_if          (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_request_if   ar_if         (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_data_if      r_if          (.clk_i(clk_i), .rst_ni(rst_ni));

  // Interface widths + dv_utils_pkg::Host mode (the agent is an AXI Manager on all channels).
  initial begin
    aw_if.set_id_w_width(IdWidth);
    aw_if.set_addr_width(AddrWidth);
    aw_if.set_user_req_width(UserWidth);
    aw_if.if_mode = dv_utils_pkg::Host;

    w_if.set_user_data_width(UserWidth);
    w_if.set_data_width(DataWidth);
    w_if.if_mode = dv_utils_pkg::Host;

    b_if.set_id_w_width(IdWidth);
    b_if.set_bresp_width($bits(axi_resp_i.b.resp));
    b_if.set_user_resp_width(UserWidth);
    b_if.if_mode = dv_utils_pkg::Host;

    ar_if.set_id_r_width(IdWidth);
    ar_if.set_addr_width(AddrWidth);
    ar_if.set_user_req_width(UserWidth);
    ar_if.if_mode = dv_utils_pkg::Host;

    r_if.set_id_r_width(IdWidth);
    r_if.set_user_data_width(UserWidth);
    r_if.set_data_width(DataWidth);
    r_if.set_rresp_width($bits(axi_resp_i.r.resp));
    r_if.set_user_resp_width(UserWidth);
    r_if.if_mode = dv_utils_pkg::Host;
  end

  // ---------------------------------------------------------------------------
  // BFM -> DUT: pack the manager-driven channels into axi_req_o.
  // ---------------------------------------------------------------------------
  // AW
  assign axi_req_o.aw.id     = $bits(axi_req_o.aw.id)'(aw_if.awid);
  assign axi_req_o.aw.addr   = $bits(axi_req_o.aw.addr)'(aw_if.awaddr);
  assign axi_req_o.aw.len    = $bits(axi_req_o.aw.len)'(aw_if.awlen);
  assign axi_req_o.aw.size   = $bits(axi_req_o.aw.size)'(aw_if.awsize);
  assign axi_req_o.aw.burst  = $bits(axi_req_o.aw.burst)'(aw_if.awburst);
  assign axi_req_o.aw.lock   = aw_if.awlock;
  assign axi_req_o.aw.cache  = $bits(axi_req_o.aw.cache)'(aw_if.awcache);
  assign axi_req_o.aw.prot   = $bits(axi_req_o.aw.prot)'(aw_if.awprot);
  assign axi_req_o.aw.qos    = $bits(axi_req_o.aw.qos)'(aw_if.awqos);
  assign axi_req_o.aw.region = $bits(axi_req_o.aw.region)'(aw_if.awregion);
  assign axi_req_o.aw.atop   = '0;
  assign axi_req_o.aw.user   = $bits(axi_req_o.aw.user)'(aw_if.awuser);
  assign axi_req_o.aw_valid  = aw_if.awvalid;
  // W
  assign axi_req_o.w.data    = w_if.wvalid ? $bits(axi_req_o.w.data)'(w_if.wdata) : '0;
  assign axi_req_o.w.strb    = w_if.wvalid ? $bits(axi_req_o.w.strb)'(w_if.wstrb) : '0;
  assign axi_req_o.w.last    = w_if.wlast;
  assign axi_req_o.w.user    = w_if.wvalid ? $bits(axi_req_o.w.user)'(w_if.wuser) : '0;
  assign axi_req_o.w_valid   = w_if.wvalid;
  // B
  assign axi_req_o.b_ready   = b_if.bready;
  // AR
  assign axi_req_o.ar.id     = $bits(axi_req_o.ar.id)'(ar_if.arid);
  assign axi_req_o.ar.addr   = $bits(axi_req_o.ar.addr)'(ar_if.araddr);
  assign axi_req_o.ar.len    = $bits(axi_req_o.ar.len)'(ar_if.arlen);
  assign axi_req_o.ar.size   = $bits(axi_req_o.ar.size)'(ar_if.arsize);
  assign axi_req_o.ar.burst  = $bits(axi_req_o.ar.burst)'(ar_if.arburst);
  assign axi_req_o.ar.lock   = ar_if.arlock;
  assign axi_req_o.ar.cache  = $bits(axi_req_o.ar.cache)'(ar_if.arcache);
  assign axi_req_o.ar.prot   = $bits(axi_req_o.ar.prot)'(ar_if.arprot);
  assign axi_req_o.ar.qos    = $bits(axi_req_o.ar.qos)'(ar_if.arqos);
  assign axi_req_o.ar.region = $bits(axi_req_o.ar.region)'(ar_if.arregion);
  assign axi_req_o.ar.user   = $bits(axi_req_o.ar.user)'(ar_if.aruser);
  assign axi_req_o.ar_valid  = ar_if.arvalid;
  // R
  assign axi_req_o.r_ready   = r_if.rready;

  // ---------------------------------------------------------------------------
  // DUT -> BFM: unpack axi_resp_i onto the agent interfaces.
  // ---------------------------------------------------------------------------
  // AW
  assign aw_if.awready = axi_resp_i.aw_ready;
  // W
  assign w_if.wready   = axi_resp_i.w_ready;
  // B
  assign b_if.bvalid = axi_resp_i.b_valid;
  assign b_if.bid    = $bits(b_if.bid)'(axi_resp_i.b.id);
  assign b_if.bresp  = $bits(b_if.bresp)'(axi_resp_i.b.resp);
  assign b_if.buser  = $bits(b_if.buser)'(axi_resp_i.b.user);
  // AR
  assign ar_if.arready = axi_resp_i.ar_ready;
  // R
  assign r_if.rvalid = axi_resp_i.r_valid;
  assign r_if.rid    = $bits(r_if.rid)'(axi_resp_i.r.id);
  assign r_if.rdata  = $bits(r_if.rdata)'(axi_resp_i.r.data);
  assign r_if.rresp  = $bits(r_if.rresp)'(axi_resp_i.r.resp);
  assign r_if.rlast  = axi_resp_i.r.last;
  assign r_if.ruser  = $bits(r_if.ruser)'(axi_resp_i.r.user);

  // ---------------------------------------------------------------------------
  // Publish the interfaces so the agent can find them without hierarchy games.
  // ---------------------------------------------------------------------------
  initial begin
    axi_agent_cfg agent_cfg = new("agent_cfg");
    agent_cfg.write_request_vif  = aw_if;
    agent_cfg.write_data_vif     = w_if;
    agent_cfg.write_response_vif = b_if;
    agent_cfg.read_request_vif   = ar_if;
    agent_cfg.read_data_vif      = r_if;
    agent_cfg.clk_rst_vif        = u_clk_rst_if;
    uvm_config_db#(axi_agent_cfg)::set(null, "*", "axi_agent_cfg", agent_cfg);
  end

endmodule
