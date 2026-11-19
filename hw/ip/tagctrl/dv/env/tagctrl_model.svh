// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // What the specification says the tag controller returns on its two subordinate ports, given the
  // accesses seen so far. Where the specification leaves an answer open, or the DUT may
  // legitimately be in more than one state, the model widens what it accepts and narrows it again
  // from what the next status read shows. Bytes and tags it cannot predict are not checked.
  class tagctrl_model extends uvm_object;
    `uvm_object_utils(tagctrl_model)

    typedef enum {CfgValid, CfgInvalid, CfgAmbiguous} cfg_check_e;

    // Whether tags are tracked: StUnknown stands for either.
    typedef enum {StUnconfigured, StServing, StUnknown} state_e;

    typedef enum {OverlapNo, OverlapYes, OverlapMaybe} overlap_e;

    // Registers
    bit [63:0] covered_base, covered_top, tag_table_base;
    bit        locked;

    // Set by the first region register write after reset; until then the error field reads 0
    bit region_written;

    // The last tag_table_top read since the region registers last changed
    bit        ttt_seen;
    bit [63:0] ttt_last;

    state_e state;

    // The state bits of status (Serving, Zeroing, Flushing, Unconfigured) a read may show
    bit [3:0] allowed_state;

    // The configuration taken by the last start, and the tag table top once read for it
    bit [63:0] run_base, run_top, run_ttb, run_ttt;
    bit        run_ttt_known;

    // Bytes written through the tagged subordinate; absent bytes are unknown
    bit [7:0] mem[bit [63:0]];

    // Chunk tags, by address / ChunkBytes; a chunk in neither array has its tag clear
    bit tag_set[bit [63:0]];
    bit tag_unknown[bit [63:0]];

    function new(string name = "tagctrl_model");
      super.new(name);
      reset();
    endfunction

    function void reset();
      covered_base   = '0;
      covered_top    = '0;
      tag_table_base = '0;
      locked         = 1'b0;
      region_written = 1'b0;
      ttt_seen       = 1'b0;
      state          = StUnconfigured;
      allowed_state  = 4'b1 << StatusUnconfigured;
      run_ttt_known  = 1'b0;
      // Memory contents survive a reset of the DUT; its tag table does not matter while
      // Unconfigured and is cleared by the next start.
      tag_set.delete();
      tag_unknown.delete();
    endfunction

    // ------------------------------------------------------------------------------------------
    // Configuration
    // ------------------------------------------------------------------------------------------

    // The most tag table space a covered range may need: 1/127 of it, or 128 bytes
    static function bit [63:0] tag_table_bound(bit [63:0] base, bit [63:0] top);
      bit [63:0] range = top - base;
      bit [63:0] bound = (range + 126) / 127;
      if (range == 0) return 0;
      return (bound > 128) ? bound : 128;
    endfunction

    // The covered alignment is 8 KiB in the register descriptions and covered_align (4 KiB) in the
    // parameter table, so a configuration that only meets the weaker one is ambiguous. So is one
    // whose tag table may run past the top of the address space.
    static function cfg_check_e check_cfg(bit [63:0] base, bit [63:0] top, bit [63:0] ttb);
      if (top < base) return CfgInvalid;
      if (base % CoveredAlign != 0 || top % CoveredAlign != 0) return CfgInvalid;
      if (ttb % TagStoreAlign != 0) return CfgInvalid;
      if (base % 8192 != 0 || top % 8192 != 0) return CfgAmbiguous;
      if (ttb + tag_table_bound(base, top) < ttb) return CfgAmbiguous;
      return CfgValid;
    endfunction

    function void cfg_write(bit [11:0] offset, bit [63:0] data, bit [7:0] strb);
      bit [63:0] mask;
      for (int i = 0; i < 8; i++) mask[8*i +: 8] = {8{strb[i]}};

      if (offset == RegControl) begin
        control_write(data & mask);
      end else if (offset inside {RegCoveredBase, RegCoveredTop, RegTagTableBase} && !locked) begin
        case (offset)
          RegCoveredBase:  covered_base   = (covered_base & ~mask) | (data & mask);
          RegCoveredTop:   covered_top    = (covered_top & ~mask) | (data & mask);
          default:         tag_table_base = (tag_table_base & ~mask) | (data & mask);
        endcase
        region_written = 1'b1;
        ttt_seen       = 1'b0;
        state          = StUnconfigured;
        allowed_state  = 4'b1 << StatusUnconfigured;
      end
    endfunction

    // Commands must be one-hot, reserved bits are ignored, and only lock has an effect while
    // locked (allow_flush_when_locked is clear)
    local function void control_write(bit [63:0] data);
      bit [63:0] cmd = data & CtrlCmdMask;
      if ($countones(cmd) != 1) return;
      if (cmd == CtrlLock) begin
        locked = 1'b1;
        return;
      end
      if (locked) return;
      case (cmd)
        CtrlStart: start();
        CtrlStop:  stop();
        default:   ; // allow_resume is clear
      endcase
    endfunction

    local function void start();
      cfg_check_e chk = check_cfg(covered_base, covered_top, tag_table_base);
      if (state != StUnconfigured) begin
        // No arc for a start outside Unconfigured
        state         = StUnknown;
        allowed_state = '1;
        weaken_tags();
        forget_tag_table();
        return;
      end
      if (chk == CfgInvalid) begin
        allowed_state = (4'b1 << StatusUnconfigured) | (4'b1 << StatusZeroing);
        return;
      end
      run_base      = covered_base;
      run_top       = covered_top;
      run_ttb       = tag_table_base;
      run_ttt       = ttt_last;
      run_ttt_known = ttt_seen;
      tag_set.delete();
      tag_unknown.delete();
      forget_tag_table();
      if (chk == CfgValid) begin
        state         = StServing;
        allowed_state = (4'b1 << StatusZeroing) | (4'b1 << StatusServing);
      end else begin
        state         = StUnknown;
        allowed_state = (4'b1 << StatusZeroing) | (4'b1 << StatusServing) |
                        (4'b1 << StatusUnconfigured);
      end
    endfunction

    // Flushing returns to Serving in the stop description and to Unconfigured in the theory of
    // operation, so either is accepted.
    local function void stop();
      if (state != StServing) weaken_tags();
      state         = StUnknown;
      allowed_state = (4'b1 << StatusFlushing) | (4'b1 << StatusServing) |
                      (4'b1 << StatusUnconfigured);
    endfunction

    // Check a configuration read. Returns a description of the mismatch, or "" if it matches.
    function string cfg_read(bit [11:0] offset, logic [63:0] data);
      case (offset)
        RegStatus:       return status_read(data);
        RegControl:      return expect_eq("control", data, 0);
        RegCoveredBase:  return expect_eq("covered_base", data, covered_base);
        RegCoveredTop:   return expect_eq("covered_top", data, covered_top);
        RegTagTableBase: return expect_eq("tag_table_base", data, tag_table_base);
        RegTagTableTop:  return tag_table_top_read(data);
        // Reserved space and, with no counters enabled, every performance register read zero
        default:         return expect_eq($sformatf("offset 0x%03h", offset), data, 0);
      endcase
    endfunction

    local function string status_read(logic [63:0] data);
      bit [3:0] st = data[3:0];
      if ($isunknown(data)) return $sformatf("status 0x%016h has X or Z bits", data);
      if (data & StatusReservedMask) return $sformatf("status 0x%016h sets reserved bits", data);
      if (data[StatusLocked] != locked) begin
        return $sformatf("status 0x%016h: Locked is %0b, expected %0b", data, data[StatusLocked],
                         locked);
      end
      if (!region_written && (data & StatusErrorMask)) begin
        return $sformatf("status 0x%016h reports an error for the reset configuration", data);
      end
      if ($countones(st) != 1) begin
        return $sformatf("status 0x%016h: state bits are not one-hot", data);
      end
      if (!(st & allowed_state)) begin
        return $sformatf("status 0x%016h: state bits 0b%04b, expected one of 0b%04b", data, st,
                         allowed_state);
      end
      if (st[StatusServing]) begin
        state         = StServing;
        allowed_state = st;
      end else if (st[StatusUnconfigured]) begin
        state         = StUnconfigured;
        allowed_state = st;
      end
      return "";
    endfunction

    local function string tag_table_top_read(logic [63:0] data);
      cfg_check_e chk   = check_cfg(covered_base, covered_top, tag_table_base);
      bit [63:0]  bound = tag_table_bound(covered_base, covered_top);
      string      err   = "";

      if ($isunknown(data)) return $sformatf("tag_table_top 0x%016h has X or Z bits", data);
      if (ttt_seen && data != ttt_last) begin
        err = $sformatf("tag_table_top changed from 0x%016h to 0x%016h", ttt_last, data);
      end else if (chk == CfgInvalid && data != 0) begin
        err = $sformatf("tag_table_top 0x%016h for an erroneous configuration, expected 0", data);
      end else if (chk == CfgValid && covered_top == covered_base && data != tag_table_base) begin
        err = $sformatf("tag_table_top 0x%016h for an empty covered region, expected 0x%016h",
                        data, tag_table_base);
      end else if (chk == CfgValid &&
                   (data < tag_table_base || data > tag_table_base + bound)) begin
        err = $sformatf("tag_table_top 0x%016h outside [0x%016h, 0x%016h]", data, tag_table_base,
                        tag_table_base + bound);
      end
      ttt_seen = 1'b1;
      ttt_last = data;
      // The region registers have not changed since the last start
      if (state != StUnconfigured && chk != CfgInvalid) begin
        run_ttt       = data;
        run_ttt_known = 1'b1;
      end
      return err;
    endfunction

    local static function string expect_eq(string name, logic [63:0] data, bit [63:0] exp);
      if (data !== exp) return $sformatf("%s read 0x%016h, expected 0x%016h", name, data, exp);
      return "";
    endfunction

    // ------------------------------------------------------------------------------------------
    // Tagged subordinate
    // ------------------------------------------------------------------------------------------

    // Whether [lo, hi] touches the tag table of the running configuration
    function overlap_e tag_table_overlap(bit [63:0] lo, bit [63:0] hi);
      bit [63:0] max_top;
      if (run_top == run_base) return OverlapNo;
      max_top = run_ttt_known ? run_ttt : run_ttb + tag_table_bound(run_base, run_top);
      if (hi < run_ttb || lo >= max_top) return OverlapNo;
      return run_ttt_known ? OverlapYes : OverlapMaybe;
    endfunction

    // Whether [lo, hi] lies in the covered region of the running configuration
    function overlap_e covered_overlap(bit [63:0] lo, bit [63:0] hi);
      if (hi < run_base || lo >= run_top) return OverlapNo;
      if (lo >= run_base && hi < run_top) return OverlapYes;
      return OverlapMaybe;
    endfunction

    // A request to the tag table must fail while Serving. Returns 1 for an error response, 0 for
    // OKAY, and -1 if either is acceptable.
    function int expected_error(bit [63:0] lo, bit [63:0] hi);
      overlap_e ov;
      if (state == StUnconfigured) return 0;
      ov = tag_table_overlap(lo, hi);
      if (ov == OverlapNo) return 0;
      if (ov == OverlapYes && state == StServing) return 1;
      return -1;
    endfunction

    function bit tag_known(bit [63:0] chunk, output bit tag);
      tag = tag_set.exists(chunk);
      return !tag_unknown.exists(chunk);
    endfunction

    function void set_tag(bit [63:0] chunk, bit known, bit tag);
      tag_set.delete(chunk);
      tag_unknown.delete(chunk);
      if (!known) tag_unknown[chunk] = 1'b1;
      else if (tag) tag_set[chunk] = 1'b1;
    endfunction

    // A set tag may have been kept or lost
    function void weaken_tags();
      foreach (tag_set[c]) tag_unknown[c] = 1'b1;
      tag_set.delete();
    endfunction

    // The DUT owns the memory behind its tag table, so stop predicting it
    function void forget_tag_table();
      forget_bytes(run_ttb, tag_table_bound(run_base, run_top));
    endfunction

    function void forget_bytes(bit [63:0] lo, bit [63:0] len);
      bit [63:0] idx = lo;
      if (len == 0) return;
      if (!mem.exists(idx) && !mem.next(idx)) return;
      while (idx - lo < len) begin
        mem.delete(idx);
        if (!mem.next(idx)) break;
      end
    endfunction
  endclass
