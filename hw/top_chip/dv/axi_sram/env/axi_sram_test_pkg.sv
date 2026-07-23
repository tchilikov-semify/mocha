// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// UVM test package for axi_sram. Each block lives in its own file and is
// `included here in dependency order:
//
//   axi_sram_ref_model.svh          — behavioural data + CHERI-tag shadow
//   axi_sram_scoreboard.svh         — checks the DUT vs the reference model
//   axi_sram_virtual_sequencer.svh  — hub of AXI channel sequencers + clk_rst vif
//   axi_sram_env.svh                — wraps the active + passive agents, scoreboard
//   axi_sram_base_vseq.svh          — read/write helper API (runs on the vseqr)
//   axi_sram_base_test.svh          — builds the env
//   axi_sram_vseqs.svh              — one virtual sequence per vplan item (body)
//   axi_sram_test.svh              — one thin test per vplan item (starts its vseq)
//
// The assert-style vplan items live as SystemVerilog assertions in
// mocha_axi_bfm_tb.sv (interface_geometry / sram_geometry, bounded_response,
// assert_wuser_not_full_cap (bj8we7), assert_wuser_mismatch (9a3xf6),
// tag_separate_memory).

package axi_sram_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_agent_pkg::*;

  // SRAM geometry (mirrors top_pkg / axi_sram parameters and the cocotb TB).
  localparam longint unsigned SramSize     = 128 * 1024;       // bytes
  localparam int unsigned     WordBytes    = 8;                // AXI data width / 8
  localparam int unsigned     CapBytes     = 16;               // CHERI capability (128-bit)
  localparam bit [63:0]       LastWordAddr = SramSize - WordBytes;  // 0x1FFF8
  localparam bit [63:0]       LastCapAddr  = SramSize - CapBytes;   // 0x1FFF0

  // Components and sequences, in dependency order.
  `include "axi_sram_ref_model.svh"
  `include "axi_sram_scoreboard.svh"
  `include "axi_sram_virtual_sequencer.svh"
  `include "axi_sram_env.svh"
  `include "axi_sram_base_vseq.svh"
  `include "axi_sram_base_test.svh"
  `include "axi_sram_vseqs.svh"
  `include "axi_sram_test.svh"
endpackage
