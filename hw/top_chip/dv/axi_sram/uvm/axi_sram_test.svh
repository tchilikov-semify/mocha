// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  class axi_sram_rst_sanity_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_rst_sanity_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_rst_sanity_vseq vseq = axi_sram_rst_sanity_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_write_read_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_write_read_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      axi_sram_write_read_vseq vseq = axi_sram_write_read_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_data_all_bits_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_data_all_bits_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_data_all_bits_vseq vseq = axi_sram_data_all_bits_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_address_boundaries_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_address_boundaries_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_address_boundaries_vseq vseq = axi_sram_address_boundaries_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_burst_last_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_burst_last_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_burst_last_vseq vseq = axi_sram_burst_last_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_resp_id_match_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_resp_id_match_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      axi_sram_resp_id_match_vseq vseq = axi_sram_resp_id_match_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_tag_write_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_tag_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      axi_sram_tag_write_vseq vseq = axi_sram_tag_write_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_no_tag_single_beat_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_no_tag_single_beat_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_no_tag_single_beat_vseq vseq = axi_sram_no_tag_single_beat_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_tag_cleared_by_write_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_tag_cleared_by_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_tag_cleared_by_write_vseq vseq = axi_sram_tag_cleared_by_write_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_tag_isolation_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_tag_isolation_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_tag_isolation_vseq vseq = axi_sram_tag_isolation_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_cap_ruser_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_cap_ruser_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_cap_ruser_vseq vseq = axi_sram_cap_ruser_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_aligned_only_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_aligned_only_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_aligned_only_vseq vseq = axi_sram_aligned_only_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_no_tag_misaligned_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_no_tag_misaligned_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_no_tag_misaligned_vseq vseq = axi_sram_no_tag_misaligned_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_no_tag_two_bursts_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_no_tag_two_bursts_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_no_tag_two_bursts_vseq vseq = axi_sram_no_tag_two_bursts_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_wuser_mismatch_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_wuser_mismatch_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_wuser_mismatch_vseq vseq = axi_sram_wuser_mismatch_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_partial_strobe_clears_tag_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_partial_strobe_clears_tag_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_partial_strobe_clears_tag_vseq vseq = axi_sram_partial_strobe_clears_tag_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_subword_read_clears_tag_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_subword_read_clears_tag_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_subword_read_clears_tag_vseq vseq = axi_sram_subword_read_clears_tag_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_concurrent_data_tag_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_concurrent_data_tag_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_concurrent_data_tag_vseq vseq = axi_sram_concurrent_data_tag_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_random_data_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_random_data_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_random_data_vseq vseq = axi_sram_random_data_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_random_capabilities_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_random_capabilities_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_random_capabilities_vseq vseq = axi_sram_random_capabilities_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_init_value_undefined_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_init_value_undefined_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_init_value_undefined_vseq vseq = axi_sram_init_value_undefined_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_execute_from_sram_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_execute_from_sram_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_execute_from_sram_vseq vseq = axi_sram_execute_from_sram_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_burst_read_mixed_tags_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_burst_read_mixed_tags_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_burst_read_mixed_tags_vseq vseq = axi_sram_burst_read_mixed_tags_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_out_of_range_error_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_out_of_range_error_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_out_of_range_error_vseq vseq = axi_sram_out_of_range_error_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_sram_atomics_excluded_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_atomics_excluded_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      axi_sram_atomics_excluded_vseq vseq = axi_sram_atomics_excluded_vseq::type_id::create("vseq");
      phase.raise_objection(this);
      vseq.start(m_env.m_vseqr);
      phase.drop_objection(this);
    endtask
  endclass
