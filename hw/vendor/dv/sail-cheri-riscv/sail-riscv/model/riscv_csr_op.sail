// The non-CHERI CSR implementation, delegates to the default non-CHERI implementation.
// This just exists so it can be overridden in the CHERI version.
function handle_csr_op(csr, rs1, rd, is_imm, op, isWrite, isRead) =
  default_handle_csr_op(csr, rs1, rd, is_imm, op, isWrite, isRead)
