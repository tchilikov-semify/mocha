# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

REPO_ROOT  := $(or $(MOCHA_ROOT),$(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/../../../..))
DV_DIR     := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CORE       := lowrisc:mocha_dv:axi_sram_tb

BUILD_ROOT    := $(DV_DIR)build
FUSESOC_BUILD := $(BUILD_ROOT)/lowrisc_mocha_dv_axi_sram_tb_0/default-verilator
VC_FILE       := $(FUSESOC_BUILD)/lowrisc_mocha_dv_axi_sram_tb_0.vc

# Verilator writes all output (Vtop.mk, C++ files) to its CWD rather than
# the absolute -Mdir path. We run make -C FUSESOC_BUILD so CWD = FUSESOC_BUILD.
SIM_BUILD := $(FUSESOC_BUILD)

TOPLEVEL            := axi_sram_tb
COCOTB_TEST_MODULES := axi_sram_tb
SIM                 := verilator

SIM_ARGS += +trace

EXTRA_ARGS += -f $(VC_FILE)
EXTRA_ARGS += --assert --timing --trace-fst --public-flat-rw
EXTRA_ARGS += -DDISABLE_PRIM_CDC_RAND_DELAY
EXTRA_ARGS += -Wno-UNOPTFLAT
EXTRA_ARGS += --trace-max-array 65536

COCOTB_MAKEFILES := $(shell cocotb-config --makefiles)

.PHONY: setup sim clean

$(VC_FILE):
	cd $(DV_DIR) && fusesoc --cores-root=$(REPO_ROOT) \
	    run --target default --setup $(CORE)

setup: $(VC_FILE)

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

clean:
	rm -rf $(BUILD_ROOT)
