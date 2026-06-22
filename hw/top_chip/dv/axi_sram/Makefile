# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

REPO_ROOT  := $(or $(MOCHA_ROOT),$(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/../../../..))
DV_DIR     := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CORE       := lowrisc:mocha_dv:axi_sram_tb

BUILD_ROOT    := $(DV_DIR)build

# ---- cocotb / Verilator (existing flow) ----
FUSESOC_BUILD := $(BUILD_ROOT)/lowrisc_mocha_dv_axi_sram_tb_0/default-verilator
VC_FILE       := $(FUSESOC_BUILD)/lowrisc_mocha_dv_axi_sram_tb_0.vc

# ---- UVM / Verilator ----
UVM_TESTNAME    ?= axi_sram_write_read_test
UVM_HOME        ?=
UVM_VLT_BUILD   := $(BUILD_ROOT)/lowrisc_mocha_dv_axi_sram_tb_0/sim_uvm_verilator-verilator
UVM_VLT_SIM     := $(UVM_VLT_BUILD)/Vaxi_sram_uvm_tb

# Verilator options for the UVM target (= not := so UVM_HOME is lazily expanded).
# Passed as VERILATOR_OPTIONS override to the edalize-generated Makefile because
# the deprecated edalize Verilator backend only propagates -D flags from
# flow_options.verilator.verilator_options; all other options are silently dropped.
UVM_VLT_OPTIONS = \
  -DDISABLE_PRIM_CDC_RAND_DELAY \
  --timing \
  --public-flat-rw \
  --assert \
  -Wno-UNOPTFLAT \
  +incdir+$(UVM_HOME)/src

# Verilator writes all output (Vtop.mk, C++ files) to its CWD rather than
# the absolute -Mdir path. We run make -C FUSESOC_BUILD so CWD = FUSESOC_BUILD.
SIM_BUILD := $(FUSESOC_BUILD)

TOPLEVEL            := axi_sram_tb
COCOTB_TEST_MODULES := axi_sram_tb
SIM                 := verilator

EXTRA_ARGS += -f $(VC_FILE)
EXTRA_ARGS += --assert --timing --public-flat-rw
EXTRA_ARGS += -DDISABLE_PRIM_CDC_RAND_DELAY
EXTRA_ARGS += -Wno-UNOPTFLAT

# Waveform tracing makes Verilator emit huge C++ for the 16384-deep SRAM array
# (--trace-max-array 65536), so the g++ compile of Vtop__Trace__*.o takes many
# minutes / lots of RAM and looks like a hang. Tracing is therefore opt-in:
#   make sim TRACE=1      # build with FST waveform dump (dump.fst)
ifdef TRACE
  SIM_ARGS   += +trace
  EXTRA_ARGS += --trace-fst --trace-max-array 65536
endif

COCOTB_MAKEFILES := $(shell cocotb-config --makefiles)

.PHONY: setup sim sim_uvm_vlt sim_uvm_xcelium clean

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

UVM_VLT_VC := $(UVM_VLT_BUILD)/lowrisc_mocha_dv_axi_sram_tb_0.vc

# Build the UVM+Verilator simulation binary (compile only, no run).
# Step 1: fusesoc --setup generates the .vc file with all source/include paths.
# Step 2: Inject uvm_pkg.sv as the first source in the .vc file so that
#         uvm_pkg is compiled before axi_agent_pkg and dv_utils_pkg, which
#         reference UVM types.  The package must precede its users in
#         Verilator's single-pass compilation.
# Step 3: make -C overrides VERILATOR_OPTIONS to inject --timing, UVM flags.
$(UVM_VLT_SIM):
	@test -n "$(UVM_HOME)" || (echo "ERROR: UVM_HOME is not set — enter 'nix develop' first"; exit 1)
	cd $(DV_DIR) && fusesoc --cores-root=$(REPO_ROOT) \
	    run --target sim_uvm_verilator --setup $(CORE)
	python3 -c "lines=open('$(UVM_VLT_VC)').readlines(); idx=next(i for i,l in enumerate(lines) if l.startswith('src/')); lines.insert(idx,'$(UVM_HOME)/src/uvm_pkg.sv\n'); open('$(UVM_VLT_VC)','w').writelines(lines)"
	$(MAKE) -C $(UVM_VLT_BUILD) VERILATOR_OPTIONS="$(UVM_VLT_OPTIONS)"

# Run UVM smoke test with Verilator.  Recompiles only if binary is stale.
#   make sim_uvm_vlt                               # default test
#   make sim_uvm_vlt UVM_TESTNAME=my_other_test    # specific test
sim_uvm_vlt: $(UVM_VLT_SIM)
	$(UVM_VLT_SIM) +UVM_TESTNAME=$(UVM_TESTNAME)

# Run UVM smoke test with Xcelium.
# Test name is set in axi_sram_tb.core sim_uvm.xrun_options; edit there to change.
sim_uvm_xcelium:
	cd $(DV_DIR) && fusesoc --cores-root=$(REPO_ROOT) \
	    run --target sim_uvm --tool xcelium $(CORE)

clean:
	rm -rf $(BUILD_ROOT)
