# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# cocotb / Verilator flow for the AXI SRAM testbench.
#
#   make            # build (fusesoc --setup) + run the cocotb tests
#   make TRACE=1    # ... with an FST waveform dump (dump.fst)
#   make clean      # remove the build directory

DV_DIR     := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT  := $(or $(MOCHA_ROOT),$(realpath $(DV_DIR)../../../../..))
CORE       := lowrisc:mocha_dv:axi_sram_cocotb

# fusesoc build tree, kept in-tree next to the sources (clean removes it).
FUSESOC_BUILD := $(DV_DIR)lowrisc_mocha_dv_axi_sram_cocotb_0/default-verilator
VC_FILE       := $(FUSESOC_BUILD)/lowrisc_mocha_dv_axi_sram_cocotb_0.vc

# Verilator writes its output (Vtop.mk, C++) to its CWD, so we run the cocotb
# make with CWD = FUSESOC_BUILD.
SIM_BUILD := $(FUSESOC_BUILD)

TOPLEVEL            := axi_sram_tb
COCOTB_TEST_MODULES := axi_sram_tb
SIM                 := verilator

EXTRA_ARGS += -f $(VC_FILE)
EXTRA_ARGS += --assert --timing --public-flat-rw
EXTRA_ARGS += -DDISABLE_PRIM_CDC_RAND_DELAY
EXTRA_ARGS += -Wno-UNOPTFLAT
# Vendored RTL (pulp axi, cva6 config pkgs) has width-lint warnings that
# Xcelium only warns on; keep Verilator from treating them as fatal.
EXTRA_ARGS += -Wno-fatal

# Waveform tracing makes Verilator emit huge C++ for the deep SRAM array, so the
# g++ compile takes many minutes / lots of RAM.  Tracing is therefore opt-in:
#   make TRACE=1      # build with FST waveform dump (dump.fst)
ifdef TRACE
  SIM_ARGS   += +trace
  EXTRA_ARGS += --trace-fst --trace-max-array 65536
endif

COCOTB_MAKEFILES := $(shell cocotb-config --makefiles)

.PHONY: sim setup clean

# Default goal: build (if needed) and run the cocotb tests.
sim: $(VC_FILE)
	$(MAKE) -C $(FUSESOC_BUILD) \
	    -f $(COCOTB_MAKEFILES)/Makefile.sim \
	    SIM=$(SIM) \
	    TOPLEVEL_LANG=verilog \
	    TOPLEVEL=$(TOPLEVEL) \
	    COCOTB_TEST_MODULES=$(COCOTB_TEST_MODULES) \
	    SIM_BUILD=$(SIM_BUILD) \
	    PYTHONPATH=$(DV_DIR) \
	    SIM_ARGS="$(SIM_ARGS)" \
	    EXTRA_ARGS="$(EXTRA_ARGS)"

# fusesoc --setup generates the .vc file (source list + include paths).
$(VC_FILE):
	cd $(DV_DIR) && fusesoc --cores-root=$(REPO_ROOT) \
	    run --build-root=$(DV_DIR) --target default --setup $(CORE)

setup: $(VC_FILE)

clean:
	rm -rf $(DV_DIR)lowrisc_mocha_dv_axi_sram_cocotb_0
