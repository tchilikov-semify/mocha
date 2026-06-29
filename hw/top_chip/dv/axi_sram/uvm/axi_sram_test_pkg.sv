// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// UVM test package for axi_sram.
//
// Contains:
//   axi_sram_env        — UVM environment (wraps axi_mgr_agent)
//   axi_sram_base_test  — Base test: builds the env and provides word/capability/burst
//                         read+write helper tasks shared by all tests
//   ...and one test per verification-plan item (axi_sram_vplan.csv):
//   P1: rst_sanity, write_read, data_all_bits, address_boundaries, burst_last,
//       resp_id_match, tag_write, no_tag_single_beat, tag_cleared_by_write,
//       tag_isolation, cap_ruser
//   P2: aligned_only, no_tag_misaligned, no_tag_two_bursts, wuser_mismatch,
//       partial_strobe_clears_tag, subword_read_clears_tag, concurrent_data_tag,
//       random_data, random_capabilities
//   P3: init_value_undefined, execute_from_sram, burst_read_mixed_tags,
//       out_of_range_error (out of scope), atomics_excluded (spec exclusion)
// (each is class axi_sram_<name>_test).
//
// The assert-style vplan items live as SystemVerilog assertions in
// axi_sram_uvm_tb.sv: interface_geometry / sram_geometry (P1), bounded_response,
// assert_wuser_not_full_cap (bj8we7), assert_wuser_mismatch (9a3xf6) (P2), and
// tag_separate_memory (P3, structural note). bj8we7 is exercised by the no_tag_*
// tests; 9a3xf6 by wuser_mismatch.

package axi_sram_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_agent_pkg::*;

  // SRAM geometry (mirrors top_pkg / axi_sram parameters and the cocotb TB).
  localparam longint unsigned SramSize     = 128 * 1024;       // bytes
  localparam int unsigned     WordBytes    = 8;                // AXI data width / 8
  localparam int unsigned     CapBytes     = 16;               // CHERI capability (128-bit)
  localparam bit [63:0]       LastWordAddr = SramSize - WordBytes;  // 0x1FFF8
  localparam bit [63:0]       LastCapAddr  = SramSize - CapBytes;   // 0x1FFF0

  // -------------------------------------------------------------------------
  // Reference model — behavioural shadow of the SRAM (data + CHERI tags).
  //
  // Updated from observed write transactions; queried to predict read-backs. It
  // encodes the DUT's tag rules: a region's tag is *set* only by a full
  // capability write (awlen==1, awsize==3, 16-byte-aligned, full strobes on both
  // beats, both beats agreeing on wuser); any other write touching a region
  // *clears* it. On reads, a region's tag is returned only for a capability-sized
  // read (arlen==1 && arsize==3); every other read returns a cleared tag flit.
  //
  // Data is byte-addressed and sparse; never-written bytes read back as 0, which
  // matches the TB's power-up zeroing of the data/tag RAMs.
  // -------------------------------------------------------------------------
  class axi_sram_ref_model extends uvm_object;
    `uvm_object_utils(axi_sram_ref_model)

    protected bit [7:0] m_data [bit [63:0]];   // byte address -> byte
    protected bit       m_tag  [bit [63:0]];   // 16-byte region base -> tag

    function new(string name = "axi_sram_ref_model");
      super.new(name);
    endfunction

    protected function automatic bit [63:0] region_base(bit [63:0] addr);
      return addr & ~64'hF;
    endfunction

    // Address of beat `i` of a burst (FIXED repeats the address; INCR steps by
    // the beat size). axi_sram never uses WRAP, so it is treated as INCR.
    protected function automatic bit [63:0] beat_addr(bit [63:0] base, bit [2:0] size,
                                                      bit [1:0] burst, int i);
      if (burst == 2'b00) return base;                 // FIXED
      return base + (64'(i) * (64'd1 << size));        // INCR
    endfunction

    // Apply an observed full write transaction.
    function void predict_write(axi_mon_item tr);
      int        nbeats   = int'(tr.awlen) + 1;
      bit [63:0] base     = tr.awaddr;
      bit        cap_user = tr.wuser[0][0];
      bit        full_cap = (tr.awlen == 8'd1) && (tr.awsize == 3'd3) && (base[3:0] == 4'd0);

      foreach (tr.wstrb[i]) if (tr.wstrb[i][7:0] !== 8'hFF)    full_cap = 1'b0;
      foreach (tr.wuser[i]) if (tr.wuser[i][0]   !== cap_user) full_cap = 1'b0;

      // Data: commit each enabled byte lane to its byte address.
      for (int i = 0; i < nbeats; i++) begin
        bit [63:0] baddr = beat_addr(base, tr.awsize, tr.awburst, i);
        bit [63:0] wbase = baddr & ~64'h7;             // 8-byte bus-word base
        for (int lane = 0; lane < 8; lane++)
          if (tr.wstrb[i][lane]) m_data[wbase + lane] = tr.wdata[i][8*lane +: 8];
      end

      // Tag: set only for a full capability write, else clear every touched region.
      if (full_cap) begin
        m_tag[region_base(base)] = cap_user;
      end else begin
        for (int i = 0; i < nbeats; i++)
          m_tag[region_base(beat_addr(base, tr.awsize, tr.awburst, i))] = 1'b0;
      end
    endfunction

    // Expected 8-byte read-back for the word containing `word_base`.
    function automatic bit [63:0] expected_word(bit [63:0] word_base);
      expected_word = '0;
      for (int lane = 0; lane < 8; lane++)
        if (m_data.exists(word_base + lane))
          expected_word[8*lane +: 8] = m_data[word_base + lane];
    endfunction

    // Predict the per-beat data and RUSER (tag) of an observed read transaction.
    function void predict_read(axi_mon_item tr, output bit [63:0] exp_data[$],
                                                output bit        exp_user[$]);
      int  nbeats   = int'(tr.arlen) + 1;
      bit  cap_read = (tr.arlen == 8'd1) && (tr.arsize == 3'd3);
      exp_data.delete();
      exp_user.delete();
      for (int i = 0; i < nbeats; i++) begin
        bit [63:0] baddr = beat_addr(tr.araddr, tr.arsize, tr.arburst, i);
        bit [63:0] reg_b = region_base(baddr);
        exp_data.push_back(expected_word(baddr & ~64'h7));
        exp_user.push_back((cap_read && m_tag.exists(reg_b)) ? m_tag[reg_b] : 1'b0);
      end
    endfunction
  endclass

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

  // -------------------------------------------------------------------------
  // Environment
  // -------------------------------------------------------------------------
  class axi_sram_env extends uvm_env;
    `uvm_component_utils(axi_sram_env)

    axi_mgr_agent       m_agent;          // active: drives stimulus (and observes)
    axi_mgr_agent       m_passive_agent;  // passive: monitor-only, feeds the scoreboard
    axi_sram_scoreboard m_scoreboard;

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
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      // Drive the scoreboard from the PASSIVE agent's monitor: the active agent
      // drives the bus, the passive agent only observes it.
      m_passive_agent.get_monitor().tx_ap.connect(m_scoreboard.tx_imp);
    endfunction
  endclass

  // -------------------------------------------------------------------------
  // Base test — builds the env and provides the read/write helper API.
  //
  // All stimulus goes through axi_mgr_write_burst_vseq / axi_mgr_read_burst_vseq
  // (single-beat helpers use a length-1 burst). Helpers check the AXI response
  // codes; functional value checking is left to the individual tests.
  // -------------------------------------------------------------------------
  class axi_sram_base_test extends uvm_test;
    `uvm_component_utils(axi_sram_base_test)

    axi_sram_env m_env;

    // When set, the read/write helpers additionally assert that each B/R response
    // carries the AXI ID of its originating request (used by resp_id_match).
    protected bit m_check_resp_id = 1'b0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_env = axi_sram_env::type_id::create("m_env", this);
    endfunction

    // ----------------------------------------------------------------- helpers

    // Wait for reset to deassert, then a couple of clocks, before issuing traffic.
    protected task automatic await_reset();
      virtual axi_write_request_if vif;
      if (!uvm_config_db#(virtual axi_write_request_if)::get(
            this, "", "write_request_vif", vif))
        `uvm_fatal(get_full_name(), "Cannot get write_request_vif from config_db")
      @(posedge vif.rst_ni);
      repeat (2) @(posedge vif.clk_i);
    endtask

    // Build a single write-data beat.
    protected function automatic axi_write_data_item make_wd(bit [63:0] data,
                                                             bit [7:0]  strb,
                                                             bit        tag,
                                                             bit        last);
      axi_write_data_item it = axi_write_data_item::type_id::create("wd");
      it.m_data = 1024'(data);    // interface uses the low AxiDataWidth (64) bits
      it.m_strb = 128'(strb);     // interface uses the low AxiDataWidth/8 (8) bits
      it.m_user = 512'(tag);      // WUSER carries the CHERI tag in bit[0]
      it.m_last = last;
      return it;
    endfunction

    // Drive a prepared write burst and check the B response.
    protected task automatic run_write(axi_mgr_write_burst_vseq seq, string ctx);
      seq.set_write_response_router(m_env.m_agent.get_write_response_router());
      seq.set_sequencers(m_env.m_agent.get_write_request_sequencer(),
                         m_env.m_agent.get_write_data_sequencer(),
                         m_env.m_agent.get_write_response_sequencer());
      seq.start(null);
      if (seq.rsp == null || seq.rsp.m_write_response == null)
        `uvm_fatal(get_full_name(), {ctx, ": write completed with null B response (reset?)"})
      if (seq.rsp.m_write_response.m_resp != axi_write_response_item::BRespOkay)
        `uvm_error(get_full_name(), $sformatf("%s: non-OKAY BRESP %0d", ctx,
                   seq.rsp.m_write_response.m_resp))
      if (m_check_resp_id && seq.rsp.m_write_response.m_id != seq.m_id)
        `uvm_error(get_full_name(), $sformatf("%s: BID 0x%0h != AWID 0x%0h", ctx,
                   seq.rsp.m_write_response.m_id, seq.m_id))
    endtask

    // Drive a prepared read burst, check the beat count and R responses.
    protected task automatic run_read(axi_mgr_read_burst_vseq seq, string ctx,
                                      int unsigned exp_beats);
      seq.set_read_response_router(m_env.m_agent.get_read_response_router());
      seq.set_sequencers(m_env.m_agent.get_read_request_sequencer(),
                         m_env.m_agent.get_read_data_sequencer());
      seq.start(null);
      if (seq.m_read_beats.size() != exp_beats)
        `uvm_fatal(get_full_name(), $sformatf("%s: expected %0d beats, got %0d (reset?)",
                   ctx, exp_beats, seq.m_read_beats.size()))
      foreach (seq.m_read_beats[i]) begin
        if (seq.m_read_beats[i].m_resp != axi_read_data_item::RRespOkay)
          `uvm_error(get_full_name(), $sformatf("%s: beat %0d non-OKAY RRESP %0d", ctx, i,
                     seq.m_read_beats[i].m_resp))
        if (m_check_resp_id && seq.m_read_beats[i].m_id != seq.m_id)
          `uvm_error(get_full_name(), $sformatf("%s: beat %0d RID 0x%0h != ARID 0x%0h", ctx, i,
                     seq.m_read_beats[i].m_id, seq.m_id))
      end
    endtask

    // Single-beat 8-byte write (no CHERI tag).
    protected task automatic write_word(bit [31:0] id, bit [63:0] addr, bit [63:0] data);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("ww");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = 3'd3; seq.m_burst = BurstFixed;
      seq.m_data_items.push_back(make_wd(data, 8'hFF, 1'b0, 1'b1));
      run_write(seq, "write_word");
    endtask

    // Single-beat 8-byte write asserting WUSER=tag (used to prove it does NOT set the
    // region tag without a full 2-beat capability burst).
    protected task automatic write_word_user(bit [31:0] id, bit [63:0] addr,
                                             bit [63:0] data, bit tag);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wwu");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = 3'd3; seq.m_burst = BurstFixed;
      seq.m_data_items.push_back(make_wd(data, 8'hFF, tag, 1'b1));
      run_write(seq, "write_word_user");
    endtask

    // 2-beat capability write (awlen=1, awsize=3, INCR) with WUSER=tag on both beats.
    protected task automatic write_cap(bit [31:0] id, bit [63:0] addr,
                                       bit [63:0] lower, bit [63:0] upper, bit tag);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wc");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = 3'd3; seq.m_burst = BurstIncr;
      seq.m_data_items.push_back(make_wd(lower, 8'hFF, tag, 1'b0));
      seq.m_data_items.push_back(make_wd(upper, 8'hFF, tag, 1'b1));
      run_write(seq, "write_cap");
    endtask

    // N-beat data burst (awsize=3, INCR), no CHERI tag. words[i] is beat i.
    protected task automatic write_burst_words(bit [31:0] id, bit [63:0] addr,
                                               ref bit [63:0] words[$]);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wb");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = 3'd3;
      seq.m_burst = (words.size() == 1) ? BurstFixed : BurstIncr;
      foreach (words[i])
        seq.m_data_items.push_back(make_wd(words[i], 8'hFF, 1'b0, 8'(i) == 8'(words.size() - 1)));
      run_write(seq, "write_burst_words");
    endtask

    // Single-beat 8-byte read; returns data and (optionally) the R-channel ID.
    protected task automatic read_word(bit [31:0] id, bit [63:0] addr, output bit [63:0] data);
      axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rw");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = 3'd3; seq.m_len = 8'd0;
      seq.m_burst = BurstFixed;
      run_read(seq, "read_word", 1);
      data = seq.m_read_beats[0].m_data[63:0];
    endtask

    // 2-beat capability read (arlen=1, arsize=3, INCR). Returns both data words and the
    // per-flit RUSER (CHERI tag) bits.
    protected task automatic read_cap(bit [31:0] id, bit [63:0] addr,
                                      output bit [63:0] lower, output bit [63:0] upper,
                                      output bit ruser0,      output bit ruser1);
      axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rc");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = 3'd3; seq.m_len = 8'd1;
      seq.m_burst = BurstIncr;
      run_read(seq, "read_cap", 2);
      lower  = seq.m_read_beats[0].m_data[63:0];
      upper  = seq.m_read_beats[1].m_data[63:0];
      ruser0 = seq.m_read_beats[0].m_user[0];
      ruser1 = seq.m_read_beats[1].m_user[0];
    endtask

    // Single-beat write with an explicit AWSIZE and WSTRB (no CHERI tag). Used for partial-strobe /
    // sub-word writes (e.g. size=2, strb=0x0F) that must clear a tag.
    protected task automatic write_word_strb(bit [31:0] id, bit [63:0] addr, bit [63:0] data,
                                             bit [2:0] size, bit [7:0] strb);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wws");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = size; seq.m_burst = BurstFixed;
      seq.m_data_items.push_back(make_wd(data, strb, 1'b0, 1'b1));
      run_write(seq, "write_word_strb");
    endtask

    // 2-beat capability-shaped write with an independent WUSER per beat. Used to drive a malformed
    // capability write (e.g. wuser=[1,0]) that the W-channel consistency assertion (9a3xf6) flags.
    protected task automatic write_cap_user(bit [31:0] id, bit [63:0] addr,
                                            bit [63:0] lower, bit [63:0] upper,
                                            bit user0, bit user1);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wcu");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = 3'd3; seq.m_burst = BurstIncr;
      seq.m_data_items.push_back(make_wd(lower, 8'hFF, user0, 1'b0));
      seq.m_data_items.push_back(make_wd(upper, 8'hFF, user1, 1'b1));
      run_write(seq, "write_cap_user");
    endtask

    // General read burst: nbeats, AXI size and prot are all configurable. Returns each beat's data
    // word and per-beat RUSER (tag) bit. Single-beat reads use a FIXED burst, multi-beat use INCR.
    protected task automatic read_generic(bit [31:0] id, bit [63:0] addr, int unsigned nbeats,
                                          bit [2:0] size, bit [2:0] prot,
                                          ref bit [63:0] data[$], ref bit ruser[$]);
      axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rg");
      seq.m_id = id; seq.m_addr = addr; seq.m_size = size; seq.m_len = 8'(nbeats - 1);
      seq.m_burst = (nbeats == 1) ? BurstFixed : BurstIncr; seq.m_prot = prot;
      run_read(seq, "read_generic", nbeats);
      data.delete();
      ruser.delete();
      foreach (seq.m_read_beats[i]) begin
        data.push_back(seq.m_read_beats[i].m_data[63:0]);
        ruser.push_back(seq.m_read_beats[i].m_user[0]);
      end
    endtask
  endclass

  // -------------------------------------------------------------------------
  // rst_sanity — DUT leaves reset cleanly and accepts its first transaction.
  // -------------------------------------------------------------------------
  class axi_sram_rst_sanity_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_rst_sanity_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] rdata;
      phase.raise_objection(this);
      await_reset();
      // The very first transaction after reset must complete and round-trip.
      write_word(32'd1, 64'h0, 64'hA5A5_5A5A_C3C3_3C3C);
      read_word(32'd1, 64'h0, rdata);
      if (rdata != 64'hA5A5_5A5A_C3C3_3C3C)
        `uvm_error(get_full_name(), $sformatf("rst_sanity: read 0x%016h", rdata))
      else
        `uvm_info(get_full_name(), "rst_sanity: first transaction after reset OK — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // write_read — single-beat 8-byte write then readback.
  // -------------------------------------------------------------------------
  class axi_sram_write_read_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_write_read_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr  = 64'h0000_0008;
      bit [63:0] wdata = 64'hDEAD_BEEF_CAFE_1234;
      bit [63:0] rdata;
      phase.raise_objection(this);
      await_reset();
      write_word(32'd1, addr, wdata);
      read_word(32'd1, addr, rdata);
      if (rdata != wdata)
        `uvm_error(get_full_name(), $sformatf("write_read: expected 0x%016h, got 0x%016h",
                   wdata, rdata))
      else
        `uvm_info(get_full_name(), "write_read: data matches — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // data_all_bits — walking-1 / walking-0 across all 64 data bits.
  // -------------------------------------------------------------------------
  class axi_sram_data_all_bits_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_data_all_bits_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0000_0100;
      bit [63:0] val, got;
      phase.raise_objection(this);
      await_reset();
      for (int b = 0; b < 64; b++) begin
        val = 64'd1 << b;                       // walking one
        write_word(32'd2, addr, val);
        read_word(32'd2, addr, got);
        if (got != val)
          `uvm_error(get_full_name(), $sformatf("walk-1 bit %0d: wrote 0x%016h read 0x%016h",
                     b, val, got))
      end
      for (int b = 0; b < 64; b++) begin
        val = ~(64'd1 << b);                    // walking zero
        write_word(32'd2, addr, val);
        read_word(32'd2, addr, got);
        if (got != val)
          `uvm_error(get_full_name(), $sformatf("walk-0 bit %0d: wrote 0x%016h read 0x%016h",
                     b, val, got))
      end
      `uvm_info(get_full_name(), "data_all_bits: walking 1/0 across 64 bits done", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // address_boundaries — first/last word and last capability slot.
  // -------------------------------------------------------------------------
  class axi_sram_address_boundaries_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_address_boundaries_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] got, lo, hi;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();

      // First word
      write_word(32'd3, 64'h0, 64'hF1F2_F3F4_F5F6_F7F8);
      read_word(32'd3, 64'h0, got);
      if (got != 64'hF1F2_F3F4_F5F6_F7F8)
        `uvm_error(get_full_name(), $sformatf("first word: got 0x%016h", got))

      // Last word
      write_word(32'd3, LastWordAddr, 64'hA1A2_A3A4_A5A6_A7A8);
      read_word(32'd3, LastWordAddr, got);
      if (got != 64'hA1A2_A3A4_A5A6_A7A8)
        `uvm_error(get_full_name(), $sformatf("last word: got 0x%016h", got))

      // Last capability slot (tagged)
      write_cap(32'd3, LastCapAddr, 64'hDEAD_BEEF_DEAD_BEEF, 64'hCAFE_BABE_CAFE_BABE, 1'b1);
      read_cap(32'd3, LastCapAddr, lo, hi, u0, u1);
      if (lo != 64'hDEAD_BEEF_DEAD_BEEF || hi != 64'hCAFE_BABE_CAFE_BABE || u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf("last cap: lo=0x%016h hi=0x%016h u=%0b%0b",
                   lo, hi, u1, u0))
      else
        `uvm_info(get_full_name(), "address_boundaries: PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // burst_last — multi-beat burst round-trips; last beat flagged correctly.
  // -------------------------------------------------------------------------
  class axi_sram_burst_last_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_burst_last_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0000_0300;
      int        nbeats = 4;
      bit [63:0] words[$];
      axi_mgr_read_burst_vseq rseq;
      phase.raise_objection(this);
      await_reset();

      for (int i = 0; i < nbeats; i++) words.push_back(64'h1000_0000_0000_0000 | i);
      write_burst_words(32'd4, addr, words);

      // Read the burst back through the burst vseq so we can inspect per-beat RLAST.
      rseq = axi_mgr_read_burst_vseq::type_id::create("rb");
      rseq.m_id = 32'd4; rseq.m_addr = addr; rseq.m_size = 3'd3;
      rseq.m_len = 8'(nbeats - 1); rseq.m_burst = BurstIncr;
      run_read(rseq, "burst_last", nbeats);

      foreach (rseq.m_read_beats[i]) begin
        bit exp_last = (i == nbeats - 1);
        if (rseq.m_read_beats[i].m_data[63:0] != (64'h1000_0000_0000_0000 | i))
          `uvm_error(get_full_name(), $sformatf("burst beat %0d data 0x%016h", i,
                     rseq.m_read_beats[i].m_data[63:0]))
        if (rseq.m_read_beats[i].m_last != exp_last)
          `uvm_error(get_full_name(), $sformatf("burst beat %0d RLAST=%0b expected %0b", i,
                     rseq.m_read_beats[i].m_last, exp_last))
      end
      `uvm_info(get_full_name(), "burst_last: 4-beat burst round-trip + RLAST OK", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // resp_id_match — each B/R response carries the originating request's AXI ID.
  // -------------------------------------------------------------------------
  class axi_sram_resp_id_match_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_resp_id_match_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [3:0]  ids[] = '{4'd0, 4'd3, 4'd5, 4'd7, 4'd9, 4'd11, 4'd13, 4'd15};
      bit [63:0] base = 64'h0000_0400;
      bit [63:0] got;
      phase.raise_objection(this);
      await_reset();
      m_check_resp_id = 1'b1;   // run_write/run_read now assert response IDs match

      foreach (ids[i]) begin
        bit [63:0] addr = base + (i * WordBytes);
        bit [63:0] val  = 64'h1D00_0000_0000_0000 + i;
        write_word(32'(ids[i]), addr, val);    // BID == AWID checked inside run_write
        read_word(32'(ids[i]), addr, got);     // RID  == ARID checked inside run_read
        if (got != val)
          `uvm_error(get_full_name(), $sformatf("id 0x%0h: expected 0x%016h, got 0x%016h",
                     ids[i], val, got))
      end
      `uvm_info(get_full_name(), "resp_id_match: B/R IDs track request IDs — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // tag_write — a full 128-bit aligned 2-beat burst with WUSER=1 sets the tag,
  // and data+tag are carried in the same transaction (vplan tag_write x2).
  // -------------------------------------------------------------------------
  class axi_sram_tag_write_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_tag_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr  = 64'h0000_0010;
      bit [63:0] lower = 64'hAAAA_BBBB_CCCC_DDDD;
      bit [63:0] upper = 64'h1111_2222_3333_4444;
      bit [63:0] lo, hi;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();
      write_cap(32'd5, addr, lower, upper, 1'b1);
      read_cap(32'd5, addr, lo, hi, u0, u1);
      if (lo != lower || hi != upper)
        `uvm_error(get_full_name(), $sformatf("tag_write data: lo=0x%016h hi=0x%016h", lo, hi))
      if (u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf("tag_write: tag not set (ruser=%0b%0b)", u1, u0))
      else
        `uvm_info(get_full_name(), "tag_write: cap stored with tag set — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // no_tag_single_beat — WUSER=1 on a single-beat (awlen=0) write must NOT set
  // the region tag (is_w_cap_sized requires awlen=1).
  // -------------------------------------------------------------------------
  class axi_sram_no_tag_single_beat_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_no_tag_single_beat_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0000_0040;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();
      // Single-beat write with WUSER=1 — tag must stay 0.
      write_word_user(32'd6, addr, 64'h0BAD_0CAB_0BAD_0CAB, 1'b1);
      read_cap(32'd6, addr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "no_tag_single_beat: tag set by single-beat write (ruser=%0b%0b)", u1, u0))
      else
        `uvm_info(get_full_name(), "no_tag_single_beat: tag stayed 0 — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // tag_cleared_by_write — a plain data write to a tagged slot clears the tag.
  // -------------------------------------------------------------------------
  class axi_sram_tag_cleared_by_write_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_tag_cleared_by_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0000_0050;   // 16-byte aligned
      bit [63:0] lo, hi, up;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();
      // Store a tagged capability.
      write_cap(32'd7, addr, 64'hAAAA_AAAA_AAAA_AAAA, 64'hBBBB_BBBB_BBBB_BBBB, 1'b1);
      read_cap(32'd7, addr, lo, hi, u0, u1);
      if (u0 != 1) `uvm_error(get_full_name(), "precondition: tag should be set")

      // Plain write to the lower word clears the whole region's tag.
      write_word(32'd7, addr, 64'h1234_5678_9ABC_DEF0);
      read_cap(32'd7, addr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf("tag not cleared (ruser=%0b%0b)", u1, u0))

      // Upper word must be untouched.
      read_word(32'd7, addr + 8, up);
      if (up != 64'hBBBB_BBBB_BBBB_BBBB)
        `uvm_error(get_full_name(), $sformatf("upper word changed: 0x%016h", up))
      else
        `uvm_info(get_full_name(), "tag_cleared_by_write: PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // tag_isolation — clearing one slot's tag must not disturb a neighbour's.
  // -------------------------------------------------------------------------
  class axi_sram_tag_isolation_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_tag_isolation_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr_a = 64'h0000_0060;
      bit [63:0] addr_b = 64'h0000_0070;   // adjacent 16-byte slot
      bit [63:0] lo, hi;
      bit        a0, a1, b0, b1;
      phase.raise_objection(this);
      await_reset();
      write_cap(32'd8, addr_a, 64'hAAAA_AAAA_AAAA_AAAA, 64'hAAAA_AAAA_AAAA_AAAA, 1'b1);
      write_cap(32'd8, addr_b, 64'hBBBB_BBBB_BBBB_BBBB, 64'hBBBB_BBBB_BBBB_BBBB, 1'b1);

      // Clear A with a plain data write; B must keep its tag.
      write_word(32'd8, addr_a, 64'hDEAD_DEAD_DEAD_DEAD);
      read_cap(32'd8, addr_a, lo, hi, a0, a1);
      read_cap(32'd8, addr_b, lo, hi, b0, b1);
      if (a0 != 0) `uvm_error(get_full_name(), "tag A must be cleared")
      if (b0 != 1) `uvm_error(get_full_name(), "tag B must be unaffected")
      if (a0 == 0 && b0 == 1)
        `uvm_info(get_full_name(), "tag_isolation: PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // cap_both_ruser_set — both RUSER flits of a valid cap read are 1, both 0 for
  // an untagged region (the core ANDs the two flits to judge validity).
  // -------------------------------------------------------------------------
  class axi_sram_cap_ruser_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_cap_ruser_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] lo, hi;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();

      // Valid capability → both flits 1.
      write_cap(32'd9, 64'h0000_00A0, 64'h5555_5555_5555_5555, 64'h6666_6666_6666_6666, 1'b1);
      read_cap(32'd9, 64'h0000_00A0, lo, hi, u0, u1);
      if (u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf("valid cap ruser=%0b%0b (expect 11)", u1, u0))

      // Untagged region → both flits 0.
      write_cap(32'd9, 64'h0000_00C0, 64'h7777_7777_7777_7777, 64'h8888_8888_8888_8888, 1'b0);
      read_cap(32'd9, 64'h0000_00C0, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf("untagged cap ruser=%0b%0b (expect 00)", u1, u0))
      else
        `uvm_info(get_full_name(), "cap_both_ruser_set: PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // =========================================================================
  // Priority-2 tests
  // =========================================================================

  // -------------------------------------------------------------------------
  // aligned_only — sweep several 8-byte-aligned addresses; each must round-trip.
  // (Misaligned data accesses are the interconnect's responsibility, not driven.)
  // -------------------------------------------------------------------------
  class axi_sram_aligned_only_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_aligned_only_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] got;
      int        i = 0;
      phase.raise_objection(this);
      await_reset();
      for (bit [63:0] addr = 64'h0000_0200; addr < 64'h0000_0280; addr += WordBytes) begin
        bit [63:0] val = 64'hC0DE_0000_0000_0000 | (i & 16'hFFFF);
        write_word(32'd10, addr, val);
        read_word(32'd10, addr, got);
        if (got != val)
          `uvm_error(get_full_name(), $sformatf("aligned @0x%0h: wrote 0x%016h read 0x%016h",
                     addr, val, got))
        i++;
      end
      `uvm_info(get_full_name(), "aligned_only: aligned 64-bit accesses round-trip — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // no_tag_misaligned — a 2-beat wuser=1 burst starting at a non-16-byte-aligned
  // address must NOT set the tag (is_w_cap_aligned requires addr[3:0]==0).
  // -------------------------------------------------------------------------
  class axi_sram_no_tag_misaligned_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_no_tag_misaligned_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr  = 64'h0000_0048;   // addr[3:0]=8 -> misaligned for a capability
      bit [63:0] lower = 64'h1234_5678_9ABC_DEF0;
      bit [63:0] upper = 64'hFEDC_BA98_7654_3210;
      bit [63:0] rl, ru, dummy_lo, dummy_hi;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();
      // 2-beat cap-shaped write at the misaligned address with wuser=1.
      write_cap(32'd11, addr, lower, upper, 1'b1);
      // Data must still be written.
      read_word(32'd11, addr,     rl);
      read_word(32'd11, addr + 8, ru);
      if (rl != lower || ru != upper)
        `uvm_error(get_full_name(), $sformatf("misaligned data lost: lo=0x%016h hi=0x%016h", rl, ru))
      // Tag bit for region 0x40: read the aligned capability slot and check it is clear.
      read_cap(32'd11, 64'h0000_0040, dummy_lo, dummy_hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "no_tag_misaligned: tag set by misaligned burst (ruser=%0b%0b)", u1, u0))
      else
        `uvm_info(get_full_name(), "no_tag_misaligned: tag stayed 0 — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // no_tag_two_bursts — covering a 128-bit region with two SEPARATE single-beat
  // wuser=1 writes must NOT set the tag (it needs one 2-beat capability burst).
  // -------------------------------------------------------------------------
  class axi_sram_no_tag_two_bursts_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_no_tag_two_bursts_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0000_00D0;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();
      // Two independent single-beat writes, each asserting wuser=1 (each also trips bj8we7).
      write_word_user(32'd12, addr,     64'hCAFE_0000_0000_0001, 1'b1);
      write_word_user(32'd12, addr + 8, 64'hCAFE_0000_0000_0002, 1'b1);
      read_cap(32'd12, addr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "no_tag_two_bursts: tag set without a single cap burst (ruser=%0b%0b)", u1, u0))
      else
        `uvm_info(get_full_name(), "no_tag_two_bursts: tag stayed 0 — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // wuser_mismatch (assert_wuser_mismatch / 9a3xf6) — a cap-shaped write whose
  // two beats disagree on wuser trips the W-channel consistency assertion. The
  // assertion firing (a non-fatal $warning from the TB) is the actual check;
  // data must still round-trip.
  // -------------------------------------------------------------------------
  class axi_sram_wuser_mismatch_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_wuser_mismatch_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr  = 64'h0000_00B0;   // 16-byte aligned
      bit [63:0] lower = 64'h1234_1234_1234_1234;
      bit [63:0] upper = 64'h5678_5678_5678_5678;
      bit [63:0] rl, ru;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();
      // Cap-shaped but per-beat wuser=[1,0]: the 9a3xf6 assertion in the TB fires (expected).
      write_cap_user(32'd13, addr, lower, upper, 1'b1, 1'b0);
      read_cap(32'd13, addr, rl, ru, u0, u1);
      if (rl != lower || ru != upper)
        `uvm_error(get_full_name(), $sformatf(
                   "wuser_mismatch: data lost: lo=0x%016h hi=0x%016h", rl, ru))
      else
        `uvm_info(get_full_name(),
                  "wuser_mismatch: data intact; 9a3xf6 $warning expected in log — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // partial_strobe_clears_tag — a sub-64-bit (partial write-strobe) write to a
  // tagged slot clears the tag (size<3 -> is_w_cap_sized false -> tag written 0).
  // -------------------------------------------------------------------------
  class axi_sram_partial_strobe_clears_tag_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_partial_strobe_clears_tag_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0000_0060;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();
      write_cap(32'd14, addr, 64'h1111_1111_1111_1111, 64'h2222_2222_2222_2222, 1'b1);
      read_cap(32'd14, addr, lo, hi, u0, u1);
      if (u0 != 1) `uvm_error(get_full_name(), "precondition: tag must be set")

      // size=2 (4-byte transfer) -> wstrb=0x0F, a partial strobe.
      write_word_strb(32'd14, addr, 64'h0000_0000_DEAD_BEEF, 3'd2, 8'h0F);
      read_cap(32'd14, addr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "partial_strobe_clears_tag: tag not cleared (ruser=%0b%0b)", u1, u0))
      else
        `uvm_info(get_full_name(), "partial_strobe_clears_tag: PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // subword_read_clears_tag — a sub-word read (size<3) of a valid cap region
  // returns data but with the tag cleared; the stored tag is unchanged.
  // -------------------------------------------------------------------------
  class axi_sram_subword_read_clears_tag_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_subword_read_clears_tag_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0000_0700;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      bit [63:0] data[$];
      bit        ruser[$];
      phase.raise_objection(this);
      await_reset();
      write_cap(32'd15, addr, 64'h7777_7777_7777_7777, 64'h8888_8888_8888_8888, 1'b1);
      read_cap(32'd15, addr, lo, hi, u0, u1);
      if (u0 != 1) `uvm_error(get_full_name(), "precondition: stored cap must be valid")

      // Sub-word read (size=2): returned tag must be cleared.
      read_generic(32'd15, addr, 1, 3'd2, 3'd0, data, ruser);
      if (ruser[0] != 0)
        `uvm_error(get_full_name(), $sformatf("subword read returned tag=%0b (expect 0)", ruser[0]))

      // The stored capability itself is unaffected — a full cap read still sees tag=1.
      read_cap(32'd15, addr, lo, hi, u0, u1);
      if (u0 != 1)
        `uvm_error(get_full_name(), "stored tag must be unchanged by a sub-word read")
      else
        `uvm_info(get_full_name(), "subword_read_clears_tag: PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // concurrent_data_tag — a plain-data transaction and a capability transaction
  // in flight together must both complete and read back correctly.
  //
  // NOTE: the two WRITES are issued sequentially. AXI4 forbids write-data
  // interleaving, so two independent write sequences sharing the single W channel
  // would have to be coordinated to keep W in AW order; that is a VIP feature, not
  // exercised here. Concurrency is exercised on the read side, where responses are
  // routed by RID: the data read and the capability read are issued together.
  // -------------------------------------------------------------------------
  class axi_sram_concurrent_data_tag_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_concurrent_data_tag_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] data_addr = 64'h0000_0020;
      bit [63:0] cap_addr  = 64'h0000_0030;
      bit [63:0] data_val  = 64'hC0FFEE00_DEADC0DE;
      bit [63:0] cap_lo    = 64'hFEED_FACE_CAFE_BABE;
      bit [63:0] cap_hi    = 64'h0123_4567_89AB_CDEF;
      bit [63:0] rdata, rl, ru;
      bit        u0, u1;
      phase.raise_objection(this);
      await_reset();

      // Writes (sequential -> compliant W ordering).
      write_word(32'd1, data_addr, data_val);
      write_cap (32'd2, cap_addr, cap_lo, cap_hi, 1'b1);

      // Reads in flight together (different IDs, routed by RID).
      fork
        read_word(32'd1, data_addr, rdata);
        read_cap (32'd2, cap_addr, rl, ru, u0, u1);
      join

      if (rdata != data_val)
        `uvm_error(get_full_name(), $sformatf("concurrent data mismatch: 0x%016h", rdata))
      if (rl != cap_lo || ru != cap_hi || u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "concurrent cap mismatch: lo=0x%016h hi=0x%016h u=%0b%0b", rl, ru, u1, u0))
      if (rdata == data_val && rl == cap_lo && ru == cap_hi && u0 == 1 && u1 == 1)
        `uvm_info(get_full_name(), "concurrent_data_tag: both transactions correct — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // random_data — N random (8-byte-aligned addr, data) write/read pairs.
  // -------------------------------------------------------------------------
  class axi_sram_random_data_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_random_data_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      int        n_iters = 32;
      bit [63:0] exp [bit [63:0]];   // addr -> expected data
      bit [63:0] got;
      int        errors = 0;
      phase.raise_objection(this);
      await_reset();
      for (int i = 0; i < n_iters; i++) begin
        bit [63:0] addr = 64'($urandom_range(0, (SramSize/WordBytes) - 1)) << 3;
        bit [63:0] val  = {$urandom, $urandom};
        exp[addr] = val;
        write_word(32'd3, addr, val);
      end
      foreach (exp[addr]) begin
        read_word(32'd3, addr, got);
        if (got != exp[addr]) begin
          `uvm_error(get_full_name(), $sformatf("@0x%0h: expected 0x%016h, got 0x%016h",
                     addr, exp[addr], got))
          errors++;
        end
      end
      if (errors == 0)
        `uvm_info(get_full_name(), $sformatf("random_data: %0d locations OK — PASS", exp.size()),
                  UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // random_capabilities — N random 16-byte-aligned capability write/read pairs.
  // -------------------------------------------------------------------------
  class axi_sram_random_capabilities_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_random_capabilities_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      int        n_iters = 32;
      bit [63:0] exp_lo [bit [63:0]];
      bit [63:0] exp_hi [bit [63:0]];
      bit [63:0] rl, ru;
      bit        u0, u1;
      int        errors = 0;
      phase.raise_objection(this);
      await_reset();
      for (int i = 0; i < n_iters; i++) begin
        bit [63:0] addr = 64'($urandom_range(0, (SramSize/CapBytes) - 1)) << 4;
        bit [63:0] lo   = {$urandom, $urandom};
        bit [63:0] hi   = {$urandom, $urandom};
        exp_lo[addr] = lo;
        exp_hi[addr] = hi;
        write_cap(32'd4, addr, lo, hi, 1'b1);
      end
      foreach (exp_lo[addr]) begin
        read_cap(32'd4, addr, rl, ru, u0, u1);
        if (rl != exp_lo[addr] || ru != exp_hi[addr] || u0 != 1 || u1 != 1) begin
          `uvm_error(get_full_name(), $sformatf(
                     "@0x%0h: lo=%016h/%016h hi=%016h/%016h tag=%0b", addr,
                     rl, exp_lo[addr], ru, exp_hi[addr], u0))
          errors++;
        end
      end
      if (errors == 0)
        `uvm_info(get_full_name(),
                  $sformatf("random_capabilities: %0d caps OK — PASS", exp_lo.size()), UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // =========================================================================
  // Priority-3 tests
  // =========================================================================

  // -------------------------------------------------------------------------
  // init_value_undefined — power-up SRAM/tag contents are undefined; only assert
  // that an un-written read completes and that a write makes it deterministic.
  // -------------------------------------------------------------------------
  class axi_sram_init_value_undefined_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_init_value_undefined_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] addr = 64'h0001_0000;   // not written by any other test
      bit [63:0] pre, post;
      phase.raise_objection(this);
      await_reset();
      // No assertion on the value: just confirm the read completes (run_read checks the beat count).
      read_word(32'd5, addr, pre);
      `uvm_info(get_full_name(), $sformatf("un-written read @0x%0h = 0x%016h (don't-care)",
                addr, pre), UVM_LOW)
      // After a write the location is deterministic.
      write_word(32'd5, addr, 64'hA5A5_5A5A_A5A5_5A5A);
      read_word(32'd5, addr, post);
      if (post != 64'hA5A5_5A5A_A5A5_5A5A)
        `uvm_error(get_full_name(), $sformatf("value not defined after write: 0x%016h", post))
      else
        `uvm_info(get_full_name(), "init_value_undefined: defined after write — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // execute_from_sram — instruction-flavoured reads (arprot[2]=1) return stored
  // words identically to data reads, as single fetches and as a sequential burst.
  // -------------------------------------------------------------------------
  class axi_sram_execute_from_sram_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_execute_from_sram_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] base = 64'h0000_0800;
      bit [63:0] prog [4];
      bit [63:0] data[$];
      bit        ruser[$];
      phase.raise_objection(this);
      await_reset();
      foreach (prog[i]) begin
        prog[i] = 64'h0000_0000_1000_0000 | i;
        write_word(32'd6, base + i * WordBytes, prog[i]);
      end
      // Fetch each word as an instruction-protected single read (prot[2]=1).
      foreach (prog[i]) begin
        read_generic(32'd6, base + i * WordBytes, 1, 3'd3, 3'b100, data, ruser);
        if (data[0] != prog[i])
          `uvm_error(get_full_name(), $sformatf("fetch @0x%0h: expected 0x%016h got 0x%016h",
                     base + i * WordBytes, prog[i], data[0]))
      end
      // Sequential instruction burst fetch of the whole program.
      read_generic(32'd6, base, 4, 3'd3, 3'b100, data, ruser);
      foreach (prog[i])
        if (data[i] != prog[i])
          `uvm_error(get_full_name(), $sformatf("burst fetch beat %0d: expected 0x%016h got 0x%016h",
                     i, prog[i], data[i]))
      `uvm_info(get_full_name(), "execute_from_sram: instruction fetches match — PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // burst_read_mixed_tags — adjacent slots return independent per-beat ruser when
  // each is read as its own 2-beat transaction. Per-beat tags across a longer
  // (awlen>1) burst are the tag controller's job (axi_sram gates ruser on
  // awlen==1), so that boundary is logged, not asserted.
  // -------------------------------------------------------------------------
  class axi_sram_burst_read_mixed_tags_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_burst_read_mixed_tags_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      bit [63:0] cap_addr   = 64'h0000_0080;   // tagged
      bit [63:0] plain_addr = 64'h0000_0090;   // untagged
      bit [63:0] lo, hi;
      bit        ct0, ct1, pt0, pt1;
      bit [63:0] data[$];
      bit        ruser[$];
      string     s;
      phase.raise_objection(this);
      await_reset();
      write_cap(32'd7, cap_addr,   64'hCAFE_BABE_FEED_FACE, 64'hDEAD_BEEF_1234_5678, 1'b1);
      write_cap(32'd7, plain_addr, 64'hAAAA_AAAA_AAAA_AAAA, 64'hBBBB_BBBB_BBBB_BBBB, 1'b0);

      read_cap(32'd7, cap_addr,   lo, hi, ct0, ct1);
      read_cap(32'd7, plain_addr, lo, hi, pt0, pt1);
      if (ct0 != 1) `uvm_error(get_full_name(), "tagged slot must return ruser=1")
      if (pt0 != 0) `uvm_error(get_full_name(), "untagged slot must return ruser=0")

      // 4-beat (awlen=3) burst across both slots: axi_sram gates ruser on awlen==1,
      // so every beat returns 0. Log the boundary; do NOT assert it as required behaviour.
      read_generic(32'd7, cap_addr, 4, 3'd3, 3'd0, data, ruser);
      foreach (ruser[i]) s = {s, $sformatf("%0b", ruser[i])};
      `uvm_info(get_full_name(), $sformatf({"burst_read_mixed_tags: per-slot ruser ok ",
                "(tagged=%0b untagged=%0b); 4-beat burst ruser=%s (tag controller owns multi-beat ",
                "burst tags) — PASS"}, ct0, pt0, s), UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // out_of_range_error — OUT OF SCOPE for axi_sram. Kept for vplan traceability.
  // -------------------------------------------------------------------------
  class axi_sram_out_of_range_error_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_out_of_range_error_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      await_reset();
      `uvm_info(get_full_name(), {"out_of_range_error (u0s8nt): OUT OF SCOPE — range checking is ",
                "enforced by the SoC interconnect / address decode upstream, not axi_sram (which ",
                "ties mem_err_i=0 and masks the address). No stimulus driven."}, UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

  // -------------------------------------------------------------------------
  // atomics_excluded — spec exclusion (bsi4rc); no functional test required.
  // -------------------------------------------------------------------------
  class axi_sram_atomics_excluded_test extends axi_sram_base_test;
    `uvm_component_utils(axi_sram_atomics_excluded_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      await_reset();
      `uvm_info(get_full_name(), {"atomics_excluded (bsi4rc): atomic (ATOP) accesses are explicitly ",
                "out of scope per spec and need no functional test. Recorded for traceability."},
                UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass

endpackage
