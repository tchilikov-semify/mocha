// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // A manager agent on each of the configuration and tagged subordinates, each taking its bus
  // from config_db, and a scoreboard fed by their monitors.
  class tagctrl_env extends uvm_env;
    `uvm_component_utils(tagctrl_env)

    axi_mgr_agent             m_cfg_agent;
    axi_mgr_agent             m_tag_agent;
    tagctrl_scoreboard        m_scoreboard;
    tagctrl_virtual_sequencer m_vseqr;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_cfg_agent  = axi_mgr_agent::type_id::create("m_cfg_agent", this);
      m_tag_agent  = axi_mgr_agent::type_id::create("m_tag_agent", this);
      m_scoreboard = tagctrl_scoreboard::type_id::create("m_scoreboard", this);
      m_vseqr      = tagctrl_virtual_sequencer::type_id::create("m_vseqr", this);
      if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif",
                                                   m_vseqr.clk_rst_vif)) begin
        `uvm_fatal(get_full_name(), "Cannot get clk_rst_vif from config_db")
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      m_cfg_agent.m_transaction_port.connect(m_scoreboard.cfg_imp);
      m_tag_agent.m_transaction_port.connect(m_scoreboard.tag_imp);
      m_tag_agent.get_reset_monitor().m_analysis_port.connect(m_scoreboard.reset_imp);

      m_vseqr.cfg_seqr      = m_cfg_agent.get_sequencer();
      m_vseqr.tag_seqr      = m_tag_agent.get_sequencer();
      m_vseqr.agent_rst_vif = m_tag_agent.get_vif().u_clk_rst_if;
    endfunction
  endclass
