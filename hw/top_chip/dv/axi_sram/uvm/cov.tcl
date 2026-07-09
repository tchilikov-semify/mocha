# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# imc batch script: merge every per-test functional-coverage UCD into one
# database and render an HTML report. Driven by `make cov_report` and executed
# from the fusesoc build directory, so all paths are relative to it (cov_work/
# lives there, populated by `make regress COVERAGE=1`).

set scope cov_work/scope
set tests [glob -nocomplain $scope/*_test]
if {[llength $tests] == 0} {
  puts "ERROR: no per-test coverage under $scope — run: make regress COVERAGE=1"
  exit 1
}

puts "Merging [llength $tests] per-test runs -> $scope/merged"
# `eval` expands the test list into separate args (imc's Tcl predates {*}).
eval merge $tests -out $scope/merged -initial_model union_all -overwrite

load -run $scope/merged
report_metrics -detail -metrics functional -out cov_report -overwrite
puts "Coverage report written to [pwd]/cov_report/index.html"
exit
