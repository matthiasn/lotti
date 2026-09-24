# ADR 0078: Entry-Link Versions Are Ordered, and an Edit Succeeds Its Predecessor

- Status: Accepted
- Date: 2026-09-24

## Context

An `EntryLink` is replicated state. Every device can edit it — collapse it,
hide it, retype it, or tombstone it when a task leaves its project — and every
version reaches every other device, in no guaranteed order and possibly more
than once: as its own `entryLink` message, as a backfill answer, and inside
every journal-entity message, which embeds a snapshot of all the entry's links
(`OutboxEnqueueWriter.prepareJournalEntity`). The receive handlers had a
comment saying links "have their own vector clock for conflict resolution via
`upsertEntryLink()`". They did not. An audit during PR #4464 (ADR 0077) found
two holes:

1. **The receive applied whatever arrived last.** `JournalDb.upsertEntryLink`
   compared nothing but the serialized row: any version that differed
   overwrote the stored one. A journal-entity message enqueued before a link
   was removed, and delivered after the removal, put the live link back. So
   did a late backfill answer. Devices that received the same versions in a
   different order kept different links. A task moved out of its project, or
   a collapsed or hidden link, could come back on the device that made the
   change or on its peers, and stay that way until the next edit.
2. **An edit did not extend the clock of the version it replaced.**
   `JournalRepository.updateLink` and `ProjectRepository._prepareDeletedLink`
   reserved their clock without `previous:`, so an edit's clock held only this
   host's counter. It was concurrent with the version it replaced, not after
   it. No receive rule could order the two causally. And the backfill
   responder could not answer an older counter from the current row, because
   that row's clock no longer covered it.

`AgentReplication.tla` (ADR 0068) already checks the order this needs, for
agent entities: causal dominance, then the later `updatedAt`, then a canonical
clock order, with two fixes on the writing side. `IntentCarriesClock` and
`ResolveLocalWrites`: a write carries the clock of the row it replaces.
`ClampTimestamp`: a successor is never stamped earlier than its predecessor.
With either switch off, TLC finds `Converged` or `LocalWriteTakesEffect`
violated in a few steps. An entry link is that model's `"state"` register
without G-counters and without a type override. No separate spec is needed.
The links now follow the same rules as the modelled design.

The same audit found `JournalRepository.createTextEntry` taking a
`required String id` and ignoring it. Every caller passed a fresh `uuid.v1()`
and read the entry's id back from the returned entity, so nothing depended
on the parameter. It only suggested a way to choose the id that did not exist.

## Decision

1. **The receive orders versions.** `JournalDb.upsertEntryLink` refuses a
   version older than the stored one: the stored clock dominates it, or the
   two are concurrent (or clockless) and it has the earlier `updatedAt`, or
   the same `updatedAt` and the canonically smaller clock
   (`compareClocksCanonically`). When even the canonical clocks tie, which
   happens only with equal clocks, the serialized versions decide. The check
   runs in the upsert's transaction, for every caller: both sync handlers and
   the local writers.
2. **An edit succeeds its predecessor.** A local update reserves its clock
   with the stored link's clock as `previous` (`updateLink` merges the stored
   and the caller's copy), and stamps `updatedAt` with `linkEditTimestamp`: now,
   or the predecessor's stamp when a peer's clock ran ahead. Dominance then
   implies a stamp at least as late, so the fallback order never contradicts
   the clocks.
3. **The canonical clock order is shared.** `compareClocksCanonically` moves
   from the agents' resolver to `lib/features/sync/vector_clock.dart`.
4. **`createTextEntry` loses its `id` parameter.** The id is minted with the
   metadata, where the reservation names it, as ADR 0077 requires.

## Consequences

- A removed or edited link is not brought back by a late copy of an older
  version, whatever the arrival order and however far a peer's wall clock
  runs ahead. Every device that has received the same versions keeps the
  same one.
- A version refused on arrival is still recorded as received in the sequence
  log. The stored clock covers its counter, so backfill stops asking for it.
- Links written before this change carry clocks without their predecessor's
  entries. Concurrent pairs among them are ordered by `updatedAt`, which beats
  the old arrival order but not a skewed clock. Such a link is ordered
  causally again after its next edit.
- A local edit that loses a race with a sync arrival between its read and its
  write is refused like any older version. `updateLink` reports false.
- Residual, not addressed here: `JournalRepository.removeLink` and
  `removeTypedLink` hard-delete the row on this device and send nothing. Peers
  keep the link, and the next journal-entity message from a peer that embeds
  it re-inserts it here. Unlinking an entry or removing a task relationship
  therefore does not reach other devices. Fixing it means turning those
  deletions into synced tombstones, like the project unlink.

## Related

- [ADR 0068](./0068-model-checked-agent-convergence.md) — the order and the
  writer-side fixes, model-checked for agent entities
- [ADR 0077](./0077-a-reservation-names-the-id-written.md) (PR #4464) — a reservation
  names the id that is written
- `specs/tla/AgentReplication.tla`, `specs/tla/README.md`
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
- [Entry links](../../knowledge/domain/entry-links.md)
