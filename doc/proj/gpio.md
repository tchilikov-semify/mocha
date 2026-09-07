# GPIO

This checklist covers the [design and verification sign-off][stages] for the GPIO block.

The GPIO block is generated with `ipgen` from the OpenTitan `gpio` IP template, vendored at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
The GPIO gives software access to the chip's general purpose input and output pins.
It supports:
* 32 bidirectional GPIO pins with per-pin output enable
* direct-write and masked output updates
* a per-pin configurable interrupt on rising edge, falling edge or high/low level
* an optional input noise filter per pin
* optional hardware strap sampling and input period counters

Mocha instantiates the block in [`top_chip_system.sv`][instantiation], connected to the peripheral fabric over TileLink-UL through `xbar_peri`, with `GpioAsyncOn` set so the inputs are synchronised, since the pins may cross clock domains.
The Mocha configuration in [mocha_gpio.ipconfig.hjson][] declares no input period counters, and hardware strap sampling is disabled at the instantiation because the chip is only an SoC subsystem, so `sampled_straps_o` is unused.
Mocha applies one patch, [0001_fix_paths_and_tool.patch][], which adjusts the testplan and simulation config templates and the default simulator; no RTL is modified.

## Design sign-offs

### D1

The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The [GPIO documentation][block doc] covers the theory of operation, the programmer's guide and the interfaces |
| Documentation | CSR_DEFINED                | Done   | Registers are described in [gpio.hjson][] and documented in [registers.md][registers] |
| RTL           | CLKRST_CONNECTED           | Done   | Checked in `gpio.sv` and `gpio_reg_top.sv`; the submodules without clock and reset (`prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk`, `tlul_rsp_intg_gen`) are purely combinational |
| RTL           | IP_TOP                     | Done   | The top module `gpio` is defined in `gpio.sv` |
| RTL           | IP_INSTANTIABLE            | Done   | Instantiated in [`top_chip_system.sv`][instantiation], which is elaborated by the Verilator model build in CI |
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | The block has no memory macros and no analogue components |
| RTL           | FUNC_IMPLEMENTED           | Done   | Input, output, masked update, filtering and interrupt generation are implemented |
| RTL           | ASSERT_KNOWN_ADDED         | Waived | `gpio.sv` has known assertions on `intr_gpio_o`, `cio_gpio_o`, `cio_gpio_en_o`, `alert_tx_o` and `racl_error_o`; `tl_o` and the unused `sampled_straps_o` have none. The block is generated unmodified from the OpenTitan template, where this item is signed off |
| Code Quality  | LINT_SETUP                 | Done   | `gpio.core` and `top_chip_system.core` each have a Verilator `lint` target with `-Wall`, and the block lints clean with no warnings in its own RTL |

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
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3

<!-- Stages and checklists -->
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[D1 checklist]: stages.md#d1-design-sign-off-checklist

<!-- Commit anchors -->
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345

<!-- Local file references -->
[block doc]: ../../hw/top_chip/ip_autogen/gpio/README.md
[registers]: ../../hw/top_chip/ip_autogen/gpio/doc/registers.md
[gpio.hjson]: ../../hw/top_chip/ip_autogen/gpio/data/gpio.hjson
[mocha_gpio.ipconfig.hjson]: ../../hw/top_chip/ip_autogen/gpio/data/mocha_gpio.ipconfig.hjson
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L779
[0001_fix_paths_and_tool.patch]: ../../hw/vendor/patches/lowrisc_ip/gpio/0001_fix_paths_and_tool.patch
