# Reset manager

This checklist covers the [design and verification sign-off][stages] for the Reset manager block.

The Reset manager block is generated with `ipgen` from the OpenTitan `rstmgr` IP template, vendored at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
The Reset manager owns every derived reset in the chip and records why the last reset happened.
It supports:
* stretching of the incoming power-on reset, and cascaded system resets
* peripheral and RISC-V non-debug-module reset requests
* limited, selective software-controlled module reset
* always-on reset information, alert crash dump and CPU crash dump registers
* reset consistency checks

Mocha instantiates the block in [`top_chip_system.sv`][instantiation], connected to the peripheral fabric over TileLink-UL through `xbar_peri`.
The Mocha configuration in [mocha_rstmgr.ipconfig.hjson][] adds an always-on reset and a debug reset domain for `rv_dm` on top of the upstream domains, and declares software-controlled resets for the SPI device, SPI host and I2C blocks.

The block-level DV is generated from the same OpenTitan template.
The DV environment reuses the CIP-based UVM infrastructure from OpenTitan.
Mocha applies three patches ([0001_Fix_Paths_And_Tools.patch][], [0002_Fix_Templates.patch][], [0003_Cascade_Assertion_Fix.patch][]) to adjust file and tool paths, fix the interface, sequence and testbench templates, and correct the cascading reset assertions; no RTL logic is modified.

## Design sign-offs

### D1

*Not yet started — see [stages.md][design stages].*

### D2

*Checklist to be defined — see [stages.md][design stages].*

### D3

*Checklist to be defined — see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`32818cb`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [Reset manager DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [Reset manager testplan][] defines the V1 smoke test and post-V1 reset, crash dump capture, software reset and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates the four clocks, TileLink, alert and reset manager interfaces along with the reset manager DUT; <br/> the block has no interrupts |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [rstmgr_bind.sv][] binds the TLUL protocol, CSR and reset cascading assertions; the reset manager RTL checks that <br/> outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | Generated from the OpenTitan template, where the block reached V2S ([OpenTitan reset manager checklist][]); <br/> `rstmgr_cnsty_chk` has its own DV environment, not yet in the Mocha config |
| Review        | DESIGN_SPEC_REVIEWED               | Waived | The specification was reviewed through the OpenTitan sign-off process; the extra debug and always-on reset <br/> domains have not had a separate review |
| Review        | TESTPLAN_REVIEWED                  | Done   | The generated [OpenTitan reset manager checklist][] records the testplan review as complete |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Reset race, stress, and the debug and low-power reset paths are covered in the [Reset manager testplan][]; <br/> error injection and leaf reset checks sit in the sec_cm testplan, which is out of scope for Mocha; performance is N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL agent and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `rstmgr_smoke`: 1/1 passed with Xcelium on August 27, 2026 at commit `32818cb` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `rstmgr_sim_cfg.hjson` selects `rstmgr_smoke`; the aggregate Mocha config imports the reset <br/> manager simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | The Reset manager is included in `mocha_sim_cfgs.hjson`, so it runs as part of the aggregate nightly regression |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `rstmgr_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No Reset manager FPV regression is configured in Mocha |

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

<!-- External references -->
[OpenTitan reset manager checklist]: ../../hw/top_chip/ip_autogen/rstmgr/doc/checklist.md
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3

<!-- Stages and checklists -->
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[V1 checklist]: stages.md#v1-verification-sign-off-checklist

<!-- Commit anchors -->
<!-- Replace the d1-commit hash once Reset manager D1 sign-off happens. -->
[d1-commit]: https://github.com/lowRISC/mocha/commit/1234def
[v1-commit]: https://github.com/lowRISC/mocha/commit/32818cb34909922f6aca375d61758ae63aa3e7da

<!-- Local file references -->
[block doc]: ../../hw/top_chip/ip_autogen/rstmgr/README.md
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L1158
[mocha_rstmgr.ipconfig.hjson]: ../../hw/top_chip/ip_autogen/rstmgr/data/mocha_rstmgr.ipconfig.hjson
[Reset manager DV document]: ../../hw/top_chip/ip_autogen/rstmgr/dv/README.md
[Reset manager testplan]: ../../hw/top_chip/ip_autogen/rstmgr/data/rstmgr_testplan.hjson
[tb.sv]: ../../hw/top_chip/ip_autogen/rstmgr/dv/tb.sv
[rstmgr_bind.sv]: ../../hw/top_chip/ip_autogen/rstmgr/dv/sva/rstmgr_bind.sv
[0001_Fix_Paths_And_Tools.patch]: ../../hw/vendor/patches/lowrisc_ip/rstmgr/0001_Fix_Paths_And_Tools.patch
[0002_Fix_Templates.patch]: ../../hw/vendor/patches/lowrisc_ip/rstmgr/0002_Fix_Templates.patch
[0003_Cascade_Assertion_Fix.patch]: ../../hw/vendor/patches/lowrisc_ip/rstmgr/0003_Cascade_Assertion_Fix.patch
