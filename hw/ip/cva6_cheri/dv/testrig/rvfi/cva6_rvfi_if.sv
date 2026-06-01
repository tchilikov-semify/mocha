// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Interface to probe Ibex RVFI interface
interface cva6_rvfi_if(input logic clk);
  logic        reset;
  logic        valid;
  logic [63:0] order;
  logic [31:0] insn;
  logic        trap;
  logic        halt;
  logic        intr;
  logic [1:0]  mode;
  logic [1:0]  ixl;
  logic [4:0]  rs1_addr;
  logic [4:0]  rs2_addr;
  logic [63:0] rs1_rdata;
  logic [63:0] rs2_rdata;
  logic [4:0]  rd_addr;
  logic [63:0] rd_wdata;
  logic [63:0] pc_rdata;
  logic [63:0] pc_wdata;
  logic [63:0] mem_addr;
  logic [63:0] mem_paddr;
  logic [7:0]  mem_rmask;
  logic [7:0]  mem_wmask;
  logic [63:0] mem_rdata;
  logic [63:0] mem_wdata;
  logic [63:0] ext_mip;
  logic [63:0] ext_mcycle;

  clocking monitor_cb @(posedge clk);
    input reset;
    input valid;
    input order;
    input insn;
    input trap;
    input halt;
    input intr;
    input mode;
    input ixl;
    input rs1_addr;
    input rs2_addr;
    input rs1_rdata;
    input rs2_rdata;
    input rd_addr;
    input rd_wdata;
    input pc_rdata;
    input pc_wdata;
    input mem_addr;
    input mem_rmask;
    input mem_wmask;
    input mem_rdata;
    input mem_wdata;
    input ext_mip;
    input ext_mcycle;
  endclocking

  task automatic wait_clks(input int num);
    repeat (num) @(posedge clk);
  endtask

  // this should honestly be checked in testRig... not sure why its not.
  `define NO_X_CHECK(SIGNAL) \
    property p_no_x_``SIGNAL; \
      @(posedge clk) \
      disable iff (reset) valid && !trap |-> !$isunknown(SIGNAL); \
    endproperty \
    a_no_x_``SIGNAL: assert property (p_no_x_``SIGNAL) \
      else $fatal(1, "Assertion Failed: %s contains an X", `"SIGNAL`");

  `NO_X_CHECK(rs1_addr)
  `NO_X_CHECK(rs2_addr)
  `NO_X_CHECK(rs1_rdata)
  `NO_X_CHECK(rs2_rdata)
  `NO_X_CHECK(rd_addr)
  `NO_X_CHECK(rd_wdata)
  `NO_X_CHECK(pc_rdata)
  `NO_X_CHECK(pc_wdata)
endinterface
