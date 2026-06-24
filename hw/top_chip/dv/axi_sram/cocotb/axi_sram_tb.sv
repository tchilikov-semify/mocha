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

  // ===========================================================================
  // TB assertions  (moved here from cocotb — vplan rows with Metric_Type=assert)
  // ===========================================================================
  // The static/elaboration and SVA-style checks belong in the SystemVerilog TB
  // rather than the cocotb stimulus layer:
  //   * interface_geometry (qohtih)               — ports / signal presence
  //   * sram_geometry      (jeluga,01skcc,u0s8nt) — widths and memory size
  //   * bounded_response   (34ld5i)               — response-latency watchdog
  //   * assert_wuser_not_full_cap (bj8we7)        — W-channel CHERI tag gating
  //   * assert_wuser_mismatch     (9a3xf6)        — W-channel CHERI tag consistency
  //   * tag_separate_memory       (lzoy40)        — structural note (see below)

  // ---------------------------------------------------------------------------
  // Static geometry checks (interface_geometry / sram_geometry)
  //
  // The four ports (clk_i, rst_ni, axi_req_i, axi_resp_o) are structurally
  // guaranteed by the u_axi_sram instantiation above; here we additionally
  // assert the AXI/SRAM geometry the spec mandates.
  // ---------------------------------------------------------------------------
  initial begin : g_geometry_check
    assert (top_pkg::AxiDataWidth == 64)
      else $fatal(1, "[axi_sram_tb] AxiDataWidth must be 64, got %0d", top_pkg::AxiDataWidth);
    assert ($bits(axi_wstrb) == top_pkg::AxiDataWidth/8)
      else $fatal(1, "[axi_sram_tb] wstrb must be %0d bits, got %0d",
                  top_pkg::AxiDataWidth/8, $bits(axi_wstrb));
    assert ($bits(axi_wuser) >= 1)
      else $fatal(1, "[axi_sram_tb] wuser must carry at least one CHERI tag bit");
    assert ($bits(axi_ruser) >= 1)
      else $fatal(1, "[axi_sram_tb] ruser must carry at least one CHERI tag bit");
    assert (SramMemSize == 128*1024)
      else $fatal(1, "[axi_sram_tb] SramMemSize must be 128 KiB, got %0d", SramMemSize);
  end

  // ---------------------------------------------------------------------------
  // Bounded response time (bounded_response / 34ld5i)
  //
  // Each accepted request must produce its response within a bounded window.
  // The bound is intentionally generous — a "no indefinite stall" watchdog; the
  // spec allows latency proportional to burst length.
  //
  // Two forms are provided.  The ACTIVE form is an immediate-assertion
  // cycle-counter watchdog that works in the cocotb/Verilator flow (the
  // '##[m:n]' bounded cycle-delay range is unsupported there).  The COMMENTED
  // form is the equivalent concurrent SVA, kept for the UVM/Xcelium move —
  // uncomment it there.
  // ---------------------------------------------------------------------------
  localparam int unsigned MaxRespLatency = 256;

  // Cycles since the DUT last made forward progress on each response channel
  // while a request is outstanding.  Progress is measured on *valid* (the DUT
  // presenting a response), so master back-pressure on b/rready is not blamed
  // on the DUT.  Trips only on a genuine stall.
  int unsigned w_outstanding, w_stall_cnt;
  int unsigned r_outstanding, r_stall_cnt;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      w_outstanding <= 0; w_stall_cnt <= 0;
      r_outstanding <= 0; r_stall_cnt <= 0;
    end else begin
      // Writes: a B response must appear within the bound after AW is accepted.
      w_outstanding <= w_outstanding
                     + ((axi_awvalid && axi_awready) ? 1 : 0)
                     - ((axi_bvalid  && axi_bready ) ? 1 : 0);
      if      (axi_bvalid)         w_stall_cnt <= 0;
      else if (w_outstanding != 0) w_stall_cnt <= w_stall_cnt + 1;
      else                         w_stall_cnt <= 0;
      assert (w_stall_cnt <= MaxRespLatency)
        else $error("[axi_sram_tb] write response exceeded %0d cycles (34ld5i)", MaxRespLatency);

      // Reads: an R beat must appear within the bound (a burst advances per beat).
      r_outstanding <= r_outstanding
                     + ((axi_arvalid && axi_arready) ? 1 : 0)
                     - ((axi_rvalid  && axi_rready && axi_rlast) ? 1 : 0);
      if      (axi_rvalid)         r_stall_cnt <= 0;
      else if (r_outstanding != 0) r_stall_cnt <= r_stall_cnt + 1;
      else                         r_stall_cnt <= 0;
      assert (r_stall_cnt <= MaxRespLatency)
        else $error("[axi_sram_tb] read response exceeded %0d cycles (34ld5i)", MaxRespLatency);
    end
  end

  // Concurrent-assertion equivalent — uncomment on the UVM/SVA-capable simulator
  // (the '##[m:n]' bounded cycle-delay range is unsupported by Verilator 5.040).
  // Shares the MaxRespLatency localparam declared above.
  //
  // property p_write_resp_bounded;
  //   @(posedge clk_i) disable iff (!rst_ni)
  //   (axi_awvalid && axi_awready) |-> ##[1:MaxRespLatency] (axi_bvalid && axi_bready);
  // endproperty
  // a_write_resp_bounded : assert property (p_write_resp_bounded)
  //   else $error("[axi_sram_tb] write response exceeded bounded latency (34ld5i)");
  //
  // property p_read_resp_bounded;
  //   @(posedge clk_i) disable iff (!rst_ni)
  //   (axi_arvalid && axi_arready) |-> ##[1:MaxRespLatency] (axi_rvalid && axi_rready && axi_rlast);
  // endproperty
  // a_read_resp_bounded : assert property (p_read_resp_bounded)
  //   else $error("[axi_sram_tb] read response exceeded bounded latency (34ld5i)");

  // ---------------------------------------------------------------------------
  // CHERI tag write assertions (assert_wuser_not_full_cap / bj8we7,
  //                             assert_wuser_mismatch     / 9a3xf6)
  //
  // A "full capability write" is a single 2-beat (awlen==1), 8-byte (awsize==3),
  // 16-byte-aligned (awaddr[3:0]==0) burst with full write strobes on its beats.
  // The W channel carries no address, so we snoop AW attributes into a small
  // FIFO (AXI4 keeps write data in AW order) and check each W beat against the
  // governing request.
  // ---------------------------------------------------------------------------
  localparam int unsigned AwFifoDepth = 16;

  logic [7:0]  aw_len_q  [AwFifoDepth];
  logic [2:0]  aw_size_q [AwFifoDepth];
  logic [3:0]  aw_alo_q  [AwFifoDepth];   // awaddr[3:0]
  int unsigned aw_head, aw_tail, aw_count;
  logic        w_first;                    // next W beat is the first of its burst
  logic        w_first_user;               // wuser captured on the first beat

  // Attributes of the AW governing the W beat currently on the bus
  logic [7:0] g_len;
  logic [2:0] g_size;
  logic [3:0] g_alo;
  logic       g_valid;
  always_comb begin
    if (aw_count != 0) begin
      g_valid = 1'b1;
      g_len   = aw_len_q[aw_head];
      g_size  = aw_size_q[aw_head];
      g_alo   = aw_alo_q[aw_head];
    end else if (axi_awvalid && axi_awready) begin
      // AW accepted on the same cycle as its first W beat
      g_valid = 1'b1;
      g_len   = axi_awlen;
      g_size  = axi_awsize;
      g_alo   = axi_awaddr[3:0];
    end else begin
      g_valid = 1'b0;
      g_len   = '0;
      g_size  = '0;
      g_alo   = '0;
    end
  end

  wire is_cap_shaped = g_valid && (g_len == 8'd1) && (g_size == 3'd3) && (g_alo == 4'd0);
  wire full_strobe   = &axi_wstrb;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_head      <= 0;
      aw_tail      <= 0;
      aw_count     <= 0;
      w_first      <= 1'b1;
      w_first_user <= 1'b0;
    end else begin
      // ---- immediate assertions for the W beat on the bus this cycle ----
      if (axi_wvalid && axi_wready) begin
        // bj8we7: a tag bit may only be set as part of a full capability write.
        if (axi_wuser[0]) begin
          assert (is_cap_shaped && full_strobe)
            else $warning("[axi_sram_tb] wuser=1 on a write that is not a full capability write (bj8we7)");
        end
        // 9a3xf6: both halves of a capability write must agree on wuser.
        // Like bj8we7 this is a spec assertion that a directed test
        // (test_wuser_mismatch_halves) deliberately triggers, so its action is a
        // non-fatal $warning rather than $error (which Verilator escalates to
        // $stop).
        if (is_cap_shaped && !w_first) begin
          assert (axi_wuser[0] == w_first_user)
            else $warning("[axi_sram_tb] wuser mismatch between capability halves (9a3xf6)");
        end
      end

      // ---- AW snoop FIFO push ----
      if (axi_awvalid && axi_awready) begin
        aw_len_q[aw_tail]  <= axi_awlen;
        aw_size_q[aw_tail] <= axi_awsize;
        aw_alo_q[aw_tail]  <= axi_awaddr[3:0];
        aw_tail            <= (aw_tail + 1) % AwFifoDepth;
      end

      // ---- W beat tracking / FIFO pop on last beat ----
      if (axi_wvalid && axi_wready) begin
        if (w_first) w_first_user <= axi_wuser[0];
        w_first <= axi_wlast;
        if (axi_wlast) aw_head <= (aw_head + 1) % AwFifoDepth;
      end

      // ---- outstanding-AW counter ----
      aw_count <= aw_count
                + ((axi_awvalid && axi_awready) ? 1 : 0)
                - ((axi_wvalid && axi_wready && axi_wlast) ? 1 : 0);
    end
  end

  // ---------------------------------------------------------------------------
  // resp_id_match (4t4cew): every B/R response must carry the AXI ID of its
  // originating request.
  //
  // Currently enforced *implicitly* by the cocotb VIP: cocotbext-axi routes each
  // response back to its request by bid/rid, so a wrong response ID would break
  // routing and fail/hang the test.  It is therefore not asserted directly here.
  //
  // TODO: add an explicit SV ID-match assertion before switching to a different
  // VIP that may not enforce ID routing.  axi_sram is single-port / in-order, so
  // it can snoop awid/arid into a small FIFO (like the AW-snoop block above) and
  // assert axi_bid / axi_rid equal the ID at the head of the outstanding queue.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // burst_last (o02amt): rlast must be asserted on exactly the last beat of each
  // read response (wlast is driven by the master, not the DUT).
  //
  // Currently enforced *implicitly* by the cocotb VIP: cocotbext-axi reassembles
  // each read burst by beat count and validates rlast placement, raising on a
  // mis-placed last beat.  It is therefore not asserted directly here.
  //
  // TODO: add an explicit SV rlast assertion before switching to a different VIP
  // that may not enforce it.  Snoop arlen into a small FIFO (like the AW-snoop
  // block above) and assert rlast == (beat == arlen) per read response.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // tag_separate_memory (lzoy40): tags are stored in a dedicated RAM, separate
  // from the data RAM.  This is a structural property of axi_sram.sv (the
  // distinct u_tag_ram and u_ram prim_ram_1p instances) enforced at elaboration;
  // it is not observable from the AXI boundary, so it is recorded here as a note
  // rather than a run-time assertion.
  // ---------------------------------------------------------------------------

endmodule
