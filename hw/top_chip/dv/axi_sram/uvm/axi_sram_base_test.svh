// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // -------------------------------------------------------------------------
  // Base test — just builds the env. Each concrete test is a thin wrapper whose
  // run_phase starts its virtual sequence (axi_sram_*_vseq, extending
  // axi_sram_base_vseq) on m_env.m_vseqr; the read/write helper API lives in
  // axi_sram_base_vseq.
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

    // The read/write helper API and per-test stimulus now live in
    // axi_sram_base_vseq and the per-test *_vseq classes. Each *_test below is a
    // thin wrapper whose run_phase starts its vseq on m_env.m_vseqr.
  endclass
