# Entropy source

This checklist covers the [design and verification sign-off][stages] for the Entropy source block.

The Entropy source block is imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
The Entropy source collects bits from an external physical noise source, health tests them, conditions them and makes them available to software.
It supports:
* a configurable noise source bus width, with the noise source driven from outside the block
* the SP 800-90B repetition count and adaptive proportion health tests, plus bucket and Markov tests
* firmware-defined and vendor-defined health tests
* SHA-3 conditioning and a boot-time bypass path
* a hardware entropy interface, an observe FIFO for firmware, and interrupts for entropy available, health test failure, observe FIFO ready and fatal error

Mocha instantiates the block in [`top_chip_system.sv`][instantiation], connected to the peripheral fabric over TileLink-UL through `xbar_peri`.
The noise source interface is brought out to the chip boundary, the OTP firmware read and override controls are tied true, and the hardware entropy and external health test interfaces are unused, so entropy is consumed by firmware over TileLink.
Mocha applies two patches: [0001_Remove_OTP_Control_Dependency.patch][] drops the `otp_ctrl_pkg` dependency from the core file, and [0002_Fix_DV_Paths.patch][] adjusts the testplan and simulation config paths. No RTL is modified.

## Design sign-offs

### D1

The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The [Entropy source documentation][block doc] covers the theory of operation, the programmer's guide and the interfaces |
| Documentation | CSR_DEFINED                | Done   | Registers are described in [entropy_src.hjson][] and documented in [registers.md][registers] |
| RTL           | CLKRST_CONNECTED           | Done   | Checked in `entropy_src.sv`, `entropy_src_core.sv`, `entropy_src_reg_top.sv`, `entropy_src_cntr_reg.sv`, `entropy_src_ack_sm.sv` and the health test modules; the submodules without clock and reset (`prim_buf`, `prim_subreg_ext`, `tlul_cmd_intg_chk`, `tlul_rsp_intg_gen`) are purely combinational |
| RTL           | IP_TOP                     | Done   | The top module `entropy_src` is defined in `entropy_src.sv` |
| RTL           | IP_INSTANTIABLE            | Done   | Instantiated in [`top_chip_system.sv`][instantiation], which is elaborated by the Verilator model build in CI |
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | The block has no memory macros and no analogue components; the FIFOs are flop-based and the noise source is external |
| RTL           | FUNC_IMPLEMENTED           | Done   | The full collect, health test, condition and distribute path is implemented, as is the register read path used by Mocha |
| RTL           | ASSERT_KNOWN_ADDED         | Waived | `entropy_src.sv` has known assertions on the TileLink, alert, hardware entropy and external health test outputs; `rng_fips_o`, `entropy_src_xht_bit_sel_o`, `entropy_src_xht_health_test_window_o` and `intr_es_observe_fifo_ready_o` have none. The block is vendored unmodified from OpenTitan, where this item is signed off |
| Code Quality  | LINT_SETUP                 | Done   | `entropy_src.core` and `top_chip_system.core` each have a Verilator `lint` target with `-Wall`, and the only warnings in the block are the `rng_bit_sel` width expansions in the health test modules and the core, waived in [top_chip_system.vlt][] |

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
[block doc]: ../../hw/vendor/lowrisc_ip/ip/entropy_src/README.md
[registers]: ../../hw/vendor/lowrisc_ip/ip/entropy_src/doc/registers.md
[entropy_src.hjson]: ../../hw/vendor/lowrisc_ip/ip/entropy_src/data/entropy_src.hjson
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L1019
[top_chip_system.vlt]: ../../hw/top_chip/lint/top_chip_system.vlt
[0001_Remove_OTP_Control_Dependency.patch]: ../../hw/vendor/patches/lowrisc_ip/entropy_src/0001_Remove_OTP_Control_Dependency.patch
[0002_Fix_DV_Paths.patch]: ../../hw/vendor/patches/lowrisc_ip/entropy_src/0002_Fix_DV_Paths.patch
