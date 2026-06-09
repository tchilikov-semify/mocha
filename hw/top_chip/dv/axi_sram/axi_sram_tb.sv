// AXI SRAM testbench wrapper — exposes flat AXI signals for cocotbext-axi
// Signal naming follows cocotbext-axi convention: {prefix}_{channel}{signal}
module axi_sram_tb;

  localparam int unsigned SramMemSize   = 128 * 1024;
  localparam int unsigned AxiAddrOffset = $clog2(top_pkg::AxiDataWidth / 8);
  localparam int unsigned SramAddrWidth = $clog2(SramMemSize) - AxiAddrOffset;

  bit clk_i  = '0;
  bit rst_ni = '0;

  // 100 MHz clock
  always #5ns clk_i = ~clk_i;

  // Reset: assert for 10 cycles then release
  initial begin
    rst_ni = '0;
    repeat (10) @(posedge clk_i);
    @(negedge clk_i);
    rst_ni = '1;
  end

  // AW channel
  logic [top_pkg::AxiIdWidth-1:0]   axi_awid;
  logic [top_pkg::AxiAddrWidth-1:0] axi_awaddr;
  logic [7:0]                        axi_awlen;
  logic [2:0]                        axi_awsize;
  logic [1:0]                        axi_awburst;
  logic                              axi_awlock;
  logic [3:0]                        axi_awcache;
  logic [2:0]                        axi_awprot;
  logic [3:0]                        axi_awqos;
  logic [3:0]                        axi_awregion;
  logic [top_pkg::AxiUserWidth-1:0]  axi_awuser;
  logic                              axi_awvalid;
  logic                              axi_awready;

  // W channel
  logic [top_pkg::AxiDataWidth-1:0] axi_wdata;
  logic [top_pkg::AxiStrbWidth-1:0] axi_wstrb;
  logic                              axi_wlast;
  logic [top_pkg::AxiUserWidth-1:0]  axi_wuser;
  logic                              axi_wvalid;
  logic                              axi_wready;

  // B channel
  logic [top_pkg::AxiIdWidth-1:0]   axi_bid;
  logic [1:0]                        axi_bresp;
  logic [top_pkg::AxiUserWidth-1:0]  axi_buser;
  logic                              axi_bvalid;
  logic                              axi_bready;

  // AR channel
  logic [top_pkg::AxiIdWidth-1:0]   axi_arid;
  logic [top_pkg::AxiAddrWidth-1:0] axi_araddr;
  logic [7:0]                        axi_arlen;
  logic [2:0]                        axi_arsize;
  logic [1:0]                        axi_arburst;
  logic                              axi_arlock;
  logic [3:0]                        axi_arcache;
  logic [2:0]                        axi_arprot;
  logic [3:0]                        axi_arqos;
  logic [3:0]                        axi_arregion;
  logic [top_pkg::AxiUserWidth-1:0]  axi_aruser;
  logic                              axi_arvalid;
  logic                              axi_arready;

  // R channel
  logic [top_pkg::AxiIdWidth-1:0]   axi_rid;
  logic [top_pkg::AxiDataWidth-1:0] axi_rdata;
  logic [1:0]                        axi_rresp;
  logic                              axi_rlast;
  logic [top_pkg::AxiUserWidth-1:0]  axi_ruser;
  logic                              axi_rvalid;
  logic                              axi_rready;

  // Pack flat signals into req/resp structs for the DUT
  top_pkg::axi_req_t  axi_req;
  top_pkg::axi_resp_t axi_resp;

  always_comb begin
    axi_req.aw.id     = axi_awid;
    axi_req.aw.addr   = axi_awaddr;
    axi_req.aw.len    = axi_awlen;
    axi_req.aw.size   = axi_awsize;
    axi_req.aw.burst  = axi_awburst;
    axi_req.aw.lock   = axi_awlock;
    axi_req.aw.cache  = axi_awcache;
    axi_req.aw.prot   = axi_awprot;
    axi_req.aw.qos    = axi_awqos;
    axi_req.aw.region = axi_awregion;
    axi_req.aw.user   = axi_awuser;
    axi_req.aw_valid  = axi_awvalid;

    axi_req.w.data    = axi_wdata;
    axi_req.w.strb    = axi_wstrb;
    axi_req.w.last    = axi_wlast;
    axi_req.w.user    = axi_wuser;
    axi_req.w_valid   = axi_wvalid;

    axi_req.b_ready   = axi_bready;

    axi_req.ar.id     = axi_arid;
    axi_req.ar.addr   = axi_araddr;
    axi_req.ar.len    = axi_arlen;
    axi_req.ar.size   = axi_arsize;
    axi_req.ar.burst  = axi_arburst;
    axi_req.ar.lock   = axi_arlock;
    axi_req.ar.cache  = axi_arcache;
    axi_req.ar.prot   = axi_arprot;
    axi_req.ar.qos    = axi_arqos;
    axi_req.ar.region = axi_arregion;
    axi_req.ar.user   = axi_aruser;
    axi_req.ar_valid  = axi_arvalid;

    axi_req.r_ready   = axi_rready;

    axi_awready = axi_resp.aw_ready;
    axi_wready  = axi_resp.w_ready;
    axi_bid     = axi_resp.b.id;
    axi_bresp   = axi_resp.b.resp;
    axi_buser   = axi_resp.b.user;
    axi_bvalid  = axi_resp.b_valid;
    axi_arready = axi_resp.ar_ready;
    axi_rid     = axi_resp.r.id;
    axi_rdata   = axi_resp.r.data;
    axi_rresp   = axi_resp.r.resp;
    axi_rlast   = axi_resp.r.last;
    axi_ruser   = axi_resp.r.user;
    axi_rvalid  = axi_resp.r_valid;
  end

  initial begin
    if ($test$plusargs("trace")) begin
      $dumpfile("dump.fst");
      $dumpvars();
    end
  end

  axi_sram #(
    .AddrWidth  ( SramAddrWidth )
  ) u_axi_sram (
    .clk_i      (clk_i   ),
    .rst_ni     (rst_ni  ),
    .axi_req_i  (axi_req ),
    .axi_resp_o (axi_resp)
  );

endmodule
