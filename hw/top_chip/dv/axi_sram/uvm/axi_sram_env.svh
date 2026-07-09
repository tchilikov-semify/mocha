// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Environment
  class axi_sram_env extends uvm_env;
    `uvm_component_utils(axi_sram_env)

    axi_mgr_agent             m_agent;          // active: drives stimulus (and observes)
    axi_mgr_agent             m_passive_agent;  // passive: monitor-only, feeds the scoreboard
    axi_sram_scoreboard       m_scoreboard;
    axi_sram_virtual_sequencer m_vseqr;         // hub that virtual sequences run on
    protected virtual clk_rst_if m_clk_rst_vif; // for wiring into the vseqr

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

      // A second agent in PASSIVE mode on the same interfaces. With is_active =
      // UVM_PASSIVE it builds no drivers/sequencers — only the (reset + txn)
      // monitors — so it exercises the agent's monitor-only path. It shares the
      // same cfg (hence the same five vifs) as the active agent.
      uvm_config_db#(uvm_active_passive_enum)::set(this, "m_passive_agent", "is_active", UVM_PASSIVE);
      m_passive_agent = axi_mgr_agent::type_id::create("m_passive_agent", this);
      m_passive_agent.set_cfg(cfg);

      m_scoreboard = axi_sram_scoreboard::type_id::create("m_scoreboard", this);

      m_vseqr = axi_sram_virtual_sequencer::type_id::create("m_vseqr", this);
      if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", m_clk_rst_vif))
        `uvm_fatal(get_full_name(), "Cannot get clk_rst_vif from config_db")
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      // Drive the scoreboard from the PASSIVE agent's monitor: the active agent
      // drives the bus, the passive agent only observes it.
      m_passive_agent.get_monitor().tx_ap.connect(m_scoreboard.tx_imp);

      // Populate the virtual sequencer with handles to the active agent's real
      // channel sequencers + routers, and the clock/reset vif.
      m_vseqr.write_request_seqr    = m_agent.get_write_request_sequencer();
      m_vseqr.write_data_seqr       = m_agent.get_write_data_sequencer();
      m_vseqr.write_response_seqr   = m_agent.get_write_response_sequencer();
      m_vseqr.read_request_seqr     = m_agent.get_read_request_sequencer();
      m_vseqr.read_data_seqr        = m_agent.get_read_data_sequencer();
      m_vseqr.write_response_router = m_agent.get_write_response_router();
      m_vseqr.read_response_router  = m_agent.get_read_response_router();
      m_vseqr.clk_rst_vif           = m_clk_rst_vif;
    endfunction
  endclass
