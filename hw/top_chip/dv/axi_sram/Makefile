# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Thin wrapper around fusesoc for the AXI SRAM UVM testbench (Xcelium).
# All xrun options live in axi_sram_tb.core; this does tool discovery and hands
# xrun an inline run-control script (waive a known DUT assertion, run, and
# optionally dump waves).
#
#   make            # compile (as needed) + run
#   make WAVES=1    # ... and dump waves.shm into the build directory
#   make clean      # remove the build directory

DV_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(or $(MOCHA_ROOT),$(realpath $(DV_DIR)../../../..))

export PATH            := /nas/lowrisc/tools/cadence/xcelium/XCELIUM2403/tools/bin:$(PATH)
export XRUN            ?= /run/current-system/sw/bin/xrun
export LD_LIBRARY_PATH := /usr/lib64:/lib64:$(LD_LIBRARY_PATH)

WAIVE_ASSERT := assertion -off {axi_sram_uvm_tb.u_dut.u_axi_to_detailed_mem.i_mem_to_banks.gen_reqs[0].i_ft_reg.DataKnown_A}

ifdef WAVES
  DUMP_WAVES := database -open waves -shm -into waves.shm; probe -create -shm -all -depth all -dynamic -memories -variables -database waves;
endif

export XMSIM_OPTIONS := -input "@$(WAIVE_ASSERT); $(DUMP_WAVES) run; exit"

.PHONY: run clean

run:
	fusesoc --cores-root=$(REPO_ROOT) run --build-root=$(DV_DIR) lowrisc:mocha_dv:axi_sram_tb

clean:
	rm -rf $(DV_DIR)lowrisc_mocha_dv_axi_sram_tb_0
