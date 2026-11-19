// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan register_map: while unlocked and Unconfigured, read, write and read again each register
  // from status to tag_table_top in turn. Control writes carry no command, and the region
  // registers are written with a valid configuration.
  class tagctrl_register_map_vseq extends tagctrl_base_vseq;
    `uvm_object_utils(tagctrl_register_map_vseq)

    function new(string name = "tagctrl_register_map_vseq");
      super.new(name);
    endfunction

    constraint register_map_c {
      configure == 0;
      baseline_cfg == 1;
      num_ops == 18;
      foreach (ops[i]) {
        ops[i].port == PortCfg;
        ops[i].addr == 8 * (i / 3);
        ops[i].write == (i % 3 == 1);
        ops[i].addr == RegControl -> (ops[i].wdata[0] & CtrlCmdMask) == 0;
      }
    }
  endclass
