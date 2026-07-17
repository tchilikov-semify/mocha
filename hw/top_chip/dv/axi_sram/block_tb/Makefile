# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Thin convenience wrapper around dvsim (the real flow) for the block-level
# axi_sram DV. The build/run recipe lives in axi_sram_block_sim_cfg.hjson.
#
#   make                 # run the default test
#   make TEST=<name>     # run one test, e.g. TEST=axi_sram_tag_write
#   make regress         # run the full block regression
#   make clean           # remove the dvsim scratch tree
#   make ... DVSIM_ARGS="--waves shm --cov"   # extra dvsim flags (waves, cov, --gui, -v d, ...)
#
# Runs inside the nix devshell (provides dvsim + xrun), e.g.:
#   nix develop --command make -C hw/top_chip/dv/axi_sram/block_tb run TEST=axi_sram_tag_write

DV_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CFG       := $(DV_DIR)axi_sram_block_sim_cfg.hjson
SCRATCH   := ./scratch

# dvsim must invoke the nix-FHS-wrapped `xrun` (bare `xrun` on PATH); the raw
# Cadence bin is only appended so xrun's sub-tools (e.g. xmroot) resolve.
export PATH            := /run/current-system/sw/bin:$(PATH):/nas/lowrisc/tools/cadence/xcelium/XCELIUM2403/tools/bin
export LD_LIBRARY_PATH := /usr/lib64:/lib64:$(LD_LIBRARY_PATH)

TEST      ?= axi_sram_write_read
DVSIM_ARGS ?=
DVSIM     := dvsim $(CFG) --tool xcelium --scratch-root $(SCRATCH) $(DVSIM_ARGS)

.PHONY: run regress clean
run:
	$(DVSIM) -i $(TEST)

regress:
	$(DVSIM) -i block

clean:
	rm -rf $(SCRATCH)
