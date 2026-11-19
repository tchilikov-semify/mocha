// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Where an access on the tagged subordinate goes, relative to the configuration of the vseq
  typedef enum {TgtCovered, TgtUncovered, TgtTagTable} tagctrl_target_e;

  // One access on the configuration or the tagged subordinate. tagctrl_base_vseq randomises a list
  // of them and runs them one after the other.
  class tagctrl_op extends uvm_object;
    `uvm_object_utils(tagctrl_op)

    rand tagctrl_port_e   port;
    rand tagctrl_target_e target;
    rand bit              write;
    rand bit [AxiIdWidth-1:0] id;
    rand bit [63:0]       addr;
    rand bit [7:0]        len;
    rand bit [2:0]        size;
    rand burst_e          burst;

    // Per beat, with the byte at the beat's address least significant
    rand bit [63:0]       wdata[];
    rand bit [7:0]        wstrb[];
    rand bit              wuser[];

    // Every beat carries the same WUSER, every strobe is set
    rand bit              uniform_user;
    rand bit              full_strb;

    // Read data of each beat once the access has completed, addressed byte least significant
    bit [63:0]            rdata[$];

    function new(string name = "tagctrl_op");
      super.new(name);
    endfunction

    constraint beats_c {
      wdata.size() == len + 1;
      wstrb.size() == len + 1;
      wuser.size() == len + 1;
    }

    // Burst lengths are kept to 16 beats; WRAP bursts and exclusive accesses are open questions
    // of the specification.
    constraint axi_c {
      size <= $clog2(BusBytes);
      len < 16;
      burst inside {BurstFixed, BurstIncr};
      burst == BurstIncr -> ((addr[11:0] >> size) + len + 1) <= (13'h1000 >> size);
    }

    constraint user_c {
      uniform_user dist {1 := 4, 0 := 1};
      uniform_user -> foreach (wuser[j]) wuser[j] == wuser[0];
    }

    constraint strb_c {
      full_strb dist {1 := 4, 0 := 1};
      full_strb -> foreach (wstrb[j]) wstrb[j] == 8'hff;
    }

    // The register map is accessed a whole 64-bit register at a time: how narrower accesses
    // behave is an open question of the specification.
    constraint cfg_c {
      port == PortCfg -> {
        len == 0;
        size == 3;
        burst == BurstIncr;
        addr < CfgSpaceBytes;
        addr[2:0] == 0;
        full_strb;
        wuser[0] == 0;
      }
    }

    function string convert2string();
      return $sformatf("%s %s addr 0x%016h len %0d size %0d %s", port.name(),
                       write ? "write" : "read", addr, len, size, burst.name());
    endfunction
  endclass
