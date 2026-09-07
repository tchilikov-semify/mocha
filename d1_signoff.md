# D1 sign-off checklist

Tracking checklist for the per-block D1 design sign-offs, mirroring [issue #50][issue50]
and its sub-issues.
The items each block must satisfy are defined in the [D1 design sign-off checklist][D1 checklist];
the sign-off procedure is described in [stages.md][stages].

Status as of 2026-09-07: **2 of 19 blocks signed off**, 5 more drafted on the `d1_signoffs`
branch and awaiting review.
A block is only ticked below once its sign-off pull request is approved and merged.

## Blocks

- [ ] AXI crossbar — [#483][483]
- [ ] Clock manager — [#497][497], drafted: [doc/proj/clkmgr.md][clkmgr]
- [ ] CVA6-CHERI — [#485][485]
- [ ] Debug module — [#481][481]
- [ ] Entropy source — [#488][488], drafted: [doc/proj/entropy_src.md][entropy_src]
- [ ] GPIO — [#492][492], drafted: [doc/proj/gpio.md][gpio]
- [ ] I2C — [#493][493], drafted: [doc/proj/i2c.md][i2c]
- [ ] KMAC — [#489][489], drafted: [doc/proj/kmac.md][kmac]
- [ ] Mailbox — [#486][486]
- [ ] PLIC — [#490][490]
- [ ] Power manager — [#499][499]
- [ ] Reset manager — [#498][498]
- [ ] ROM control — [#487][487]
- [ ] SPI device — [#494][494]
- [ ] SPI host — [#495][495]
- [ ] SRAM — [#482][482]
- [ ] Tag controller — [#480][480]
- [x] TileLink crossbar — [#484][484], [doc/proj/xbar_peri.md][xbar_peri]
- [ ] Timer — [#491][491]
- [x] UART — [#496][496], [doc/proj/uart.md][uart]

The top chip integration has no design stage, so no D1 sign-off applies to it.

## Supporting work

- [x] Document the development stages and sign-off procedure — [#479][479], [doc/proj/stages.md][stages]

## D1 items per block

| Type          | Item                       |
|---------------|----------------------------|
| Documentation | SPEC_COMPLETED             |
| Documentation | CSR_DEFINED                |
| RTL           | CLKRST_CONNECTED           |
| RTL           | IP_TOP                     |
| RTL           | IP_INSTANTIABLE            |
| RTL           | PHYSICAL_MACROS_DEFINED_80 |
| RTL           | FUNC_IMPLEMENTED           |
| RTL           | ASSERT_KNOWN_ADDED         |
| Code Quality  | LINT_SETUP                 |

To sign a block off, open a pull request adding `doc/proj/BLOCK.md` from the
[checklist template][template], get three approvals (ideally one from someone not involved in the
block's design or verification), and update the status table in [stages.md][stages].

[issue50]: https://github.com/lowRISC/mocha/issues/50
[479]: https://github.com/lowRISC/mocha/issues/479
[480]: https://github.com/lowRISC/mocha/issues/480
[481]: https://github.com/lowRISC/mocha/issues/481
[482]: https://github.com/lowRISC/mocha/issues/482
[483]: https://github.com/lowRISC/mocha/issues/483
[484]: https://github.com/lowRISC/mocha/issues/484
[485]: https://github.com/lowRISC/mocha/issues/485
[486]: https://github.com/lowRISC/mocha/issues/486
[487]: https://github.com/lowRISC/mocha/issues/487
[488]: https://github.com/lowRISC/mocha/issues/488
[489]: https://github.com/lowRISC/mocha/issues/489
[490]: https://github.com/lowRISC/mocha/issues/490
[491]: https://github.com/lowRISC/mocha/issues/491
[492]: https://github.com/lowRISC/mocha/issues/492
[493]: https://github.com/lowRISC/mocha/issues/493
[494]: https://github.com/lowRISC/mocha/issues/494
[495]: https://github.com/lowRISC/mocha/issues/495
[496]: https://github.com/lowRISC/mocha/issues/496
[497]: https://github.com/lowRISC/mocha/issues/497
[498]: https://github.com/lowRISC/mocha/issues/498
[499]: https://github.com/lowRISC/mocha/issues/499
[stages]: doc/proj/stages.md
[D1 checklist]: doc/proj/stages.md#d1-design-sign-off-checklist
[template]: doc/proj/checklist_template.md
[uart]: doc/proj/uart.md
[xbar_peri]: doc/proj/xbar_peri.md
[clkmgr]: doc/proj/clkmgr.md
[entropy_src]: doc/proj/entropy_src.md
[gpio]: doc/proj/gpio.md
[i2c]: doc/proj/i2c.md
[kmac]: doc/proj/kmac.md
