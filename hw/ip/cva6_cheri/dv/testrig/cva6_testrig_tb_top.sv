import uvm_pkg::*;
`include "rvfi_types.svh"
`include "uvm_macros.svh"
`include "dv_macros.svh"

module cva6_testrig_tb_top;
  import cva6_cheri_pkg::*;
  import cva6_testrig_test_pkg::*;

  localparam logic [31:0] BOOT_ADDR = 32'h8000_0000;

  cap_reg_t boot_cap;
  initial begin
    boot_cap      = REG_ROOT_CAP;
    boot_cap.addr = addrw_t'(BOOT_ADDR);
    boot_cap.flags.int_mode = '1;
  end

  wire clk;
  wire rst_n;
  logic [CVA6Cfg.DIIIDLEN-1:0] dii_id_commit;
  logic [CVA6Cfg.DIIIDLEN-1:0] trap_cnt;

  clk_rst_if    clk_if  (.clk(clk), .rst_n(rst_n));
  cva6_rvfi_if  rvfi_if (.clk(clk));
  cva6_dii_intf dii_if  (.clk(clk), .rst_n(rst_n), .instructions_committed(32'(dii_id_commit)));

  function automatic config_pkg::cva6_cfg_t build_cva6_config(config_pkg::cva6_user_cfg_t CVA6UserCfg);
    config_pkg::cva6_user_cfg_t cfg = CVA6UserCfg;
    cfg.RVZiCond                      = bit'(0);
    cfg.CvxifEn                       = bit'(0);
    cfg.SuperscalarEn                 = bit'(0);
    cfg.NrNonIdempotentRules          = unsigned'(1);
    cfg.NonIdempotentAddrBase         = 1024'({64'b0});
    cfg.NonIdempotentLength           = 1024'({top_pkg::SRAMBase});
    cfg.DcacheFlushOnFence            = 1'b0;
    cfg.ExecuteRegionAddrBase         = 1024'({64'h8000_0000, 64'h1_0000, 64'h0});
    cfg.ExecuteRegionLength           = 1024'({64'h40000000, 64'h10000, 64'h1000});
    cfg.CachedRegionLength            = 1024'({64'h40000000});
    return build_config_pkg::build_config(cfg);
  endfunction
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_cva6_config(cva6_config_pkg::cva6_cfg);

  // RVFI
  localparam type rvfi_instr_t    = `RVFI_INSTR_T(CVA6Cfg);
  localparam type rvfi_csr_elmt_t = `RVFI_CSR_ELMT_T(CVA6Cfg);
  localparam type rvfi_csr_t      = `RVFI_CSR_T(CVA6Cfg, rvfi_csr_elmt_t);
  localparam type rvfi_to_iti_t   = `RVFI_TO_ITI_T(CVA6Cfg);

  // RVFI PROBES
  localparam type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg);
  localparam type rvfi_probes_csr_t   = `RVFI_PROBES_CSR_T(CVA6Cfg);

  localparam type rvfi_probes_t = struct packed {
    rvfi_probes_csr_t csr;
    rvfi_probes_instr_t instr;
  };

  rvfi_probes_t rvfi_probes;
  rvfi_instr_t [CVA6Cfg.NrCommitPorts-1:0] rvfi_instr;
  rvfi_instr_t  rvfi_serial;
  rvfi_csr_t    rvfi_csr;

  top_pkg::axi_req_t  axi_req;
  top_pkg::axi_resp_t axi_resp;

  AXI_BUS #(
    .AXI_ID_WIDTH   (cva6_config_pkg::CVA6ConfigAxiIdWidth  ),
    .AXI_ADDR_WIDTH (cva6_config_pkg::CVA6ConfigAxiAddrWidth),
    .AXI_DATA_WIDTH (cva6_config_pkg::CVA6ConfigAxiDataWidth),
    .AXI_USER_WIDTH (cva6_config_pkg::CVA6ConfigDataUserWidth)
  ) axi_slave();

  cva6 #(
    .CVA6Cfg              ( CVA6Cfg                 ),
    .rvfi_probes_instr_t  ( rvfi_probes_instr_t     ),
    .rvfi_probes_csr_t    ( rvfi_probes_csr_t       ),
    .rvfi_probes_t        ( rvfi_probes_t           ),
    .axi_ar_chan_t        ( top_pkg::axi_ar_chan_t  ),
    .axi_aw_chan_t        ( top_pkg::axi_aw_chan_t  ),
    .axi_w_chan_t         ( top_pkg::axi_w_chan_t   ),
    .b_chan_t             ( top_pkg::axi_b_chan_t   ),
    .r_chan_t             ( top_pkg::axi_r_chan_t   ),
    .noc_req_t            ( top_pkg::axi_req_t      ),
    .noc_resp_t           ( top_pkg::axi_resp_t     )
  ) i_cva6 (
    .clk_i         (clk         ),
    .rst_ni        (rst_n       ),
    .boot_addr_i   (boot_cap    ),
    .hart_id_i     ('0          ),
    .irq_i         (2'b0        ),
    .ipi_i         (1'b0        ),
    .time_irq_i    (1'b0        ),
    .debug_req_i   (1'b0        ),
    .rvfi_probes_o (rvfi_probes ),
    .cvxif_resp_i  ('0          ),
    .noc_req_o     (axi_req     ),
    .noc_resp_i    (axi_resp    )
  );

  localparam int unsigned SRAM_ADDR_WIDTH = $clog2(top_pkg::SRAMLength / (top_pkg::AxiDataWidth / 8));
  axi_sram #(
    .AddrWidth          (SRAM_ADDR_WIDTH)
  ) u_axi_sram (
    .clk_i              (clk     ),
    .rst_ni             (rst_n   ),
    .axi_req_i          (axi_req ),
    .axi_resp_o         (axi_resp)
  );

  // Clear data and tag memories between tests.
  initial forever begin
    u_axi_sram.u_ram.mem          = '{default: '0};
    @(negedge rst_n);
  end

  cva6_rvfi #(
    .CVA6Cfg              (CVA6Cfg            ),
    .rvfi_instr_t         (rvfi_instr_t       ),
    .rvfi_csr_t           (rvfi_csr_t         ),
    .rvfi_probes_instr_t  (rvfi_probes_instr_t),
    .rvfi_probes_csr_t    (rvfi_probes_csr_t  ),
    .rvfi_probes_t        (rvfi_probes_t      ),
    .rvfi_to_iti_t        (rvfi_to_iti_t      )
  ) i_cva6_rvfi (
    .clk_i         (clk         ),
    .rst_ni        (rst_n       ),
    .rvfi_probes_i (rvfi_probes ),
    .rvfi_instr_o  (rvfi_instr  ),
    .rvfi_csr_o    (rvfi_csr    ),
    .rvfi_to_iti_o (            )
  );

  isa_coverage i_isa_cov (
    .clk_i        (clk          ),
    .rst_ni       (rst_n        ),
    .rvfi_valid_i (rvfi_if.valid),
    .rvfi_insn_i  (rvfi_if.insn )
  );

  cva6_rvfi_serializer #(
    .CVA6Cfg      (CVA6Cfg      ),
    .rvfi_instr_t (rvfi_instr_t )
  ) i_rvfi_serializer (
    .clk      (clk          ),
    .rst_n    (rst_n        ),
    .rvfi0_i  (rvfi_instr[0]),
    .rvfi1_i  (rvfi_instr[1]),
    .rvfi_o   (rvfi_serial  )
  );

  assign rvfi_if.reset         = ~rst_n;
  assign rvfi_if.valid         = rvfi_serial.valid || rvfi_serial.trap;
  assign rvfi_if.order         = rvfi_serial.order;
  assign rvfi_if.insn          = rvfi_serial.insn;
  assign rvfi_if.trap          = rvfi_serial.trap;
  assign rvfi_if.intr          = rvfi_serial.intr;
  assign rvfi_if.mode          = rvfi_serial.mode;
  assign rvfi_if.ixl           = rvfi_serial.ixl;
  assign rvfi_if.rs1_addr      = rvfi_serial.rs1_addr;
  assign rvfi_if.rs2_addr      = rvfi_serial.rs2_addr;
  assign rvfi_if.rs1_rdata     = rvfi_serial.rs1_rdata;
  assign rvfi_if.rs2_rdata     = rvfi_serial.rs2_rdata;
  assign rvfi_if.rd_addr       = rvfi_serial.rd_addr;
  assign rvfi_if.rd_wdata      = rvfi_serial.rd_wdata;
  assign rvfi_if.pc_rdata      = rvfi_serial.pc_rdata;
  assign rvfi_if.pc_wdata      = rvfi_serial.pc_wdata;
  assign rvfi_if.mem_addr      = rvfi_serial.mem_addr;
  assign rvfi_if.mem_paddr     = rvfi_serial.mem_paddr;
  assign rvfi_if.mem_rmask     = rvfi_serial.mem_rmask;
  assign rvfi_if.mem_wmask     = rvfi_serial.mem_wmask;
  assign rvfi_if.mem_rdata     = rvfi_serial.mem_rdata;
  assign rvfi_if.mem_wdata     = rvfi_serial.mem_wdata;
  assign rvfi_if.ext_mip       = rvfi_csr.mip;
  assign rvfi_if.ext_mcycle    = rvfi_csr.mcycle;

  assign dii_id_commit = rvfi_if.order[31:0] + trap_cnt;


  always @(posedge clk) begin
    if(~rst_n) begin
      trap_cnt = '0;
    end else begin
      if(rvfi_if.trap) begin
        trap_cnt = trap_cnt + 1'b1;
      end
    end
  end

  initial begin
    clk_if.set_active();

    fork
      clk_if.apply_reset(.reset_width_clks (100));
    join_none

    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_if", clk_if);
    uvm_config_db#(virtual cva6_dii_intf)::set(null, "*", "dii_if", dii_if);
    uvm_config_db#(virtual cva6_rvfi_if)::set(null, "*", "rvfi_if", rvfi_if);

    run_test();
  end

endmodule
