// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // rst_sanity — DUT leaves reset cleanly and accepts its first transaction.
  class axi_sram_rst_sanity_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_rst_sanity_vseq)
    function new(string name = "axi_sram_rst_sanity_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] rdata;
      await_reset();
      // The very first transaction after reset must complete and round-trip.
      write_word(32'd1, 64'h0, 64'hA5A5_5A5A_C3C3_3C3C);
      read_word(32'd1, 64'h0, rdata);
      if (rdata != 64'hA5A5_5A5A_C3C3_3C3C)
        `uvm_error(get_full_name(), $sformatf("rst_sanity: read 0x%016h", rdata))
      else
        `uvm_info(get_full_name(), "rst_sanity: first transaction after reset OK — PASS", UVM_LOW)
    endtask
  endclass


  // write_read — single-beat 8-byte write then readback. (Migrated to the vseq
  // style: stimulus lives in a virtual sequence run on m_vseqr; the test is a
  // thin wrapper that starts it.)
  class axi_sram_write_read_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_write_read_vseq)
    function new(string name = "axi_sram_write_read_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr  = 64'h0000_0008;
      bit [63:0] wdata = 64'hDEAD_BEEF_CAFE_1234;
      bit [63:0] rdata;
      await_reset();
      write_word(32'd1, addr, wdata);
      read_word(32'd1, addr, rdata);
      if (rdata != wdata)
        `uvm_error(get_full_name(), $sformatf("write_read: expected 0x%016h, got 0x%016h",
                   wdata, rdata))
      else
        `uvm_info(get_full_name(), "write_read: data matches — PASS", UVM_LOW)
    endtask
  endclass


  // data_all_bits — walking-1 / walking-0 across all 64 data bits.
  class axi_sram_data_all_bits_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_data_all_bits_vseq)
    function new(string name = "axi_sram_data_all_bits_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0100;
      bit [63:0] val, got;
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
    endtask
  endclass


  // address_boundaries — first/last word and last capability slot.
  class axi_sram_address_boundaries_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_address_boundaries_vseq)
    function new(string name = "axi_sram_address_boundaries_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] got, lo, hi;
      bit        u0, u1;
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
    endtask
  endclass


  // burst_last — multi-beat burst round-trips; last beat flagged correctly.
  class axi_sram_burst_last_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_last_vseq)
    function new(string name = "axi_sram_burst_last_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0300;
      int        nbeats = 4;
      bit [63:0] words[$];
      axi_mgr_read_burst_vseq rseq;
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
    endtask
  endclass


  // resp_id_match — each B/R response carries the originating request's AXI ID.
  //
  class axi_sram_resp_id_match_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_resp_id_match_vseq)
    function new(string name = "axi_sram_resp_id_match_vseq"); super.new(name); endfunction

    task body();
      bit [3:0]  ids[] = '{4'd0, 4'd3, 4'd5, 4'd7, 4'd9, 4'd11, 4'd13, 4'd15};
      bit [63:0] base = 64'h0000_0400;
      bit [63:0] got;
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
    endtask
  endclass


  // tag_write — a full 128-bit aligned 2-beat burst with WUSER=1 sets the tag,
  // and data+tag are carried in the same transaction.
  class axi_sram_tag_write_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_tag_write_vseq)
    function new(string name = "axi_sram_tag_write_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr  = 64'h0000_0010;
      bit [63:0] lower = 64'hAAAA_BBBB_CCCC_DDDD;
      bit [63:0] upper = 64'h1111_2222_3333_4444;
      bit [63:0] lo, hi;
      bit        u0, u1;
      await_reset();
      write_cap(32'd5, addr, lower, upper, 1'b1);
      read_cap(32'd5, addr, lo, hi, u0, u1);
      if (lo != lower || hi != upper)
        `uvm_error(get_full_name(), $sformatf("tag_write data: lo=0x%016h hi=0x%016h", lo, hi))
      if (u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf("tag_write: tag not set (ruser=%0b%0b)", u1, u0))
      else
        `uvm_info(get_full_name(), "tag_write: cap stored with tag set — PASS", UVM_LOW)
    endtask
  endclass


  // no_tag_single_beat — WUSER=1 on a single-beat (awlen=0) write must NOT set
  // the region tag (is_w_cap_sized requires awlen=1).
  class axi_sram_no_tag_single_beat_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_no_tag_single_beat_vseq)
    function new(string name = "axi_sram_no_tag_single_beat_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0040;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      await_reset();
      // Single-beat write with WUSER=1 — tag must stay 0.
      write_word_user(32'd6, addr, 64'h0BAD_0CAB_0BAD_0CAB, 1'b1);
      read_cap(32'd6, addr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "no_tag_single_beat: tag set by single-beat write (ruser=%0b%0b)", u1, u0))
      else
        `uvm_info(get_full_name(), "no_tag_single_beat: tag stayed 0 — PASS", UVM_LOW)
    endtask
  endclass


  // tag_cleared_by_write — a plain data write to a tagged slot clears the tag.
  class axi_sram_tag_cleared_by_write_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_tag_cleared_by_write_vseq)
    function new(string name = "axi_sram_tag_cleared_by_write_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0050;   // 16-byte aligned
      bit [63:0] lo, hi, up;
      bit        u0, u1;
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
    endtask
  endclass


  // tag_isolation — clearing one slot's tag must not disturb a neighbour's.
  class axi_sram_tag_isolation_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_tag_isolation_vseq)
    function new(string name = "axi_sram_tag_isolation_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr_a = 64'h0000_0060;
      bit [63:0] addr_b = 64'h0000_0070;   // adjacent 16-byte slot
      bit [63:0] lo, hi;
      bit        a0, a1, b0, b1;
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
    endtask
  endclass


  // cap_both_ruser_set — both RUSER flits of a valid cap read are 1, both 0 for
  // an untagged region (the core ANDs the two flits to judge validity).
  class axi_sram_cap_ruser_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_cap_ruser_vseq)
    function new(string name = "axi_sram_cap_ruser_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] lo, hi;
      bit        u0, u1;
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
    endtask
  endclass


  // Priority-2 tests

  // aligned_only — sweep several 8-byte-aligned addresses; each must round-trip.
  // (Misaligned data accesses are the interconnect's responsibility, not driven.)
  class axi_sram_aligned_only_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_aligned_only_vseq)
    function new(string name = "axi_sram_aligned_only_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] got;
      int        i = 0;
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
    endtask
  endclass


  // no_tag_misaligned — a 2-beat wuser=1 burst starting at a non-16-byte-aligned
  // address must NOT set the tag (is_w_cap_aligned requires addr[3:0]==0).
  class axi_sram_no_tag_misaligned_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_no_tag_misaligned_vseq)
    function new(string name = "axi_sram_no_tag_misaligned_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr  = 64'h0000_0048;   // addr[3:0]=8 -> misaligned for a capability
      bit [63:0] lower = 64'h1234_5678_9ABC_DEF0;
      bit [63:0] upper = 64'hFEDC_BA98_7654_3210;
      bit [63:0] rl, ru, dummy_lo, dummy_hi;
      bit        u0, u1;
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
    endtask
  endclass


  // no_tag_two_bursts — covering a 128-bit region with two SEPARATE single-beat
  // wuser=1 writes must NOT set the tag (it needs one 2-beat capability burst).
  class axi_sram_no_tag_two_bursts_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_no_tag_two_bursts_vseq)
    function new(string name = "axi_sram_no_tag_two_bursts_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_00D0;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
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
    endtask
  endclass


  // wuser_mismatch (assert_wuser_mismatch / 9a3xf6) — a cap-shaped write whose
  // two beats disagree on wuser trips the W-channel consistency assertion. The
  // assertion firing (a non-fatal $warning from the TB) is the actual check;
  // data must still round-trip.
  class axi_sram_wuser_mismatch_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_wuser_mismatch_vseq)
    function new(string name = "axi_sram_wuser_mismatch_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr  = 64'h0000_00B0;   // 16-byte aligned
      bit [63:0] lower = 64'h1234_1234_1234_1234;
      bit [63:0] upper = 64'h5678_5678_5678_5678;
      bit [63:0] rl, ru;
      bit        u0, u1;
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
    endtask
  endclass


  // partial_strobe_clears_tag — a sub-64-bit (partial write-strobe) write to a
  // tagged slot clears the tag (size<3 -> is_w_cap_sized false -> tag written 0).
  class axi_sram_partial_strobe_clears_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_partial_strobe_clears_tag_vseq)
    function new(string name = "axi_sram_partial_strobe_clears_tag_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0060;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
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
    endtask
  endclass


  // subword_read_clears_tag — a sub-word read (size<3) of a valid cap region
  // returns data but with the tag cleared; the stored tag is unchanged.
  class axi_sram_subword_read_clears_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_subword_read_clears_tag_vseq)
    function new(string name = "axi_sram_subword_read_clears_tag_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0700;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      bit [63:0] data[$];
      bit        ruser[$];
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
    endtask
  endclass


  // concurrent_data_tag — a plain-data transaction and a capability transaction
  // in flight together must both complete and read back correctly.
  //
  // NOTE: the two WRITES are issued sequentially. AXI4 forbids write-data
  // interleaving, so two independent write sequences sharing the single W channel
  // would have to be coordinated to keep W in AW order; that is a VIP feature, not
  // exercised here. Concurrency is exercised on the read side, where responses are
  // routed by RID: the data read and the capability read are issued together.
  class axi_sram_concurrent_data_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_concurrent_data_tag_vseq)
    function new(string name = "axi_sram_concurrent_data_tag_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] data_addr = 64'h0000_0020;
      bit [63:0] cap_addr  = 64'h0000_0030;
      bit [63:0] data_val  = 64'hC0FFEE00_DEADC0DE;
      bit [63:0] cap_lo    = 64'hFEED_FACE_CAFE_BABE;
      bit [63:0] cap_hi    = 64'h0123_4567_89AB_CDEF;
      bit [63:0] rdata, rl, ru;
      bit        u0, u1;
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
    endtask
  endclass


  // random_data — N random (8-byte-aligned addr, data) write/read pairs.
  class axi_sram_random_data_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_random_data_vseq)
    function new(string name = "axi_sram_random_data_vseq"); super.new(name); endfunction

    task body();
      int        n_iters = 32;
      bit [63:0] exp [bit [63:0]];   // addr -> expected data
      bit [63:0] got;
      int        errors = 0;
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
    endtask
  endclass


  // random_capabilities — N random 16-byte-aligned capability write/read pairs.
  class axi_sram_random_capabilities_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_random_capabilities_vseq)
    function new(string name = "axi_sram_random_capabilities_vseq"); super.new(name); endfunction

    task body();
      int        n_iters = 32;
      bit [63:0] exp_lo [bit [63:0]];
      bit [63:0] exp_hi [bit [63:0]];
      bit [63:0] rl, ru;
      bit        u0, u1;
      int        errors = 0;
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
    endtask
  endclass


  // Priority-3 tests

  // init_value_undefined — power-up SRAM/tag contents are undefined; only assert
  // that an un-written read completes and that a write makes it deterministic.
  class axi_sram_init_value_undefined_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_init_value_undefined_vseq)
    function new(string name = "axi_sram_init_value_undefined_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0001_0000;   // not written by any other test
      bit [63:0] pre, post;
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
    endtask
  endclass


  // execute_from_sram — instruction-flavoured reads (arprot[2]=1) return stored
  // words identically to data reads, as single fetches and as a sequential burst.
  class axi_sram_execute_from_sram_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_execute_from_sram_vseq)
    function new(string name = "axi_sram_execute_from_sram_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] base = 64'h0000_0800;
      bit [63:0] prog [4];
      bit [63:0] data[$];
      bit        ruser[$];
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
    endtask
  endclass


  // burst_read_mixed_tags — adjacent slots return independent per-beat ruser when
  // each is read as its own 2-beat transaction. Per-beat tags across a longer
  // (awlen>1) burst are the tag controller's job (axi_sram gates ruser on
  // awlen==1), so that boundary is logged, not asserted.
  class axi_sram_burst_read_mixed_tags_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_read_mixed_tags_vseq)
    function new(string name = "axi_sram_burst_read_mixed_tags_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] cap_addr   = 64'h0000_0080;   // tagged
      bit [63:0] plain_addr = 64'h0000_0090;   // untagged
      bit [63:0] lo, hi;
      bit        ct0, ct1, pt0, pt1;
      bit [63:0] data[$];
      bit        ruser[$];
      string     s;
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
    endtask
  endclass


  // out_of_range_error (u0s8nt) -- accesses outside every mapped region must return
  // DECERR. Now exercisable because the DUT sits behind the real xbar, which has no
  // default master port (en_default_mst_port=0). run_*/scoreboard both check it.
  class axi_sram_out_of_range_error_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_out_of_range_error_vseq)
    function new(string name = "axi_sram_out_of_range_error_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] data;
      m_base = 64'h0;   // drive absolute system addresses
      await_reset();
      // Just past the SRAM aperture (SRAMBase + SRAMLength): unmapped -> DECERR.
      read_word (32'd1, top_pkg::SRAMBase + top_pkg::SRAMLength, data);
      write_word(32'd1, top_pkg::SRAMBase + top_pkg::SRAMLength, 64'hDEAD_BEEF_DEAD_BEEF);
      // A rule-less gap (TlCrossbar end .. DRAM base): unmapped -> DECERR.
      read_word (32'd1, 64'h6000_0000, data);
      write_word(32'd1, 64'h6000_0000, 64'hBAD0_C0DE_BAD0_C0DE);
      `uvm_info(get_full_name(),
                "out_of_range_error: unmapped accesses returned DECERR -- PASS", UVM_LOW)
    endtask
  endclass

  // wrong_region_decerr -- every *other* mapped region (ROM, Mailbox, RestOfChip,
  // TlCrossbar, DRAM) routes away from the SRAM to an axi_err_slv and returns
  // DECERR. Confirms the xbar decode delivers only the SRAM aperture to axi_sram.
  class axi_sram_wrong_region_decerr_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_wrong_region_decerr_vseq)
    function new(string name = "axi_sram_wrong_region_decerr_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] data;
      bit [63:0] bases[] = '{top_pkg::RomCtrlMemBase, top_pkg::MailboxBase,
                             top_pkg::RestOfChipBase, top_pkg::TlCrossbarBase,
                             top_pkg::DRAMBase};
      m_base = 64'h0;   // absolute system addresses
      await_reset();
      foreach (bases[i]) begin
        read_word (32'd2, bases[i], data);
        write_word(32'd2, bases[i], 64'hA5A5_5A5A_A5A5_5A5A);
      end
      `uvm_info(get_full_name(),
                "wrong_region_decerr: all non-SRAM mapped regions returned DECERR -- PASS", UVM_LOW)
    endtask
  endclass

  // sram_boundary -- pin the aperture edges: the first and last words inside the
  // SRAM round-trip (OKAY), while the word just below the base and the word just
  // past the top are unmapped and return DECERR.
  class axi_sram_sram_boundary_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_sram_boundary_vseq)
    function new(string name = "axi_sram_sram_boundary_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] got;
      await_reset();

      // In-aperture edges (m_base = SRAMBase): first and last words round-trip.
      write_word(32'd3, 64'h0, 64'hF00D_0000_0000_0001);
      read_word (32'd3, 64'h0, got);
      if (got != 64'hF00D_0000_0000_0001)
        `uvm_error(get_full_name(), $sformatf("first word: got 0x%016h", got))
      write_word(32'd3, LastWordAddr, 64'hF00D_0000_0000_0002);
      read_word (32'd3, LastWordAddr, got);
      if (got != 64'hF00D_0000_0000_0002)
        `uvm_error(get_full_name(), $sformatf("last word: got 0x%016h", got))

      // Out-of-aperture edges (absolute): one word below the base and one word past
      // the top are unmapped -> DECERR (checked by run_read + the scoreboard).
      m_base = 64'h0;
      read_word(32'd3, top_pkg::SRAMBase - WordBytes,           got);
      read_word(32'd3, top_pkg::SRAMBase + top_pkg::SRAMLength, got);
      `uvm_info(get_full_name(),
                "sram_boundary: aperture edges OK, just-outside returned DECERR -- PASS", UVM_LOW)
    endtask
  endclass

  // burst_wrap -- the "partial burst out of range" scenario (u0s8nt): a burst that
  // starts in-SRAM whose later beats cross the aperture top. Such a burst would cross
  // the 4 KiB boundary at SRAMBase+SRAMLength, which AXI4 (A4.1.2) forbids, so a
  // compliant master cannot issue it -- u0s8nt is met by proxy of AXI4. This test
  // confirms the protocol layer actually rejects it: the VIP's request item carries
  // no_4kb_boundary_crossing_c, so a boundary-crossing request fails to randomise.
  //
  // (Were it forced through anyway, axi_sram has no range check -- mem_err_i=0, it
  // masks the address -- so the over-the-top beat would wrap to SRAM word 0. But the
  // xbar already blocks fully-out-of-range accesses and AXI4 blocks the partial case,
  // so axi_sram never sees an out-of-aperture address; range enforcement is by proxy.)
  class axi_sram_burst_wrap_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_wrap_vseq)
    function new(string name = "axi_sram_burst_wrap_vseq"); super.new(name); endfunction

    task body();
      axi_txn_request_item aw = axi_txn_request_item::type_id::create("aw");
      bit legal;
      await_reset();
      // 2-beat INCR (8-byte) burst whose second beat lands one word past the aperture
      // top -- i.e. it crosses the 4 KiB boundary at SRAMBase+SRAMLength.
      legal = aw.randomize() with {
        m_addr  == (top_pkg::SRAMBase + top_pkg::SRAMLength - WordBytes);
        m_len   == 8'd1;
        m_size  == 3'd3;
        m_burst == BurstIncr;
      };
      if (legal)
        `uvm_error(get_full_name(), {"burst_wrap: a burst crossing the SRAM aperture top randomised ",
                  "as legal -- the AXI4 4 KiB-boundary constraint is missing"})
      else
        `uvm_info(get_full_name(), {"burst_wrap: a burst crossing the SRAM aperture top is rejected by ",
                  "the AXI4 4 KiB-boundary constraint; the partial-out-of-range scenario cannot be ",
                  "issued by a compliant master, so u0s8nt is met by proxy -- PASS"}, UVM_LOW)
    endtask
  endclass


  // atomics_excluded — spec exclusion (bsi4rc); no functional test required.
  class axi_sram_atomics_excluded_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_atomics_excluded_vseq)
    function new(string name = "axi_sram_atomics_excluded_vseq"); super.new(name); endfunction

    task body();
      await_reset();
      `uvm_info(get_full_name(), {"atomics_excluded (bsi4rc): atomic (ATOP) accesses are explicitly ",
                "out of scope per spec and need no functional test. Recorded for traceability."},
                UVM_LOW)
    endtask
  endclass

