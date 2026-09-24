# Tag Controller

The tag controller in Mocha is imported from Capabilities Limited's tag controller [repository][axi_cheri_tagcontroller] at revision [`173646d`][tagctrl hash].
The documentation for the hardware IP block is provided as part of the upstream repository under [`/docs/tag_controller.adoc`][tagctrl_doc].
A newer HPDCache-based version of the tag controller with a hierarchical tag table is available and will be integrated in mocha in an upcoming release.

The rest of this document contains the design checklist for the Tag Controller hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

This sign-off is based on commit [`316ca66`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The documentation and specifications of the tag controller is available in the tag controller repository under [`/docs/tag_controller.adoc`][tagctrl_doc]. It mentions the overall expected behaviour of the tag controller and describes a more recent [HPDCache](https://github.com/Capabilities-Limited/cv-hpdcache)-based version with support for advanced configuration and hierarchical tag table. The document postdates the vendored revision, so the behavioural description is the part that applies here; the advanced configuration and hierarchical tag table belong to the newer version and are out of scope for this sign-off.
| Documentation | CSR_DEFINED                | Done   | The documentation has a [Programmer’s Model & Software Interface][tag_ctrl_doc_progmod] section describing the memory mapped configuration interface of the recent tag controller. That section postdates the vendored revision; the registers as built come from `axi_llc_reg_top` instantiated in `axi_tagctrl_reg_wrap.sv`, which provides the `cfg_spm` and `cfg_flush` register pairs. The two are to be reconciled when the newer tag controller is integrated.
| RTL           | CLKRST_CONNECTED           | Done   | The clock and reset are driven into the toplevel from [`top_chip_system.sv`][instantiation]. Modules containing submodules checked: `axi_tagctrl_reg_wrap.sv`, `axi_tagctrl_top.sv`, `axi_tagctrl_config.sv`, `axi_tagctrl_r.sv`, `axi_tagctrl_w.sv`, `axi_tagc_read_unit.sv`, `axi_tagc_write_unit.sv`, `axi_tagctrl_data_way.sv`, `axi_tagctrl_ways.sv`, `axi_llc_tag_store.sv`, `eviction_refill/axi_llc_r_master.sv`, `axi_llc_hit_miss.sv`, `axi_llc_evict_unit.sv`, `axi_llc_refill_unit.sv` and `axi_llc_merge_unit.sv`. `axi_tagctrl_ax.sv` takes a clock and reset and instantiates nothing further. Modules without clocks and resets are confirmed to be purely combinational: `axi_id_prepend`, `lzc`, `onehot_to_bin`, `prim_subreg_arb`, `stream_demux` and `sub_per_hash`.
| RTL           | IP_TOP                     | Done   | The tag controller's toplevel module is defined in [`/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv`](/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv)
| RTL           | IP_INSTANTIABLE            | Done   | The tag controller's toplevel module is instantiated in [`/hw/top_chip/rtl/top_chip_system.sv`](/hw/top_chip/rtl/top_chip_system.sv).
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The macros as instantiated are all `prim_ram_1p`, fixed by the `SetAssociativity` of 8, `NumLines` of 128 and `NumBlocks` of 4 at the top: eight data macros of 512 entries by 64 bits in `axi_tagctrl_data_way.sv`, and eight tag macros of 128 entries by 54 bits in `axi_llc_tag_store.sv`, totalling 32 KiB of data and 6.75 KiB of tag storage. The new hierarchical tag controller is expected to be 6 KiB instead (4 KiB leaf cache, 2 KiB directory/root cache); any synthesis flow run after it is integrated must substitute those sizes to get an accurate area.
| RTL           | FUNC_IMPLEMENTED           | Done   | The tag controller's functionality is implemented. Tagged requests can be served, and the tag controller can effectively bridge between a tag aware memory subsystem and a tag unaware one. The tag controller was successfully used in booting the cheriBSD capability operating system. Planned improvements exist, specifically in the recent HPDCache-based version of the tag controller.
| RTL           | ASSERT_KNOWN_ADDED         | DONE   | Assertion that the output of the toplevel module are know were added to [`/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv`](/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv).
| Code Quality  | LINT_SETUP                 | DONE   | Verilator warning waivers are added to [`/hw/top_chip/lint/top_chip_system.vlt`](/hw/top_chip/lint/top_chip_system.vlt#L150) tag controller and the PULP LLC. The Lint setup will need updating before D2 which is tracked in [this issue](https://github.com/lowRISC/mocha/issues/742).

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

[axi_cheri_tagcontroller]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller
[d1-commit]: https://github.com/lowRISC/mocha/commit/316ca6649e51d17c5968986e6f2dd7b503cae5c0
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L1301-L1302
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[tagctrl hash]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/tree/173646d5947d09bcb27f6ae3817ae7f6d3c1f6a9
[tagctrl_doc]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/blob/ea82870f2619bd092d4f7b52ef66513f67fa8e35/docs/tag_controller.adoc
[tag_ctrl_doc_progmod]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/blob/ea82870f2619bd092d4f7b52ef66513f67fa8e35/docs/tag_controller.adoc#5-programmers-model--software-interface
