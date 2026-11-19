// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Every access on a port: the register it maps to, or none, the direction and the response
covergroup mailbox_access_cg (string name) with function sample(int reg_idx, bit is_write,
                                                                 logic [1:0] resp);
  option.per_instance = 1;
  option.name         = name;

  cp_reg: coverpoint reg_idx {
    bins regs[] = {[0:NumRegs-1]};
    bins no_reg = {-1};
  }
  cp_dir: coverpoint is_write {
    bins read  = {1'b0};
    bins write = {1'b1};
  }
  cp_resp: coverpoint resp {
    bins okay   = {RespOkay};
    bins slverr = {RespSlverr};
  }
  cr_access: cross cp_reg, cp_dir, cp_resp;
endgroup : mailbox_access_cg

// Each MBOXW and MBOXR access on a FIFO and its response
covergroup mailbox_fifo_cg (string name) with function sample(bit is_push, logic [1:0] resp);
  option.per_instance = 1;
  option.name         = name;

  cp_kind: coverpoint is_push {
    bins pop  = {1'b0};
    bins push = {1'b1};
  }
  cp_resp: coverpoint resp {
    bins okay   = {RespOkay};
    bins slverr = {RespSlverr};
  }
  cr_kind_resp: cross cp_kind, cp_resp;
endgroup : mailbox_fifo_cg

// Each STATUS flag a port reads, at 0 and 1
covergroup mailbox_status_cg (string name) with function sample(logic [3:0] flags);
  option.per_instance = 1;
  option.name         = name;

  cp_empty:  coverpoint flags[0];
  cp_full:   coverpoint flags[1];
  cp_wfifol: coverpoint flags[2];
  cp_rfifol: coverpoint flags[3];
endgroup : mailbox_status_cg

// Each value written to WIRQT or RIRQT: below the depth, clamped, or with reserved bits set
covergroup mailbox_threshold_cg (string name) with function sample(uvm_reg_data_t value);
  option.per_instance = 1;
  option.name         = name;

  cp_value: coverpoint value {
    bins below[] = {[0:MailboxDepth-1]};
    bins clamped = {[MailboxDepth:3]};
    bins reserved_bits = {[4:$]};
  }
endgroup : mailbox_threshold_cg

class mailbox_env_cov extends uvm_component;
  `uvm_component_utils(mailbox_env_cov)

  mailbox_env_cfg cfg;

  mailbox_access_cg    access_cg[NumPorts];
  mailbox_fifo_cg      fifo_cg[NumPorts];
  mailbox_status_cg    status_cg[NumPorts];
  mailbox_threshold_cg wirqt_cg[NumPorts];
  mailbox_threshold_cg rirqt_cg[NumPorts];

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  // Class specific methods
  // Sample the covergroups for an access the scoreboard has checked
  extern function void sample(mailbox_access acc);
endclass : mailbox_env_cov


function mailbox_env_cov::new(string name, uvm_component parent);
  super.new(name, parent);
  foreach (access_cg[i]) begin
    access_cg[i] = new({"access_cg_", PortName[i]});
    // FIFO f holds MBOXW words from port f
    fifo_cg[i]   = new({"fifo_cg_", PortName[i]});
    status_cg[i] = new({"status_cg_", PortName[i]});
    wirqt_cg[i]  = new({"wirqt_cg_", PortName[i]});
    rirqt_cg[i]  = new({"rirqt_cg_", PortName[i]});
  end
endfunction : new

function void mailbox_env_cov::sample(mailbox_access acc);
  uvm_reg_map map     = cfg.ral[acc.port].default_map;
  int         reg_idx = (acc.rg == null) ? -1 : int'(acc.rg.get_offset(map) / map.get_n_bytes());

  access_cg[acc.port].sample(reg_idx, acc.is_write, acc.resp);
  unique case (acc.kind)
    AccessMboxw: begin
      fifo_cg[acc.port].sample(1'b1, acc.resp);
    end
    AccessMboxr: begin
      fifo_cg[1 - acc.port].sample(1'b0, acc.resp);
    end
    AccessStatus: begin
      if (acc.ok) begin
        status_cg[acc.port].sample(acc.data[3:0]);
      end
    end
    AccessWirqt: begin
      if (acc.ok) begin
        wirqt_cg[acc.port].sample(acc.data);
      end
    end
    AccessRirqt: begin
      if (acc.ok) begin
        rirqt_cg[acc.port].sample(acc.data);
      end
    end
    default: begin
    end
  endcase
endfunction : sample
