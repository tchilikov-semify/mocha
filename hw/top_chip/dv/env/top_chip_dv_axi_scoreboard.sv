// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(top_chip_dv_axi_scoreboard)

  // Device-side AXI ID.
  typedef bit [top_pkg::AxiDevIdWidth-1:0] dev_id_t;

  axi_addr_range_t mem_map[$];
  string           default_subordinate_id = "INTERNAL_XBAR_DEFAULT";

  // The sw_dv window is a simulation-only sink so there is no subordinate tap on it and
  // nothing will ever arrive to match a manager access. It is excluded from routing comparison.
  string           sw_dv_window_id = "sim_sw_dv_window";

  `uvm_analysis_imp_decl(_mgr0_cva6)
  `uvm_analysis_imp_decl(_mgr1_dm_host)
  `uvm_analysis_imp_decl(_sub0_romctrlmem)
  `uvm_analysis_imp_decl(_sub1_sram)
  `uvm_analysis_imp_decl(_sub2_mailbox)
  `uvm_analysis_imp_decl(_sub3_tlcrossbar)
  `uvm_analysis_imp_decl(_sub4_dram)
  `uvm_analysis_imp_decl(_sub5_dm_dev)
  `uvm_analysis_imp_decl(_sub6_restofchip)
  `uvm_analysis_imp_decl(_reset)

  uvm_analysis_imp_mgr0_cva6        #(axi_mon_item, top_chip_dv_axi_scoreboard) mgr0_cva6_imp;
  uvm_analysis_imp_mgr1_dm_host     #(axi_mon_item, top_chip_dv_axi_scoreboard) mgr1_dm_host_imp;
  uvm_analysis_imp_sub0_romctrlmem  #(axi_mon_item, top_chip_dv_axi_scoreboard) sub0_romctrlmem_imp;
  uvm_analysis_imp_sub1_sram        #(axi_mon_item, top_chip_dv_axi_scoreboard) sub1_sram_imp;
  uvm_analysis_imp_sub2_mailbox     #(axi_mon_item, top_chip_dv_axi_scoreboard) sub2_mailbox_imp;
  uvm_analysis_imp_sub3_tlcrossbar  #(axi_mon_item, top_chip_dv_axi_scoreboard) sub3_tlcrossbar_imp;
  uvm_analysis_imp_sub4_dram        #(axi_mon_item, top_chip_dv_axi_scoreboard) sub4_dram_imp;
  uvm_analysis_imp_sub5_dm_dev      #(axi_mon_item, top_chip_dv_axi_scoreboard) sub5_dm_dev_imp;
  uvm_analysis_imp_sub6_restofchip  #(axi_mon_item, top_chip_dv_axi_scoreboard) sub6_restofchip_imp;
  uvm_analysis_imp_reset            #(axi_reset_item, top_chip_dv_axi_scoreboard) reset_imp;

  // A transaction sits in one of these queues. Expected_queue holds manager completions awaiting 
  // their subordinate counterpart, actual_queue the reverse.
  // Both empty means every observed transaction has been matched.
  protected axi_mon_item expected_queue[string][dev_id_t][$];
  protected axi_mon_item actual_queue[string][dev_id_t][$];

  // Set once the environment has seen the scoreboard fully drained and is ending the run phase.
  // The CPU traffic persists through shutdown.
  protected bit recording_stopped;

  // Set while the AXI fabric reset is asserted. Queued transactions are flushed
  protected bit under_reset;

  extern function new(string name, uvm_component parent);
  extern virtual function void build_phase(uvm_phase phase);
  // Record a subordinate address range from its base and size.
  extern protected function void add_mem_range(string name,
                                               bit [63:0] start_addr,
                                               bit [63:0] addr_size);
  // Device-side ID observed at a subordinate port (already carries the host index).
  extern protected function dev_id_t get_dev_id(bit [63:0] raw_id);
  // Device-side ID for a manager transaction: prepend the host index to its slave-side ID.
  extern protected function dev_id_t mgr_dev_id(int unsigned host_idx, bit [63:0] raw_id);
  // Return the subordinate range name that contains addr, or the default target.
  extern protected function string addr_to_mem_range(bit [63:0] addr);
  extern virtual function void perform_comparison(axi_mon_item exp,
                                                  axi_mon_item act,
                                                  string sub);

  // Match/queue a manager completion for host host_idx.
  extern protected function void record_manager_completion(axi_mon_item tr, int unsigned host_idx);

  // True when every observed transaction has been matched on both sides.
  // This is what the environment waits on before ending the run phase.
  extern virtual function bit is_drained();

  // Stop accepting new observations. Called by the environment once is_drained() has held.
  extern virtual function void stop_recording();

  extern virtual function void write_mgr0_cva6(axi_mon_item tr);
  extern virtual function void write_mgr1_dm_host(axi_mon_item tr);
  extern virtual function void write_sub0_romctrlmem(axi_mon_item tr);
  extern virtual function void write_sub1_sram(axi_mon_item tr);
  extern virtual function void write_sub2_mailbox(axi_mon_item tr);
  extern virtual function void write_sub3_tlcrossbar(axi_mon_item tr);
  extern virtual function void write_sub4_dram(axi_mon_item tr);
  extern virtual function void write_sub5_dm_dev(axi_mon_item tr);
  extern virtual function void write_sub6_restofchip(axi_mon_item tr);

  extern protected function void check_subordinate_arrival(axi_mon_item act, string sub_id);
  extern virtual function void write_reset(axi_reset_item item);
  extern virtual function void reset();
  extern virtual function void check_phase(uvm_phase phase);

endclass : top_chip_dv_axi_scoreboard

function top_chip_dv_axi_scoreboard::new(string name, uvm_component parent);
  super.new(name, parent);
  mgr0_cva6_imp        = new("mgr0_cva6_imp", this);
  mgr1_dm_host_imp     = new("mgr1_dm_host_imp", this);
  sub0_romctrlmem_imp  = new("sub0_romctrlmem_imp", this);
  sub1_sram_imp        = new("sub1_sram_imp", this);
  sub2_mailbox_imp     = new("sub2_mailbox_imp", this);
  sub3_tlcrossbar_imp  = new("sub3_tlcrossbar_imp", this);
  sub4_dram_imp        = new("sub4_dram_imp", this);
  sub5_dm_dev_imp      = new("sub5_dm_dev_imp", this);
  sub6_restofchip_imp  = new("sub6_restofchip_imp", this);
  reset_imp            = new("reset_imp", this);
endfunction : new

function void top_chip_dv_axi_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);

  add_mem_range("sub0_romctrlmem", top_pkg::RomCtrlMemBase, top_pkg::RomCtrlMemLength);
  add_mem_range("sub1_sram", top_pkg::SRAMBase, top_pkg::SRAMLength);
  add_mem_range("sub2_mailbox", top_pkg::MailboxBase, top_pkg::MailboxLength);
  add_mem_range("sub3_tlcrossbar", top_pkg::TlCrossbarBase, top_pkg::TlCrossbarLength);
  add_mem_range("sub4_dram", top_pkg::DRAMBase, top_pkg::DRAMUsableLength);
  add_mem_range("sub5_dm_dev", top_pkg::DebugMemBase, top_pkg::DebugMemLength);
  add_mem_range("sub6_restofchip", top_pkg::RestOfChipBase, top_pkg::RestOfChipLength);
  add_mem_range(sw_dv_window_id, top_pkg::SwDvWindowBase, top_pkg::SwDvWindowLength);
endfunction : build_phase

function void top_chip_dv_axi_scoreboard::add_mem_range(string name,
                                                        bit [63:0] start_addr,
                                                        bit [63:0] addr_size);
  bit [63:0] end_addr = start_addr + addr_size - 1;
  mem_map.push_back('{name, start_addr, end_addr});
endfunction : add_mem_range

function top_chip_dv_axi_scoreboard::dev_id_t
  top_chip_dv_axi_scoreboard::get_dev_id(bit [63:0] raw_id);
  bit [63:0] mask = (64'(1) << top_pkg::AxiDevIdWidth) - 1;
  return dev_id_t'(raw_id & mask);
endfunction : get_dev_id

function top_chip_dv_axi_scoreboard::dev_id_t
  top_chip_dv_axi_scoreboard::mgr_dev_id(int unsigned host_idx, bit [63:0] raw_id);
  bit [63:0] id_mask = (64'(1) << top_pkg::AxiIdWidth) - 1;
  return dev_id_t'((raw_id & id_mask) | (host_idx << top_pkg::AxiIdWidth));
endfunction : mgr_dev_id

function string top_chip_dv_axi_scoreboard::addr_to_mem_range(bit [63:0] addr);
  foreach (mem_map[i]) begin
    if (addr >= mem_map[i].start_addr && addr <= mem_map[i].end_addr) begin
      return mem_map[i].subordinate_name;
    end
  end
  return default_subordinate_id;
endfunction : addr_to_mem_range

function void top_chip_dv_axi_scoreboard::perform_comparison(axi_mon_item exp,
                                                             axi_mon_item act,
                                                             string sub);
  dev_id_t did = get_dev_id(act.get_id());

  // If directions disagree, flag it rather than comparing.
  if (exp.get_dir() != act.get_dir()) begin
    `uvm_error("SCB_DIR_MISMATCH",
               $sformatf("Direction mismatch on %s ID:%h: exp=%s act=%s",
                         sub, did, exp.get_dir().name(), act.get_dir().name()))
    return;
  end

  if (act.get_dir() == AXI_WRITE) begin
    axi_mon_write_item a, e;
    `DV_CHECK_FATAL($cast(a, act))
    `DV_CHECK_FATAL($cast(e, exp))
    if (a.awaddr  !== e.awaddr  || a.awlen   !== e.awlen  ||
        a.awsize  !== e.awsize  || a.awburst !== e.awburst) begin
      `uvm_error("SCB_ATTR_WR",
                 $sformatf({"Write attribute mismatch on %s ID:%h: ",
                             "act={addr:%h len:%h size:%h burst:%h} ",
                             "exp={addr:%h len:%h size:%h burst:%h}"},
                            sub, did, a.awaddr, a.awlen, a.awsize, a.awburst,
                            e.awaddr, e.awlen, e.awsize, e.awburst))
    end
    if (a.wdata != e.wdata) begin
      `uvm_error("SCB_WDATA",
                 $sformatf("Write data mismatch on %s ID:%h: act=%p exp=%p",
                           sub, did, a.wdata, e.wdata))
    end
    if (a.wstrb != e.wstrb) begin
      `uvm_error("SCB_WSTRB",
                 $sformatf("Write strobe mismatch on %s ID:%h: act=%p exp=%p",
                           sub, did, a.wstrb, e.wstrb))
    end
  end else begin
    axi_mon_read_item a, e;
    `DV_CHECK_FATAL($cast(a, act))
    `DV_CHECK_FATAL($cast(e, exp))
    if (a.araddr  !== e.araddr  || a.arlen   !== e.arlen  ||
        a.arsize  !== e.arsize  || a.arburst !== e.arburst) begin
      `uvm_error("SCB_ATTR_RD",
                 $sformatf({"Read attribute mismatch on %s ID:%h: ",
                             "act={addr:%h len:%h size:%h burst:%h} ",
                             "exp={addr:%h len:%h size:%h burst:%h}"},
                            sub, did, a.araddr, a.arlen, a.arsize, a.arburst,
                            e.araddr, e.arlen, e.arsize, e.arburst))
    end
    if (a.rdata != e.rdata) begin
      `uvm_error("SCB_RDATA",
                 $sformatf("Read data mismatch on %s ID:%h: act=%p exp=%p",
                           sub, did, a.rdata, e.rdata))
    end
    if (a.rresp != e.rresp) begin
      `uvm_error("SCB_RRESP",
                 $sformatf("Read response mismatch on %s ID:%h: act=%p exp=%p",
                           sub, did, a.rresp, e.rresp))
    end
  end
endfunction : perform_comparison

function void top_chip_dv_axi_scoreboard::record_manager_completion(axi_mon_item tr,
                                                                    int unsigned host_idx);
  bit    [63:0] addr = tr.get_addr();
  bit    [63:0] raw_id = tr.get_id();
  string        target_sub = addr_to_mem_range(addr);
  dev_id_t      did = mgr_dev_id(host_idx, raw_id);

  if (under_reset || recording_stopped) return;

  if (target_sub == default_subordinate_id) begin
    `uvm_error("SCB_ADDR_DECODE", $sformatf("Manager access to unmapped address: %h", addr))
  end else if (target_sub == sw_dv_window_id) begin
    return;
  end else begin
    if (actual_queue[target_sub].exists(did) && actual_queue[target_sub][did].size() > 0) begin
      axi_mon_item act_tr = actual_queue[target_sub][did].pop_front();
      perform_comparison(tr, act_tr, target_sub);
    end else begin
      expected_queue[target_sub][did].push_back(tr.item_clone());
    end
  end
endfunction : record_manager_completion

function void top_chip_dv_axi_scoreboard::stop_recording();
  recording_stopped = 1'b1;
endfunction : stop_recording

function bit top_chip_dv_axi_scoreboard::is_drained();
  foreach (expected_queue[s, i]) if (expected_queue[s][i].size() > 0) return 1'b0;
  foreach (actual_queue[s, i])   if (actual_queue[s][i].size()   > 0) return 1'b0;
  return 1'b1;
endfunction : is_drained

function void top_chip_dv_axi_scoreboard::write_mgr0_cva6(axi_mon_item tr);
  record_manager_completion(tr, int'(top_pkg::CVA6));
endfunction : write_mgr0_cva6

function void top_chip_dv_axi_scoreboard::write_mgr1_dm_host(axi_mon_item tr);
  record_manager_completion(tr, int'(top_pkg::DM_HOST));
endfunction : write_mgr1_dm_host

function void top_chip_dv_axi_scoreboard::check_subordinate_arrival(axi_mon_item act,
                                                                    string sub_id);
  dev_id_t did = get_dev_id(act.get_id());

  if (under_reset || recording_stopped) return;

  if (expected_queue[sub_id].exists(did) && expected_queue[sub_id][did].size() > 0) begin
    axi_mon_item exp_tr = expected_queue[sub_id][did].pop_front();
    perform_comparison(exp_tr, act, sub_id);
  end else begin
    actual_queue[sub_id][did].push_back(act.item_clone());
  end
endfunction : check_subordinate_arrival

function void top_chip_dv_axi_scoreboard::write_sub0_romctrlmem(axi_mon_item tr);
  check_subordinate_arrival(tr, "sub0_romctrlmem");
endfunction : write_sub0_romctrlmem

function void top_chip_dv_axi_scoreboard::write_sub1_sram(axi_mon_item tr);
  check_subordinate_arrival(tr, "sub1_sram");
endfunction : write_sub1_sram

function void top_chip_dv_axi_scoreboard::write_sub2_mailbox(axi_mon_item tr);
  check_subordinate_arrival(tr, "sub2_mailbox");
endfunction : write_sub2_mailbox

function void top_chip_dv_axi_scoreboard::write_sub3_tlcrossbar(axi_mon_item tr);
  check_subordinate_arrival(tr, "sub3_tlcrossbar");
endfunction : write_sub3_tlcrossbar

function void top_chip_dv_axi_scoreboard::write_sub4_dram(axi_mon_item tr);
  check_subordinate_arrival(tr, "sub4_dram");
endfunction : write_sub4_dram

function void top_chip_dv_axi_scoreboard::write_sub5_dm_dev(axi_mon_item tr);
  check_subordinate_arrival(tr, "sub5_dm_dev");
endfunction : write_sub5_dm_dev

function void top_chip_dv_axi_scoreboard::write_sub6_restofchip(axi_mon_item tr);
  check_subordinate_arrival(tr, "sub6_restofchip");
endfunction : write_sub6_restofchip

function void top_chip_dv_axi_scoreboard::write_reset(axi_reset_item item);
  under_reset = item.m_in_reset;
  if (under_reset) reset();
endfunction : write_reset

function void top_chip_dv_axi_scoreboard::reset();
  expected_queue.delete();
  actual_queue.delete();
endfunction : reset

function void top_chip_dv_axi_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);

  foreach (expected_queue[s, i]) begin
    if (expected_queue[s][i].size() > 0) begin
      `uvm_error("SCB_DRAIN_DROP", $sformatf("DROPPED: Manager request for %s (ID %h) lost", s, i))
    end
  end

  foreach (actual_queue[s, i]) begin
    if (actual_queue[s][i].size() > 0) begin
      axi_mon_item t = actual_queue[s][i][0];
      bit [63:0] a = t.get_addr();
      `uvm_error("SCB_DRAIN_ERROR",
                 $sformatf("ERROR: %s (ID %h) responded without a manager request: %s addr=%h (%0d leftover)",
                           s, i, t.get_dir().name(), a, actual_queue[s][i].size()))
    end
  end
endfunction : check_phase
