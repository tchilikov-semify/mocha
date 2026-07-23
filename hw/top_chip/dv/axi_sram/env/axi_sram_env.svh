// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Environment
  class axi_sram_env extends uvm_env;
    `uvm_component_utils(axi_sram_env)

    axi_mgr_agent             m_agent;          // drives stimulus; its monitor feeds the scoreboard
    axi_sram_scoreboard       m_scoreboard;
    axi_sram_virtual_sequencer m_vseqr;         // hub that virtual sequences run on
    protected virtual clk_rst_if m_clk_rst_vif; // for wiring into the vseqr

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      axi_agent_cfg cfg;

      super.build_phase(phase);

      if (!uvm_config_db#(axi_agent_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal(get_full_name(), "Cannot get axi_agent cfg (key \"cfg\") from config_db")

      // Active/passive is controlled solely by cfg.is_active (default UVM_ACTIVE):
      // the monitor is always built and feeds the scoreboard; the driver side supplies stimulus.
      m_agent = axi_mgr_agent::type_id::create("m_agent", this);
      m_agent.set_cfg(cfg);

      m_scoreboard = axi_sram_scoreboard::type_id::create("m_scoreboard", this);

      m_vseqr = axi_sram_virtual_sequencer::type_id::create("m_vseqr", this);
      m_vseqr.agent_rst_vif = cfg.clk_rst_vif;
      void'(uvm_config_db#(bit [63:0])::get(this, "", "sram_base", m_vseqr.sram_base));
      if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", m_clk_rst_vif))
        `uvm_fatal(get_full_name(), "Cannot get clk_rst_vif from config_db")
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      // Feed the scoreboard from the agent's monitor (built regardless of active/passive).
      m_agent.get_monitor().tx_ap.connect(m_scoreboard.tx_imp);

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
