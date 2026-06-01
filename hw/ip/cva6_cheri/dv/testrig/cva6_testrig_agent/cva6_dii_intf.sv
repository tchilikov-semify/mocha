interface cva6_dii_intf (
  input clk,
  input rst_n,
  input [31:0] instructions_committed //todo: eventually make this parameterized on CVA6Cfg.DIIIDLEN
);

  // Instruction denoting end of test
  localparam [31:0] END_OF_TEST_INSTR = 32'h13;

  logic [31:0] instr_buffer [$];        // buffer holding all test instructions. index into it using DII ID.
  logic        test_sequence_complete;  // signals all test instructions have been consumed and committed by the core

  assign test_sequence_complete = instructions_committed > instr_buffer.size();

  function automatic logic[31:0] num_test_insns();
    return instr_buffer.size();
  endfunction

  function automatic logic [31:0] get_instr(int dii_id);
    if (instr_buffer.size() == 0 || dii_id >= instr_buffer.size() || dii_id < 0)
      return END_OF_TEST_INSTR;
    else
      return instr_buffer[dii_id];
  endfunction

  function automatic logic is_compressed(int dii_id);
    return ((get_instr(dii_id) & 32'b11) != 32'b11);
  endfunction

endinterface : cva6_dii_intf
