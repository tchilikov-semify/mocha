# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Thin wrapper around fusesoc for the AXI SRAM UVM testbench (Xcelium).
# All xrun options live in axi_sram_uvm.core; this does tool discovery and hands
# xrun an inline run-control script (waive a known DUT assertion, run, and
# optionally dump waves).
#
#   make                  # compile (as needed) + run the default test
#   make TEST=<uvm_test>  # ... run a specific UVM test instead
#   make regress          # run every UVM test; print a pass/fail summary
#   make regress COVERAGE=1  # ... collecting a per-test coverage UCD for merging
#   make WAVES=1          # ... and dump waves.shm into the build directory
#   make COVERAGE=1       # ... and collect functional (covergroup) coverage
#   make clean            # remove the build directory

DV_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(or $(MOCHA_ROOT),$(realpath $(DV_DIR)../../../../..))
# fusesoc build output directory (VLNV-derived; appended to --build-root=$(DV_DIR)).
BUILD_DIR := $(DV_DIR)lowrisc_mocha_dv_axi_sram_uvm_0

export PATH            := /nas/lowrisc/tools/cadence/xcelium/XCELIUM2403/tools/bin:$(PATH)
export XRUN            ?= /run/current-system/sw/bin/xrun
export LD_LIBRARY_PATH := /usr/lib64:/lib64:$(LD_LIBRARY_PATH)

# Waive the known-harmless prim_fifo_sync DataKnown_A assertion in the DUT. It
# fires on the don't-care wdata of the tag read-modify-write request in 4-state
# Xcelium (Verilator reads X as 0, so cocotb never saw it). NumBanks=1, so the
# single gen_reqs[0] FIFO is the only instance.
WAIVE_ASSERT := assertion -off {axi_sram_uvm_tb.u_dut.u_axi_to_detailed_mem.i_mem_to_banks.gen_reqs[0].i_ft_reg.DataKnown_A}

ifdef WAVES
  DUMP_WAVES := database -open waves -shm -into waves.shm; probe -create -shm -all -depth all -dynamic -memories -variables -database waves;
endif

export XMSIM_OPTIONS := -input "@$(WAIVE_ASSERT); $(DUMP_WAVES) run; exit"

# The UVM test to run. The core deliberately does not set +UVM_TESTNAME: UVM
# honours the first one on the command line and fusesoc can only append options,
# so selecting the test here (via --xrun_options) keeps a single, overridable
# source. It must go on the real xrun command line, not -xmsimargs, which UVM's
# cmdline processor does not read.
TEST ?= axi_sram_write_read_test

# Functional (covergroup) coverage. Opt-in: Xcelium only samples covergroups when
# -coverage u is set. Each run writes a UCD named after the test into the build
# directory's cov_work/, so the per-test databases can later be merged/reported
# with imc (that merge flow is not added here — see the vplan Coverage section).
ifdef COVERAGE
  COV_OPTS := -coverage u -covworkdir $(BUILD_DIR)/cov_work -covtest $(TEST) -covoverwrite
endif

# Every runnable UVM test declared in the test package (excludes the base test).
TESTS := $(filter-out axi_sram_base_test,\
           $(shell grep -oE 'axi_sram_[a-z0-9_]+_test' $(DV_DIR)axi_sram_test_pkg.sv | sort -u))

.PHONY: run regress clean

run:
	fusesoc --cores-root=$(REPO_ROOT) run --build-root=$(DV_DIR) lowrisc:mocha_dv:axi_sram_uvm --xrun_options "+UVM_TESTNAME=$(TEST) $(COV_OPTS)"

# Run every test serially (the build directory is shared, so runs cannot overlap).
# Per-test console logs land in $(BUILD_DIR)/regress/. Passes COVERAGE/WAVES through.
# Exits non-zero if any test fails.
regress:
	@mkdir -p $(BUILD_DIR)/regress; pass=0; total=0; fails=""; \
	for t in $(TESTS); do \
	  total=$$((total+1)); printf '  %-30s ' "$$t"; \
	  $(MAKE) -s run TEST=$$t > $(BUILD_DIR)/regress/$$t.log 2>&1; \
	  err=$$(grep -oE 'UVM_ERROR :[[:space:]]*[0-9]+' $(BUILD_DIR)/regress/$$t.log | tail -1 | grep -oE '[0-9]+$$'); \
	  fat=$$(grep -oE 'UVM_FATAL :[[:space:]]*[0-9]+' $(BUILD_DIR)/regress/$$t.log | tail -1 | grep -oE '[0-9]+$$'); \
	  if [ "$$err" = "0" ] && [ "$$fat" = "0" ]; then echo PASS; pass=$$((pass+1)); \
	  else echo "FAIL (UVM_ERROR=$${err:-?} UVM_FATAL=$${fat:-?}; see $(BUILD_DIR)/regress/$$t.log)"; fails="$$fails $$t"; fi; \
	done; \
	echo "==================================================="; \
	echo "  $$pass / $$total passed"; \
	[ -z "$$fails" ] || { echo "  failed:$$fails"; false; }

clean:
	rm -rf $(BUILD_DIR)
