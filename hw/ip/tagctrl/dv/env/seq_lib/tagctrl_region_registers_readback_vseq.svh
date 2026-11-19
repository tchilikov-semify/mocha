// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan region_registers_readback: write covered_base, covered_top and tag_table_base with any
  // 64-bit value and read each write back.
  class tagctrl_region_registers_readback_vseq extends tagctrl_base_vseq;
    `uvm_object_utils(tagctrl_region_registers_readback_vseq)

    function new(string name = "tagctrl_region_registers_readback_vseq");
      super.new(name);
    endfunction

    // Any value, not only the configuration of the vseq
    constraint region_write_c {}

    constraint region_registers_readback_c {
      configure == 0;
      num_ops % 2 == 0;
      num_ops >= 12;
      foreach (ops[i]) {
        ops[i].port == PortCfg;
        ops[i].addr inside {RegCoveredBase, RegCoveredTop, RegTagTableBase};
        ops[i].write == (i % 2 == 0);
        i % 2 == 1 -> ops[i].addr == ops[i - 1].addr;
      }
    }
  endclass
