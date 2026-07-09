# AXI SRAM UVM — commands

Run inside `nix develop` (repo root), from this directory.

```sh
make                                  # run default test (axi_sram_write_read_test)
make TEST=axi_sram_tag_write_test     # run a specific test
make regress                          # run all tests + pass/fail summary
make COVERAGE=1 TEST=...              # run with functional coverage (UCD -> cov_work/)
make WAVES=1 TEST=...                 # dump waves.shm
make clean                            # remove the build dir

# list tests
grep -oE 'axi_sram_[a-z0-9_]+_test' axi_sram_test.svh | sort -u

# view waves (needs an X display)
simvision lowrisc_mocha_dv_axi_sram_uvm_0/default-xcelium/waves.shm &
```
