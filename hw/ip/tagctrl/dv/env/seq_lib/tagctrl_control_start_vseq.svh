// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan control_start: while unlocked and Unconfigured, program the baseline configuration and
  // start. Status must leave Unconfigured for Zeroing, then reach Serving.
  class tagctrl_control_start_vseq extends tagctrl_base_vseq;
    `uvm_object_utils(tagctrl_control_start_vseq)

    function new(string name = "tagctrl_control_start_vseq");
      super.new(name);
    endfunction

    constraint control_start_c {
      configure == 1;
      baseline_cfg == 1;
      num_ops inside {[1:4]};
      foreach (ops[i]) {
        ops[i].port == PortCfg;
        !ops[i].write;
        ops[i].addr == RegStatus;
      }
    }

    task body();
      super.body();
      if (!saw_zeroing) `uvm_error(get_full_name(), "Status never showed Zeroing after start")
    endtask
  endclass
