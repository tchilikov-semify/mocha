SIM_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PRJ_DIR := $(abspath $(SIM_DIR)/..)
HW_DIR  := $(abspath $(SIM_DIR)/../../../..)

# FuseSoC places Xcelium build artefacts here.
# --build-root directs FuseSoC to create its build tree under sim/ rather than
# the project root.  The subdirectory name is derived from VLNV cosmic::cva6_testrig:0.
FUSESOC_BUILD_DIR := $(SIM_DIR)cosmic__cva6_testrig_0/default-xcelium

VERBOSE ?= 0
WAVES   ?= 1

export VERBOSE
export WAVES
export PRJ_DIR

ifeq ($(VERBOSE),1)
  UVM_VERBOSITY := +UVM_VERBOSITY=UVM_HIGH
else
  UVM_VERBOSITY := +UVM_VERBOSITY=UVM_LOW
endif

ifeq ($(WAVES),1)
  WAVE_ARG := -input "@database -open waves -shm -into waves.shm; probe -create cva6_testrig_tb_top -depth all -database waves; run; exit"
else
  WAVE_ARG := -input "@run; exit"
endif

.PHONY: build run coverage dvplan clean
# Elaborate via FuseSoC.  All xrun flags and file lists are managed by
# testrig_tb/cva6_testrig.core.  The Edalize-generated Makefile has no
# separate build target, so FuseSoC runs its full flow (setup + run).
# xrun stops at elaboration because -elaborate is in the core's xrun_options.
build:
	export LD_LIBRARY_PATH=/usr/lib64:/lib64:$$LD_LIBRARY_PATH; \
	fusesoc --cores-root=$(HW_DIR) run --build-root=$(SIM_DIR) --target=default cosmic::cva6_testrig

# Called by runTestRIG.py as the cva6_coverage subprocess.
# RVFI_DII_PORT is injected into the environment by runTestRIG.py before invoking this.
run:
	@[ -d $(FUSESOC_BUILD_DIR) ] || $(MAKE) build
	export LD_PRELOAD=$$(gcc -print-file-name=libstdc++.so.6):$$LD_PRELOAD; \
	cd $(FUSESOC_BUILD_DIR) && \
	xrun \
	 -64bit \
	 -R \
	 -snapshot cva6_work \
	 -l run.log \
	 -coverage functional \
	 -covworkdir cov_work \
	 -covoverwrite \
	 -covtest cva6_testrig_test \
	 +UVM_TESTNAME=cva6_testrig_test \
	 $(WAVE_ARG) \
	 $(UVM_VERBOSITY)

dvplan: | $(FUSESOC_BUILD_DIR)
	FUSESOC_BUILD_DIR=$(FUSESOC_BUILD_DIR) imc -exec coverage/coverage_report.tcl && \
	nix shell git+ssh://git@github.com/lowrisc/dvplan.git --command bash -c ' \
	  dvplan generate $(PRJ_DIR)/testrig_tb/coverage/ISA_V_Plan.hjson $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson && \
	  dvplan tag $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson && \
	  COV_REPORT_FILE=$$(ls -t $(FUSESOC_BUILD_DIR)/coverage_reports/report_data/* | head -n 1) && \
	  echo "Using coverage report: $$COV_REPORT_FILE" && \
	  dvplan annotate -c cadence_report CVA6-CHERI tb.dut $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson $$COV_REPORT_FILE && \
	  dvplan aggregate $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson && \
	  dvplan report $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson -o $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.html \
	'

clean:
	rm -rf $(SIM_DIR)cosmic__cva6_testrig_0
