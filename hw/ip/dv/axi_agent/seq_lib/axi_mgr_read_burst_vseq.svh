// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A virtual sequence that sends a single AXI read burst of arbitrary length and collects every
// returned beat.
//
// This is the multi-beat generalisation of axi_mgr_read_fixed_vseq. The caller configures the AR
// request fields and the number of beats (via m_len). All R beats for our ID are gathered into
// m_read_beats, in beat order. rsp.m_read_data points at the first beat for convenience.

class axi_mgr_read_burst_vseq extends uvm_sequence#(uvm_sequence_item, axi_fixed_read_rsp_item);
  `uvm_object_utils(axi_mgr_read_burst_vseq)

  // The read response router. Set this by calling set_read_response_router before starting.
  local axi_response_router       m_read_response_router;

  // Sequencers for AR and R. Set these by calling set_sequencers before starting.
  local read_request_sequencer_t  m_read_request_sequencer;
  local read_data_sequencer_t     m_read_data_sequencer;

  // AR request fields. Set these (as needed) before starting the sequence.
  bit [31:0]  m_id;
  bit [63:0]  m_addr;
  bit [2:0]   m_size  = 3'd3;          // ARSIZE (log2 bytes per beat); 8 bytes by default
  bit [7:0]   m_len   = 8'd0;          // ARLEN (number of beats - 1)
  burst_e     m_burst = BurstIncr;     // ARBURST
  bit [3:0]   m_region;
  bit         m_lock;
  bit [3:0]   m_cache;
  bit [2:0]   m_prot;
  bit [3:0]   m_qos;
  bit [127:0] m_user;                  // ARUSER

  // The read data beats that came back, in beat order. Populated by body().
  axi_read_data_item m_read_beats[$];

  extern function new(string name="");
  extern task body();

  // Set the read response router
  extern function void set_read_response_router(axi_response_router router);

  // Set sequencers for the AR and R channels
  extern function void set_sequencers(read_request_sequencer_t  read_request_sequencer,
                                      read_data_sequencer_t     read_data_sequencer);
endclass

function axi_mgr_read_burst_vseq::new(string name="");
  super.new(name);
endfunction

task axi_mgr_read_burst_vseq::body();
  axi_mgr_txn_request_seq ar_seq;
  int unsigned            n_beats = 32'(m_len) + 1;

  if (m_read_response_router == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because there is no read response router.")
  end
  if (m_read_request_sequencer == null || m_read_data_sequencer == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because sequencers are not both set.")
  end

  // Send the read request (AR). All fields are pinned via the m_use_fixed_* mechanism.
  ar_seq = axi_mgr_txn_request_seq::type_id::create("ar_seq");
  ar_seq.m_use_fixed_id     = 1'b1;  ar_seq.m_fixed_id     = m_id;
  ar_seq.m_use_fixed_addr   = 1'b1;  ar_seq.m_fixed_addr   = m_addr;
  ar_seq.m_use_fixed_region = 1'b1;  ar_seq.m_fixed_region = m_region;
  ar_seq.m_use_fixed_len    = 1'b1;  ar_seq.m_fixed_len    = m_len;
  ar_seq.m_use_fixed_size   = 1'b1;  ar_seq.m_fixed_size   = m_size;
  ar_seq.m_use_fixed_burst  = 1'b1;  ar_seq.m_fixed_burst  = m_burst;
  ar_seq.m_use_fixed_lock   = 1'b1;  ar_seq.m_fixed_lock   = m_lock;
  ar_seq.m_use_fixed_cache  = 1'b1;  ar_seq.m_fixed_cache  = m_cache;
  ar_seq.m_use_fixed_prot   = 1'b1;  ar_seq.m_fixed_prot   = m_prot;
  ar_seq.m_use_fixed_qos    = 1'b1;  ar_seq.m_fixed_qos    = m_qos;
  ar_seq.m_use_fixed_user   = 1'b1;  ar_seq.m_fixed_user   = m_user;
  if (!ar_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize ar_seq.")
  end

  // Fork one R-accept sequence per beat, up front, so rready is asserted before the data arrives.
  // Each consumes a single R beat and hands it to the router keyed by RID. Because beats arrive in
  // order, on_response (and therefore the router's per-ID FIFO) preserves beat order regardless of
  // sequencer arbitration order.
  for (int unsigned i = 0; i < n_beats; i++) begin
    automatic axi_mgr_read_data_seq r_seq =
      axi_mgr_read_data_seq::type_id::create($sformatf("r_seq_%0d", i));
    if (!r_seq.randomize()) begin
      `uvm_fatal(get_full_name(), "Failed to randomize r_seq.")
    end
    fork begin
      r_seq.start(m_read_data_sequencer);
      if (r_seq.rsp != null) begin
        m_read_response_router.on_response(r_seq.rsp.m_id, r_seq.rsp);
      end
    end join_none
  end

  // Send AR and collect our n_beats responses.
  m_read_beats.delete();
  fork
    ar_seq.start(m_read_request_sequencer);
    begin
      for (int unsigned i = 0; i < n_beats; i++) begin
        uvm_sequence_item  read_data_item;
        axi_read_data_item read_data;
        m_read_response_router.wait_for_response(m_id, read_data_item);
        if (read_data_item == null) break;  // reset
        if (!$cast(read_data, read_data_item))
          `uvm_fatal(get_full_name(), "wait_for_response returned unexpected item type")
        m_read_beats.push_back(read_data);
      end
    end
  join

  rsp = axi_fixed_read_rsp_item::type_id::create("rsp");
  rsp.m_ar_status = ar_seq.rsp;
  rsp.m_read_data = (m_read_beats.size() > 0) ? m_read_beats[0] : null;
endtask

function void axi_mgr_read_burst_vseq::set_read_response_router(axi_response_router router);
  if (router == null) `uvm_fatal(get_full_name(), "Router is null.")
  m_read_response_router = router;
endfunction

function void
  axi_mgr_read_burst_vseq::set_sequencers(read_request_sequencer_t  read_request_sequencer,
                                          read_data_sequencer_t     read_data_sequencer);
  if (read_request_sequencer == null)  `uvm_fatal(get_full_name(), "No read_request_sequencer.")
  if (read_data_sequencer == null)     `uvm_fatal(get_full_name(), "No read_data_sequencer.")

  m_read_request_sequencer  = read_request_sequencer;
  m_read_data_sequencer     = read_data_sequencer;
endfunction
