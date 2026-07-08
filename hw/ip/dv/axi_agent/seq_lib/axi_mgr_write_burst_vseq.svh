// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A virtual sequence that sends a single AXI write burst of arbitrary length.
//
// This is the multi-beat generalisation of axi_mgr_write_fixed_vseq. The caller configures the AW
// request fields and supplies one write data item per beat in m_data_items (its length sets AWLEN).
// The B response is collected into the rsp field, which is created before the sequence completes
// (or is left with a null m_write_response on reset).

class axi_mgr_write_burst_vseq extends uvm_sequence#(uvm_sequence_item, axi_fixed_write_rsp_item);
  `uvm_object_utils(axi_mgr_write_burst_vseq)

  // The write response router. Set this by calling set_write_response_router before starting.
  local axi_response_router        m_write_response_router;

  // Sequencers for AW, W and B. Set these by calling set_sequencers before starting.
  local write_request_sequencer_t  m_write_request_sequencer;
  local write_data_sequencer_t     m_write_data_sequencer;
  local write_response_sequencer_t m_write_response_sequencer;

  // AW request fields. Set these (as needed) before starting the sequence.
  bit [31:0]  m_id;
  bit [63:0]  m_addr;
  bit [2:0]   m_size  = 3'd3;          // AWSIZE (log2 bytes per beat); 8 bytes by default
  burst_e     m_burst = BurstIncr;     // AWBURST
  bit [3:0]   m_region;
  bit         m_lock;
  bit [3:0]   m_cache;
  bit [2:0]   m_prot;
  bit [3:0]   m_qos;
  bit [127:0] m_user;                  // AWUSER (the CHERI tag travels on WUSER, not here)

  // The write data beats, in order; one item per beat. AWLEN is set to m_data_items.size()-1.
  axi_write_data_item m_data_items[$];

  extern function new(string name="");
  extern task body();

  // Set the write response router
  extern function void set_write_response_router(axi_response_router router);

  // Set sequencers for the AW, W and B channels
  extern function void set_sequencers(write_request_sequencer_t  write_request_sequencer,
                                      write_data_sequencer_t     write_data_sequencer,
                                      write_response_sequencer_t write_response_sequencer);
endclass

function axi_mgr_write_burst_vseq::new(string name="");
  super.new(name);
endfunction

task axi_mgr_write_burst_vseq::body();
  axi_mgr_txn_request_seq        aw_seq;
  axi_mgr_write_listed_data_seq  w_seq;
  axi_mgr_write_response_seq     b_seq;
  uvm_sequence_item              write_response_item;
  axi_write_response_item        write_response;

  if (m_write_response_router == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because there is no write response router.")
  end
  if (m_write_request_sequencer == null ||
      m_write_data_sequencer == null ||
      m_write_response_sequencer == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because sequencers are not all set.")
  end
  if (m_data_items.size() == 0) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence: m_data_items is empty.")
  end

  // Send the write request (AW). All fields are pinned via the m_use_fixed_* mechanism.
  aw_seq = axi_mgr_txn_request_seq::type_id::create("aw_seq");
  aw_seq.m_use_fixed_id     = 1'b1;  aw_seq.m_fixed_id     = m_id;
  aw_seq.m_use_fixed_addr   = 1'b1;  aw_seq.m_fixed_addr   = m_addr;
  aw_seq.m_use_fixed_region = 1'b1;  aw_seq.m_fixed_region = m_region;
  aw_seq.m_use_fixed_len    = 1'b1;  aw_seq.m_fixed_len    = 8'(m_data_items.size() - 1);
  aw_seq.m_use_fixed_size   = 1'b1;  aw_seq.m_fixed_size   = m_size;
  aw_seq.m_use_fixed_burst  = 1'b1;  aw_seq.m_fixed_burst  = m_burst;
  aw_seq.m_use_fixed_lock   = 1'b1;  aw_seq.m_fixed_lock   = m_lock;
  aw_seq.m_use_fixed_cache  = 1'b1;  aw_seq.m_fixed_cache  = m_cache;
  aw_seq.m_use_fixed_prot   = 1'b1;  aw_seq.m_fixed_prot   = m_prot;
  aw_seq.m_use_fixed_qos    = 1'b1;  aw_seq.m_fixed_qos    = m_qos;
  aw_seq.m_use_fixed_user   = 1'b1;  aw_seq.m_fixed_user   = m_user;
  if (!aw_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize aw_seq.")
  end

  // Send the write data (W): one beat per item in m_data_items.
  w_seq = axi_mgr_write_listed_data_seq::type_id::create("w_seq");
  w_seq.m_items = m_data_items;
  if (!w_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize w_seq.")
  end

  // Create a sequence to receive a single write response (B). It might or might not match our ID;
  // the router sorts that out by ID.
  b_seq = axi_mgr_write_response_seq::type_id::create("b_seq");
  if (!b_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize b_seq.")
  end

  // Consume a write response in the background and hand it to the router.
  fork begin
    b_seq.start(m_write_response_sequencer);
    if (b_seq.rsp != null) begin
      m_write_response_router.on_response(b_seq.rsp.m_id, b_seq.rsp);
    end
  end join_none

  // Run AW and W, and wait for our B response.
  fork
    aw_seq.start(m_write_request_sequencer);
    w_seq.start(m_write_data_sequencer);
    m_write_response_router.wait_for_response(m_id, write_response_item);
  join

  // write_response_item is null on reset; otherwise downcast to the concrete type.
  if (write_response_item != null && !$cast(write_response, write_response_item))
    `uvm_fatal(get_full_name(), "wait_for_response returned unexpected item type")

  rsp = axi_fixed_write_rsp_item::type_id::create("rsp");
  rsp.m_aw_status      = aw_seq.rsp;
  rsp.m_w_status       = w_seq.rsp;
  rsp.m_write_response = write_response;
endtask

function void axi_mgr_write_burst_vseq::set_write_response_router(axi_response_router router);
  if (router == null) `uvm_fatal(get_full_name(), "Router is null.")
  m_write_response_router = router;
endfunction

function void
  axi_mgr_write_burst_vseq::set_sequencers(write_request_sequencer_t  write_request_sequencer,
                                           write_data_sequencer_t     write_data_sequencer,
                                           write_response_sequencer_t write_response_sequencer);
  if (write_request_sequencer == null)  `uvm_fatal(get_full_name(), "No write_request_sequencer.")
  if (write_data_sequencer == null)     `uvm_fatal(get_full_name(), "No write_data_sequencer.")
  if (write_response_sequencer == null) `uvm_fatal(get_full_name(), "No write_response_sequencer.")

  m_write_request_sequencer  = write_request_sequencer;
  m_write_data_sequencer     = write_data_sequencer;
  m_write_response_sequencer = write_response_sequencer;
endfunction
