// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan reset_state: out of reset, read every register, then the performance registers and
  // the reserved space.
  class tagctrl_reset_state_vseq extends tagctrl_base_vseq;
    `uvm_object_utils(tagctrl_reset_state_vseq)

    function new(string name = "tagctrl_reset_state_vseq");
      super.new(name);
    endfunction

    constraint reset_state_c {
      configure == 0;
      num_ops == MaxOps;
      foreach (ops[i]) {
        ops[i].port == PortCfg;
        !ops[i].write;
        i < 6 -> ops[i].addr == 8 * i;
        // Both the table and the sections place the performance registers
        i == 6 -> ops[i].addr == 'heb0;
        i == 7 -> ops[i].addr == 'hec0;
        i == 8 -> ops[i].addr == 'hed0;
        i == 9 -> ops[i].addr == 'hee0;
        i == 10 -> ops[i].addr == 'hf00;
        i == 11 -> ops[i].addr == 'hff8;
        i >= 12 -> ops[i].addr >= RegTagTableTop + 8;
      }
    }
  endclass
