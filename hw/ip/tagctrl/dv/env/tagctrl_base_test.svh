// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Builds the env, then randomises the vseq named by +UVM_TEST_SEQ and runs it on m_env.m_vseqr.
  class tagctrl_base_test extends uvm_test;
    `uvm_component_utils(tagctrl_base_test)

    tagctrl_env m_env;

    // Overridable with +test_timeout_ns=N
    longint unsigned test_timeout_ns = 20_000_000;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_env = tagctrl_env::type_id::create("m_env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      void'($value$plusargs("test_timeout_ns=%0d", test_timeout_ns));
      uvm_top.set_timeout(test_timeout_ns * 1ns);
    endfunction

    task run_phase(uvm_phase phase);
      string       test_seq_s;
      uvm_sequence test_seq;

      if (!$value$plusargs("UVM_TEST_SEQ=%0s", test_seq_s)) begin
        `uvm_fatal(get_full_name(), "No +UVM_TEST_SEQ given")
      end
      if (!$cast(test_seq,
                 uvm_factory::get().create_object_by_name(test_seq_s, "", test_seq_s))) begin
        `uvm_fatal(get_full_name(), {"Cannot create sequence ", test_seq_s})
      end
      if (!test_seq.randomize()) begin
        `uvm_fatal(get_full_name(), {"Cannot randomize ", test_seq_s})
      end
      phase.raise_objection(this);
      test_seq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask

    // Emit the pass/fail status line from the UVM error and fatal tallies
    function void report_phase(uvm_phase phase);
      uvm_report_server rs = uvm_report_server::get_server();
      super.report_phase(phase);
      dv_test_status_pkg::dv_test_status((rs.get_severity_count(UVM_ERROR) == 0) &&
                                         (rs.get_severity_count(UVM_FATAL) == 0));
    endfunction
  endclass
