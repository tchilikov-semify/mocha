cd $env(SIM_DIR)
load -run ./cosmic__cva6_testrig_0/default-xcelium/cov_work/scope/cva6_testrig_test
config reports.detachable_report_data -set true

# Generate the text report (summary is sufficient).
report -summary \
  -inst uvm_pkg cva6 \
  -metrics all \
  -all \
  -cumulative on \
  -local off \
  -grading covered \
  -out ./cosmic__cva6_testrig_0/default-xcelium/coverage_reports/cov_report.txt

# Generate the functional coverage report for tracking.
report -summary \
  -type \
  -all \
  -metrics covergroup \
  -source off \
  -out ./cosmic__cva6_testrig_0/default-xcelium/coverage_reports/cov_report_cg.txt

# Generate the HTML reports.
report_metrics \
  -out ./cosmic__cva6_testrig_0/default-xcelium/coverage_reports \
  -overwrite \
  -title cva6_title \
  -detail \
  -metrics all \
  -kind aggregate \
  -source on \
  -exclComments \
  -assertionStatus \
  -allAssertionCounters \
  -all

# rank the test runs
#rank -runfile cosmic__cva6_testrig_0/default-xcelium/cov_work/scope/cva6_testrig_test/runs.txt -html -out ./cosmic__cva6_testrig_0/default-xcelium/coverage_reports/grading

report -detail -text -out ./cosmic__cva6_testrig_0/default-xcelium/coverage_report.txt
exit
