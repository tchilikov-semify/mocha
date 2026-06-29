// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // -------------------------------------------------------------------------
  // Scoreboard — subscribes to the agent's monitor (tx_ap, fully-merged write/
  // read transactions) and checks the DUT against the reference model. Writes
  // update the model and have their BRESP checked; reads are compared beat by
  // beat on data, RUSER (CHERI tag) and RRESP.
  // -------------------------------------------------------------------------
  class axi_sram_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_sram_scoreboard)

    uvm_analysis_imp #(axi_mon_item, axi_sram_scoreboard) tx_imp;
    axi_sram_ref_model m_model;

    int unsigned m_writes, m_reads, m_data_errs, m_tag_errs, m_resp_errs;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      tx_imp = new("tx_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_model = axi_sram_ref_model::type_id::create("m_model");
    endfunction

    // Analysis callback (tx_ap only ever emits fully merged transactions).
    function void write(axi_mon_item tr);
      case (tr.obs_kind)
        AXI_FULL_WRITE_TR: check_write(tr);
        AXI_FULL_READ_TR : check_read(tr);
        default: ;
      endcase
    endfunction

    protected function void check_write(axi_mon_item tr);
      m_writes++;
      if (tr.bresp != 3'd0) begin
        `uvm_error(get_full_name(), $sformatf(
                   "write @0x%0h (id 0x%0h): BRESP=%0d (expected OKAY)", tr.awaddr, tr.bid, tr.bresp))
        m_resp_errs++;
      end
      m_model.predict_write(tr);
    endfunction

    protected function void check_read(axi_mon_item tr);
      bit [63:0] exp_data[$];
      bit        exp_user[$];
      m_reads++;
      m_model.predict_read(tr, exp_data, exp_user);
      foreach (tr.rdata[i]) begin
        bit [63:0] baddr = tr.araddr + ((tr.arburst == 2'b00) ? 0 : (64'(i) << tr.arsize));
        if (tr.rresp[i] != 3'd0) begin
          `uvm_error(get_full_name(), $sformatf(
                     "read @0x%0h beat %0d (id 0x%0h): RRESP=%0d (expected OKAY)",
                     baddr, i, tr.rid, tr.rresp[i]))
          m_resp_errs++;
        end
        if (tr.rdata[i][63:0] != exp_data[i]) begin
          `uvm_error(get_full_name(), $sformatf(
                     "read DATA @0x%0h beat %0d (id 0x%0h): got 0x%016h, model 0x%016h",
                     baddr, i, tr.rid, tr.rdata[i][63:0], exp_data[i]))
          m_data_errs++;
        end
        if (tr.ruser[i][0] != exp_user[i]) begin
          `uvm_error(get_full_name(), $sformatf(
                     "read TAG  @0x%0h beat %0d (id 0x%0h): got %0b, model %0b",
                     baddr, i, tr.rid, tr.ruser[i][0], exp_user[i]))
          m_tag_errs++;
        end
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info(get_full_name(), $sformatf({"scoreboard: %0d writes, %0d reads checked; ",
                "data_errs=%0d tag_errs=%0d resp_errs=%0d"},
                m_writes, m_reads, m_data_errs, m_tag_errs, m_resp_errs), UVM_LOW)
    endfunction
  endclass
