# AXI SRAM UVM environment — SystemVerilog bring-up changes

This note records every SystemVerilog (`.sv` / `.svh`) change made to get the
Xcelium UVM testbench for `axi_sram` to **compile, elaborate, run, and pass**
the `axi_sram_write_read_test` smoke test.

The fixes fall into three groups:

1. **Parse / elaborate errors** — the AXI VIP and TB had never been built with a
   UVM-capable simulator before, so several first-time compile errors surfaced.
2. **Runtime / factory errors** — issues that only appeared once the simulation
   started running the test.
3. **Functional correctness** — bugs that let the test run but produced wrong
   data, fixed so the readback matches.

Build-flow files (`axi_sram_uvm.core`, `axi_agent.core`, `Makefile`) were also
changed; those are summarised at the end but are not SV source.

---

## 1. Parse / elaboration fixes (AXI VIP — `hw/ip/dv/axi_agent/`)

### `axi_agent_cfg.svh`
- **Added a constructor** `function new(string name = "axi_agent_cfg")`.
  Without it, the `` `uvm_object_utils(axi_agent_cfg) `` expansion failed with a
  preprocessor `TOOMAC` ("too many actual arguments") error. A `uvm_object`
  registered with the factory needs a `new` that the macro can reference.

### `axi_reset_monitor_aw.svh`, `_w.svh`, `_b.svh`, `_ar.svh`, `_r.svh` (5 files)
- **Uncommented the `set_vif()` implementation** in each monitor.
  Each class declares `extern function void set_vif(...)` but the body was
  commented out, giving `PMBNOB` ("implementation body was not found for the
  indicated prototype") at elaboration, plus a cascade at every call site in
  `axi_mgr_agent.svh`.

### `seq_lib/axi_mgr_write_fixed_vseq.svh`
- **Fixed the base-class specialization**:
  `extends uvm_sequence(uvm_sequence_item, axi_fixed_write_rsp_item)` →
  `extends uvm_sequence #(uvm_sequence_item, axi_fixed_write_rsp_item)`
  (missing `#`, which made the parser treat the type args as an expression —
  `TDNOTR`).
- **Fixed the response type handling** to match the already-correct
  `axi_mgr_read_fixed_vseq.svh`: added a local `uvm_sequence_item
  write_response_item;`, pass it to `wait_for_response()` (whose `output` is
  `uvm_sequence_item`), then `$cast` it down to `axi_write_response_item`.
  Previously the `axi_write_response_item` variable was passed directly to a
  `uvm_sequence_item` output → `TYCMPAT`.

### `axi_fixed_read_req_item.svh`, `axi_fixed_write_req_item.svh`, `axi_fixed_read_rsp_item.svh`, `axi_fixed_write_rsp_item.svh` (4 files)
- **Added `` `uvm_object_utils(<class>) ``** to each.
  These classes were not registered with the factory, so
  `<class>::type_id::create(...)` resolved to the base `uvm_sequence_item`
  registry and returned a `uvm_sequence_item` handle — assigning it to the
  concrete type failed elaboration (`TYCMPAT`).

---

## 2. Runtime / factory fixes

### `axi_sram_uvm_tb.sv`  (`hw/top_chip/dv/axi_sram/`)
- **Imported the test package**: added `import axi_sram_test_pkg::*;` to the TB
  top module. Without it the package was never pulled into elaboration, so the
  tests never registered with the UVM factory and
  `+UVM_TESTNAME=axi_sram_write_read_test` failed with
  `BDTYP` / `INVTST` ("test not found"). (This also required listing
  `axi_sram_test_pkg.sv` before `axi_sram_uvm_tb.sv` in the core file.)

### Driver response IDs — `axi_mgr_write_data_driver.svh`, `axi_mgr_read_data_driver.svh`, `axi_mgr_write_response_driver.svh`, `axi_mgr_read_request_driver.svh`, `axi_mgr_write_request_driver.svh` (5 files)
- **Added `<rsp>.set_id_info(req);`** before each `seq_item_port.item_done(<rsp>)`.
  The drivers returned a freshly created response item that was never linked to
  the originating `req`, so its `sequence_id` was null. The sequences retrieve
  it with `get_response()` (via `get_base_response`), which made the sequencer
  raise `UVM_FATAL [SQRPUT] Driver put a response with null sequence_id`.
  `set_id_info(req)` copies the sequence/transaction id from the request.

---

## 3. Functional correctness fixes

### `axi_sram_uvm_tb.sv` — interface width configuration order
- **Reordered the W and R channel width setup** so `set_user_data_width(1)` is
  called **before** `set_data_width(AxiDataWidth)`.
  `set_data_width()` enforces `DATA_WIDTH >= 2 * USER_DATA_WIDTH`, and
  `USER_DATA_WIDTH` defaults high (512), so calling `set_data_width(64)` first
  tripped a `UVM_ERROR` on both the W and R interfaces.

### `seq_lib/axi_mgr_write_data_seq.svh` — the key data-path bug
- **Made `randomize_item()` `virtual`**:
  `extern protected function void randomize_item(...)` →
  `extern protected virtual function void randomize_item(...)`.
  The base `body()` calls `randomize_item()` through the base handle. Because it
  was non-virtual, the override in `axi_mgr_write_single_data_seq` (which copies
  the test's payload) was **never called** — the base version randomized the
  item instead. This is why the driver saw fully random `m_data` / `m_strb` /
  `m_user`, the readback mismatched, and random byte strobes caused partial
  writes (and `DataKnown_A` assertion noise).

### `seq_lib/axi_mgr_write_single_data_seq.svh`
- **Marked the override `virtual`** as well (for clarity; implied once the base
  is virtual).

### `seq_lib/axi_mgr_write_fixed_vseq.svh` — copy ordering (belt-and-braces)
- **Moved `w_seq.m_write_data_item.copy(m_fixed_req.m_write_data_item)` to after
  `w_seq.randomize()`** so the explicit test payload is the last value written
  to `m_write_data_item` before the sequence starts, and cannot be clobbered by
  randomization. (Strictly redundant once `randomize_item` is virtual, but makes
  the intent unambiguous.)

---

## Result

- `make`        → compile + elaborate + run in one fusesoc/xrun call; exits 0
  with `Write completed with OKAY response` and
  `Read data matches written value — PASS!`, `UVM_ERROR : 0`, `UVM_FATAL : 0`.
- `make WAVES=1` → same, plus an SHM waveform dump (`waves.shm`).
- `make clean`  → removes the in-tree build directory.

### A known DUT assertion: `prim_fifo_sync DataKnown_A`
In 4-state Xcelium the tag read-modify-write path reads uninitialised tag RAM
(X), which propagates into the DUT `prim_fifo_sync` instances and trips
`DataKnown_A` (Verilator reads X as 0, so the cocotb flow never saw it). It does
not affect functional correctness, and the vplan treats power-up contents as
undefined. The vendored RTL is left untouched. The **primary** fix is the TB
memory pre-clear added for the priority-1 port (see below), which removes the X
at its source so the assertion no longer fires anywhere; the Makefile's inline
`assertion -off {…gen_reqs[0]…}` waive is kept as a safety net.

---

## Non-SV build-flow changes (for reference)

The flow is "just call fusesoc": a single `fusesoc run` compiles, elaborates and
simulates in one xrun invocation, with all artifacts in an in-tree build dir.

The UVM and cocotb/Verilator environments now live in sibling directories under
`hw/top_chip/dv/axi_sram/` — `uvm/` (this one) and `cocotb/` — each fully
self-contained with its own `.core` + `Makefile`. The two share the DUT via
`depend: lowrisc:mocha:axi_sram`, not a shared core.

- **`uvm/axi_sram_uvm.core`** (`lowrisc:mocha_dv:axi_sram_uvm`) — the entry point
  and single source of truth for xrun options. The `default` Xcelium target
  carries `-64bit -sv -uvm -uvmhome CDNS-1.2 -licqueue +define+UVM -access rwc
  -l xrun.log -nowarn ... +UVM_VERBOSITY`. It deliberately does **not** set
  `+UVM_TESTNAME` — see the priority-1 port section below. `+define+UVM` is needed
  so `dv_utils_pkg`'s `` `ifdef UVM `` guard includes `uvm_macros.svh`. The UVM
  file list is ordered so `axi_sram_test_pkg.sv` precedes `axi_sram_uvm_tb.sv`.
  The cocotb/Verilator filesets and targets were split out into
  `cocotb/axi_sram_cocotb.core` (Xcelium-only here).
- **`axi_agent.core`** — uncommented the `lowrisc:dv:dv_utils` dependency so
  `dv_utils_pkg` (which the `axi_*_if` interfaces import) is compiled first.
- **`Makefile`** — a thin wrapper: `run` (default goal) just calls `fusesoc run`,
  `clean` removes the build dir. It exports the environment Edalize's generated
  Makefile needs — the real Cadence `bin` on `PATH` so `xmroot` resolves (the nix
  dev-shell only exposes the FHS-wrapped `xrun`), plus `XRUN`/`LD_LIBRARY_PATH`.
  It also injects an inline run-control script via `XMSIM_OPTIONS`
  (`-input "@assertion -off {...}; run; exit"`) that waives the assertion above
  and, with `WAVES=1`, splices in the SHM probe commands.

---

## Priority-1 verification-plan test port

The smoke test above was extended into a port of every priority-1 item from the
verification plan (`axi_sram_vplan.csv`), mirroring the cocotb environment's
coverage. The P1 set needs **multi-beat bursts with per-beat `wuser`/`ruser`**
(2-beat CHERI capability writes/reads, N-beat data bursts), which the original
single-beat FIXED-burst VIP sequences could not drive. The work spanned the VIP,
the TB, the test package, the core and the Makefile.

### New burst-capable VIP sequences (`hw/ip/dv/axi_agent/`)
- **`seq_lib/axi_mgr_write_listed_data_seq.svh`** — extends
  `axi_mgr_write_data_seq`; sends a caller-supplied list of `axi_write_data_item`
  beats (one per beat), driving `WLAST` on the last.
- **`seq_lib/axi_mgr_write_burst_vseq.svh`** — multi-beat generalisation of
  `axi_mgr_write_fixed_vseq`: configurable AW (id/addr/size/burst/…) and one data
  item per beat (`AWLEN = nbeats-1`).
- **`seq_lib/axi_mgr_read_burst_vseq.svh`** — multi-beat generalisation of
  `axi_mgr_read_fixed_vseq`: issues one AR and collects every R beat into
  `m_read_beats` (per-beat data + `ruser`).
- Registered (in dependency order) in `axi_agent_pkg.sv` and `axi_agent.core`.

### VIP driver fixes (real AXI bugs — fixed in the VIP)
The manager-side accept drivers had two latent AXI-protocol bugs that only show
up with multi-beat bursts or back-to-back transactions; both were fixed **in the
drivers** (no test- or vseq-level workarounds). Full write-up:
[`hw/ip/dv/axi_agent/axi_driver_bugs.md`](../../../../ip/dv/axi_agent/axi_driver_bugs.md).
In short: `drive_req()` in `axi_mgr_read_data_driver.svh` and
`axi_mgr_write_response_driver.svh` used to read its own clocking *output*
(`rready`/`bready`) back to infer the handshake and sample *after* the edge,
which (a) re-sampled the same beat/response when two accepts ran back-to-back in
the same time step, and (b) lost a beat when a speculative `ready` consumed it
inside the wait loop. Both `drive_req()`s were rewritten to **track the driven
`ready` locally and sample on the exact `valid && ready` edge**, which is the
real AXI transfer condition. This is correct under any back-pressure (the
`ready_without_valid_pct` / `valid_to_ready_delay` knobs still work and are now
randomised, not pinned), and it also removes the `*W,CONOTR` illegal-rvalue
warning. With the drivers correct, `axi_mgr_write_burst_vseq` uses the standard
`axi_response_router` pattern — identical to `axi_mgr_read_burst_vseq` and the
`*_fixed_vseq` sequences — with no special-casing.

### TB (`axi_sram_uvm_tb.sv`)
- **Geometry assertions** (vplan `interface_geometry` / `sram_geometry`): an
  `initial` block asserts `AxiDataWidth==64`, the 8-bit `wstrb`, ≥1 `wuser`/
  `ruser` tag bit, and `SramMemSize==128 KiB`.
- **Memory pre-clear**: an `initial` zeroes `u_dut.u_ram.mem` and
  `u_dut.u_tag_ram.mem`. In 4-state Xcelium the tag read-modify-write reads the
  existing tag word; uninitialised X there propagates into the DUT FIFOs and
  trips `prim_fifo_sync DataKnown_A` (Verilator reads X as 0, so cocotb never saw
  it). Zeroing matches the 2-state behaviour; the vplan treats power-up contents
  as undefined. This removes the `DataKnown_A` firings at the source (the
  Makefile `assertion -off` waive is kept as a belt-and-suspenders safety net).

### Test package (`axi_sram_test_pkg.sv`)
- `axi_sram_base_test` gained reusable helpers built on the burst vseqs:
  `write_word`, `write_word_user`, `write_cap`, `write_burst_words`, `read_word`,
  `read_cap` (returns both data words and both per-flit `ruser` bits), plus
  `run_write`/`run_read` which check B/R response codes (and, when
  `m_check_resp_id` is set, that responses echo the request ID).
- One test per P1 vplan item: `axi_sram_{rst_sanity, write_read, data_all_bits,
  address_boundaries, burst_last, resp_id_match, tag_write, no_tag_single_beat,
  tag_cleared_by_write, tag_isolation, cap_ruser}_test`. (`interface_geometry`
  and `sram_geometry` are the TB assertions above.)

### Test selection moved to the Makefile
UVM honours the **first** `+UVM_TESTNAME` on the command line, and fusesoc can
only *append* options — so a `+UVM_TESTNAME` baked into the core can't be
overridden per run. The core therefore no longer sets it; the Makefile selects
the test via `make TEST=<name>` (default `axi_sram_write_read_test`), passed as
`fusesoc … --xrun_options "+UVM_TESTNAME=$(TEST)"`. All build options stay in the
core.

### Result
All 11 priority-1 tests pass under `make TEST=…`: `UVM_ERROR : 0`,
`UVM_FATAL : 0`, and no `DataKnown_A` firings.

---

## Priority-2 / priority-3 verification-plan test port

The same approach was extended to every P2 and P3 vplan item, all built on the
burst VIP and helpers above (no further VIP changes were needed). New helpers in
`axi_sram_base_test`: `write_word_strb` (partial-strobe / sub-word writes),
`write_cap_user` (per-beat WUSER, for the malformed-capability assertion), and
`read_generic` (configurable beats / AXI size / prot, returning per-beat data and
RUSER — used for sub-word reads, instruction-flavoured reads and burst reads).

- **P2 tests:** `aligned_only`, `no_tag_misaligned`, `no_tag_two_bursts`,
  `wuser_mismatch`, `partial_strobe_clears_tag`, `subword_read_clears_tag`,
  `concurrent_data_tag`, `random_data`, `random_capabilities`.
- **P3 tests:** `init_value_undefined`, `execute_from_sram`,
  `burst_read_mixed_tags`, plus `out_of_range_error` and `atomics_excluded`
  (out-of-scope placeholders that log why and drive no stimulus, for vplan
  traceability).

### New TB assertions (`axi_sram_uvm_tb.sv`)
- **`bounded_response` (34ld5i, P2):** a clocked watchdog. Progress is measured on
  `bvalid`/`rvalid` (the DUT presenting a response), so legal master back-pressure
  is never blamed on the DUT; it `$error`s only on a genuine >256-cycle stall.
- **`assert_wuser_not_full_cap` (bj8we7) and `assert_wuser_mismatch` (9a3xf6),
  P2:** the W channel carries no address, so an AW-attribute snoop FIFO (AXI4 keeps
  write data in AW order) associates each W beat with its governing request.
  bj8we7 flags `wuser=1` on a write that is not a full capability write; 9a3xf6
  flags two cap halves disagreeing on `wuser`. Both are deliberately tripped by
  directed tests, so their action is a non-fatal `$warning` (the firing *is* the
  check): bj8we7 fires in the `no_tag_*` tests, 9a3xf6 in `wuser_mismatch`.
- **`tag_separate_memory` (lzoy40, P3):** structural property, documented as a
  comment (distinct `u_tag_ram` / `u_ram` instances); not observable at the AXI
  boundary, so no runtime assertion.

### Notes
- **`concurrent_data_tag`** issues the two *writes* sequentially (AXI4 forbids
  write-data interleaving, so two independent write sequences sharing the single W
  channel would need explicit AW/W coordination — a VIP feature, not exercised);
  concurrency is exercised on the *read* side, where responses are routed by RID.
- **AXI ID width:** `AxiIdWidth = 4`, so test IDs must be ≤ 15. The write-request
  driver correctly *refuses* to drive an ID that does not fit the interface width
  (driving a truncated ID would be non-compliant) — a useful guard rail, not a bug.

### Result
All 14 P2/P3 tests pass (`UVM_ERROR : 0`, `UVM_FATAL : 0`, no `DataKnown_A`, no
bounded-response firings), the P1 set still passes with the new assertions in
place, and the bj8we7/9a3xf6 `$warning`s fire exactly where expected.

---

## Functional coverage

CHERI-tag functional coverage lives in **`axi_sram_cov.sv`**, a passive module
instantiated by `axi_sram_uvm_tb` (it snoops the AXI structs and keeps small AW/AR
attribute FIFOs so each W/R beat is attributed to its governing request). Two
covergroups, sampled at WLAST/RLAST:

- **`cg_tag_write`** — awlen (single/cap/multi), awsize, 16-byte alignment,
  full/partial strobe, any-beat wuser, and per-beat wuser mismatch, with each
  gating dimension crossed with wuser (the full-capability tag-set condition and
  every disqualifying corner).
- **`cg_tag_read`** — the per-flit RUSER pair on a 2-beat capability read
  (`{00}`/`{11}`; mixed is impossible and `ignore_bins`'d) and sub-word reads
  returning a cleared tag, crossed with arlen/arsize.

Collect with **`make COVERAGE=1`** (adds Xcelium `-coverage u`; without it Xcelium
does not sample covergroups). Each run writes a named UCD under `cov_work/`; the
module also prints a per-run `get_coverage()` readout. The multi-test UCD merge +
report (Cadence `imc`), generic AXI-protocol covergroups, and code coverage remain
deferred — see the vplan Coverage section. Two vplan rows were added
(`cov_tag_write_gating`, `cov_tag_read_ruser`).
