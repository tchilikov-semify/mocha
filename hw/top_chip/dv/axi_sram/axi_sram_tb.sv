// Slim axi_sram wrapper to expose interface signals to cocotb
module axi_sram_tb;

  localparam int unsigned SramMemSize    = 128 * 1024; // 128 KiB
  localparam int unsigned AxiAddrOffset  = $clog2(top_pkg::AxiDataWidth / 8);
  localparam int unsigned SramAddrWidth  = $clog2(SramMemSize) - AxiAddrOffset;

  bit clk_i  = '0;
  bit rst_ni = '0;

  bit test = '0;

  always @(posedge clk_i, negedge rst_ni) begin
	  if(~rst_ni) begin
	  end
  end

  top_pkg::axi_req_t  axi_req;
  top_pkg::axi_resp_t axi_resp;

  axi_sram #(
    .AddrWidth  ( SramAddrWidth )
  ) u_axi_sram (
    .clk_i      (clk_i   ),
    .rst_ni     (rst_ni  ),

    // Capability AXI interface
    .axi_req_i  (axi_req ),
    .axi_resp_o (axi_resp)
  );

endmodule

