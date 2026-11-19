// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  `uvm_analysis_imp_decl(_cfg)
  `uvm_analysis_imp_decl(_tag)

  // Checks every completed access on the configuration and tagged subordinates against
  // tagctrl_model, in the order the accesses complete.
  class tagctrl_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(tagctrl_scoreboard)

    uvm_analysis_imp_cfg #(axi_mon_item, tagctrl_scoreboard) cfg_imp;
    uvm_analysis_imp_tag #(axi_mon_item, tagctrl_scoreboard) tag_imp;

    // Reset of the DUT, from the tagged subordinate's reset monitor
    uvm_analysis_imp #(axi_reset_item, tagctrl_scoreboard) reset_imp;

    tagctrl_model m_model;

    // A tag read back from a covered chunk read whole, by the number of chunks in the burst
    covergroup tag_roundtrip_cg with function sample(bit tag, int unsigned chunks);
      cp_tag: coverpoint tag;
      cp_chunks: coverpoint chunks {
        bins single   = {1};
        bins multiple = {[2:$]};
      }
      cp_tag_x_chunks: cross cp_tag, cp_chunks;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      tag_roundtrip_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg_imp   = new("cfg_imp", this);
      tag_imp   = new("tag_imp", this);
      reset_imp = new("reset_imp", this);
      m_model   = tagctrl_model::type_id::create("m_model");
    endfunction

    function void write(axi_reset_item item);
      if (item.m_in_reset) m_model.reset();
    endfunction

    // ------------------------------------------------------------------------------------------
    // Configuration subordinate
    // ------------------------------------------------------------------------------------------

    function void write_cfg(axi_mon_item item);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      string             err;

      if ($cast(wr, item)) begin
        if (wr.m_bresp !== RespOkay) begin
          `uvm_error("cfg", $sformatf("write to 0x%0h answered %0d, expected OKAY", wr.m_awaddr,
                                      wr.m_bresp))
        end
        m_model.cfg_write(wr.m_awaddr[11:0], wr.m_wdata[0][63:0], wr.m_wstrb[0][7:0]);
      end else if ($cast(rd, item)) begin
        if (rd.m_rresp[0] !== RespOkay) begin
          `uvm_error("cfg", $sformatf("read of 0x%0h answered %0d, expected OKAY", rd.m_araddr,
                                      rd.m_rresp[0]))
        end
        err = m_model.cfg_read(rd.m_araddr[11:0], rd.m_rdata[0][63:0]);
        if (err != "") `uvm_error("cfg", err)
      end
    endfunction

    // ------------------------------------------------------------------------------------------
    // Tagged subordinate
    // ------------------------------------------------------------------------------------------

    // The lowest and highest byte an access addresses
    local function void access_bounds(axi_addr_t addr, bit [2:0] size, bit [7:0] len,
                                      bit [1:0] burst, output bit [63:0] lo,
                                      output bit [63:0] hi);
      lo = '1;
      hi = '0;
      for (int unsigned n = 0; n <= len; n++) begin
        bit [63:0]   beat_addr;
        int unsigned lower, upper;
        axi_beat_lanes(addr, size, len, burst, BusBytes, n, beat_addr, lower, upper);
        beat_addr = beat_addr / BusBytes * BusBytes;
        if (beat_addr + lower < lo) lo = beat_addr + lower;
        if (beat_addr + upper > hi) hi = beat_addr + upper;
      end
    endfunction

    function void write_tag(axi_mon_item item);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      string             users = "";
      if ($cast(wr, item)) begin
        foreach (wr.m_wuser[n]) users = {users, $sformatf("%0b", wr.m_wuser[n][0])};
        `uvm_info("tag", $sformatf("write 0x%0h, WUSER per beat %s", wr.m_awaddr, users), UVM_HIGH)
        check_tag_write(wr);
      end else if ($cast(rd, item)) begin
        foreach (rd.m_ruser[n]) users = {users, $sformatf("%0b", rd.m_ruser[n][0])};
        `uvm_info("tag", $sformatf("read 0x%0h, RUSER per beat %s", rd.m_araddr, users), UVM_HIGH)
        check_tag_read(rd);
      end
    endfunction

    local function bit check_resp(string what, axi_addr_t addr, logic [1:0] resp, int exp_err);
      bit    is_err = resp inside {RespSlverr, RespDecerr};
      string exp_s  = "OKAY";
      if (exp_err == 1) exp_s = "a bus error";
      if ($isunknown(resp) || (exp_err == 0 && resp !== RespOkay) ||
          (exp_err == 1 && !is_err)) begin
        `uvm_error("tag", $sformatf("%s at 0x%0h answered %0d, expected %s", what, addr, resp,
                                    exp_s))
      end
      return resp === RespOkay;
    endfunction

    local function void check_tag_write(axi_mon_write_item wr);
      bit [63:0]                lo, hi;
      int                       exp_err;
      bit                       tracked;
      tagctrl_model::overlap_e  cov;
      // Per chunk the access touches: whether a byte of it was written, and the WUSER values
      bit                       chunk_written[bit [63:0]];
      bit [1:0]                 chunk_users[bit [63:0]];

      access_bounds(wr.m_awaddr, wr.m_awsize, wr.m_awlen, wr.m_awburst, lo, hi);
      exp_err = m_model.expected_error(lo, hi);
      if (!check_resp("write", wr.m_awaddr, wr.m_bresp, exp_err)) begin
        // Nothing reached memory
        return;
      end

      cov     = m_model.covered_overlap(lo, hi);
      tracked = m_model.state != tagctrl_model::StUnconfigured;

      foreach (wr.m_wdata[n]) begin
        bit [63:0]   beat_addr;
        int unsigned lower, upper;
        axi_beat_lanes(wr.m_awaddr, wr.m_awsize, wr.m_awlen, wr.m_awburst, BusBytes, n,
                       beat_addr, lower, upper);
        beat_addr = beat_addr / BusBytes * BusBytes;
        for (int unsigned lane = lower; lane <= upper; lane++) begin
          bit [63:0] a     = beat_addr + lane;
          bit [63:0] chunk = a / ChunkBytes;
          if (!chunk_users.exists(chunk)) begin
            chunk_written[chunk] = 1'b0;
            chunk_users[chunk]   = 2'b00;
          end
          if (wr.m_wstrb[n][lane] === 1'b1) begin
            if ($isunknown(wr.m_wdata[n][8*lane +: 8])) m_model.mem.delete(a);
            else m_model.mem[a] = wr.m_wdata[n][8*lane +: 8];
            chunk_written[chunk] = 1'b1;
            chunk_users[chunk][wr.m_wuser[n][0] === 1'b1] = 1'b1;
          end
        end
      end

      // Tags are taken from WUSER only while Serving, and only inside the covered region. A chunk
      // written by beats with different WUSER, or not written at all, is not predicted.
      if (!tracked || cov == tagctrl_model::OverlapNo) return;
      foreach (chunk_users[c]) begin
        bit known = cov == tagctrl_model::OverlapYes && chunk_written[c] &&
                    $countones(chunk_users[c]) == 1;
        m_model.set_tag(c, known, chunk_users[c][1]);
      end
    endfunction

    local function void check_tag_read(axi_mon_read_item rd);
      bit [63:0]               lo, hi;
      int                      exp_err;
      tagctrl_model::overlap_e cov;
      // Per chunk the read touches: the bytes returned, and the RUSER values seen with them
      int unsigned             chunk_bytes[bit [63:0]];
      bit [1:0]                chunk_users[bit [63:0]];
      bit                      all_okay = 1'b1;

      access_bounds(rd.m_araddr, rd.m_arsize, rd.m_arlen, rd.m_arburst, lo, hi);
      exp_err = m_model.expected_error(lo, hi);
      cov     = m_model.covered_overlap(lo, hi);

      foreach (rd.m_rdata[n]) begin
        bit [63:0]   beat_addr;
        int unsigned lower, upper;
        logic        user = rd.m_ruser[n][0];

        if (!check_resp($sformatf("read beat %0d", n), rd.m_araddr, rd.m_rresp[n], exp_err)) begin
          all_okay = 1'b0;
          continue;
        end
        axi_beat_lanes(rd.m_araddr, rd.m_arsize, rd.m_arlen, rd.m_arburst, BusBytes, n,
                       beat_addr, lower, upper);
        beat_addr = beat_addr / BusBytes * BusBytes;
        for (int unsigned lane = lower; lane <= upper; lane++) begin
          bit [63:0] a     = beat_addr + lane;
          bit [63:0] chunk = a / ChunkBytes;
          logic [7:0] got   = rd.m_rdata[n][8*lane +: 8];
          if (m_model.mem.exists(a) && got !== m_model.mem[a]) begin
            `uvm_error("tag", $sformatf("read of 0x%0h returned 0x%02h at 0x%0h, expected 0x%02h",
                                        rd.m_araddr, got, a, m_model.mem[a]))
          end
          if (!chunk_users.exists(chunk)) begin
            chunk_bytes[chunk] = 0;
            chunk_users[chunk] = 2'b00;
          end
          chunk_bytes[chunk]++;
          if ($isunknown(user)) chunk_users[chunk] = 2'b11;
          else chunk_users[chunk][user] = 1'b1;
        end
      end

      foreach (chunk_users[c]) begin
        bit tag, known;
        bit seen_set = chunk_users[c][1];
        // Tags read zero while Unconfigured and outside the covered region
        if (m_model.state == tagctrl_model::StUnconfigured ||
            cov == tagctrl_model::OverlapNo) begin
          known = 1'b1;
          tag   = 1'b0;
        end else if (cov == tagctrl_model::OverlapYes) begin
          known = m_model.tag_known(c, tag);
        end else begin
          known = 1'b0;
        end
        if (!known) continue;
        if (!tag && seen_set) begin
          `uvm_error("tag", $sformatf("read of 0x%0h returned a set tag for chunk 0x%0h",
                                      rd.m_araddr, c * ChunkBytes))
        end
        // A set tag is only predicted for a chunk read whole while Serving
        if (tag && !seen_set && m_model.state == tagctrl_model::StServing &&
            chunk_bytes[c] >= ChunkBytes) begin
          `uvm_error("tag", $sformatf("read of 0x%0h returned a clear tag for chunk 0x%0h",
                                      rd.m_araddr, c * ChunkBytes))
        end
      end

      // Coverage: a read of whole aligned chunks from the covered region while Serving
      if (all_okay && m_model.state == tagctrl_model::StServing &&
          cov == tagctrl_model::OverlapYes && lo % ChunkBytes == 0 &&
          (hi + 1) % ChunkBytes == 0) begin
        foreach (chunk_users[c]) begin
          bit tag;
          if (m_model.tag_known(c, tag)) begin
            tag_roundtrip_cg.sample(tag, chunk_users.num());
          end
        end
      end
    endfunction
  endclass
