// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // base test which builds the env. Each concrete test is a thin wrapper whose
  // run_phase starts its virtual sequence  on m_env.m_vseqr
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

    // Emit the dvsim pass/fail signature  so dvsim's run_pass_patterns can grade the run.
    function void report_phase(uvm_phase phase);
      uvm_report_server rs = uvm_report_server::get_server();
      super.report_phase(phase);
      dv_test_status_pkg::dv_test_status((rs.get_severity_count(UVM_ERROR) == 0) &&
                                         (rs.get_severity_count(UVM_FATAL) == 0));
    endfunction

  endclass
