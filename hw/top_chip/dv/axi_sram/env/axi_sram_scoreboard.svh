// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Scoreboard — subscribes to the agent's monitor (tx_ap) and checks the DUT
  // against the reference model. Because the SRAM now sits behind the crossbar,
  // it also validates the address decode: an access inside the SRAM aperture must
  // return OKAY (with the modelled data/tag), and an access outside it must return
  // an error (the xbar / axi_err_slv DECERR) — an OKAY there is a decode bug.
  class axi_sram_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_sram_scoreboard)

    uvm_analysis_imp #(axi_mon_item, axi_sram_scoreboard) tx_imp;
    axi_sram_ref_model m_model;

    int unsigned m_writes, m_reads, m_oor_writes, m_oor_reads;
    int unsigned m_data_errs, m_tag_errs, m_resp_errs;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      tx_imp = new("tx_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_model = axi_sram_ref_model::type_id::create("m_model");
      void'(uvm_config_db#(bit [63:0])::get(this, "", "sram_base", m_model.m_sram_base));
    endfunction

    // Analysis callback (tx_ap only ever emits fully merged transactions).
    function void write(axi_mon_item tr);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      if      ($cast(wr, tr)) check_write(wr);
      else if ($cast(rd, tr)) check_read(rd);
    endfunction

    protected function void check_write(axi_mon_write_item tr);
      m_writes++;
      if (m_model.in_sram(tr.awaddr)) begin
        if (tr.bresp != 3'd0) begin
          `uvm_error(get_full_name(), $sformatf(
                     "in-SRAM write @0x%0h (id 0x%0h): BRESP=%0d (expected OKAY)",
                     tr.awaddr, tr.bid, tr.bresp))
          m_resp_errs++;
        end
        m_model.predict_write(tr);
      end else begin
        m_oor_writes++;
        if (tr.bresp == 3'd0) begin
          `uvm_error(get_full_name(), $sformatf(
                     "out-of-SRAM write @0x%0h returned OKAY (address decode error)", tr.awaddr))
          m_resp_errs++;
        end
      end
    endfunction

    protected function void check_read(axi_mon_read_item tr);
      bit [63:0] exp_data[$];
      bit        exp_user[$];
      m_reads++;
      if (m_model.in_sram(tr.araddr)) begin
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
      end else begin
        m_oor_reads++;
        foreach (tr.rresp[i]) begin
          if (tr.rresp[i] == 3'd0) begin
            `uvm_error(get_full_name(), $sformatf(
                       "out-of-SRAM read @0x%0h beat %0d returned OKAY (address decode error)",
                       tr.araddr, i))
            m_resp_errs++;
          end
        end
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info(get_full_name(), $sformatf({"scoreboard: %0d writes (%0d out-of-SRAM), ",
                "%0d reads (%0d out-of-SRAM) checked; data_errs=%0d tag_errs=%0d resp_errs=%0d"},
                m_writes, m_oor_writes, m_reads, m_oor_reads,
                m_data_errs, m_tag_errs, m_resp_errs), UVM_LOW)
    endfunction
  endclass
