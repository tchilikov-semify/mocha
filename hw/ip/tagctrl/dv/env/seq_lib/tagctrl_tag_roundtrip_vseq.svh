// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan tag_roundtrip: once Serving with the baseline configuration, write capabilities with
  // their tags set or clear to the covered region, as aligned bursts of one or more whole chunks,
  // then read each burst back in the same order.
  class tagctrl_tag_roundtrip_vseq extends tagctrl_base_vseq;
    `uvm_object_utils(tagctrl_tag_roundtrip_vseq)

    localparam int unsigned NumWrites = MaxOps / 2;

    function new(string name = "tagctrl_tag_roundtrip_vseq");
      super.new(name);
    endfunction

    constraint tag_roundtrip_c {
      configure == 1;
      baseline_cfg == 1;
      num_ops == 2 * NumWrites;
      foreach (ops[i]) {
        ops[i].port == PortTag;
        ops[i].target == TgtCovered;
        ops[i].size == $clog2(BusBytes);
        ops[i].burst == BurstIncr;
        ops[i].addr % ChunkBytes == 0;
        (ops[i].len + 1) % (ChunkBytes / BusBytes) == 0;
        ops[i].full_strb;
        // One tag for every beat of a chunk
        foreach (ops[i].wuser[j]) {
          j % (ChunkBytes / BusBytes) != 0 -> ops[i].wuser[j] == ops[i].wuser[j - 1];
        }
        ops[i].write == (i < NumWrites);
        i >= NumWrites -> ops[i].addr == ops[i - NumWrites].addr;
        i >= NumWrites -> ops[i].len == ops[i - NumWrites].len;
      }
    }
  endclass
