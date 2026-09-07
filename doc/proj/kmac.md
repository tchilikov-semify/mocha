# KMAC

This checklist covers the [design and verification sign-off][stages] for the KMAC block.

The KMAC block is imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
KMAC computes SHA-3, SHAKE, cSHAKE and KMAC digests for software and for other hardware blocks.
It supports:
* SHA3-224, 256, 384 and 512, SHAKE-128 and 256, and cSHAKE-128 and 256
* KMAC with secret key lengths from 128 to 512 bits, byte-granular messages and arbitrary output lengths
* a message FIFO and a software register interface, plus a set of hardware application interfaces
* first-order domain-oriented masking of the Keccak core, which can be disabled at compile time
* an EDN interface for reseeding the masking entropy and a key manager sideload interface

Mocha instantiates the block in [`top_chip_system.sv`][instantiation] only to check the ROM contents at boot: masking is disabled, and the TileLink, key manager, EDN, life cycle and interrupt interfaces are tied off or unused.
It is configured with three application interfaces, which is what the RTL expects, and only the first one is driven, by the ROM controller; the other two are tied to their defaults.
Mocha applies [0001-Remove-keymgr-edn-deps.patch][], which drops the `keymgr_pkg` and `edn_pkg` dependencies by declaring the sideload key and EDN types in `kmac_pkg` instead; the logic is unchanged.
The remaining patches ([0002-Fix-DV-Paths.patch][], [0003-kmac-dv-env-fixes.patch][] and [0004-Guard-masked-entropy-asserts.patch][]) only touch the DV environment and its configuration.

## Design sign-offs

### D1

The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The [KMAC documentation][block doc] covers the theory of operation, the programmer's guide and the interfaces |
| Documentation | CSR_DEFINED                | Done   | Registers are described in [kmac.hjson][] and documented in [registers.md][registers]; the register interface is not connected in Mocha |
| RTL           | CLKRST_CONNECTED           | Done   | Checked in `kmac.sv`, `kmac_core.sv`, `kmac_app.sv`, `kmac_entropy.sv`, `kmac_msgfifo.sv`, `kmac_staterd.sv`, `kmac_reg_top.sv` and the `sha3` modules; the submodules without clock and reset (`prim_sec_anchor_buf`, `prim_slicer`, `prim_subreg_ext`, `tlul_cmd_intg_chk`, `tlul_rsp_intg_gen`) are purely combinational |
| RTL           | IP_TOP                     | Done   | The top module `kmac` is defined in `kmac.sv`; `kmac_reduced.sv` is a separate synthesis top and is not part of the KMAC file list |
| RTL           | IP_INSTANTIABLE            | Done   | Instantiated in [`top_chip_system.sv`][instantiation], which is elaborated by the Verilator model build in CI |
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | The block has no memory macros and no analogue components; the message FIFO is flop-based |
| RTL           | FUNC_IMPLEMENTED           | Done   | The full Keccak, padding, message FIFO and application interface datapath is implemented; Mocha exercises only the unmasked application interface path |
| RTL           | ASSERT_KNOWN_ADDED         | Waived | `kmac.sv` has known assertions on `tl_o`, `alert_tx_o`, the interrupts and `en_masking_o`; `app_o`, `entropy_o` and `idle_o` have none. The block is vendored from OpenTitan, where this item is signed off, and the Mocha patch does not change the logic |
| Code Quality  | LINT_SETUP                 | Done   | `kmac.core` and `top_chip_system.core` each have a Verilator `lint` target with `-Wall`, and the only warnings in the block are hidden enum values and circular combinational logic, waived in [top_chip_system.vlt][]; unused clock and width warnings are waived in [kmac.vlt][] |

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
[block doc]: ../../hw/vendor/lowrisc_ip/ip/kmac/README.md
[registers]: ../../hw/vendor/lowrisc_ip/ip/kmac/doc/registers.md
[kmac.hjson]: ../../hw/vendor/lowrisc_ip/ip/kmac/data/kmac.hjson
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L1453
[top_chip_system.vlt]: ../../hw/top_chip/lint/top_chip_system.vlt
[kmac.vlt]: ../../hw/vendor/lowrisc_ip/ip/kmac/lint/kmac.vlt
[0001-Remove-keymgr-edn-deps.patch]: ../../hw/vendor/patches/lowrisc_ip/kmac/0001-Remove-keymgr-edn-deps.patch
[0002-Fix-DV-Paths.patch]: ../../hw/vendor/patches/lowrisc_ip/kmac/0002-Fix-DV-Paths.patch
[0003-kmac-dv-env-fixes.patch]: ../../hw/vendor/patches/lowrisc_ip/kmac/0003-kmac-dv-env-fixes.patch
[0004-Guard-masked-entropy-asserts.patch]: ../../hw/vendor/patches/lowrisc_ip/kmac/0004-Guard-masked-entropy-asserts.patch
