// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// SystemVerilog configuration that elaborates the axi_sram chip-level testbench
// with the CVA6 core replaced by axi_driver_wrapper.
// Elaborate this config as the top

config mocha_cfg;
  design work.mocha_axi_bfm_tb;
  cell cva6 use work.axi_driver_wrapper;
endconfig
