SIM_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PRJ_DIR := $(abspath $(SIM_DIR)/..)
HW_DIR  := $(abspath $(SIM_DIR)/../../../..)
XRUN 		?= /run/current-system/sw/bin/xrun

# FuseSoC places Xcelium build artefacts here.
# --build-root directs FuseSoC to create its build tree under sim/ rather than
# the project root.  The subdirectory name is derived from VLNV cosmic::cva6_testrig:0.
FUSESOC_BUILD_DIR := $(SIM_DIR)cosmic__cva6_testrig_0/default-xcelium

export PRJ_DIR
export SIM_DIR
export XRUN

.PHONY: build run coverage dvplan clean run_testrig

build:
	export LD_LIBRARY_PATH=/usr/lib64:/lib64:$$LD_LIBRARY_PATH; \
	fusesoc --cores-root=$(HW_DIR) run --build-root=$(SIM_DIR) --target=default cosmic::cva6_testrig

dvplan: | $(FUSESOC_BUILD_DIR)
	FUSESOC_BUILD_DIR=$(FUSESOC_BUILD_DIR) imc -exec coverage/coverage_report.tcl && \
	nix shell git+ssh://git@github.com/lowrisc/dvplan.git --command bash -c ' \
	  dvplan generate $(PRJ_DIR)/testrig/coverage/ISA_V_Plan.hjson $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson && \
	  dvplan tag $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson && \
	  COV_REPORT_FILE=$$(ls -t $(FUSESOC_BUILD_DIR)/coverage_reports/report_data/* | head -n 1) && \
	  echo "Using coverage report: $$COV_REPORT_FILE" && \
	  dvplan annotate -c cadence_report CVA6-CHERI tb.dut $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson $$COV_REPORT_FILE && \
	  dvplan aggregate $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson && \
	  dvplan report $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.hjson -o $(FUSESOC_BUILD_DIR)/ISA_V_Plan_annotated.html \
	'

run_testrig:
	python $(HW_DIR)/vendor/dv/testrig/testrig.py -a sail -b cva6_coverage -r rv64icxcheri --no-support-misaligned --test-exclude-regex unstructured

clean:
	rm -rf $(SIM_DIR)cosmic__cva6_testrig_0
