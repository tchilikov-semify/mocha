# SPI device

The SPI device in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The SPI device emulates a serial NOR flash towards an external host, can pass transactions through to a downstream flash device, and carries a TPM interface on its own chip select.
The block spans two clock domains, the system clock and the incoming SPI clock, so its submodules take clocks and resets named for the domain they belong to rather than the usual `clk_i` and `rst_ni`.
Mocha instantiates it with the default two-port SRAM, `SramType2p`.
The [vendor patches][patch] only adjust testplan and simulation config paths and the default simulator; no RTL is modified.

The rest of this document contains the design checklist for the SPI device hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The SPI device used for [D1 sign-off][OpenTitan D1 signoff] is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [SPI device specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [SPI device registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `spi_device.sv`, `spi_readcmd.sv`, `spi_passthrough.sv`, `spi_tpm.sv`, `spid_dpram.sv`, `spid_readsram.sv`, `spid_readbuffer.sv`, `spid_status.sv`, `spid_upload.sv`, `spid_addr_4b.sv`, `spid_csb_sync.sv` and `spi_device_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_onehot_enc`, `prim_slicer`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `spi_device.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The buffers share one dual-port RAM instantiated through `prim_ram_2p_async_adv` in `spid_dpram.sv`, fixed at 1024 entries of 32 bits.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output except `cio_sd_o` and `passthrough_o`, which carry SPI-domain data that is legitimately undefined outside a transaction. Upstream takes the same view, checking `cio_sd_en_o` instead and asserting that the block does not drive the pads while both chip selects are inactive.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `spi_device.core` and in the top. Width, unused signal and unoptimisable-flat warnings in `spi_device_pkg.sv`, `spi_tpm.sv`, `spid_status.sv` and `spi_readcmd.sv` [are waived][lint waivers].

### D2

*Checklist to be defined — see [stages.md][design stages].*

### D3

*Checklist to be defined — see [stages.md][design stages].*

## Verification sign-offs

### V1

*Not yet started — see [stages.md][verification stages].*

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/spi_device/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 signoff]: https://github.com/lowRISC/opentitan/pull/898
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/vendor/lowrisc_ip/ip/spi_device/doc/registers.md
[output asserts]: ../../hw/vendor/lowrisc_ip/ip/spi_device/rtl/spi_device.sv#L1958-L1980
[ot checklist]: ../../hw/vendor/lowrisc_ip/ip/spi_device/doc/checklist.md
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt
[patch]: ../../hw/vendor/patches/lowrisc_ip/spi_device
