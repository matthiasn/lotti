# ADR 0125: Definitions Carry Vector Clocks and Settle Concurrent Edits Under the Joined Clock

- Status: Accepted
- Date: 2026-10-07

## Context

Entity definitions — categories, labels, habits, dashboards, measurables and
speech dictionary entries — replicate as whole documents. Every write passed
a null vector clock, so the receiving gate ordered versions by `updatedAt`
alone, and the sync sequence log never saw them: a lost definition stayed
lost until the next edit or a manual *Sync Entities*, and an edit made on a
device whose clock ran behind could lose to the version it replaced.

Journal entries, links, agent records and consumption events already reserve
a counter per write and are repaired through the sequence log. Journal
entries surface concurrent versions as conflicts for the user to resolve;
for a category or a label that would ask the user to choose between two
near-identical settings rows.

## Decision

- **Every local definition write reserves this host's next counter on top of
  the stored clock**, in one journal transaction with the read and the write,
  so the write dominates everything its device has seen and is never refused.
  Its `updatedAt` goes above the stored one when the caller's does not.
- **Concurrent versions are settled last-writer-wins** — later `updatedAt`,
  then greater canonical content without the clock — **and stored under the
  join of both clocks** (pointwise maximum). The join is strictly greater
  than either, so no counter is spent on the resolution, nothing is sent
  because of it, and two devices that resolved the same pair hold the same
  version. The resolver does not increment its own counter: that would make
  each resolution a new concurrent version and ping-pong.
- **Definitions are sequence-tracked** under a new payload type,
  `entityDefinition`, appended to the persisted enum: sends bind the counter,
  receives record the copy's clock whether it was kept or written, requests
  are answered with the current version, and deep backfill reads the six
  tables as one store.
- **Rows written before clocks are migrated manually.** The existing *Repair
  vector clocks* action stamps every clockless definition on the device, its
  content and `updatedAt` unchanged. A clockless copy never displaces a
  clocked row; a clockless row is ordered by `updatedAt`, and one that keeps
  its place against a clocked copy is stamped on top of that copy's clock, so
  running the migration on one device is enough.
- `specs/tla/DefinitionClocks.tla` gives each of the join, the content
  tie-break, the clockless fallback, the monotone `updatedAt` and the
  stamp-on-receipt a counterexample; `SyncPipeline` checks the transport and
  repair obligations for the new family.

## Consequences

- A lost definition version is detected and backfilled like any tracked
  payload; *Sync Entities* is no longer the only repair.
- Concurrent edits still keep one of them, as before — there is no field-level
  merge — but the outcome no longer depends on arrival order or a device's
  clock running behind the edit it replaced.
- The speech dictionary's content tie-break (ADR 0124) is now every
  definition's.
- Until a device's rows are stamped they are ordered by `updatedAt` as before;
  nothing is migrated automatically.
