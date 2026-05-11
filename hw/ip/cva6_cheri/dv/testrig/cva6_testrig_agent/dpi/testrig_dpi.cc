// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <svdpi.h>
#include <cassert>
#include <fstream>
#include <iostream>
#include "testrig.hh"
#include "testrig_dpi.h"

// Returns a file stream opened to the path in TESTRIG_LOG_EXEC_PKTS, or a
// closed stream if the variable is not set. Opened once on first use.
static std::ofstream& exec_log() {
  static std::ofstream log_file;
  static bool opened = false;
  if (!opened) {
    opened = true;
    log_file.open("exec_pkts.log");
  }
  return log_file;
}

TestRIG::Connection* testrig_create(const int port) {
  return new TestRIG::Connection(port);
}

svBit testrig_get_next_instruction(
        TestRIG::Connection* testrig_conn,
        svBitVecVal* dii_insn,
        svBitVecVal* dii_time,
        svBitVecVal* dii_cmd
) {

  assert(testrig_conn);

  TestRIG::RVFI_DII_Instruction_Packet insn_pkt;

  if (testrig_conn->get_next_instruction(insn_pkt, 100)) {
    *dii_insn = insn_pkt.dii_insn;
    *dii_time = static_cast<uint32_t>(insn_pkt.dii_time);
    *dii_cmd = static_cast<uint32_t>(insn_pkt.dii_cmd);

    return 1;
  }

  return 0;
}

void testrig_send_rvfi_halt(TestRIG::Connection* conn) {
  if (exec_log().is_open()) {
    exec_log() << "[TESTRIG_HALT] sending halt packet\n";
    exec_log().flush();
  }

  TestRIG::RVFI_DII_Execution_Packet rstpacket = {
      .rvfi_halt = 1
  };

  conn->put_execution(rstpacket);
}

void testrig_send_exec_pkt(TestRIG::Connection* conn, svBitVecVal* pkt_val) {
  TestRIG::RVFI_DII_Execution_Packet exec_pkt;
  exec_pkt = *reinterpret_cast<TestRIG::RVFI_DII_Execution_Packet*>(pkt_val);

  // Open the file once and keep it open for the duration of the simulation
  static std::ofstream log_file("exec_pkts.log");

  if (exec_log().is_open()) {
    exec_log()
      << "[TESTRIG_EXEC]"
      << " order=0x"    << std::hex << exec_pkt.rvfi_order
      << " pc_r=0x"     << std::hex << exec_pkt.rvfi_pc_rdata
      << " pc_w=0x"     << std::hex << exec_pkt.rvfi_pc_wdata
      << " insn=0x"     << std::hex << exec_pkt.rvfi_insn
      << " trap="       << std::dec << (uint32_t)exec_pkt.rvfi_trap
      << " intr="       << std::dec << (uint32_t)exec_pkt.rvfi_intr
      << " halt="       << std::dec << (uint32_t)exec_pkt.rvfi_halt
      << " rs1="        << std::dec << (uint32_t)exec_pkt.rvfi_rs1_addr
      << "/0x"          << std::hex << exec_pkt.rvfi_rs1_data
      << " rs2="        << std::dec << (uint32_t)exec_pkt.rvfi_rs2_addr
      << "/0x"          << std::hex << exec_pkt.rvfi_rs2_data
      << " rd="         << std::dec << (uint32_t)exec_pkt.rvfi_rd_addr
      << "/0x"          << std::hex << exec_pkt.rvfi_rd_wdata
      << " mem_addr=0x" << std::hex << exec_pkt.rvfi_mem_addr
      << " rmask=0x"    << std::hex << (uint32_t)exec_pkt.rvfi_mem_rmask
      << " rdata=0x"    << std::hex << exec_pkt.rvfi_mem_rdata
      << " wmask=0x"    << std::hex << (uint32_t)exec_pkt.rvfi_mem_wmask
      << " wdata=0x"    << std::hex << exec_pkt.rvfi_mem_wdata
      << std::dec << std::endl; // endl forces a flush so you see data if it crashes
  }

  conn->put_execution(exec_pkt);
}