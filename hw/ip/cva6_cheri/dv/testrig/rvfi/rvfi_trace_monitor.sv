// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Logs every RVFI-committed instruction to a file.
//
// One line is written per retired instruction:
//   .4byte 0xXXXXXXXX
//
// The file is overwritten (started fresh) each time reset deasserts, so each
// test trace begins at line 1. Instantiate alongside the DUT and connect the
// RVFI outputs directly.
//
// Parameters:
//   TRACE_FILE  – path/name of the output file (default: "rvfi_trace.S")
//
// Ports (all driven from the RVFI outputs):
//   clk_i    – simulation clock
//   rst_ni   – active-low reset (same signal as the DUT's rst_ni)
//   valid_i  – rvfi_valid: high when an instruction retires this cycle
//   insn_i   – rvfi_insn:  the 32-bit encoding of the retired instruction

module rvfi_trace_monitor #(
  parameter string TRACE_FILE = "rvfi_trace.S"
) (
  input logic        clk_i,
  input logic        rst_ni,
  input logic        valid_i,
  input logic [31:0] insn_i
);

  int unsigned fd;

  // --------------------------------------------------------------------------
  // File lifecycle: open fresh on every reset deassertion.
  // The always @(posedge rst_ni) fires on the very first deassertion as well
  // as on every subsequent test boundary, so no separate initial open is
  // needed.
  // --------------------------------------------------------------------------
  initial fd = 0;

  always @(posedge rst_ni) begin
    if (fd != 0) $fclose(fd);
    fd = $fopen(TRACE_FILE, "w");
    if (fd == 0)
      $fatal(1, "rvfi_trace_logger: could not open trace file '%s'", TRACE_FILE);
  end

  // --------------------------------------------------------------------------
  // Instruction logging: one line per retired instruction.
  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (rst_ni && valid_i && fd != 0) begin
      $fwrite(fd, ".4byte 0x%08x\n", insn_i);
      $fflush(fd);
    end
  end

  // --------------------------------------------------------------------------
  // Close on simulation end so the OS flushes any remaining buffered output.
  // --------------------------------------------------------------------------
  final begin
    if (fd != 0) $fclose(fd);
  end

endmodule
