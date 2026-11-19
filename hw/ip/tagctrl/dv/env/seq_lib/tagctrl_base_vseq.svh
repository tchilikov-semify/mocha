// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // The fully random test. After reset it may program the region registers and start the
  // controller, then runs num_ops random accesses on the configuration and the tagged
  // subordinates, one at a time. Every vseq of a vPlan testpoint extends it and only adds
  // constraints; a directed step is a constraint that fixes the values.
  class tagctrl_base_vseq extends uvm_sequence;
    `uvm_object_utils(tagctrl_base_vseq)
    `uvm_declare_p_sequencer(tagctrl_virtual_sequencer)

    localparam int unsigned MaxOps = 40;

    // Zeroing time grows with the covered region, so keep it to a size a test can wait for
    localparam bit [63:0] MaxCoveredBytes = 64'h400_0000;

    // Clock cycles an access may take before the DUT counts as hung
    localparam int unsigned MaxOpClks = 10000;

    // Program the region registers with the values below and start, before the ops
    rand bit        configure;

    // The baseline region layout of the vPlan
    rand bit        baseline_cfg;

    rand bit [63:0] covered_base;
    rand bit [63:0] covered_top;
    rand bit [63:0] tag_table_base;

    rand int unsigned num_ops;
    rand tagctrl_op   ops[MaxOps];

    // Set by configure_and_start if a status read showed Zeroing
    bit saw_zeroing;

    function new(string name = "tagctrl_base_vseq");
      super.new(name);
      foreach (ops[i]) ops[i] = tagctrl_op::type_id::create($sformatf("op_%0d", i));
    endfunction

    constraint configure_c {
      configure dist {1 := 4, 0 := 1};
    }

    constraint num_ops_c {
      num_ops inside {[1:MaxOps]};
    }

    // Mostly aligned, so that most starts take the configuration. A covered top below the base is
    // left out, since it is no practical size.
    constraint region_c {
      covered_top - covered_base <= MaxCoveredBytes;
      covered_base[12:0] dist {0 :/ 9, [1:13'h1fff] :/ 1};
      covered_top[12:0] dist {0 :/ 9, [1:13'h1fff] :/ 1};
      tag_table_base[5:0] dist {0 :/ 9, [1:6'h3f] :/ 1};
    }

    // A 4 MiB covered region, beyond the reach of the leaf cache, with uncovered space below and
    // above it, a tag table outside it, and every boundary 8 KiB aligned
    constraint baseline_cfg_c {
      baseline_cfg -> {
        covered_base % 8192 == 0;
        covered_top == covered_base + 64'h40_0000;
        covered_base >= 8192;
        covered_top <= 64'hffff_ffff_ffff_e000;
        tag_table_base % 8192 == 0;
        tag_table_base <= 64'hffff_ffff_fff0_0000;
        tag_table_base + 64'h10_0000 <= covered_base || tag_table_base >= covered_top;
      }
    }

    // Accesses on the tagged subordinate mostly go to the covered region
    constraint target_c {
      foreach (ops[i]) {
        ops[i].port dist {PortTag := 3, PortCfg := 1};
        ops[i].target dist {TgtCovered := 6, TgtUncovered := 3, TgtTagTable := 1};
        ops[i].port == PortTag && ops[i].target == TgtCovered ->
          ops[i].addr - covered_base < covered_top - covered_base;
        ops[i].port == PortTag && ops[i].target == TgtUncovered ->
          !(ops[i].addr - covered_base < covered_top - covered_base);
        ops[i].port == PortTag && ops[i].target == TgtTagTable ->
          ops[i].addr - tag_table_base < 64'h1000;
      }
    }

    // Accesses on the configuration subordinate mostly go to the registers, and control writes
    // mostly carry one command
    constraint cfg_op_c {
      foreach (ops[i]) {
        ops[i].port == PortCfg -> ops[i].addr dist {[0:RegTagTableTop] :/ 8,
                                                    [RegTagTableTop + 8:CfgSpaceBytes - 8] :/ 2};
        ops[i].port == PortCfg && ops[i].write && ops[i].addr == RegControl ->
          ops[i].wdata[0] dist {CtrlStart :/ 4, CtrlStop :/ 2, CtrlResume :/ 1, CtrlLock :/ 1,
                                [0:64'hffff_ffff_ffff_ffff] :/ 2};
      }
    }

    // A region register write puts back the value of the vseq, so the next start is practical
    constraint region_write_c {
      foreach (ops[i]) {
        ops[i].port == PortCfg && ops[i].write -> {
          ops[i].addr == RegCoveredBase -> ops[i].wdata[0] == covered_base;
          ops[i].addr == RegCoveredTop -> ops[i].wdata[0] == covered_top;
          ops[i].addr == RegTagTableBase -> ops[i].wdata[0] == tag_table_base;
        }
      }
    }

    task body();
      await_reset();
      if (configure) configure_and_start();
      for (int unsigned i = 0; i < num_ops; i++) run_op(ops[i]);
    endtask

    // Reset the DUT, then wait until the agents are also out of reset
    protected task await_reset();
      int unsigned stable = 0;
      p_sequencer.clk_rst_vif.apply_reset();
      for (int unsigned waited = 0; stable < 20; waited++) begin
        if (waited > 10000) `uvm_fatal(get_full_name(), "Reset never released")
        p_sequencer.clk_rst_vif.wait_clks(1);
        stable = (p_sequencer.agent_rst_vif.rst_n === 1'b1) ? stable + 1 : 0;
      end
    endtask

    // Program the region registers and start, wait for Zeroing to end, then read tag_table_top
    // as software would to size the tag table
    protected task configure_and_start();
      bit [63:0] status;
      cfg_write(RegCoveredBase, covered_base);
      cfg_write(RegCoveredTop, covered_top);
      cfg_write(RegTagTableBase, tag_table_base);
      cfg_write(RegControl, CtrlStart);
      for (int unsigned polls = 0; ; polls++) begin
        if (polls > 10000) `uvm_fatal(get_full_name(), "Zeroing never ended")
        cfg_read(RegStatus, status);
        if (!status[StatusZeroing]) break;
        saw_zeroing = 1'b1;
      end
      cfg_read(RegTagTableTop, status);
    endtask

    protected task cfg_write(bit [11:0] offset, bit [63:0] data);
      tagctrl_op op = tagctrl_op::type_id::create("cfg_write");
      if (!op.randomize() with { port == PortCfg; write; addr == offset; wdata[0] == data; }) begin
        `uvm_fatal(get_full_name(), "Cannot randomize a configuration write")
      end
      run_op(op);
    endtask

    protected task cfg_read(bit [11:0] offset, output bit [63:0] data);
      tagctrl_op op = tagctrl_op::type_id::create("cfg_read");
      if (!op.randomize() with { port == PortCfg; !write; addr == offset; }) begin
        `uvm_fatal(get_full_name(), "Cannot randomize a configuration read")
      end
      run_op(op);
      data = op.rdata[0];
    endtask

    // Send one access and wait for its response
    protected task run_op(tagctrl_op op);
      axi_txn_sequencer_t seqr = (op.port == PortCfg) ? p_sequencer.cfg_seqr : p_sequencer.tag_seqr;
      axi_transfer_seq    seq  = axi_transfer_seq::type_id::create("seq");

      `uvm_info(get_name(), op.convert2string(), UVM_HIGH)
      seq.set_bus_properties(seqr.m_vif);
      if (!seq.randomize() with { m_write       == local::op.write;
                                  m_req.m_id    == local::op.id;
                                  m_req.m_addr  == local::op.addr;
                                  m_req.m_len   == local::op.len;
                                  m_req.m_size  == local::op.size;
                                  m_req.m_burst == local::op.burst;
                                  m_req.m_lock  == 1'b0;
                                  m_req.m_user  == '0; }) begin
        `uvm_fatal(get_full_name(), {"Cannot randomize ", op.convert2string()})
      end
      // Keep only the bytes each beat carries
      if (op.write) begin
        foreach (op.wdata[n]) begin
          bit [63:0]   beat_addr;
          int unsigned lower, upper, nbytes;
          axi_beat_lanes(op.addr, op.size, op.len, op.burst, BusBytes, n, beat_addr, lower,
                         upper);
          nbytes = upper - lower + 1;
          seq.m_beat_wdata.push_back(nbytes == 8 ? op.wdata[n] :
                                                   op.wdata[n] & ((64'h1 << (8 * nbytes)) - 1));
          seq.m_beat_wstrb.push_back(op.wstrb[n] & ((9'h1 << nbytes) - 1));
          seq.m_beat_wuser.push_back(op.wuser[n]);
        end
      end
      // A DUT that stops responding fails the test at once
      fork begin
        fork
          seq.start(seqr);
          begin
            p_sequencer.clk_rst_vif.wait_clks(MaxOpClks);
            `uvm_fatal(get_full_name(), {"DUT stopped responding to ", op.convert2string()})
          end
        join_any
        disable fork;
      end join
      if (!seq.has_full_transaction()) begin
        `uvm_fatal(get_full_name(), {"No complete response to ", op.convert2string()})
      end
      op.rdata.delete();
      if (!op.write) foreach (seq.m_responses[n]) op.rdata.push_back(seq.m_responses[n].m_rdata);
    endtask
  endclass
