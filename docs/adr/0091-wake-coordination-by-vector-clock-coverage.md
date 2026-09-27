# ADR 0091: Wake Coordination by Vector-Clock Coverage

- Status: Accepted
- Date: 2026-09-27
- Amends: [ADR 0090](0090-cross-device-agent-wake-coordination.md)

## Context

ADR 0090 let a device stand down only when a peer's run was over *exactly*
its own task state: both devices hashed the versions of every row the task
context reads, and only equal digests deferred or cancelled. Tried on two
devices, it did not stop a single duplicate. Change a task on A, and with 30
seconds left on A's countdown check off one of its checklist items on B; A
runs and completes, then B runs as well.

Exact equality asks two replicas to agree on every version of every input at
the moment each starts, and anything that differs between them breaks it: a
row one device has and the other does not yet, an edit made between the two
dispatches, a device-local setting that filters the linked entries. In each
of those cases the earlier run may well have read everything the later one
holds, and more — the case that matters, and the one equality cannot see. And
nothing told us which case we were in: the coordinator logged only its defer
and cancel decisions.

## Decision

A peer's run **covers** a device when it has read every write the device's
own inputs rest on. The model's `Covers` is the subset relation on the set of
edits a device holds (`specs/tla/AgentWakeCoordination.tla`, re-checked; with
the old equality in place, `CoverSuperset = FALSE`, `Exclusive` fails in nine
states: B holds edit 1, A runs over edits 1 and 2, and B runs edit 1 again).

- **What a claim carries: a watermark.** Per host, the highest counter up to
  which the sender holds every one of that host's writes — the sync sequence
  log's gap-free prefix (`SyncDatabase.contiguousWatermarks`), not its highest
  counter, which a gap would overstate — and, for its own host, the last
  counter it handed out. Journal entities, entry links and agent entities
  share one counter per host, so one number per device describes everything
  the sender's run will read. The watermark is read when the wake starts, and
  the run reads later still.
- **What a receiver checks: its inputs' vector clocks.** `taskWakeInputs`
  collects the vector clock of every row in the task's neighbourhood: the
  task, every link from or to it and the entity at the other end, its
  checklists and items, and one ring further for linked images and linked
  tasks, with linked tasks' agent links and current reports. Removed links
  and deleted entities stay in. A removal is a write like any other, but only
  the clock of a row that is read gets checked, and the context reads skip
  tombstones. The receiver is covered when every `(host, counter)` in those
  clocks is at or below the peer's watermark. A row without a vector clock is
  never covered.
- **Private entries.** The claim also says whether the sender's context
  includes private entries. One that hides them does not cover one that reads
  them.
- **Everything else in ADR 0090 stands**: the claim at dispatch, the
  heartbeat, the timer re-armed by every message, `done` and `release`, the
  history of completed runs kept apart from the live claim, the fail-open
  rules, and the user's explicit wakes running regardless.
- **Logging.** Every decision is logged in the agent-runtime domain, under
  `coordination`: a proceed names, for each known peer run, the first write it
  lacks. Every claim, done and release sent and received is logged too, so a
  duplicate run can be traced to its cause on either device.
- **Wire.** The variant keeps its Dart name, `SyncMessage.agentWakeCoordination`,
  and goes over the wire as `agentWakeCoverage`. 1.1.29 decodes
  `agentWakeCoordination` with a required digest, and a message without one
  would fail with an error the sync pipeline retries rather than skips. Under
  a name each version does not know, both skip the other's messages: a mixed
  pair of devices simply runs uncoordinated.

## Consequences

- A device whose peer ran after syncing its edits stands down, even when the
  peer held more than it did: the check-off above no longer runs twice,
  provided it reached A before A started.
- A check-off that reaches A only after A started is new work for A's run, and
  B runs. That is the protocol's purpose, not a gap in it, and the log says so.
- A run's own writes are change-set proposals in the agent database, so they
  are not inputs; a peer's report on a *linked* task is, and a new one makes
  the task agent run again, as before.
- The inputs are read wider than the context builders read — both link
  directions, removed rows, private entries regardless of the setting. A row
  that is read but never rendered can only cost a run, never drop one.
- A counter the sync log gave up on (`unresolvable` after its retries) counts
  as held, so a watermark can overstate what a device read. That needs a gap
  the backfill could not close, and costs at most one wake that the device
  holding the write would otherwise have run.
