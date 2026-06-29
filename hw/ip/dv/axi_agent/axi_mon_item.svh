// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A merged-transaction item produced by the passive AXI monitor (axi_monitor).
//
// One object can hold a whole write (AW + all W beats + B) or a whole read
// (AR + all R beats); obs_kind says which, and which fields are populated. The
// per-beat W/R payloads are queues. Signal widths use the same max footprint as
// the per-channel driver interfaces (axi_*_if): the interfaces already mask each
// field to its configured width, so the monitor records the resolved values
// directly.

class axi_mon_item extends uvm_sequence_item;

  axi_obs_e obs_kind;
  axi_dir_e dir;

  // Write address (AW)
  bit [31:0]   awid;
  bit [63:0]   awaddr;
  bit [7:0]    awlen;
  bit [2:0]    awsize;
  bit [1:0]    awburst;
  bit          awlock;
  bit [3:0]    awcache;
  bit [2:0]    awprot;
  bit [3:0]    awqos;
  bit [3:0]    awregion;
  bit [127:0]  awuser;

  // Write data (W) — one entry per beat
  bit [1023:0] wdata[$];
  bit [127:0]  wstrb[$];
  bit          wlast[$];
  bit [511:0]  wuser[$];

  // Write response (B)
  bit [31:0]   bid;
  bit [2:0]    bresp;
  bit [15:0]   buser;

  // Read address (AR)
  bit [31:0]   arid;
  bit [63:0]   araddr;
  bit [7:0]    arlen;
  bit [2:0]    arsize;
  bit [1:0]    arburst;
  bit          arlock;
  bit [3:0]    arcache;
  bit [2:0]    arprot;
  bit [3:0]    arqos;
  bit [3:0]    arregion;
  bit [127:0]  aruser;

  // Read data (R) — one entry per beat
  bit [31:0]   rid;
  bit [1023:0] rdata[$];
  bit [2:0]    rresp[$];
  bit          rlast[$];
  bit [527:0]  ruser[$];

  `uvm_object_utils_begin(axi_mon_item)
    `uvm_field_enum(axi_obs_e, obs_kind, UVM_DEFAULT)
    `uvm_field_enum(axi_dir_e, dir, UVM_DEFAULT)

    // Write Address
    `uvm_field_int(awid, UVM_DEFAULT)
    `uvm_field_int(awaddr, UVM_DEFAULT)
    `uvm_field_int(awlen, UVM_DEFAULT)
    `uvm_field_int(awsize, UVM_DEFAULT)
    `uvm_field_int(awburst, UVM_DEFAULT)
    `uvm_field_int(awlock, UVM_DEFAULT)
    `uvm_field_int(awcache, UVM_DEFAULT)
    `uvm_field_int(awprot, UVM_DEFAULT)
    `uvm_field_int(awqos, UVM_DEFAULT)
    `uvm_field_int(awregion, UVM_DEFAULT)
    `uvm_field_int(awuser, UVM_DEFAULT)

    // Write Data (Queues)
    `uvm_field_queue_int(wdata, UVM_DEFAULT)
    `uvm_field_queue_int(wstrb, UVM_DEFAULT)
    `uvm_field_queue_int(wlast, UVM_DEFAULT)
    `uvm_field_queue_int(wuser, UVM_DEFAULT)

    // Write Response
    `uvm_field_int(bid, UVM_DEFAULT)
    `uvm_field_int(bresp, UVM_DEFAULT)
    `uvm_field_int(buser, UVM_DEFAULT)

    // Read Address
    `uvm_field_int(arid, UVM_DEFAULT)
    `uvm_field_int(araddr, UVM_DEFAULT)
    `uvm_field_int(arlen, UVM_DEFAULT)
    `uvm_field_int(arsize, UVM_DEFAULT)
    `uvm_field_int(arburst, UVM_DEFAULT)
    `uvm_field_int(arlock, UVM_DEFAULT)
    `uvm_field_int(arcache, UVM_DEFAULT)
    `uvm_field_int(arprot, UVM_DEFAULT)
    `uvm_field_int(arqos, UVM_DEFAULT)
    `uvm_field_int(arregion, UVM_DEFAULT)
    `uvm_field_int(aruser, UVM_DEFAULT)

    // Read Data (Queues)
    `uvm_field_int(rid, UVM_DEFAULT)
    `uvm_field_queue_int(rdata, UVM_DEFAULT)
    `uvm_field_queue_int(rresp, UVM_DEFAULT)
    `uvm_field_queue_int(rlast, UVM_DEFAULT)
    `uvm_field_queue_int(ruser, UVM_DEFAULT)
  `uvm_object_utils_end

  extern function new(string name = "");

  // Clone and return the result already cast to axi_mon_item.
  extern virtual function axi_mon_item item_clone();

endclass : axi_mon_item

function axi_mon_item::new(string name = "");
  super.new(name);
endfunction : new

function axi_mon_item axi_mon_item::item_clone();
  $cast(item_clone, clone());
endfunction : item_clone
