# Enhancement scope: concurrent / outstanding writes in the AXI agent

Status: **proposed** (not implemented). Companion to
[`axi_driver_bugs.md`](axi_driver_bugs.md).

## Problem

AXI4 removed write-data interleaving: the W beats of all outstanding writes must
appear on the single W channel **in the same order as their AW addresses were
issued** (AMBA AXI, AXI4: a master must complete the write data for one
transaction before starting the next). The current `axi_agent` cannot guarantee
this when more than one write is in flight.

Each `axi_mgr_write_burst_vseq` independently forks its own AW, W and B
sub-sequences onto the *shared* sequencers:

```
fork
  aw_seq.start(m_write_request_sequencer);   // one AW
  w_seq.start(m_write_data_sequencer);       // this write's W beats
  b_seq.start(m_write_response_sequencer);   // one B
join
```

If a test forks two of these, two `w_seq`s arbitrate independently on the W
sequencer, so the W beats can be emitted out of AW order — e.g. `AW0, AW1` then
`W1.beat0, W0.beat0, W1.beat1`. That is **non-compliant** master traffic and, with
a real DUT, mis-associates write data with addresses (data corruption) or
deadlocks (a beat stuck `wvalid && !wready` while the DUT waits for the in-order
beat). The agent is therefore safe only for **one outstanding write at a time**
(which is how every current sequence, including `axi_sram`'s `concurrent_data_tag`,
is written — the two writes are issued sequentially).

This is purely a *coordination* gap. The per-beat drivers themselves are
AXI-compliant (see `axi_driver_bugs.md`); what is missing is a layer that
serialises the W channel across writes.

## How the cocotb VIP (cocotbext-axi) handles it

`cocotbext.axi.AxiMaster` makes concurrent `write()` calls compliant by funnelling
them through a single ordered W producer (file `axi_master.py`):

- **One command queue.** Every `write()` enqueues an `AxiWriteCmd` into the single
  `write_command_queue` (≈ line 420). User-level concurrency (`start_soon` two
  writes) just means two commands land in this FIFO.
- **One W producer.** A single `_process_write` coroutine (≈ line 473, started
  once) pulls **one command at a time**, sends its AW(s) (≈ line 550) and then all
  its W beats (≈ line 573), and only then pulls the next command. Because one
  coroutine owns the W channel and drives AW-then-W per command serially, **W is
  always in AW order** — compliant by construction.
- **Decoupled responses.** A separate `_process_write_resp` coroutine (≈ line 588)
  receives B beats and matches them to commands by ID (`active_id` counter /
  `tag_context_manager`). Because responses are handled off the W-producer path,
  the producer can issue the next AW+W before the previous B arrives — i.e. real
  pipelined / multiple-outstanding writes, still in compliant W order.

The user fires writes concurrently; the VIP serialises the *wire* traffic and
tracks responses by ID. That single-ordered-W-stream + decoupled-B is exactly the
structure the UVM agent lacks.

## Proposed UVM design

Introduce the same shape: a single component that owns the AW and W sequencers
and emits one ordered W stream, with B responses routed by ID (the existing
`axi_response_router` already does ID routing).

### Option A — write-ordering manager (recommended; mirrors cocotbext-axi)

A new component, e.g. `axi_mgr_write_manager`, owned by `axi_mgr_agent`:

- **API:** a non-blocking `submit(write_cmd)` (or an analysis/TLM `put` port) where
  `write_cmd` carries `{id, addr, size, len, burst, prot, user, data_beats[$]}`
  and an event/handle the caller can wait on for completion.
- **One W producer task:** pulls one `write_cmd` at a time from an internal queue
  and, per command, starts an `axi_mgr_txn_request_seq` (AW) followed by an
  `axi_mgr_write_listed_data_seq` (W beats) on the AW/W sequencers — serially — so
  W is always in AW order. To pipeline, it may start the next command's AW after
  the current command's W completes, without waiting for B.
- **B handling:** a parallel task runs `axi_mgr_write_response_seq` accepts and
  feeds the `axi_response_router`; each submitted command waits on
  `router.wait_for_response(id, …)` (or a per-op event) for its B.
- **Thin caller sequence:** `axi_mgr_write_op_vseq` submits one command and waits
  for its completion. A test issues concurrency by `fork`-ing several of these (or
  by calling `submit` N times then awaiting), and the manager linearises the W
  stream.

Pros: faithful to cocotbext-axi, supports genuine multiple-outstanding writes,
keeps callers simple. Cons: most code; needs careful reset/abort and TLM plumbing.

### Option B — one batched multi-write vseq

A single `axi_mgr_multi_write_vseq` that takes a *list* of write descriptors and
drives them through one AW+W loop (optionally pipelined). Simpler than A but the
caller must batch all concurrent writes into one sequence up front, so it does not
compose with independently-forked stimulus.

### Option C — grab/lock the sequencers (minimal correctness stopgap)

Make `axi_mgr_write_burst_vseq` `grab` (or `lock`) **both** the AW and W
sequencers for the duration of its AW+W phase, so a write's AW and all its W beats
are emitted atomically before any other write's. This restores compliant W
ordering with a small change, but fully serialises writes (no pipelining) and
needs careful grab/ungrab ordering and reset handling to avoid deadlock. Useful as
an interim guard if concurrent-write *coverage* is needed before A lands.

Recommendation: **Option A** for the real capability; **Option C** only if a quick
compliant-but-serial path is needed sooner.

## Work breakdown (Option A)

1. `axi_mgr_write_manager` component: internal command queue, single W-producer
   task, parallel B-accept task, reset/abort handling (drain queue, null out
   in-flight responses like the existing vseqs do on reset).
2. `axi_write_cmd` item + `axi_mgr_write_op_vseq` (submit + wait-for-B).
3. Wire the manager into `axi_mgr_agent` (own the AW/W/B sequencers; expose
   `get_write_manager()`); keep `axi_mgr_write_burst_vseq` as the single-write
   convenience path (it can delegate to the manager).
4. Register the new files in `axi_agent_pkg.sv` and `axi_agent.core`.
5. ID management: allow caller-supplied IDs and validate against `ID_W_WIDTH`
   (the request driver already rejects over-wide IDs).

## Verification

- A `concurrent_writes` test that forks N writes (mixed `id`, `len`, `size`,
  including capability 2-beat writes) and checks every location/tag reads back
  correctly and every B is received.
- A **W-ordering assertion** in the TB/monitor: maintain an AW-order queue and
  assert each accepted W beat belongs to the burst at the head (no interleave).
  The existing bj8we7/9a3xf6 AW-snoop block already *assumes* W-in-AW-order; this
  would turn that assumption into an explicit check and would have caught a naive
  concurrent-write regression.
- Re-confirm single-write and the existing `axi_sram` suite are unaffected.

## Notes

- The `axi_sram` DUT appears single-outstanding (it holds `awready`/`arready`
  while a response is pending), so for *this* DUT pipelining yields little extra
  coverage — but the enhancement is about the VIP emitting **compliant** traffic
  for any concurrent-write stimulus and any DUT, not about this DUT's depth.
- Read concurrency already works today: reads carry their ID on every R beat and
  are routed by the `axi_response_router`, so independently-forked reads compose
  correctly (this is what `axi_sram`'s `concurrent_data_tag` uses).
