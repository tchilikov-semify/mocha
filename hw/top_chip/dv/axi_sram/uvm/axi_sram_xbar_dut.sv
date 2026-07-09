// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// DUT wrapper that places axi_sram behind the real mocha AXI crossbar, so the
// testbench drives the SRAM through the same interconnect (and the same address
// map) that the CVA6 sees in top_chip_system. The single host (slave) port is
// the spot where CVA6 connects; axi_sram hangs off the SRAM device port; the
// other five device ports get axi_err_slv so a mis-decode returns a clean DECERR
// rather than hanging. The xbar_cfg + addr_map mirror top_chip_system exactly.

module axi_sram_xbar_dut (
  input  logic               clk_i,
  input  logic               rst_ni,
  // CVA6 host port (the bus the VIP master drives).
  input  top_pkg::axi_req_t  axi_req_i,
  output top_pkg::axi_resp_t axi_resp_o
);

  // axi_sram address width (mirrors top_chip_system's SramAddrWidth).
  localparam int unsigned SramAddrWidth =
      $clog2(top_pkg::SRAMLength) - $clog2(top_pkg::AxiDataWidth / 8);

  // Crossbar config — verbatim from top_chip_system.
  localparam axi_pkg::xbar_cfg_t XbarCfg = '{
    NoSlvPorts:         int'(top_pkg::AxiXbarHosts),
    NoMstPorts:         int'(top_pkg::AxiXbarDevices),
    MaxMstTrans:        32'd10,
    MaxSlvTrans:        32'd6,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_AX,
    PipelineStages:     32'd1,
    AxiIdWidthSlvPorts: 32'd4,
    AxiIdUsedSlvPorts:  32'd1,
    UniqueIds:          1'b0,
    AxiAddrWidth:       int'(top_pkg::AxiAddrWidth),
    AxiDataWidth:       int'(top_pkg::AxiDataWidth / 8), // In bytes
    NoAddrRules:        int'(top_pkg::AxiXbarDevices)
  };

  // Address map — verbatim from top_chip_system.
  axi_pkg::xbar_rule_64_t [XbarCfg.NoAddrRules-1:0] addr_map;
  assign addr_map = '{
    '{ idx: top_pkg::RomCtrlMem, start_addr: top_pkg::RomCtrlMemBase, end_addr: top_pkg::RomCtrlMemBase + top_pkg::RomCtrlMemLength },
    '{ idx: top_pkg::SRAM,       start_addr: top_pkg::SRAMBase,       end_addr: top_pkg::SRAMBase       + top_pkg::SRAMLength       },
    '{ idx: top_pkg::Mailbox,    start_addr: top_pkg::MailboxBase,    end_addr: top_pkg::MailboxBase    + top_pkg::MailboxLength    },
    '{ idx: top_pkg::RestOfChip, start_addr: top_pkg::RestOfChipBase, end_addr: top_pkg::RestOfChipBase + top_pkg::RestOfChipLength },
    '{ idx: top_pkg::TlCrossbar, start_addr: top_pkg::TlCrossbarBase, end_addr: top_pkg::TlCrossbarBase + top_pkg::TlCrossbarLength },
    '{ idx: top_pkg::DRAM,       start_addr: top_pkg::DRAMBase,       end_addr: top_pkg::DRAMBase       + top_pkg::DRAMUsableLength }
  };

  top_pkg::axi_req_t  [XbarCfg.NoSlvPorts-1:0] host_req;
  top_pkg::axi_resp_t [XbarCfg.NoSlvPorts-1:0] host_resp;
  top_pkg::axi_req_t  [XbarCfg.NoMstPorts-1:0] dev_req;
  top_pkg::axi_resp_t [XbarCfg.NoMstPorts-1:0] dev_resp;

  // Single host = CVA6.
  assign host_req[top_pkg::CVA6] = axi_req_i;
  assign axi_resp_o              = host_resp[top_pkg::CVA6];

  axi_xbar #(
    .Cfg          (XbarCfg                ),
    .ATOPs        (1'b0                   ),
    .slv_aw_chan_t(top_pkg::axi_aw_chan_t ),
    .mst_aw_chan_t(top_pkg::axi_aw_chan_t ),
    .w_chan_t     (top_pkg::axi_w_chan_t  ),
    .slv_b_chan_t (top_pkg::axi_b_chan_t  ),
    .mst_b_chan_t (top_pkg::axi_b_chan_t  ),
    .slv_ar_chan_t(top_pkg::axi_ar_chan_t ),
    .mst_ar_chan_t(top_pkg::axi_ar_chan_t ),
    .slv_r_chan_t (top_pkg::axi_r_chan_t  ),
    .mst_r_chan_t (top_pkg::axi_r_chan_t  ),
    .slv_req_t    (top_pkg::axi_req_t     ),
    .slv_resp_t   (top_pkg::axi_resp_t    ),
    .mst_req_t    (top_pkg::axi_req_t     ),
    .mst_resp_t   (top_pkg::axi_resp_t    ),
    .rule_t       (axi_pkg::xbar_rule_64_t)
  ) u_xbar (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .test_i               (1'b0),
    .slv_ports_req_i      (host_req),
    .slv_ports_resp_o     (host_resp),
    .mst_ports_req_o      (dev_req),
    .mst_ports_resp_i     (dev_resp),
    .addr_map_i           (addr_map),
    .en_default_mst_port_i('0),
    .default_mst_port_i   ('0)
  );

  // SRAM on its device port.
  axi_sram #(
    .AddrWidth (SramAddrWidth)
  ) u_sram (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .axi_req_i  (dev_req [top_pkg::SRAM]),
    .axi_resp_o (dev_resp[top_pkg::SRAM])
  );

  // Error subordinate on every other device port: a mapped-but-unmodelled region
  // (DRAM, Mailbox, ...) or any mis-route returns DECERR instead of hanging.
  for (genvar d = 0; d < int'(top_pkg::AxiXbarDevices); d++) begin : gen_dev
    if (d != int'(top_pkg::SRAM)) begin : gen_err_slv
      axi_err_slv #(
        .AxiIdWidth (top_pkg::AxiIdWidth),
        .axi_req_t  (top_pkg::axi_req_t),
        .axi_resp_t (top_pkg::axi_resp_t),
        .Resp       (axi_pkg::RESP_DECERR),
        .ATOPs      (1'b0),
        .MaxTrans   (1)
      ) u_err_slv (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .test_i     (1'b0),
        .slv_req_i  (dev_req [d]),
        .slv_resp_o (dev_resp[d])
      );
    end
  end

endmodule
