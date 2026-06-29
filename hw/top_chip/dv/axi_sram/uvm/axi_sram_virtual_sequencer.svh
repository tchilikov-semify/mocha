// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // -------------------------------------------------------------------------
  // Virtual sequencer — the single hub that a virtual sequence (axi_sram_base_vseq)
  // runs on. It holds handles to the active agent's per-channel AXI sequencers and
  // response routers (the *real* sequencers, where stimulus is arbitrated onto the
  // drivers), plus the clk_rst_if virtual interface. Note clock/reset is method-
  // driven (apply_reset/wait_clks), not a sequencer — so it is a *vif handle*, not
  // a sequencer handle. Wired up in axi_sram_env::connect_phase.
  // -------------------------------------------------------------------------
  class axi_sram_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(axi_sram_virtual_sequencer)

    // Real AXI channel sequencers (from the active agent).
    write_request_sequencer_t  write_request_seqr;
    write_data_sequencer_t     write_data_seqr;
    write_response_sequencer_t write_response_seqr;
    read_request_sequencer_t   read_request_seqr;
    read_data_sequencer_t      read_data_seqr;

    // ID-keyed B/R response routers used by the burst vseqs.
    axi_response_router        write_response_router;
    axi_response_router        read_response_router;

    // Clock/reset interface (method-driven: apply_reset, wait_clks, ...).
    virtual clk_rst_if         clk_rst_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass
