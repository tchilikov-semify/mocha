# AXI agent driver bugs (and fixes)

This note documents AXI-protocol bugs found in the `axi_agent` VIP's
**manager-side accept drivers** while bringing up multi-beat traffic for the
`axi_sram` UVM environment, and the fixes applied **in the VIP**. All were
latent: the VIP had only ever driven **single-beat** transfers (the original
`*_fixed_vseq` sequences and the register-layer flow), and every bug needs either
a **multi-beat burst** or **back-to-back transactions** to show up.

Both bugs were fixed at the **driver** level so that every consumer is correct
under any back-pressure policy — there are no test- or vseq-level workarounds.

Files changed:

| File | Change |
|---|---|
| `axi_mgr_read_data_driver.svh` | `drive_req()` rewritten to sample on the real handshake edge |
| `axi_mgr_write_response_driver.svh` | `drive_req()` rewritten the same way (B channel) |

---

## How the accept drivers work (background)

Both accept drivers follow the same pattern. The sequencer hands the driver one
`axi_response_accept_item` at a time; `drive_req()` drives the `ready` line
(`rready`/`bready`) and samples the payload when the transfer happens. Two knobs
shape the back-pressure (these are legitimate, AXI-legal features):

- `ready_without_valid_pct` — fraction of cycles `ready` is asserted
  *speculatively*, before `valid` (a master may assert `ready` before `valid`);
- `valid_to_ready_delay` — cycles to hold `ready` low *after* `valid` is seen.

`get_and_drive()` then loops straight back to `get_next_item` for the next item,
so when a vseq forks N accept items (a burst) or two vseqs run back-to-back, the
next `drive_req()` can begin in the **same simulation time step** as the previous
one finished — `item_done` → `get_next_item` → `drive_req` all at the same
`$time`, before any `posedge clk`.

The original `drive_req()` had two AXI-incorrect behaviours:

1. **It read back its own clocking output** (`if (mgr_cb.rready !== 1'b1)`) to
   decide whether the handshake had already occurred, and then **sampled after
   the edge** based on that. Reading a clocking *output* as an rvalue is itself
   illegal (Xcelium `*W,CONOTR`), and the value read across a zero-time boundary
   is whatever NBA happens to be pending.
2. **Its wait-for-`valid` loop could consume a beat without sampling it.** While
   waiting, it toggled `ready` per `ready_without_valid_pct`; if `ready` was high
   on the cycle `valid` first asserted, the handshake completed *inside the wait
   loop*, but the loop only re-checked `valid` after the edge and never sampled
   that beat.

---

## Bug 1 — a beat/response is re-sampled on back-to-back accepts

**Symptom (reads).** Every multi-beat read returned beat 0 repeated: a 2-beat
capability read came back with `upper == lower`; a 4-beat burst returned
`[word0, word0, word0, word0]`. Single-beat reads were fine.

**Symptom (writes).** A **deterministic hang** on the first read after two writes
(originally `tag_isolation`). A handshake trace showed **2 `AW` handshakes but
only 1 `B` accepted**; a signal probe at the hang showed `bvalid=1, bready=0` —
the second write's response was stuck on the wire, and the DUT will not accept a
new request (`arready=0`) while a B is outstanding.

**Root cause (behaviour #1 + the zero-time boundary).** For a 2-beat read the
burst vseq forks two accept items. Accept #1 handshakes beat 0, samples it,
schedules `rready <= 0`, and returns — with no clock edge. Accept #2's
`drive_req()` runs at the **same `$time`**, reads `mgr_cb.rready` back, still sees
`1` (the `<= 0` is a pending NBA), takes the "handshake already happening"
shortcut, and samples `rdata` immediately — still beat 0. The B channel fails the
same way: the second write's `b_seq` re-samples the first write's (already
accepted) B and returns instantly, so the second write never accepts its own B.

## Bug 2 — a speculative `ready` consumes an un-sampled beat

**Symptom.** Intermittent, timing-dependent **hangs** on multi-beat reads: the
collection loop waited forever for a beat that had already gone by.

**Root cause (behaviour #2).** If `ready` was high (speculatively) on the exact
cycle `valid` first asserted, the beat transferred at that `@cb` inside the wait
loop but was never sampled — a lost beat.

---

## The fix (both drivers)

`drive_req()` was rewritten to **track the `ready` value it drives in a local
variable and sample on the exact `valid && ready` edge**, instead of reading the
clocking output back and sampling afterwards:

```systemverilog
forever begin
  if (!valid_seen)
    rready_q = ($urandom_range(0, 99) < req.m_ready_without_valid_pct); // speculative
  else
    rready_q = (delay >= req.m_valid_to_ready_delay);                   // after valid

  m_vif.mgr_cb.rready <= rready_q;
  @(m_vif.mgr_cb);

  if (m_vif.mgr_cb.rvalid === 1'b1) begin
    if (rready_q) break;                  // rvalid && rready this edge -> transfer; sample now
    if (!valid_seen) valid_seen = 1'b1;   // first rvalid -> start valid_to_ready_delay
    else             delay++;
  end
end
// ... sample mgr_cb here (the beat that transferred on the edge we broke on) ...
m_vif.mgr_cb.rready <= 1'b0;
```

Why this is protocol-correct and fixes every symptom:

- **Samples on the real handshake.** A beat is recorded only on an edge where
  `valid` is high *and the `ready` we are driving this cycle* is high — the exact
  AXI transfer condition. The speculative-`ready` transfer (Bug 2) is now one of
  those edges and is sampled, not dropped.
- **No clocking-output read-back.** `ready` is tracked in `rready_q`, never read
  back from `mgr_cb`, so the illegal-rvalue (`CONOTR`) hazard and the stale
  zero-time read (Bug 1) are both gone.
- **Back-to-back safe.** Every iteration advances one clock (`@cb`) before
  checking, so a fresh `drive_req()` starting in the same time step cannot sample
  a stale beat. If accepts are truly contiguous, the next accept re-drives `ready`
  before the next edge, so consecutive beats are still accepted with no dead
  cycle.

The write-response driver got the identical rewrite on the B channel.

The `axi_response_accept_item` knobs (`ready_without_valid_pct`,
`valid_to_ready_delay`) are preserved, so randomised back-pressure for stress
still works — it is now *correct* rather than lossy.

---

## A note on the response router (not a separate bug)

While debugging Bug 1 on the B channel, the write burst vseq's use of the
ID-routing `axi_response_router` looked suspect (a second write appeared to
"match" a leftover B). That was a **symptom** of the driver re-sampling, not an
independent router bug: with the driver fixed, the standard pattern — fork a
`b_seq` that accepts one B and routes it by ID, then `wait_for_response(id)` —
works correctly, and `axi_mgr_write_burst_vseq` uses exactly that, the same as
`axi_mgr_read_burst_vseq` and the `*_fixed_vseq` sequences. (The router is FIFO
per ID, which matches AXI's same-ID response ordering. Distinguishing *concurrent*
same-ID transactions would need per-transaction tracking, but no current sequence
issues those — each drives a single outstanding transaction.)

---

## Validation

- All 11 `axi_sram` priority-1 UVM tests pass with the drivers using their
  **default randomised back-pressure** (no `ready_without_valid_pct` pinning, no
  trailing-cycle hacks). The previously-hanging `tag_isolation` and the
  multi-beat `burst_last` / capability reads all pass.
- Re-run across several `-svseed` values (different `ready` timings): still green.
- The `*W,CONOTR` "clocking output is not a legal rvalue" warning is gone.

## Blast radius

- In this repo the only `.core` depending on `lowrisc:dv:axi_agent` is
  `hw/top_chip/dv/axi_sram/uvm/axi_sram_uvm.core`; the `*_fixed_vseq` and
  register-layer sequences live inside the VIP but are not instantiated by any
  built target here, so there was nothing else in-repo to re-run.
- `axi_agent` is a reusable `lowrisc:dv` component. The driver rewrite is a strict
  correctness improvement (single-beat behaviour is unchanged; multi-beat and
  back-to-back are now correct), but other repos/testbenches that drive this VIP
  — e.g. ones that exercise the register-layer flow — were not re-run here.
