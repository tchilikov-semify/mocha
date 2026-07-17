// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Drop-in replacement for the CVA6 core in mocha.

module axi_driver_wrapper import top_pkg::*; #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = '0,
  parameter type axi_ar_chan_t = logic,
  parameter type axi_aw_chan_t = logic,
  parameter type axi_w_chan_t  = logic,
  parameter type b_chan_t      = logic,
  parameter type r_chan_t      = logic,
  parameter type noc_req_t     = top_pkg::axi_req_t,
  parameter type noc_resp_t    = top_pkg::axi_resp_t,
  parameter type rvfi_probes_t = logic,
  parameter type cvxif_req_t   = logic,
  parameter type cvxif_resp_t  = logic
) (
  input  logic         clk_i,
  input  logic         rst_ni,
  output noc_req_t     noc_req_o,   // AXI4 outputs
  input  noc_resp_t    noc_resp_i,  // AXI4 inputs

  // Ignored
  input  logic [CVA6Cfg.PCLEN-1:0]  boot_addr_i,
  input  logic [CVA6Cfg.XLEN-1:0]   hart_id_i,
  input  logic [1:0]                irq_i,
  input  logic                      ipi_i,
  input  logic                      time_irq_i,
  input  logic                      debug_req_i,
  output rvfi_probes_t              rvfi_probes_o,
  output cvxif_req_t                cvxif_req_o,
  input  cvxif_resp_t               cvxif_resp_i
);
  // unused tie-offs
  assign rvfi_probes_o = '0;
  assign cvxif_req_o   = '0;

  axi_bfm #(
    .req_t     (noc_req_t),
    .resp_t    (noc_resp_t),
    .IdWidth   (CVA6Cfg.AxiIdWidth),
    .AddrWidth (CVA6Cfg.AxiAddrWidth),
    .DataWidth (CVA6Cfg.AxiDataWidth),
    .UserWidth (CVA6Cfg.AxiUserWidth)
  ) u_axi_bfm (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .axi_req_o (noc_req_o),
    .axi_resp_i(noc_resp_i)
  );

endmodule
