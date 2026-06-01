//TODO: add a license message
module cva6_rvfi_serializer #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
  parameter type rvfi_instr_t = logic
)(
  input  clk,
  input  rst_n,
  input  rvfi_instr_t rvfi0_i,
  input  rvfi_instr_t rvfi1_i,
  output rvfi_instr_t rvfi_o
);

rvfi_instr_t rvfi_fifo[$];
rvfi_instr_t rvfi_temp;

logic fifo_empty;
logic dual_commit;
logic rvfi0_valid;
logic rvfi1_valid;

assign fifo_empty = rvfi_fifo.size() == 0;
assign dual_commit = (rvfi0_valid && rvfi1_valid) || (!fifo_empty && rvfi0_valid);
assign rvfi0_valid = rvfi0_i.valid || rvfi0_i.trap;
assign rvfi1_valid = rvfi1_i.valid || rvfi1_i.trap;


initial begin
  forever begin
    @(posedge clk, negedge rst_n);
    if(~rst_n) begin
      rvfi_fifo.delete();
    end else begin
      automatic logic was_empty = fifo_empty;

      // FIFO writes
      if(dual_commit) begin
        if(!fifo_empty) begin
          // on a empty fifo dual commmit, push only rvfi1 since rvfi0 will be consumed same cycle
          rvfi_fifo.push_back(rvfi0_i);
        end
        if(rvfi1_valid) begin
          rvfi_temp = rvfi1_i;
          if(rvfi_temp.order == rvfi0_i.order) // re-apply the sequenial order
            rvfi_temp.order = rvfi_temp.order + 1'b1;
          rvfi_fifo.push_back(rvfi_temp);
        end
      end

      // FIFO reads
      if(!was_empty) begin
        rvfi_fifo.pop_front();
      end
    end
  end
end
assign rvfi_o = fifo_empty ? rvfi0_i : rvfi_fifo[0];

endmodule