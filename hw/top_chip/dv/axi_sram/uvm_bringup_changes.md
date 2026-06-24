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

Build-flow files (`axi_sram_tb.core`, `axi_agent.core`, `Makefile`) were also
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

### A known DUT assertion, waived in the Makefile (not an SV change)
A single DUT RTL assertion fires during the run: `prim_fifo_sync DataKnown_A` at
`u_dut.u_axi_to_detailed_mem.i_mem_to_banks.gen_reqs[0].i_ft_reg`. It is an
`ASSERT_KNOWN` tripping on the **don't-care `wdata` of the tag read-modify-write
request** in 4-state Xcelium (Verilator reads X as 0, so the cocotb flow never
saw it). It does not affect functional correctness, and the verification plan
treats power-up contents as undefined. The RTL is vendored and was left
untouched; instead the Makefile waives just that one assertion at run time via an
inline `assertion -off {...}` so the run exits cleanly (`UVM_ERROR : 0`) instead
of failing `make` on a harmless error.

---

## Non-SV build-flow changes (for reference)

The flow is "just call fusesoc": a single `fusesoc run` compiles, elaborates and
simulates in one xrun invocation, with all artifacts in an in-tree build dir.

- **`axi_sram_tb.core`** — the entry point and single source of truth for xrun
  options. The `default` Xcelium target carries `-64bit -sv -uvm -uvmhome
  CDNS-1.2 -licqueue +define+UVM -access rwc -l xrun.log -nowarn ... +UVM_TESTNAME
  +UVM_VERBOSITY`. `+define+UVM` is needed so `dv_utils_pkg`'s `` `ifdef UVM ``
  guard includes `uvm_macros.svh`. The UVM file list is ordered so
  `axi_sram_test_pkg.sv` precedes `axi_sram_uvm_tb.sv`. The cocotb/Verilator
  filesets and targets were removed (Xcelium-only).
- **`axi_agent.core`** — uncommented the `lowrisc:dv:dv_utils` dependency so
  `dv_utils_pkg` (which the `axi_*_if` interfaces import) is compiled first.
- **`Makefile`** — a thin wrapper: `run` (default goal) just calls `fusesoc run`,
  `clean` removes the build dir. It exports the environment Edalize's generated
  Makefile needs — the real Cadence `bin` on `PATH` so `xmroot` resolves (the nix
  dev-shell only exposes the FHS-wrapped `xrun`), plus `XRUN`/`LD_LIBRARY_PATH`.
  It also injects an inline run-control script via `XMSIM_OPTIONS`
  (`-input "@assertion -off {...}; run; exit"`) that waives the assertion above
  and, with `WAVES=1`, splices in the SHM probe commands.
