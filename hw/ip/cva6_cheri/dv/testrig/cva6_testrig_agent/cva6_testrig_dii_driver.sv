// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

import uvm_pkg::*;
import cva6_rvfi_pkg::*;

typedef class cva6_testrig_agent;

// This driver is a plain uvm_componment rather than a uvm_driver because it has no need for the
// sequence functionality. It's being controlled directly by DII packets from TestRIG. This is all
// handled internally to the class rather than using an external sequencer to feed in the packets.
class cva6_testrig_dii_driver extends uvm_component;
  `uvm_component_utils(cva6_testrig_dii_driver)
  `uvm_component_new

  cva6_testrig_agent agent;

  typedef enum logic [7:0] {
    DII_CMD_RST = 0,
    DII_CMD_INSN = 1,
    DII_CMD_SET_VER = 8'h76,
    DII_CMD_INTR_REQ = 8'h69,
    DII_CMD_INTR_BAR = 8'h49
  } dii_cmd_e;

  virtual cva6_dii_intf dii_vif;
  virtual clk_rst_if clk_vif;
  chandle testrig_conn;
  bit     dii_stream_begun;
  int     insn_wait_timeouts;
  int     insn_wait_timeout_limit = 10;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual clk_rst_if)::get(this, "*", "clk_if", clk_vif)) begin
      `uvm_fatal(`gfn, "clk_if must be provided");
    end

    if (!uvm_config_db#(chandle)::get(this, "*", "testrig_conn", testrig_conn)) begin
      `uvm_fatal(`gfn, "testrig_conn must be provided");
    end

    if (!uvm_config_db#(virtual cva6_dii_intf)::get(this, "*", "dii_if", dii_vif)) begin
      `uvm_fatal(`gfn, "dif_if must be provided");
    end
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    bit [31:0] dii_insn;
    bit [15:0] dii_time;
    bit [7:0]  dii_cmd;

    super.run_phase(phase);

    dii_stream_begun = 0;

    clk_vif.wait_for_reset();
    @clk_vif.cb;

    forever begin
      `uvm_info(`gfn, "Waiting for next DII packet", UVM_HIGH)

      while (!testrig_get_next_instruction(testrig_conn, dii_insn, dii_time, dii_cmd));

      dii_stream_begun = 1;
      insn_wait_timeouts = 0;

      `uvm_info(`gfn, $sformatf("Receive a DII packet %x %x %x", dii_insn, dii_time, dii_cmd),
        UVM_HIGH);

      if (dii_cmd == DII_CMD_RST) begin
        `uvm_info(`gfn, "Received reset command, inject NOPs until remaining instructions retire",
          UVM_LOW);

        // Wait for all of the injected instructions to retire.
        wait (dii_vif.test_sequence_complete || (dii_vif.num_test_insns() == 0 && dii_vif.instructions_committed == '0));

        `uvm_info(`gfn,
          $sformatf("Seen %d instructions in and %d instructions out, waiting for the rest",
          dii_vif.num_test_insns(), dii_vif.instructions_committed), UVM_LOW);

        // Tell the agent how many instructions have been injected. The hold will stop it
        // sending more than that number back on RVFI.
        agent.set_hold_rvfi_send(dii_vif.num_test_insns());
        repeat (2) @(posedge dii_vif.clk);

        // Reset the core.
        `uvm_info(`gfn, "Performing reset", UVM_LOW);
        clk_vif.apply_reset(.reset_width_clks(2));
        dii_vif.instr_buffer.delete();
      end
      if (dii_cmd == DII_CMD_SET_VER) begin
        `uvm_info(`gfn, "DII set version command not supported, ignoring", UVM_MEDIUM);
        // TODO: implement version setting when implementing RVFI V2
      end
      if (dii_cmd == DII_CMD_INTR_REQ) begin
        `uvm_info(`gfn, $sformatf("Interrupt request for MIP[%0d]", dii_insn), UVM_LOW);
        // TODO: implement interrupt request interface
        `uvm_info(`gfn, "Interrupt request logic not implemented, ignoring request", UVM_LOW);
      end
      if (dii_cmd == DII_CMD_INTR_BAR) begin
        `uvm_info(`gfn, "Interrupt barrier, injecting NOP", UVM_HIGH);
        // TODO: refactor out the duplication of code from the DII_CMD_INSN case
        // TODO: update this to fit new instantanious instruction consumption scheme
        dii_vif.instr_buffer.push_back(dii_vif.END_OF_TEST_INSTR);

      end
      if (dii_cmd == DII_CMD_INSN) begin
        `uvm_info(`gfn, $sformatf("Injecting instruction %x", dii_insn), UVM_HIGH);
        dii_vif.instr_buffer.push_back(dii_insn);
      end
    end
  endtask : run_phase
endclass
