# I2C

This checklist covers the [design and verification sign-off][stages] for the I2C block.

The I2C block is imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
The I2C block can be programmed in both controller and target modes.
It supports:
* standard, fast, and fast-plus speed modes
* 7-bit target address
* all the mandatory features listed for controllers in [Table 2: I2C specification Rev 6][]
* multi-controller features such as bus arbitration and controller-controller clock synchronization
* clock stretching in both controller and target modes

Mocha instantiates the block in [`top_chip_system.sv`][instantiation], connected to the peripheral fabric over TileLink-UL through `xbar_peri`, with the SCL and SDA lines brought out to the chip boundary.
`InputDelayCycles` is zero and the RAM configuration ports are left at their defaults.
Mocha applies one patch, [0001-Fix-Paths-and-Tool.patch][], which adjusts the testplan and simulation config paths and the default simulator; no RTL is modified.

## Design sign-offs

### D1

The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The [I2C documentation][block doc] covers the theory of operation, the programmer's guide and the interfaces |
| Documentation | CSR_DEFINED                | Done   | Registers are described in [i2c.hjson][] and documented in [registers.md][registers] |
| RTL           | CLKRST_CONNECTED           | Done   | Checked in `i2c.sv`, `i2c_core.sv`, `i2c_fifos.sv`, `i2c_fifo_sync_sram_adapter.sv` and `i2c_reg_top.sv`; the submodules without clock and reset (`prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk`, `tlul_rsp_intg_gen`) are purely combinational |
| RTL           | IP_TOP                     | Done   | The top module `i2c` is defined in `i2c.sv` |
| RTL           | IP_INSTANTIABLE            | Done   | Instantiated in [`top_chip_system.sv`][instantiation], which is elaborated by the Verilator model build in CI |
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The four FIFOs share one single-port RAM instantiated through `prim_ram_1p_adv` in `i2c_fifos.sv`, fixed at 464 entries of 13 bits with no ECC or parity |
| RTL           | FUNC_IMPLEMENTED           | Done   | Controller and target mode, the bus monitor and the FIFO subsystem are implemented |
| RTL           | ASSERT_KNOWN_ADDED         | Waived | `i2c.sv` has known assertions on every output except `ram_cfg_rsp_o`, which is unused in Mocha. The block is vendored unmodified from OpenTitan, where this item is signed off |
| Code Quality  | LINT_SETUP                 | Done   | `i2c.core` and `top_chip_system.core` each have a Verilator `lint` target with `-Wall`, and the block lints clean with no warnings in its own RTL |

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

<!-- External references -->
[Table 2: I2C specification Rev 6]: https://assets.nexperia.com/documents/user-manual/UM10204.pdf
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3

<!-- Stages and checklists -->
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[D1 checklist]: stages.md#d1-design-sign-off-checklist

<!-- Commit anchors -->
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345

<!-- Local file references -->
[block doc]: ../../hw/vendor/lowrisc_ip/ip/i2c/README.md
[registers]: ../../hw/vendor/lowrisc_ip/ip/i2c/doc/registers.md
[i2c.hjson]: ../../hw/vendor/lowrisc_ip/ip/i2c/data/i2c.hjson
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L844
[0001-Fix-Paths-and-Tool.patch]: ../../hw/vendor/patches/lowrisc_ip/i2c/0001-Fix-Paths-and-Tool.patch
