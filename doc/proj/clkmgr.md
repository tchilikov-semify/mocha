# Clock manager

The Clock manager in Mocha is generated with `ipgen` from the OpenTitan `clkmgr` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [register mapping][registers], and block [README][block doc].
The README is currently a stub; the theory of operation is still the OpenTitan EarlGray configuration.
Both will be updated for Mocha as part of [issue #709][block doc issue].
The register mapping documentation is currently an empty stub but it will be generated once `cmdgen` is imported, as part of [issue #706][cmdgen].
The [Mocha configuration][ipconfig] declares `main`, `io` and `aon` source clocks, no derived clocks, one software-gated clock and one hint clock.
At the top all three source clocks are driven by the same chip clock, and the idle hint, jitter enable and clock gating indications are tied off or unused.
`ext_clk_bypass` is false, so there is no external clock bypass or calibration-ready input and `calib_rdy` is tied to `MuBi4False`, which clears any measurement enable software writes.

The rest of this document contains the design checklist for the Clock manager hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Clock manager used for D1 sign-off is generated from the OpenTitan template at revision [bf4a2b2][OpenTitan hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [b597321][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Waived | [Theory of operation][theory] and [programmer's guide][pguide]. The README is a stub and the theory of operation still describes the OpenTitan configuration; both are tracked by [issue #709][block doc issue].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [clkmgr.hjson][csrs] and generated into `clkmgr_reg_pkg.sv` and `clkmgr_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `clkmgr.sv`, `clkmgr_root_ctrl.sv`, `clkmgr_trans.sv`, `clkmgr_meas_chk.sv`, `clkmgr_clk_status.sv` and `clkmgr_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The clock cells `prim_clock_buf` and `prim_clock_gating` take a clock and no reset.
| RTL           | IP_TOP                     | Done   | This module is defined in `clkmgr.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | No memory macros or analogue components. The clock sources arrive as ports.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented. Frequency measurement is disabled by the Mocha configuration.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `clkmgr.core` and in the top. The block lints clean with no warnings in its own RTL.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`4c320ef`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [Clock manager DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [Clock manager testplan][] defines the V1 smoke test and post-V1 peripheral and transactional clock enable, clock status, jitter, register lock and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates the register, `main`, `io` and `aon` clocks and resets, the root clock resets, the shadowed reset, TileLink, power manager handshake, idle, scan mode and alert interfaces along with the Clock manager DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [clkmgr_bind.sv][] binds the TLUL protocol, CSR, power manager handshake, gated clock, transactional clock and clock gating indication assertions; the Clock manager RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The Clock manager and its primitive submodules (`prim_clock_gating`, `prim_subreg_shadow`, etc.) and TileLink adapters (`tlul_adapter_reg`, `tlul_cmd_intg_chk`, etc.) are generated from the OpenTitan template, where the block reached V2S; the [OpenTitan clock manager checklist][] records this item as N/A |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The specification was reviewed through the OpenTitan sign-off process, and the [theory of operation][theory] was reviewed against the Mocha instantiation for this sign-off. It describes the clock groups, software and hint gating and the power manager handshake correctly, but it is written for the OpenTitan EarlGrey configuration ([issue #709][block doc issue]): Mocha has one hint clock, no derived clocks and no external clock bypass, so frequency measurement is disabled, the idle hint and scan mode inputs are tied off, and `alert_tx_o` and `jitter_en_o` are left unconnected at the [instantiation][instantiation] |
| Review        | TESTPLAN_REVIEWED                  | Done   | The generated [OpenTitan clock manager checklist][] records the testplan review as complete upstream. The V1 testpoints of the [Clock manager testplan][], `smoke` plus the imported CSR testpoints, apply as written; the [vendor patches][patch] drop the frequency measurement testpoints that the Mocha configuration disables. The testbench drives `main`, `io` and `aon` at the frequencies in the [Mocha configuration][ipconfig], while the top drives all three from the same clock |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Clock gating, register lock and stress tests are covered in the [Clock manager testplan][]; security countermeasures are captured in the sec_cm testplan, but V2S is not used in Mocha; debug, power and performance are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL agent and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | All V1 testpoints (`clkmgr_smoke` and the five CSR tests): 30/30 passed, 5 seeds each, with Xcelium on November 19, 2026 at commit `4c320ef` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `clkmgr_sim_cfg.hjson` selects `clkmgr_smoke`; the aggregate Mocha config imports the Clock manager simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | The Clock manager is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `clkmgr_env_cov.sv`, with the idle input covered by `clkmgr_cov_bind.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No Clock manager FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/top_chip/ip_autogen/clkmgr/README.md
[stages]: stages.md
[block doc issue]: https://github.com/lowRISC/mocha/issues/709
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/top_chip/ip_autogen/clkmgr/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/clkmgr/data/clkmgr.hjson
[theory]: ../../hw/top_chip/ip_autogen/clkmgr/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/clkmgr/doc/programmers_guide.md
[ipconfig]: ../../hw/top_chip/ip_autogen/clkmgr/data/mocha_clkmgr.ipconfig.hjson
[output asserts]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/top_chip/ip_autogen/clkmgr/rtl/clkmgr.sv#L483-L490
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/4c320ef82c8e3f46acc69f069dc7c22f9c34d301
[instantiation]: https://github.com/lowRISC/mocha/blob/4c320ef82c8e3f46acc69f069dc7c22f9c34d301/hw/top_chip/rtl/top_chip_system.sv#L1075-L1108
[patch]: ../../hw/vendor/patches/lowrisc_ip/clkmgr
[Clock manager DV document]: ../../hw/top_chip/ip_autogen/clkmgr/dv/README.md
[Clock manager testplan]: ../../hw/top_chip/ip_autogen/clkmgr/data/clkmgr_testplan.hjson
[tb.sv]: ../../hw/top_chip/ip_autogen/clkmgr/dv/tb.sv
[clkmgr_bind.sv]: ../../hw/top_chip/ip_autogen/clkmgr/dv/sva/clkmgr_bind.sv
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
[OpenTitan clock manager checklist]: ../../hw/top_chip/ip_autogen/clkmgr/doc/checklist.md
