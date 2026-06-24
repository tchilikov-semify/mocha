// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// UVM test package for axi_sram.
//
// Contains:
//   axi_sram_env           — UVM environment (wraps axi_mgr_agent)
//   axi_sram_base_test     — Base test: builds the env, provides helpers
//   axi_sram_write_read_test — Smoke test: single write, read back, check data

package axi_sram_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_agent_pkg::*;

  // -------------------------------------------------------------------------
  // Environment
  // -------------------------------------------------------------------------
  class axi_sram_env extends uvm_env;
    `uvm_component_utils(axi_sram_env)

    axi_mgr_agent m_agent;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      axi_agent_cfg cfg;
      virtual axi_write_request_if  wr_req_vif;
      virtual axi_write_data_if     wr_dat_vif;
      virtual axi_write_response_if wr_rsp_vif;
      virtual axi_read_request_if   rd_req_vif;
      virtual axi_read_data_if      rd_dat_vif;

      super.build_phase(phase);

      // Retrieve virtual interfaces from config_db
      if (!uvm_config_db#(virtual axi_write_request_if)::get(
            this, "", "write_request_vif", wr_req_vif))
        `uvm_fatal(get_full_name(), "Cannot get write_request_vif from config_db")
      if (!uvm_config_db#(virtual axi_write_data_if)::get(
            this, "", "write_data_vif", wr_dat_vif))
        `uvm_fatal(get_full_name(), "Cannot get write_data_vif from config_db")
      if (!uvm_config_db#(virtual axi_write_response_if)::get(
            this, "", "write_response_vif", wr_rsp_vif))
        `uvm_fatal(get_full_name(), "Cannot get write_response_vif from config_db")
      if (!uvm_config_db#(virtual axi_read_request_if)::get(
            this, "", "read_request_vif", rd_req_vif))
        `uvm_fatal(get_full_name(), "Cannot get read_request_vif from config_db")
      if (!uvm_config_db#(virtual axi_read_data_if)::get(
            this, "", "read_data_vif", rd_dat_vif))
        `uvm_fatal(get_full_name(), "Cannot get read_data_vif from config_db")

      // Build cfg, wire up virtual interfaces, and hand to agent before its build_phase
      cfg = axi_agent_cfg::type_id::create("cfg");
      cfg.write_request_vif  = wr_req_vif;
      cfg.write_data_vif     = wr_dat_vif;
      cfg.write_response_vif = wr_rsp_vif;
      cfg.read_request_vif   = rd_req_vif;
      cfg.read_data_vif      = rd_dat_vif;

      m_agent = axi_mgr_agent::type_id::create("m_agent", this);
      m_agent.set_cfg(cfg);
    endfunction
  endclass

  // -------------------------------------------------------------------------
  // Base test
  // -------------------------------------------------------------------------
  class axi_sram_base_test extends uvm_test;
    `uvm_component_utils(axi_sram_base_test)

    axi_sram_env m_env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_env = axi_sram_env::type_id::create("m_env", this);
    endfunction
  endclass

  // -------------------------------------------------------------------------
  // Write-read smoke test
  //
  // Writes a known 64-bit pattern to SRAM word 0, reads it back and checks it.
  // Uses axi_mgr_write_fixed_vseq / axi_mgr_read_fixed_vseq (FIXED burst,
  // single beat, 8-byte transfer).
  // -------------------------------------------------------------------------
  class axi_sram_write_read_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_write_read_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      axi_mgr_write_fixed_vseq wr_seq;
      axi_mgr_read_fixed_vseq  rd_seq;
      virtual axi_write_request_if vif;

      // Test stimulus values
      bit [63:0]  test_data = 64'hC0FFEE_DE_ADBEEF_12;
      bit [63:0]  test_addr = 64'h0000_0000_0000_0000; // SRAM word 0

      phase.raise_objection(this);

      // Wait for reset to deassert before issuing transactions
      if (!uvm_config_db#(virtual axi_write_request_if)::get(
            this, "", "write_request_vif", vif))
        `uvm_fatal(get_full_name(), "Cannot get write_request_vif from config_db")
      @(posedge vif.rst_ni);
      repeat (2) @(posedge vif.clk_i);

      // ------------------------------------------------------------------ WRITE
      wr_seq = axi_mgr_write_fixed_vseq::type_id::create("wr_seq");

      // Request fields (awid within AxiIdWidth, awaddr = target word)
      wr_seq.m_fixed_req.m_id             = 32'd1;
      wr_seq.m_fixed_req.m_addr           = test_addr;
      wr_seq.m_fixed_req.m_size           = 3'd3;    // 8 bytes
      wr_seq.m_fixed_req.m_region         = '0;
      wr_seq.m_fixed_req.m_lock           = '0;
      wr_seq.m_fixed_req.m_cache          = '0;
      wr_seq.m_fixed_req.m_prot           = '0;
      wr_seq.m_fixed_req.m_qos            = '0;
      wr_seq.m_fixed_req.m_user           = '0;

      // Write data: lower 64 bits carry the payload; interface masks the rest
      wr_seq.m_fixed_req.m_write_data_item.m_data = 1024'(test_data);
      wr_seq.m_fixed_req.m_write_data_item.m_strb = 128'h0000_0000_0000_0000_0000_0000_0000_00FF;
      wr_seq.m_fixed_req.m_write_data_item.m_user = '0;   // no CHERI tag
      wr_seq.m_fixed_req.m_write_data_item.m_last = 1'b1; // single beat

      wr_seq.set_write_response_router(m_env.m_agent.get_write_response_router());
      wr_seq.set_sequencers(
        m_env.m_agent.get_write_request_sequencer(),
        m_env.m_agent.get_write_data_sequencer(),
        m_env.m_agent.get_write_response_sequencer()
      );
      wr_seq.start(null);

      // Check response
      if (wr_seq.rsp == null)
        `uvm_fatal(get_full_name(), "Write sequence completed with null response (reset?)")
      if (wr_seq.rsp.m_write_response == null)
        `uvm_fatal(get_full_name(), "Write B-channel response is null (reset during transfer?)")
      if (wr_seq.rsp.m_write_response.m_resp != axi_write_response_item::BRespOkay)
        `uvm_error(get_full_name(), $sformatf(
          "Write got non-OKAY BRESP: %0d (expected BRespOkay=0)",
          wr_seq.rsp.m_write_response.m_resp))
      else
        `uvm_info(get_full_name(), "Write completed with OKAY response.", UVM_LOW)

      // ------------------------------------------------------------------ READ
      rd_seq = axi_mgr_read_fixed_vseq::type_id::create("rd_seq");

      rd_seq.m_fixed_req.m_id     = 32'd1;
      rd_seq.m_fixed_req.m_addr   = test_addr;
      rd_seq.m_fixed_req.m_size   = 3'd3;
      rd_seq.m_fixed_req.m_region = '0;
      rd_seq.m_fixed_req.m_lock   = '0;
      rd_seq.m_fixed_req.m_cache  = '0;
      rd_seq.m_fixed_req.m_prot   = '0;
      rd_seq.m_fixed_req.m_qos    = '0;
      rd_seq.m_fixed_req.m_user   = '0;

      rd_seq.set_read_response_router(m_env.m_agent.get_read_response_router());
      rd_seq.set_sequencers(
        m_env.m_agent.get_read_request_sequencer(),
        m_env.m_agent.get_read_data_sequencer()
      );
      rd_seq.start(null);

      // Check response and data
      if (rd_seq.rsp == null)
        `uvm_fatal(get_full_name(), "Read sequence completed with null response (reset?)")
      if (rd_seq.rsp.m_read_data == null)
        `uvm_fatal(get_full_name(), "Read R-channel data is null (reset during transfer?)")
      if (rd_seq.rsp.m_read_data.m_resp != axi_read_data_item::RRespOkay)
        `uvm_error(get_full_name(), $sformatf(
          "Read got non-OKAY RRESP: %0d (expected RRespOkay=0)",
          rd_seq.rsp.m_read_data.m_resp))
      if (rd_seq.rsp.m_read_data.m_data[63:0] != test_data)
        `uvm_error(get_full_name(), $sformatf(
          "Read data mismatch: expected 0x%0h, got 0x%0h",
          test_data, rd_seq.rsp.m_read_data.m_data[63:0]))
      else
        `uvm_info(get_full_name(), "Read data matches written value — PASS!", UVM_LOW)

      phase.drop_objection(this);
    endtask
  endclass

endpackage
