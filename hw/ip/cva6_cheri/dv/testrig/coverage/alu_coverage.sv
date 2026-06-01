module alu_coverage
  import ariane_pkg::*;
#(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
  input logic                     clk_i,
  input logic                     rst_ni,
  // Functional-unit selector from the issue stage: used to gate sampling.
  input fu_t                      fu_i,
  // Decoded ALU operation.
  input fu_op                     operation_i,
  input logic [CVA6Cfg.XLEN-1:0]  operand_a_i,
  input logic [CVA6Cfg.XLEN-1:0]  operand_b_i,
  // ALU result and branch comparison output.
  input logic [CVA6Cfg.XLEN-1:0]  result_o,
  input logic                     alu_branch_res_o
);

  logic valid;
  assign valid = (fu_i == ALU);

  // Sign bits.
  logic a_sign, b_sign;
  assign a_sign = operand_a_i[CVA6Cfg.XLEN-1];
  assign b_sign = operand_b_i[CVA6Cfg.XLEN-1];

  // Narrow shift amount — matches the slice used by alu.sv.
  logic [$clog2(CVA6Cfg.XLEN)-1:0] shift_amt;
  assign shift_amt = operand_b_i[$clog2(CVA6Cfg.XLEN)-1:0];

  // Signed addition overflow: both operands same sign, result opposite.
  logic signed_add_overflow;
  assign signed_add_overflow =
      (~a_sign & ~b_sign & result_o[CVA6Cfg.XLEN-1]) |
      ( a_sign &  b_sign & ~result_o[CVA6Cfg.XLEN-1]);

  // Signed subtraction overflow: operands differ in sign, result sign != a_sign.
  logic signed_sub_overflow;
  assign signed_sub_overflow =
      (~a_sign &  b_sign & result_o[CVA6Cfg.XLEN-1]) |
      ( a_sign & ~b_sign & ~result_o[CVA6Cfg.XLEN-1]);

  // iff guards reused across multiple covergroups.
  logic is_branch_op, is_shift_op;
  assign is_branch_op = operation_i inside {EQ, NE, LTS, GES, LTU, GEU};
  assign is_shift_op  = operation_i inside {SLL, SRL, SRA, SLLW, SRLW, SRAW};

  //--------------------------------------------------------------------------
  // Operand / result value classification
  //
  // Four structural corners meaningful for any XLEN-wide value:
  //   CORNER_ZERO     — all bits 0
  //   CORNER_ALL_ONES — all bits 1  (= -1 in two's complement)
  //   CORNER_NEG      — MSB set, not all-ones (large negative)
  //   CORNER_POS      — MSB clear, not zero   (positive nonzero)
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {
    CORNER_ZERO     = 2'd0,
    CORNER_ALL_ONES = 2'd1,
    CORNER_NEG      = 2'd2,
    CORNER_POS      = 2'd3
  } corner_e;

  function automatic corner_e classify_val(input logic [CVA6Cfg.XLEN-1:0] val);
    if      (val == '0)                return CORNER_ZERO;
    else if (val == '1)                return CORNER_ALL_ONES;
    else if (val[CVA6Cfg.XLEN-1])     return CORNER_NEG;
    else                               return CORNER_POS;
  endfunction

  corner_e a_corner, b_corner, result_corner;
  assign a_corner      = classify_val(operand_a_i);
  assign b_corner      = classify_val(operand_b_i);
  assign result_corner = classify_val(result_o);


  //==========================================================================
  // Covergroup 1 — Base-ISA ALU operations
  //
  // Every RV32/64I arithmetic, logical, shift and comparison operation must
  // reach the ALU at least once.
  //==========================================================================
  covergroup cg_alu_base_ops @(posedge clk_i iff (valid && rst_ni));
    option.per_instance = 1;
    option.name         = "cg_alu_base_ops";
    option.comment      = "Every base-ISA ALU operation exercised at least once";
    option.detect_overlap = 1;

    cp_arith_logic: coverpoint operation_i {
      bins ADD  = {ADD};
      bins SUB  = {SUB};
      bins ANDL = {ANDL};
      bins ORL  = {ORL};
      bins XORL = {XORL};
      bins SLTS = {SLTS};
      bins SLTU = {SLTU};
    }

    // Full-width shifts; 32-bit word variants live in cg_alu_word_ops.
    cp_shifts: coverpoint operation_i {
      bins SLL = {SLL};
      bins SRL = {SRL};
      bins SRA = {SRA};
    }

    // Branch comparison ops whose outcome drives the branch unit.
    cp_branch_ops: coverpoint operation_i {
      bins EQ  = {EQ};
      bins NE  = {NE};
      bins LTS = {LTS};
      bins GES = {GES};
      bins LTU = {LTU};
      bins GEU = {GEU};
    }

  endgroup


  // //==========================================================================
  // // Covergroup 2 — RV64I 32-bit word operations
  // //==========================================================================
  // covergroup cg_alu_word_ops @(posedge clk_i iff (valid && rst_ni && CVA6Cfg.IS_XLEN64));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_word_ops";
  //   option.comment      = "RV64I 32-bit word ALU operations (ADDW, SUBW, SxxW)";
  //   option.detect_overlap = 1;

  //   cp_word_arith: coverpoint operation_i {
  //     bins ADDW = {ADDW};
  //     bins SUBW = {SUBW};
  //   }

  //   cp_word_shifts: coverpoint operation_i {
  //     bins SLLW = {SLLW};
  //     bins SRLW = {SRLW};
  //     bins SRAW = {SRAW};
  //   }

  // endgroup


  // //==========================================================================
  // // Covergroup 3 — Zba / Zbb / Zbs operations  (requires RVB)
  // //==========================================================================
  // covergroup cg_alu_rvb_ops @(posedge clk_i iff (valid && rst_ni && CVA6Cfg.RVB));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_rvb_ops";
  //   option.comment      = "RVB (Zba/Zbb/Zbs) ALU operations coverage";
  //   option.detect_overlap = 1;

  //   // Zba: address-generation shifted-add (64-bit UW forms in cg_alu_rvb_word_ops).
  //   cp_zba: coverpoint operation_i {
  //     bins SH1ADD = {SH1ADD};
  //     bins SH2ADD = {SH2ADD};
  //     bins SH3ADD = {SH3ADD};
  //   }

  //   // Zbb: logic-with-negate and byte-manipulation.
  //   cp_zbb_logic: coverpoint operation_i {
  //     bins ANDN = {ANDN};
  //     bins ORN  = {ORN};
  //     bins XNOR = {XNOR};
  //     bins ORCB = {ORCB};
  //     bins REV8 = {REV8};
  //   }

  //   // Zbb: bit counting.
  //   cp_zbb_bitcount: coverpoint operation_i {
  //     bins CLZ  = {CLZ};
  //     bins CTZ  = {CTZ};
  //     bins CPOP = {CPOP};
  //   }

  //   // Zbb: sign- and zero-extend.
  //   cp_zbb_extend: coverpoint operation_i {
  //     bins SEXTB = {SEXTB};
  //     bins SEXTH = {SEXTH};
  //     bins ZEXTH = {ZEXTH};
  //   }

  //   // Zbb: rotation.
  //   cp_zbb_rotate: coverpoint operation_i {
  //     bins ROL  = {ROL};
  //     bins ROR  = {ROR};
  //     bins RORI = {RORI};
  //   }

  //   // Zbb: integer minimum / maximum.
  //   cp_zbb_minmax: coverpoint operation_i {
  //     bins MAX  = {MAX};
  //     bins MAXU = {MAXU};
  //     bins MIN  = {MIN};
  //     bins MINU = {MINU};
  //   }

  //   // Zbs: single-bit operations (register and immediate forms).
  //   cp_zbs: coverpoint operation_i {
  //     bins BCLR  = {BCLR};
  //     bins BCLRI = {BCLRI};
  //     bins BEXT  = {BEXT};
  //     bins BEXTI = {BEXTI};
  //     bins BINV  = {BINV};
  //     bins BINVI = {BINVI};
  //     bins BSET  = {BSET};
  //     bins BSETI = {BSETI};
  //   }

  // endgroup


  // //==========================================================================
  // // Covergroup 4 — RVB 64-bit word operations  (requires RVB && IS_XLEN64)
  // //==========================================================================
  // covergroup cg_alu_rvb_word_ops
  //     @(posedge clk_i iff (valid && rst_ni && CVA6Cfg.RVB && CVA6Cfg.IS_XLEN64));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_rvb_word_ops";
  //   option.comment      = "RVB 64-bit word ops: ADDUW, SHxADDUW, SLLIUW, CLxW, CPOPx, ROxW";

  //   cp_zba_uw: coverpoint operation_i {
  //     bins ADDUW    = {ADDUW};
  //     bins SH1ADDUW = {SH1ADDUW};
  //     bins SH2ADDUW = {SH2ADDUW};
  //     bins SH3ADDUW = {SH3ADDUW};
  //     bins SLLIUW   = {SLLIUW};
  //   }

  //   cp_zbb_bitcount_w: coverpoint operation_i {
  //     bins CLZW  = {CLZW};
  //     bins CTZW  = {CTZW};
  //     bins CPOPW = {CPOPW};
  //   }

  //   cp_zbb_rotate_w: coverpoint operation_i {
  //     bins ROLW  = {ROLW};
  //     bins RORW  = {RORW};
  //     bins RORIW = {RORIW};
  //   }

  // endgroup


  // //==========================================================================
  // // Covergroup 5 — RVZiCond conditional-zero operations
  // //==========================================================================
  // covergroup cg_alu_zicond_ops @(posedge clk_i iff (valid && rst_ni && CVA6Cfg.RVZiCond));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_zicond_ops";
  //   option.comment      = "RVZiCond: CZERO_EQZ and CZERO_NEZ, both condition outcomes";

  //   cp_zicond_ops: coverpoint operation_i {
  //     bins CZERO_EQZ = {CZERO_EQZ};
  //     bins CZERO_NEZ = {CZERO_NEZ};
  //   }

  //   // CZERO_EQZ result = (rs2 == 0) ? 0 : rs1 — cover both paths.
  //   cp_czero_eqz_cond: coverpoint (operand_b_i == '0) iff (operation_i == CZERO_EQZ) {
  //     bins rs2_zero    = {1'b1};  // condition true  → result forced to 0
  //     bins rs2_nonzero = {1'b0};  // condition false → result = rs1
  //   }

  //   // CZERO_NEZ result = (rs2 != 0) ? 0 : rs1 — cover both paths.
  //   cp_czero_nez_cond: coverpoint (operand_b_i == '0) iff (operation_i == CZERO_NEZ) {
  //     bins rs2_zero    = {1'b1};  // condition false → result = rs1
  //     bins rs2_nonzero = {1'b0};  // condition true  → result forced to 0
  //   }

  // endgroup


  // //==========================================================================
  // // Covergroup 6 — Operand value corner cases
  // //
  // // The four structural corners (zero, all-ones, MSB-set, MSB-clear) must be
  // // seen for both operand A and B.  Additionally all four sign-bit pairings
  // // must be seen for ADD and for SUB.
  // //==========================================================================
  // covergroup cg_alu_operand_corners @(posedge clk_i iff (valid && rst_ni));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_operand_corners";
  //   option.comment      = "Operand A and B corner values: zero, all-ones, sign extremes";

  //   cp_operand_a: coverpoint a_corner {
  //     bins zero     = {CORNER_ZERO};
  //     bins all_ones = {CORNER_ALL_ONES};
  //     bins negative = {CORNER_NEG};
  //     bins positive = {CORNER_POS};
  //   }

  //   cp_operand_b: coverpoint b_corner {
  //     bins zero     = {CORNER_ZERO};
  //     bins all_ones = {CORNER_ALL_ONES};
  //     bins negative = {CORNER_NEG};
  //     bins positive = {CORNER_POS};
  //   }

  //   // Both operands simultaneously zero.
  //   cp_both_zero: coverpoint (a_corner == CORNER_ZERO && b_corner == CORNER_ZERO) {
  //     bins both_zero = {1'b1};
  //   }

  //   // All four (a_sign, b_sign) pairings for ADD.
  //   cp_add_sign_combo: coverpoint {a_sign, b_sign} iff (operation_i == ADD) {
  //     bins pp = {2'b00};  // pos + pos
  //     bins pn = {2'b01};  // pos + neg
  //     bins np = {2'b10};  // neg + pos
  //     bins nn = {2'b11};  // neg + neg
  //   }

  //   // All four (a_sign, b_sign) pairings for SUB.
  //   cp_sub_sign_combo: coverpoint {a_sign, b_sign} iff (operation_i == SUB) {
  //     bins pp = {2'b00};  // pos - pos
  //     bins pn = {2'b01};  // pos - neg
  //     bins np = {2'b10};  // neg - pos
  //     bins nn = {2'b11};  // neg - neg
  //   }

  // endgroup


  // //==========================================================================
  // // Covergroup 7 — Result value corner cases
  // //
  // // The four structural result corners must be produced, and each main
  // // arithmetic / logical / shift operation must produce a zero result at
  // // least once.  The 8 × 4 = 32-bin cross captures this completely.
  // //==========================================================================
  // covergroup cg_alu_result_corners @(posedge clk_i iff (valid && rst_ni));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_result_corners";
  //   option.comment      = "Result corners (zero/all-ones/neg/pos) × main operations";

  //   cp_result: coverpoint result_corner {
  //     bins zero     = {CORNER_ZERO};
  //     bins all_ones = {CORNER_ALL_ONES};
  //     bins negative = {CORNER_NEG};
  //     bins positive = {CORNER_POS};
  //   }

  //   cp_arith_ops: coverpoint operation_i {
  //     bins ADD  = {ADD};
  //     bins SUB  = {SUB};
  //     bins ANDL = {ANDL};
  //     bins ORL  = {ORL};
  //     bins XORL = {XORL};
  //     bins SLL  = {SLL};
  //     bins SRL  = {SRL};
  //     bins SRA  = {SRA};
  //   }

  //   // Require every (operation, result-corner) combination — the most
  //   // informative of these is (any_op, zero) showing each op can produce 0.
  //   cx_op_result: cross cp_arith_ops, cp_result;

  // endgroup


  // //==========================================================================
  // // Covergroup 8 — Adder microarchitectural corners
  // //
  // // Zero result for ADD / SUB (and ADDW / SUBW on RV64), signed overflow
  // // and underflow.  These complement the operand-corner coverage above by
  // // testing the arithmetic edge conditions the adder must handle.
  // //==========================================================================
  // covergroup cg_alu_adder @(posedge clk_i iff (valid && rst_ni));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_adder";
  //   option.comment      = "Adder corners: zero result, signed overflow/underflow for ADD and SUB";

  //   // ADD result == 0  (occurs when operand_b == -operand_a).
  //   cp_add_result_zero: coverpoint (result_o == '0) iff (operation_i == ADD) {
  //     bins zero    = {1'b1};
  //     bins nonzero = {1'b0};
  //   }

  //   // SUB result == 0  (occurs when operand_a == operand_b).
  //   cp_sub_result_zero: coverpoint (result_o == '0) iff (operation_i == SUB) {
  //     bins zero    = {1'b1};
  //     bins nonzero = {1'b0};
  //   }

  //   // Signed overflow on ADD.
  //   cp_add_overflow: coverpoint signed_add_overflow iff (operation_i == ADD) {
  //     bins overflow    = {1'b1};
  //     bins no_overflow = {1'b0};
  //   }

  //   // Signed overflow on SUB.
  //   cp_sub_overflow: coverpoint signed_sub_overflow iff (operation_i == SUB) {
  //     bins overflow    = {1'b1};
  //     bins no_overflow = {1'b0};
  //   }

  //   // 64-bit word variants (iff guards keep these silent in 32-bit configs).
  //   cp_addw_result_zero: coverpoint (result_o == '0)
  //       iff (operation_i == ADDW && CVA6Cfg.IS_XLEN64) {
  //     bins zero    = {1'b1};
  //     bins nonzero = {1'b0};
  //   }

  //   cp_subw_result_zero: coverpoint (result_o == '0)
  //       iff (operation_i == SUBW && CVA6Cfg.IS_XLEN64) {
  //     bins zero    = {1'b1};
  //     bins nonzero = {1'b0};
  //   }

  // endgroup


  // //==========================================================================
  // // Covergroup 9 — Branch comparison outcomes
  // //
  // // Every branch comparison operation must fire with both taken (1) and
  // // not-taken (0) outcomes.  The 6 × 2 = 12 cross is the key metric.
  // //==========================================================================
  // covergroup cg_alu_branch @(posedge clk_i iff (valid && rst_ni && is_branch_op));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_branch";
  //   option.comment      = "Each branch comparison op fires with both taken and not-taken results";
  //   option.detect_overlap = 1;

  //   cp_branch_op: coverpoint operation_i {
  //     bins EQ  = {EQ};
  //     bins NE  = {NE};
  //     bins LTS = {LTS};
  //     bins GES = {GES};
  //     bins LTU = {LTU};
  //     bins GEU = {GEU};
  //   }

  //   cp_branch_outcome: coverpoint alu_branch_res_o {
  //     bins taken     = {1'b1};
  //     bins not_taken = {1'b0};
  //   }

  //   // All 12 (operation, outcome) pairs must be seen.
  //   cx_op_outcome: cross cp_branch_op, cp_branch_outcome;

  // endgroup


  // //==========================================================================
  // // Covergroup 10 — Shift microarchitectural coverage
  // //
  // // Direction (left / right), type (arithmetic / logical), shift-amount
  // // corners (0, 1, half-width, max), operand-A sign for SRA, and a cross of
  // // direction × amount-corner.
  // //==========================================================================
  // covergroup cg_alu_shift @(posedge clk_i iff (valid && rst_ni && is_shift_op));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_shift";
  //   option.comment      = "Shift direction/type and amount corners for full-width operations";
  //   option.detect_overlap = 1;

  //   cp_shift_op: coverpoint operation_i {
  //     bins SLL = {SLL};
  //     bins SRL = {SRL};
  //     bins SRA = {SRA};
  //   }

  //   // Critical shift-amount corners for full-width operations.
  //   cp_shift_amt: coverpoint shift_amt {
  //     bins zero  = {0};
  //     bins one   = {1};
  //     bins half  = {CVA6Cfg.XLEN / 2};
  //     bins max   = {CVA6Cfg.XLEN - 1};
  //     bins other = default;
  //   }

  //   // For SRA: operand_a sign determines whether 1-fill or 0-fill occurs.
  //   cp_sra_sign: coverpoint a_sign iff (operation_i == SRA) {
  //     bins positive = {1'b0};  // logical fill — shift in zeros
  //     bins negative = {1'b1};  // arithmetic fill — shift in ones
  //   }

  //   // All (shift-direction, amount-corner) combinations must be exercised.
  //   cx_shift_op_amt: cross cp_shift_op, cp_shift_amt;

  // endgroup


  // //==========================================================================
  // // Covergroup 11 — SLT / SLTU comparison coverage
  // //
  // // Each set-less-than variant must produce both 0 and 1, and equal operands
  // // must be presented (guaranteed to yield 0 — a corner the test must hit).
  // //==========================================================================
  // covergroup cg_alu_slt @(posedge clk_i iff (valid && rst_ni));
  //   option.per_instance = 1;
  //   option.name         = "cg_alu_slt";
  //   option.comment      = "SLT/SLTU: both result values and equal-operand corner";

  //   // Signed comparison: result must be seen as both 0 and 1.
  //   cp_slts_result: coverpoint result_o[0] iff (operation_i == SLTS) {
  //     bins set   = {1'b1};
  //     bins clear = {1'b0};
  //   }

  //   // Unsigned comparison: result must be seen as both 0 and 1.
  //   cp_sltu_result: coverpoint result_o[0] iff (operation_i == SLTU) {
  //     bins set   = {1'b1};
  //     bins clear = {1'b0};
  //   }

  //   // Equal operands → SLTS must produce 0.
  //   cp_slts_equal_ops: coverpoint (operand_a_i == operand_b_i) iff (operation_i == SLTS) {
  //     bins equal     = {1'b1};
  //     bins not_equal = {1'b0};
  //   }

  //   // Equal operands → SLTU must produce 0.
  //   cp_sltu_equal_ops: coverpoint (operand_a_i == operand_b_i) iff (operation_i == SLTU) {
  //     bins equal     = {1'b1};
  //     bins not_equal = {1'b0};
  //   }

  // endgroup


  //==========================================================================
  // Instantiation
  //==========================================================================

  cg_alu_base_ops        alu_base_ops_cov;
  // cg_alu_word_ops        alu_word_ops_cov;
  // cg_alu_rvb_ops         alu_rvb_ops_cov;
  // cg_alu_rvb_word_ops    alu_rvb_word_ops_cov;
  // cg_alu_zicond_ops      alu_zicond_ops_cov;
  // cg_alu_operand_corners alu_operand_corners_cov;
  // cg_alu_result_corners  alu_result_corners_cov;
  // cg_alu_adder           alu_adder_cov;
  // cg_alu_branch          alu_branch_cov;
  // cg_alu_shift           alu_shift_cov;
  // cg_alu_slt             alu_slt_cov;

  initial begin
    alu_base_ops_cov        = new();
    $display("ALU base ops coverage added");
    // alu_word_ops_cov        = new();
    // $display("ALU word ops coverage added");
    // alu_rvb_ops_cov         = new();
    // $display("ALU RVB ops coverage added");
    // alu_rvb_word_ops_cov    = new();
    // $display("ALU RVB word ops coverage added");
    // alu_zicond_ops_cov      = new();
    // $display("ALU ZiCond ops coverage added");
    // alu_operand_corners_cov = new();
    // $display("ALU operand corners coverage added");
    // alu_result_corners_cov  = new();
    // $display("ALU result corners coverage added");
    // alu_adder_cov           = new();
    // $display("ALU adder coverage added");
    // alu_branch_cov          = new();
    // $display("ALU branch coverage added");
    // alu_shift_cov           = new();
    // $display("ALU shift coverage added");
    // alu_slt_cov             = new();
    // $display("ALU SLT coverage added");
  end

endmodule