// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Block-level UVM testbench: the DUT is axi_sram alone, driven directly by the
// shared AXI BFM (no chip, no crossbar). The BFM publishes the agent interfaces
// as an axi_agent_cfg, exactly like the integration harness, so the shared env
// runs unchanged -- only the base address differs (0 here vs SRAMBase on chip).

module axi_sram_block_tb;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import top_pkg::*;
  import axi_agent_pkg::*;
  import axi_sram_test_pkg::*;

  // axi_sram's word-address width for the 128 KiB / 64-bit-word geometry.
  localparam int unsigned SramAddrWidth =
      $clog2(axi_sram_test_pkg::SramSize / (top_pkg::AxiDataWidth / 8));

  wire clk;
  wire rst_n;
  clk_rst_if u_clk_rst (.clk(clk), .rst_n(rst_n));

  // DUT device-side AXI port, driven by the BFM.
  top_pkg::axi_dev_req_t  sram_req;
  top_pkg::axi_dev_resp_t sram_resp;

  axi_bfm #(
    .req_t     (top_pkg::axi_dev_req_t),
    .resp_t    (top_pkg::axi_dev_resp_t),
    .IdWidth   (top_pkg::AxiDevIdWidth),
    .AddrWidth (top_pkg::AxiAddrWidth),
    .DataWidth (top_pkg::AxiDataWidth),
    .UserWidth (top_pkg::AxiUserWidth)
  ) u_axi_bfm (
    .clk_i     (clk),
    .rst_ni    (rst_n),
    .axi_req_o (sram_req),
    .axi_resp_i(sram_resp)
  );

  axi_sram #(
    .AddrWidth(SramAddrWidth)
  ) dut (
    .clk_i     (clk),
    .rst_ni    (rst_n),
    .axi_req_i (sram_req),
    .axi_resp_o(sram_resp)
  );

  // Pre-clear the data + CHERI-tag memories at time 0 (same reason as the chip
  // harness: an X in the tag RMW read trips prim_fifo_sync DataKnown_A).
  initial begin
    foreach (dut.u_ram.mem[i])     dut.u_ram.mem[i]     = '0;
    foreach (dut.u_tag_ram.mem[i]) dut.u_tag_ram.mem[i] = '0;
  end

  initial begin
    u_clk_rst.set_freq_mhz(100);
    u_clk_rst.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_rst_vif", u_clk_rst);
    // Block DUT is addressed from 0 (no system-map aperture / crossbar).
    uvm_config_db#(bit [63:0])::set(null, "*", "sram_base", 64'h0);
    run_test();
  end

endmodule
