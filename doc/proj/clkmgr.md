# Clock manager

This checklist covers the [design and verification sign-off][stages] for the Clock manager block.

The Clock manager is generated with `ipgen` from the OpenTitan `clkmgr` IP template, vendored at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
The Clock manager turns the chip's source clocks into the clock tree the rest of the design runs on, and reports clock status back to the power manager.
It supports:
* free-running powerup clocks for each source clock
* root clock gating per clock group, sequenced with the power manager
* a software-gated peripheral clock and a hint-based transactional clock
* clock gating indications for the alert handler and a jitter enable output
* frequency measurement of each source clock against the always-on clock, with recoverable measurement and timeout errors

Mocha instantiates the block in [`top_chip_system.sv`][instantiation], connected to the peripheral fabric over TileLink-UL through `xbar_peri`.
The Mocha configuration in [mocha_clkmgr.ipconfig.hjson][] declares `main`, `io` and `aon` source clocks, no derived clocks, one software-gated clock (`clk_io_peri`) and one hint clock (`clk_main_hint`).
At the top level all three source clocks are driven by the same chip clock, and `idle_i`, `jitter_en_o`, `cg_en_o`, `clk_io_peri` and `clk_main_hint` are tied off or unused, so the hint clock never gates off in the chip.
The configuration sets `ext_clk_bypass` to false: there is no external clock bypass or calibration-ready input, and `calib_rdy` is tied to `MuBi4False`, which clears any measurement enable software writes.

## Design sign-offs

### D1

The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The [Clock manager documentation][block doc] covers the theory of operation, the programmer's guide and the interfaces |
| Documentation | CSR_DEFINED                | Done   | Registers are described in [clkmgr.hjson][] and documented in [registers.md][registers] |
| RTL           | CLKRST_CONNECTED           | Done   | Checked in `clkmgr.sv`, `clkmgr_root_ctrl.sv`, `clkmgr_trans.sv`, `clkmgr_meas_chk.sv`, `clkmgr_clk_status.sv` and `clkmgr_reg_top.sv`; the submodules without clock and reset (`prim_buf`, `prim_subreg_ext`, `tlul_cmd_intg_chk`, `tlul_rsp_intg_gen`) are purely combinational and the clock cells `prim_clock_buf` and `prim_clock_gating` take a clock only |
| RTL           | IP_TOP                     | Done   | The top module `clkmgr` is defined in `clkmgr.sv`; `clkmgr_byp.sv` is in the file list but is not instantiated in this configuration |
| RTL           | IP_INSTANTIABLE            | Done   | Instantiated in [`top_chip_system.sv`][instantiation], which is elaborated by the Verilator model build in CI |
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | The block has no memory macros and no analogue components; the clock sources arrive as ports |
| RTL           | FUNC_IMPLEMENTED           | Done   | Root gating, software and hint clock control, clock status and the power manager handshake are implemented; frequency measurement is implemented but disabled by the Mocha configuration |
| RTL           | ASSERT_KNOWN_ADDED         | Done   | `clkmgr.sv` has known assertions on every output: `tl_o`, `alert_tx_o`, `pwr_o`, `jitter_en_o`, `cg_en_o` and `clocks_o` |
| Code Quality  | LINT_SETUP                 | Done   | `clkmgr.core` and `top_chip_system.core` each have a Verilator `lint` target with `-Wall`, and the block lints clean with no warnings in its own RTL |

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
[block doc]: ../../hw/top_chip/ip_autogen/clkmgr/README.md
[registers]: ../../hw/top_chip/ip_autogen/clkmgr/doc/registers.md
[clkmgr.hjson]: ../../hw/top_chip/ip_autogen/clkmgr/data/clkmgr.hjson
[mocha_clkmgr.ipconfig.hjson]: ../../hw/top_chip/ip_autogen/clkmgr/data/mocha_clkmgr.ipconfig.hjson
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L1075
