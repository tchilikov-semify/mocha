//`define ISA_COVERAGE 1
module isa_coverage
  //import ariane_pkg::*;
(
  input logic clk_i,
  input logic rst_ni,

  // RVFI interface signals
  input logic         rvfi_valid_i,      // Instruction retired
  input logic [31:0]  rvfi_insn_i       // Instruction encoding
);

  // Instruction opcode fields
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [11:0] funct12;
  logic [4:0]  rd, rs1, rs2;
  logic [1:0]  compressed_op;

  // Decode instruction fields
  assign opcode        = rvfi_insn_i[6:0];
  assign funct3        = rvfi_insn_i[14:12];
  assign funct7        = rvfi_insn_i[31:25];
  assign funct12       = rvfi_insn_i[31:20];
  assign rd            = rvfi_insn_i[11:7];
  assign rs1           = rvfi_insn_i[19:15];
  assign rs2           = rvfi_insn_i[24:20];
  assign compressed_op = rvfi_insn_i[1:0];


  // Check if instruction is compressed
  logic is_compressed;
  assign is_compressed = (compressed_op != 2'b11);

  // Check if instruction is I Type
  logic is_itype;
  always_comb begin
    is_itype = '0;

    if (opcode inside {7'b0010011, 7'b0110111, 7'b0010111, 7'b1101111,
                       7'b1100111, 7'b1100011, 7'b0000011, 7'b0100011,
                       7'b0001111, 7'b0111011, 7'b0011011}) begin
      is_itype = 1'b1;
    end
    else if (opcode == 7'b0110011 && !funct7[0]) begin
      is_itype = 1'b1;  // OP, but not M-extension
    end
    else if (opcode == 7'b1110011 && funct3 == 3'b000 &&
             (funct12 == 12'h000 || funct12 == 12'h001)) begin
      is_itype = 1'b1;  // ECALL/EBREAK only
    end

    if (is_compressed) is_itype = '0;
  end

  //==========================================================================
  // RV64I BASE INSTRUCTION COVERAGE
  //==========================================================================

  covergroup cg_itype @(posedge clk_i iff (rvfi_valid_i && is_itype && rst_ni));
    option.per_instance = 1;
    option.name = "cg_rv32/64i";
    option.comment = "Coverage of all RV32I and RV64I base integer instructions";
    option.detect_overlap = 1;

    // R-type: Arithmetic and Logic (OP = 0110011)
    cp_r_type: coverpoint {funct7, funct3} iff (opcode == 7'b0110011) {
      bins ADD     = {10'b0000000_000};
      bins SUB     = {10'b0100000_000};
      bins SLL     = {10'b0000000_001};
      bins SLT     = {10'b0000000_010};
      bins SLTU    = {10'b0000000_011};
      bins XOR     = {10'b0000000_100};
      bins SRL     = {10'b0000000_101};
      bins SRA     = {10'b0100000_101};
      bins OR      = {10'b0000000_110};
      bins AND     = {10'b0000000_111};
      bins ERR     = default;
    }

    // I-type: Immediate Arithmetic (OP-IMM = 0010011)
    cp_i_type: coverpoint funct3 iff (opcode == 7'b0010011) {
      bins ADDI    = {3'b000};
      bins SLTI    = {3'b010};
      bins SLTIU   = {3'b011};
      bins XORI    = {3'b100};
      bins ORI     = {3'b110};
      bins ANDI    = {3'b111};
      bins ERR     = default;
    }

    // Shift Immediate (OP-IMM = 0010011, special funct7 check)
    cp_shift_i: coverpoint {funct7[6:1], funct3} iff (opcode == 7'b0010011) {
      bins SLLI    = {9'b000000_001};
      bins SRLI    = {9'b000000_101};
      bins SRAI    = {9'b010000_101};
      bins ERR     = default;
    }

    // R-type 32-bit (OP-32 = 0111011) for RV64I
    cp_r_type_32: coverpoint {funct7, funct3} iff (opcode == 7'b0111011) {
      bins ADDW    = {10'b0000000_000};
      bins SUBW    = {10'b0100000_000};
      bins SLLW    = {10'b0000000_001};
      bins SRLW    = {10'b0000000_101};
      bins SRAW    = {10'b0100000_101};
      bins ERR     = default;
    }

    // I-type 32-bit (OP-IMM-32 = 0011011) for RV64I
    cp_i_type_32: coverpoint funct3 iff (opcode == 7'b0011011) {
      bins ADDIW   = {3'b000};
    }

    // Shift Immediate 32-bit
    cp_shift_i_32: coverpoint {funct7, funct3} iff (opcode == 7'b0011011) {
      bins SLLIW   = {10'b0000000_001};
      bins SRLIW   = {10'b0000000_101};
      bins SRAIW   = {10'b0100000_101};
      bins ERR     = default;
    }

    // U-type: Upper Immediate
    cp_lui: coverpoint opcode {
      bins LUI     = {7'b0110111};
    }

    cp_auipc: coverpoint opcode {
      bins AUIPC   = {7'b0010111};
    }

    // J-type: Jump
    cp_jal: coverpoint opcode {
      bins JAL     = {7'b1101111};
    }

    // JALR
    cp_jalr: coverpoint opcode {
      bins JALR    = {7'b1100111};
    }

    // B-type: Branches (BRANCH = 1100011)
    cp_branch: coverpoint funct3 iff (opcode == 7'b1100011) {
      bins BEQ     = {3'b000};
      bins BNE     = {3'b001};
      bins BLT     = {3'b100};
      bins BGE     = {3'b101};
      bins BLTU    = {3'b110};
      bins BGEU    = {3'b111};
      bins ERR     = default;
    }

    // Loads (LOAD = 0000011)
    cp_load: coverpoint funct3 iff (opcode == 7'b0000011) {
      bins LB      = {3'b000};
      bins LH      = {3'b001};
      bins LW      = {3'b010};
      bins LD      = {3'b011}; // RV64I
      bins LBU     = {3'b100};
      bins LHU     = {3'b101};
      bins LWU     = {3'b110}; // RV64I
      bins ERR     = default;
    }

    // Stores (STORE = 0100011)
    cp_store: coverpoint funct3 iff (opcode == 7'b0100011) {
      bins SB      = {3'b000};
      bins SH      = {3'b001};
      bins SW      = {3'b010};
      bins SD      = {3'b011}; // RV64I
      bins ERR     = default;
    }

    // Memory Ordering (MISC-MEM = 0001111)
    cp_misc_mem: coverpoint funct3 iff (opcode == 7'b0001111) {
      bins FENCE   = {3'b000};
      bins FENCE_I = {3'b001};
      bins ERR     = default;
    }

    // System Instructions (SYSTEM = 1110011)
    cp_system: coverpoint funct12 iff (opcode == 7'b1110011 && funct3 == 3'b000) {
      bins ECALL   = {12'h000};
      bins EBREAK  = {12'h001};
      bins ERR     = default;
    }

    // Special Instructions
    cp_special_instrs: coverpoint rvfi_insn_i {
      bins FENCE_TSO = {32'b1000_0011_0011_0000_0000_0000_0000_1111};
      bins PAUSE     = {32'b0000_0001_0000_0000_0000_0000_0000_1111};
    }

  endgroup

  covergroup cg_cheri_type @(posedge clk_i iff (rvfi_valid_i && rst_ni));
    option.per_instance = 1;
    option.name = "cg_cheri";
    option.comment = "Coverage of Cheri specific instructions";
    option.detect_overlap = 1;

    // =============================================================================
    // CHERI RVY ISA Coverage Points
    // Source: riscv-cheri v0.9.6 specification
    //
    // All encodings taken verbatim from the spec.
    //   opcode      = rvfi_insn_i[6:0]
    //   funct3      = rvfi_insn_i[14:12]
    //   funct7      = rvfi_insn_i[31:25]
    //   funct5      = rvfi_insn_i[31:27]   (used for AMO / single-source instructions)
    //   rs2         = rvfi_insn_i[24:20]
    //   rvfi_insn_i = full 32-bit instruction word (also used for 16-bit in low half)
    //
    // For 16-bit (compressed) instructions:
    //   c_op    = rvfi_insn_i[1:0]     (quadrant)
    //   c_f3    = rvfi_insn_i[15:13]
    //   c_f4    = rvfi_insn_i[15:12]
    //   c_rd    = rvfi_insn_i[11:7]
    //   c_rs2   = rvfi_insn_i[6:2]
    // =============================================================================

    // =============================================================================
    // Opcode Group 1: OP-class instructions (opcode = 7'b0110011)
    //
    // Layout: funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode
    //
    // ADDY    funct7=0000110, rs2≠x0,  funct3=000   (ADDY with rs2=x0 → YMV)
    // YMV     funct7=0000110, rs2=x0,  funct3=000   (encoded as ADDY rs2=x0)
    // YADDRW  funct7=0000110,          funct3=001
    // YPERMC  funct7=0000110,          funct3=010
    // YBNDSW  funct7=0000111,          funct3=000
    // YBNDSRW funct7=0000111,          funct3=001
    // YSUNSEAL funct7=0000111,         funct3=010
    // YBLD    funct7=0000110,          funct3=101
    // PACKY   funct7=0000100,          funct3=011   (YHIW is a pseudoinstruction for PACKY)
    // SYEQ    funct7=0000110,          funct3=100
    // YLT     funct7=0000110,          funct3=110
    // YMODEW  funct7=0000110,          funct3=111   (Zyhybrid)
    // SHxADDY funct7=0100000,          funct3=011/101/000/111
    // YTAGR   funct7=0001000, rs2=00000, funct3=000
    // YPERMR  funct7=0001000, rs2=00001, funct3=000
    // YTYPER  funct7=0001000, rs2=00010, funct3=000
    // YMODER  funct7=0001000, rs2=00011, funct3=000  (Zyhybrid)
    // YBASER  funct7=0001000, rs2=00101, funct3=000
    // YLENR   funct7=0001000, rs2=00110, funct3=000
    // YAMASK  funct7=0001000, rs2=00111, funct3=000
    // YSENTRY funct7=0001000, rs2=01000, funct3=000  (Zys)
    // YMODESWY funct7=0001001, rs2=00000,rs1=00000, funct3=001  (Zyhybrid)
    // YMODESWI funct7=0001010, rs2=00000,rs1=00000, funct3=001  (Zyhybrid)
    // =============================================================================

    // --- Two-source R-type capability instructions (distinguished by {funct7,funct3}) ---
    cp_op_cheri_2src: coverpoint {funct7, funct3} iff (opcode == 7'b0110011) {
        // ADDY: copy capability rs1 + increment address by rs2 (rs2≠x0)
        bins ADDY       = {10'b0000110_000};  // NOTE: only valid when rs2≠x0; rs2=x0 → YMV
        // YADDRW: copy rs1 to rd, set rd.address = rs2
        bins YADDRW     = {10'b0000110_001};
        // YPERMC: AND-clear permissions using rs2 mask
        bins YPERMC     = {10'b0000110_010};
        // YBLD: build capability (subset check rs2 ⊆ rs1, copy rs2)
        bins YBLD       = {10'b0000110_101};
        // SYEQ: set rd=1 if YLEN+tag of rs1 == rs2
        bins SYEQ       = {10'b0000110_100};
        // YLT: set rd=1 if rs2 permissions/bounds ⊆ rs1
        bins YLT        = {10'b0000110_110};
        // YMODEW: write capability execution mode (Zyhybrid)
        bins YMODEW     = {10'b0000110_111};
        // YBNDSW: set bounds exact (length = rs2)
        bins YBNDSW     = {10'b0000111_000};
        // YBNDSRW: set bounds rounded (length = rs2)
        bins YBNDSRW    = {10'b0000111_001};
        // YSUNSEAL: superset unseal (authority=rs1, sealed cap=rs2)
        bins YSUNSEAL   = {10'b0000111_010};
        // PACKY (= YHIW): pack rs1[XLEN-1:0] and rs2 into rd, tag=0
        bins PACKY      = {10'b0000100_011};
        bins ERR        = default;
    }

    // --- YMV: encoded as ADDY with rs2=x0 ---
    cp_ymv: coverpoint {funct7, rs2, funct3} iff (opcode == 7'b0110011) {
        bins YMV        = {15'b0000110_00000_000};  // funct7=0000110, rs2=x0, funct3=000
    }

    // --- Single-source R-type (rs2 field = funct5 specifier, funct7=0001000) ---
    cp_op_cheri_1src: coverpoint {funct7, rs2, funct3} iff (opcode == 7'b0110011) {
        // YTAGR  rs2=00000: read tag bit
        bins YTAGR      = {15'b0001000_00000_000};
        // YPERMR rs2=00001: read permissions
        bins YPERMR     = {15'b0001000_00001_000};
        // YTYPER rs2=00010: read capability type (CT-field)
        bins YTYPER     = {15'b0001000_00010_000};
        // YMODER rs2=00011: read capability mode M-bit (Zyhybrid)
        bins YMODER     = {15'b0001000_00011_000};
        // YBASER rs2=00101: read decoded base address
        bins YBASER     = {15'b0001000_00101_000};
        // YLENR  rs2=00110: read decoded length
        bins YLENR      = {15'b0001000_00110_000};
        // YAMASK rs2=00111: compute alignment mask from integer rs1
        bins YAMASK     = {15'b0001000_00111_000};
        // YSENTRY rs2=01000: seal capability as sentry (Zys)
        bins YSENTRY    = {15'b0001000_01000_000};
    }

    // --- Mode switch instructions (Zyhybrid, fixed rs1=rs2=rd=x0, funct3=001) ---
    cp_ymodesw: coverpoint {funct7, funct3} iff (
        opcode == 7'b0110011 &&
        rs2    == 5'b00000  &&
        rvfi_insn_i[19:15] == 5'b00000 &&  // rs1=x0
        rvfi_insn_i[11:7]  == 5'b00000     // rd=x0
    ) {
        // YMODESWY: switch to (CHERI) Capability Mode
        bins YMODESWY   = {10'b0001001_001};
        // YMODESWI: switch to (Non-CHERI) Address Mode
        bins YMODESWI   = {10'b0001010_001};
        bins ERR        = default;
    }

    // --- SHxADDY: shift-and-add for capability address generation (Zba, funct7=0100000) ---
    cp_shaddy: coverpoint {funct7, funct3} iff (opcode == 7'b0110011) {
        // Encoding from spec table (page 143): funct7=0b0100000
        bins SH1ADDY    = {10'b0100000_011};  // shift left 1
        bins SH2ADDY    = {10'b0100000_101};  // shift left 2
        bins SH3ADDY    = {10'b0100000_000};  // shift left 3
        bins SH4ADDY    = {10'b0100000_111};  // shift left 4 (RV64Y only)
    }

    // =============================================================================
    // Opcode Group 2: OP-IMM-32 instructions (opcode = 7'b0011011)
    //
    // ADDIY  : funct3=010  (I-type, 12-bit imm)
    // YBNDSWI: funct3=011  (I-type, funct2=00 | 10-bit imm | rs1=rd)
    // =============================================================================
    cp_op_imm32_cheri: coverpoint funct3 iff (opcode == 7'b0011011) {
        // ADDIY: increment capability address by sign-extended 12-bit immediate
        bins ADDIY      = {3'b010};
        // YBNDSWI: set exact bounds with encoded immediate length
        bins YBNDSWI    = {3'b011};
        bins ERR        = default;
    }

    // =============================================================================
    // Opcode Group 3: OP-32 instructions (opcode = 7'b0111011)
    //
    // SHxADDY.UW: (RV64Y) shift-and-add with zero-extended word, funct7=0100000
    // =============================================================================
    cp_shaddy_uw: coverpoint {funct7, funct3} iff (opcode == 7'b0111011) {
        bins SH1ADDY_UW = {10'b0010000_011};  // shift left 1
        bins SH2ADDY_UW = {10'b0010000_101};  // shift left 2
        bins SH3ADDY_UW = {10'b0010000_000};  // shift left 3
        bins SH4ADDY_UW = {10'b0010000_111};  // shift left 4
    }

    // =============================================================================
    // Opcode Group 4: OP-IMM instructions (opcode = 7'b0010011)
    //
    // SRLIY (and YHIR pseudoinstruction):
    //   funct3=101, shamt=XLEN
    //   RV64Y: {funct5=00000, funct7=1000000} → shamt=64 = 7'b1000000
    //   RV32Y: {funct5=00000, funct7=0100000} → shamt=32 = 6'b100000 (special)
    //
    // PREFETCH.I: funct3=110, rd=x0, rs2(=imm[24:20])=00000
    // PREFETCH.R: funct3=110, rd=x0, rs2(=imm[24:20])=00001
    // PREFETCH.W: funct3=110, rd=x0, rs2(=imm[24:20])=00011
    // =============================================================================

    // SRLIY encoding: funct3=101 with specific shamt (shift by XLEN)
    cp_srliy_rv64: coverpoint {rvfi_insn_i[31:20], funct3} iff (opcode == 7'b0010011) {
        // RV64Y: {funct5=00000, funct7=1000000} = 12'b000000_1000000 → shamt=64
        bins SRLIY_RV64 = {15'b000000_1000000_101};
        // RV32Y: {funct5=00000, funct7=0100000} = 12'b000000_0100000 → shamt=32
        bins SRLIY_RV32 = {15'b000000_0100000_101};
    }

    // PREFETCH instructions: OP-IMM, funct3=ORI=110, rd=x0, imm[4:0]=0
    cp_prefetch: coverpoint rvfi_insn_i[24:20] iff (
        opcode      == 7'b0010011 &&
        funct3      == 3'b110     &&
        rvfi_insn_i[11:7]  == 5'b00000   &&  // rd=x0
        rvfi_insn_i[19:15] != 5'b00000       // rs1≠x0 per spec
    ) {
        bins PREFETCH_I = {5'b00000};  // imm[11:5] is offset, imm[4:0]=0 per encoding
        bins PREFETCH_R = {5'b00001};
        bins PREFETCH_W = {5'b00011};
        bins ERR        = default;
    }

    // =============================================================================
    // Opcode Group 5: MISC-MEM (opcode = 7'b0001111)
    //
    // LY         : funct3=100, MISCMEM opcode
    // CBO.INVAL  : funct12=000000000000, funct3=010, funct5(rd)=00000
    // CBO.CLEAN  : funct12=000000000001, funct3=010, funct5(rd)=00000
    // CBO.FLUSH  : funct12=000000000010, funct3=010, funct5(rd)=00000
    // CBO.ZERO   : funct12=000000000100, funct3=010, funct5(rd)=00000
    // =============================================================================

    // LY: Load capability (MISC-MEM opcode, funct3=100)
    cp_ly: coverpoint funct3 iff (opcode == 7'b0001111) {
        bins LY         = {3'b100};
        bins ERR        = default;
    }

    // CBO instructions: MISC-MEM, funct3=010, rd=x0, differentiated by funct12
    cp_cbo: coverpoint rvfi_insn_i[31:20] iff (
        opcode     == 7'b0001111 &&
        funct3     == 3'b010     &&
        rvfi_insn_i[11:7] == 5'b00000     // rd=x0
    ) {
        bins CBO_INVAL  = {12'b000000000000};
        bins CBO_CLEAN  = {12'b000000000001};
        bins CBO_FLUSH  = {12'b000000000010};
        bins CBO_ZERO   = {12'b000000000100};
        bins ERR        = default;
    }

    // =============================================================================
    // Opcode Group 6: STORE (opcode = 7'b0100011)
    //
    // SY: Store capability, funct3=100
    // =============================================================================
    cp_sy: coverpoint funct3 iff (opcode == 7'b0100011) {
        bins SY         = {3'b100};
        bins ERR        = default;
    }

    // =============================================================================
    // Opcode Group 7: AMO (opcode = 7'b0101111)
    //
    // All use funct3=100 (.Y width) for RV32Y/RV64Y
    // funct5 = rvfi_insn_i[31:27]
    // LR.Y     : funct5=00010, rs2=00000, funct3=100
    // SC.Y     : funct5=00011,            funct3=100
    // AMOSWAP.Y: funct5=00001,            funct3=100
    // =============================================================================
    cp_amo_y: coverpoint {rvfi_insn_i[31:27], funct3} iff (opcode == 7'b0101111) {
        bins LR_Y       = {8'b00010_100};
        bins SC_Y       = {8'b00011_100};
        bins AMOSWAP_Y  = {8'b00001_100};
        bins ERR        = default;
    }

    // =============================================================================
    // Opcode Group 8: Instructions with same encoding as base ISA (RVY modified semantics)
    //
    // AUIPC (RVY): opcode=0010111 (U-type) — same encoding as base AUIPC
    // JAL (RVY)  : opcode=1101111 (J-type) — same encoding as base JAL
    // JALR (RVY) : opcode=1100111, funct3=000 — same encoding as base JALR
    // CSR* (RVY) : opcode=1110011, funct3=001/010/011/101/110/111
    // =============================================================================

    cp_auipc_rvy: coverpoint opcode {
        bins AUIPC_RVY  = {7'b0010111};
    }

    cp_jal_rvy: coverpoint opcode {
        bins JAL_RVY    = {7'b1101111};
    }

    cp_jalr_rvy: coverpoint funct3 iff (opcode == 7'b1100111) {
        bins JALR_RVY   = {3'b000};
        bins ERR        = default;
    }

    cp_csr_rvy: coverpoint funct3 iff (opcode == 7'b1110011) {
        bins CSRRW_RVY  = {3'b001};
        bins CSRRS_RVY  = {3'b010};
        bins CSRRC_RVY  = {3'b011};
        bins CSRRWI_RVY = {3'b101};
        bins CSRRSI_RVY = {3'b110};
        bins CSRRCI_RVY = {3'b111};
        bins ERR        = default;
    }

    // =============================================================================
    // Opcode Group 9: Hypervisor instructions (H extension + RVY)
    //
    // HLV.Y: opcode=1110011, funct3=100, funct7=0111000, rs2=00000
    // HSV.Y: opcode=1110011, funct3=100, funct7=0111001
    // =============================================================================
    cp_hlv_hsv_y: coverpoint {funct7, funct3} iff (opcode == 7'b1110011) {
        // HLV.Y=0111000, type(rs2)=00000 per spec page 206
        bins HLV_Y      = {10'b0111000_100};
        // HSV.Y=0111001 per spec page 207
        bins HSV_Y      = {10'b0111001_100};
        bins ERR        = default;
    }

    // =============================================================================
    // Opcode Group 10: 16-bit Compressed instructions (C extension, RVY)
    //
    // Signals for 16-bit instructions use the lower 16 bits of `rvfi_insn_i`.
    // c_op  = rvfi_insn_i[1:0]   (quadrant)
    // c_f3  = rvfi_insn_i[15:13] (funct3 for most formats)
    // c_f4  = rvfi_insn_i[15:12] (funct4 for CR-format)
    // c_rd  = rvfi_insn_i[11:7]
    // c_rs2 = rvfi_insn_i[6:2]
    //
    // Encoding maps (from spec tables 47-51):
    //
    // RV32Y / RV64Y (Quadrant 0, op=00):
    //   C.ADDI4SPN (RVY): c_f3=000, op=00
    //   C.LY             : RV32Y c_f3=011, op=00 / RV64Y c_f3=001, op=00
    //   C.SY             : RV32Y c_f3=111, op=00 / RV64Y c_f3=101, op=00
    //
    // RV32Y / RV64Y (Quadrant 1, op=01):
    //   C.ADDI16SP (RVY): c_f3=011, c_rd=x2(=5'd2), op=01
    //   C.JAL (RV32Y)   : c_f3=001, op=01
    //
    // RV32Y / RV64Y (Quadrant 2, op=10):
    //   C.LYSP           : RV32Y c_f3=011, op=10 / RV64Y c_f3=001, op=10
    //   C.SYSP           : RV32Y c_f3=111, op=10 / RV64Y c_f3=101, op=10
    //   C.YMV            : c_f4=1000, c_rd≠x0, c_rs2≠x0, op=10
    //   C.JR (RVY)       : c_f4=1000, c_rd≠x0, c_rs2=x0,  op=10
    //   C.JALR (RVY)     : c_f4=1001, c_rd≠x0, c_rs2=x0,  op=10
    // =============================================================================

    // --- Quadrant 0 (op=00) ---
    cp_c_addi4spn_rvy: coverpoint rvfi_insn_i[15:13] iff (rvfi_insn_i[1:0] == 2'b00) {
        bins C_ADDI4SPN_RVY = {3'b000};   // C.ADDI4SPN (RVY)
        // RV32Y: LY=011, SY=111; RV64Y: LY=001, SY=101
        // Cover all variants together in combined coverpoints below
    }

    // C.LY: quadrant 0
    cp_c_ly: coverpoint rvfi_insn_i[15:13] iff (rvfi_insn_i[1:0] == 2'b00) {
        bins C_LY_RV32Y = {3'b011};   // RV32Y encoding
        bins C_LY_RV64Y = {3'b001};   // RV64Y encoding
    }

    // C.SY: quadrant 0
    cp_c_sy: coverpoint rvfi_insn_i[15:13] iff (rvfi_insn_i[1:0] == 2'b00) {
        bins C_SY_RV32Y = {3'b111};   // RV32Y encoding
        bins C_SY_RV64Y = {3'b101};   // RV64Y encoding
    }

    // --- Quadrant 1 (op=01) ---
    // C.ADDI16SP (RVY): funct3=011, rd/rs1=x2
    cp_c_addi16sp_rvy: coverpoint rvfi_insn_i[15:13] iff (
        rvfi_insn_i[1:0]  == 2'b01 &&
        rvfi_insn_i[11:7] == 5'd2       // rd=x2 (sp)
    ) {
        bins C_ADDI16SP_RVY = {3'b011};
        bins ERR            = default;
    }

    // C.JAL (RV32Y only): funct3=001, op=01
    cp_c_jal_rv32y: coverpoint rvfi_insn_i[15:13] iff (rvfi_insn_i[1:0] == 2'b01) {
        bins C_JAL_RV32Y = {3'b001};
        bins ERR         = default;
    }

    // --- Quadrant 2 (op=10) ---
    // C.LYSP: stack-pointer-relative capability load
    cp_c_lysp: coverpoint rvfi_insn_i[15:13] iff (rvfi_insn_i[1:0] == 2'b10) {
        bins C_LYSP_RV32Y = {3'b011};  // RV32Y
        bins C_LYSP_RV64Y = {3'b001};  // RV64Y
    }

    // C.SYSP: stack-pointer-relative capability store
    cp_c_sysp: coverpoint rvfi_insn_i[15:13] iff (rvfi_insn_i[1:0] == 2'b10) {
        bins C_SYSP_RV32Y = {3'b111};  // RV32Y
        bins C_SYSP_RV64Y = {3'b101};  // RV64Y
    }

    // CR-format: C.YMV, C.JR, C.JALR — all quadrant 2, differentiated by funct4 + rs2
    // C.YMV:  funct4=1000, rd≠x0, rs2≠x0
    cp_c_ymv: coverpoint rvfi_insn_i[15:12] iff (
        rvfi_insn_i[1:0]  == 2'b10    &&
        rvfi_insn_i[11:7] != 5'b00000 &&   // rd≠x0
        rvfi_insn_i[6:2]  != 5'b00000      // rs2≠x0
    ) {
        bins C_YMV = {4'b1000};
        bins ERR   = default;
    }

    // C.JR (RVY): funct4=1000, rs1≠x0, rs2=x0
    cp_c_jr_rvy: coverpoint rvfi_insn_i[15:12] iff (
        rvfi_insn_i[1:0]  == 2'b10    &&
        rvfi_insn_i[11:7] != 5'b00000 &&   // rs1≠x0
        rvfi_insn_i[6:2]  == 5'b00000      // rs2=x0
    ) {
        bins C_JR_RVY = {4'b1000};
        bins ERR      = default;
    }

    // C.JALR (RVY): funct4=1001, rs1≠x0, rs2=x0
    cp_c_jalr_rvy: coverpoint rvfi_insn_i[15:12] iff (
        rvfi_insn_i[1:0]  == 2'b10    &&
        rvfi_insn_i[11:7] != 5'b00000 &&   // rs1≠x0
        rvfi_insn_i[6:2]  == 5'b00000      // rs2=x0
    ) {
        bins C_JALR_RVY = {4'b1001};
        bins ERR        = default;
    }

  endgroup


  //==========================================================================
  // Instantiate Covergroups
  //==========================================================================

  cg_itype       rv64i_cov;
  cg_cheri_type  cheri_cov;

  initial begin
    rv64i_cov = new();
    $display("RV32/64 coverage added ");

    cheri_cov = new();
    $display("Cheri coverage added ");

  end


`ifdef ENABLE_OVERLAP_DETECTION
  //==========================================================================
  // OVERLAP DETECTION — stops simulation via $fatal if any instruction
  // simultaneously satisfies more than one bin condition
  // slows down simulation by afactor of 10 at lest -> use it only for debugging
  //==========================================================================

  //Helper function: count how many cg_itype bins match the current instruction
  function automatic int count_itype_hits();
    automatic int n = 0;

    // cp_r_type (opcode = 0110011)
    if (opcode == 7'b0110011) begin
      if ({funct7,funct3} == 10'b0000000_000) n++; // ADD
      if ({funct7,funct3} == 10'b0100000_000) n++; // SUB
      if ({funct7,funct3} == 10'b0000000_001) n++; // SLL
      if ({funct7,funct3} == 10'b0000000_010) n++; // SLT
      if ({funct7,funct3} == 10'b0000000_011) n++; // SLTU
      if ({funct7,funct3} == 10'b0000000_100) n++; // XOR
      if ({funct7,funct3} == 10'b0000000_101) n++; // SRL
      if ({funct7,funct3} == 10'b0100000_101) n++; // SRA
      if ({funct7,funct3} == 10'b0000000_110) n++; // OR
      if ({funct7,funct3} == 10'b0000000_111) n++; // AND
    end

    // cp_i_type (opcode = 0010011) — funct3 only, no funct7
    if (opcode == 7'b0010011) begin
      if (funct3 == 3'b000) n++; // ADDI
      if (funct3 == 3'b010) n++; // SLTI
      if (funct3 == 3'b011) n++; // SLTIU
      if (funct3 == 3'b100) n++; // XORI
      if (funct3 == 3'b110) n++; // ORI
      if (funct3 == 3'b111) n++; // ANDI
    end

    // cp_shift_i (opcode = 0010011) — funct7[6:1]+funct3 key
    // NOTE: ADDI and SRLI share opcode+funct3=101 — shift bins use funct7
    // so they are disjoint from cp_i_type in practice for SLLI/SRLI/SRAI
    if (opcode == 7'b0010011) begin
      if ({funct7[6:1],funct3} == 9'b000000_001) n++; // SLLI
      if ({funct7[6:1],funct3} == 9'b000000_101) n++; // SRLI
      if ({funct7[6:1],funct3} == 9'b010000_101) n++; // SRAI
    end

    // cp_r_type_32 (opcode = 0111011)
    if (opcode == 7'b0111011) begin
      if ({funct7,funct3} == 10'b0000000_000) n++; // ADDW
      if ({funct7,funct3} == 10'b0100000_000) n++; // SUBW
      if ({funct7,funct3} == 10'b0000000_001) n++; // SLLW
      if ({funct7,funct3} == 10'b0000000_101) n++; // SRLW
      if ({funct7,funct3} == 10'b0100000_101) n++; // SRAW
    end

    // cp_i_type_32 / cp_shift_i_32 (opcode = 0011011)
    if (opcode == 7'b0011011) begin
      if (funct3 == 3'b000)                         n++; // ADDIW
      if ({funct7,funct3} == 10'b0000000_001)       n++; // SLLIW
      if ({funct7,funct3} == 10'b0000000_101)       n++; // SRLIW
      if ({funct7,funct3} == 10'b0100000_101)       n++; // SRAIW
    end

    // U/J type — these are unique opcodes so no overlap possible,
    // but count them anyway for completeness
    if (opcode == 7'b0110111) n++; // LUI
    if (opcode == 7'b0010111) n++; // AUIPC
    if (opcode == 7'b1101111) n++; // JAL
    if (opcode == 7'b1100111) n++; // JALR

    // cp_branch (opcode = 1100011)
    if (opcode == 7'b1100011) begin
      if (funct3 == 3'b000) n++; // BEQ
      if (funct3 == 3'b001) n++; // BNE
      if (funct3 == 3'b100) n++; // BLT
      if (funct3 == 3'b101) n++; // BGE
      if (funct3 == 3'b110) n++; // BLTU
      if (funct3 == 3'b111) n++; // BGEU
    end

    // cp_load (opcode = 0000011)
    if (opcode == 7'b0000011) begin
      if (funct3 == 3'b000) n++; // LB
      if (funct3 == 3'b001) n++; // LH
      if (funct3 == 3'b010) n++; // LW
      if (funct3 == 3'b011) n++; // LD
      if (funct3 == 3'b100) n++; // LBU
      if (funct3 == 3'b101) n++; // LHU
      if (funct3 == 3'b110) n++; // LWU
    end

    // cp_store (opcode = 0100011)
    if (opcode == 7'b0100011) begin
      if (funct3 == 3'b000) n++; // SB
      if (funct3 == 3'b001) n++; // SH
      if (funct3 == 3'b010) n++; // SW
      if (funct3 == 3'b011) n++; // SD
    end

    // cp_misc_mem (opcode = 0001111)
    if (opcode == 7'b0001111) begin
      if (funct3 == 3'b000) n++; // FENCE
      if (funct3 == 3'b001) n++; // FENCE_I
    end

    // cp_system (opcode = 1110011, funct3=000)
    if (opcode == 7'b1110011 && funct3 == 3'b000) begin
      if (funct12 == 12'h000) n++; // ECALL
      if (funct12 == 12'h001) n++; // EBREAK
    end

    return n;
  endfunction

  // Helper function: count how many cg_cheri_type bins match
  function automatic int count_cheri_hits();
    automatic int n = 0;

    if (opcode == 7'b0110011) begin
      // cp_op_cheri_2src — two-source R-type
      if ({funct7,funct3} == 10'b0000110_000 && rs2 != 5'b00000) n++; // ADDY
      if ({funct7,funct3} == 10'b0000110_001) n++; // YADDRW
      if ({funct7,funct3} == 10'b0000110_010) n++; // YPERMC
      if ({funct7,funct3} == 10'b0000110_101) n++; // YBLD
      if ({funct7,funct3} == 10'b0000110_100) n++; // SYEQ
      if ({funct7,funct3} == 10'b0000110_110) n++; // YLT
      if ({funct7,funct3} == 10'b0000110_111) n++; // YMODEW
      if ({funct7,funct3} == 10'b0000111_000) n++; // YBNDSW
      if ({funct7,funct3} == 10'b0000111_001) n++; // YBNDSRW
      if ({funct7,funct3} == 10'b0000111_010) n++; // YSUNSEAL
      if ({funct7,funct3} == 10'b0000100_011) n++; // PACKY

      // cp_ymv — ADDY with rs2=x0 (intentional spec overlap with ADDY above)
      // We deliberately DON'T count this separately here because it's a
      // known spec-defined encoding alias. Comment out if you want to detect it:
      // if ({funct7,rs2,funct3} == 15'b0000110_00000_000) n++; // YMV

      // cp_op_cheri_1src — single-source (funct7=0001000)
      if ({funct7,rs2,funct3} == 15'b0001000_00000_000) n++; // YTAGR
      if ({funct7,rs2,funct3} == 15'b0001000_00001_000) n++; // YPERMR
      if ({funct7,rs2,funct3} == 15'b0001000_00010_000) n++; // YTYPER
      if ({funct7,rs2,funct3} == 15'b0001000_00011_000) n++; // YMODER
      if ({funct7,rs2,funct3} == 15'b0001000_00101_000) n++; // YBASER
      if ({funct7,rs2,funct3} == 15'b0001000_00110_000) n++; // YLENR
      if ({funct7,rs2,funct3} == 15'b0001000_00111_000) n++; // YAMASK
      if ({funct7,rs2,funct3} == 15'b0001000_01000_000) n++; // YSENTRY

      // cp_ymodesw (rs1=x0, rd=x0)
      if (rs2 == 5'b00000 && rvfi_insn_i[19:15] == 5'b00000 && rvfi_insn_i[11:7]  == 5'b00000) begin
        if ({funct7,funct3} == 10'b0001001_001) n++; // YMODESWY
        if ({funct7,funct3} == 10'b0001010_001) n++; // YMODESWI
      end

      // cp_shaddy (funct7=0100000)
      if ({funct7,funct3} == 10'b0100000_011) n++; // SH1ADDY
      if ({funct7,funct3} == 10'b0100000_101) n++; // SH2ADDY
      if ({funct7,funct3} == 10'b0100000_000) n++; // SH3ADDY
      if ({funct7,funct3} == 10'b0100000_111) n++; // SH4ADDY
    end

    // OP-IMM-32 (opcode = 0011011)
    if (opcode == 7'b0011011) begin
      if (funct3 == 3'b010) n++; // ADDIY
      if (funct3 == 3'b011) n++; // YBNDSWI
    end

    // OP-32 (opcode = 0111011)
    if (opcode == 7'b0111011) begin
      if ({funct7,funct3} == 10'b0010000_011) n++; // SH1ADDY_UW
      if ({funct7,funct3} == 10'b0010000_101) n++; // SH2ADDY_UW
      if ({funct7,funct3} == 10'b0010000_000) n++; // SH3ADDY_UW
      if ({funct7,funct3} == 10'b0010000_111) n++; // SH4ADDY_UW
    end

    // OP-IMM (opcode = 0010011)
    if (opcode == 7'b0010011 && funct3 == 3'b101) begin
      if ({rvfi_insn_i[31:20],funct3} == 15'b000000_1000000_101) n++; // SRLIY_RV64
      if ({rvfi_insn_i[31:20],funct3} == 15'b000000_0100000_101) n++; // SRLIY_RV32
    end

    // MISC-MEM (opcode = 0001111)
    if (opcode == 7'b0001111) begin
      if (funct3 == 3'b100) n++; // LY
      // CBO instructions
      if (funct3 == 3'b010 && rvfi_insn_i[11:7] == 5'b00000) begin
        if (rvfi_insn_i[31:20] == 12'b000000000000) n++; // CBO_INVAL
        if (rvfi_insn_i[31:20] == 12'b000000000001) n++; // CBO_CLEAN
        if (rvfi_insn_i[31:20] == 12'b000000000010) n++; // CBO_FLUSH
        if (rvfi_insn_i[31:20] == 12'b000000000100) n++; // CBO_ZERO
      end
    end

    // STORE (opcode = 0100011)
    if (opcode == 7'b0100011) begin
      if (funct3 == 3'b100) n++; // SY
    end

    // AMO (opcode = 0101111)
    if (opcode == 7'b0101111) begin
      if ({rvfi_insn_i[31:27],funct3} == 8'b00010_100) n++; // LR_Y
      if ({rvfi_insn_i[31:27],funct3} == 8'b00011_100) n++; // SC_Y
      if ({rvfi_insn_i[31:27],funct3} == 8'b00001_100) n++; // AMOSWAP_Y
    end

    // SYSTEM (opcode = 1110011) — CSR and hypervisor
    if (opcode == 7'b1110011) begin
      if (funct3 inside {3'b001,3'b010,3'b011,3'b101,3'b110,3'b111}) n++; // CSR*_RVY
      if ({funct7,funct3} == 10'b0111000_100) n++; // HLV_Y
      if ({funct7,funct3} == 10'b0111001_100) n++; // HSV_Y
    end

    return n;
  endfunction

   Overlap detection block
  always @(posedge clk_i) begin
    if (rst_ni && rvfi_valid_i) begin
      automatic int itype_hits = count_itype_hits();
      automatic int cheri_hits = count_cheri_hits();

      // cg_itype overlap check
      assert (itype_hits <= 1)
        else begin
          $display($sformatf("[OVERLAP][cg_itype] t=%0t insn=0x%08x",$time, rvfi_insn_i));
          $display($sformatf("[OVERLAP][cg_itype] opcode=0b%7b funct3=0b%3b funct7=0b%7b",  opcode, funct3, funct7));
          $fatal(1,$sformatf("[OVERLAP][cg_itype] More than one coverpoint was hit. %d hits.", itype_hits));
        end

      // cg_cheri_type overlap check
      assert (cheri_hits <= 1) begin
          $display($sformatf("[OVERLAP][cg_cheri_type] t=%0t insn=0x%08x",$time, rvfi_insn_i));
          $display($sformatf("[OVERLAP][cg_cheri_type] opcode=0b%7b funct3=0b%3b funct7=0b%7b rs2=0b%5b",  opcode, funct3, funct7,rs2));
          $fatal(1,$sformatf("[OVERLAP][cg_cheri_type] More than one coverpoint was hit. %d hits.", cheri_hits));
      end

      // Cross-group mutual exclusion check — an instruction cannot be
      // both a base integer instruction AND a CHERI instruction
      assert (!(itype_hits > 0 && cheri_hits > 0)) begin
          $display($sformatf("[OVERLAP][cross-group] t=%0t insn=0x%08x",$time, rvfi_insn_i));
          $display($sformatf("[OVERLAP][cross-group] opcode=0b%7b funct3=0b%3b funct7=0b%7b rs2=0b%5b",  opcode, funct3, funct7,rs2));
          $fatal(1,$sformatf("[OVERLAP][cross-group] Multiple covergroups were hit. cg_itype:%d cg_cheri_type:%d.", itype_hits, cheri_hits));
      end

    end
  end
`endif

endmodule
