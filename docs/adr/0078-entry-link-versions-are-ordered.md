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

`AgentReplication.tla` (ADR 0068) checks the writer-side half of this for
agent entities. `IntentCarriesClock` and `ResolveLocalWrites`: a write
carries the clock of the row it replaces. `ClampTimestamp`: a successor is
never stamped earlier than its predecessor. With either switch off, TLC finds
`Converged` or `LocalWriteTakesEffect` violated in a few steps. The agent
receive rule puts causal dominance first and falls back to `updatedAt`. For
links we use a single lexicographic key instead (Decision 1). Such a rule is
transitive for any mix of versions, including clockless legacy copies. A
dominance check followed by a timestamp fallback is not: a clock-dominant
version stamped earlier than its predecessor, plus a clockless copy stamped
in between, form a cycle. Given the two writer-side rules, the two orders
agree on every history the writers produce. No separate spec is needed.

Review found one more edge. A new host's first counter is 0, and
`VectorClock.compare` reads an absent host as 0. So a fresh device's first
edit, `{…, host: 0}`, compares *equal* to the version it extends. The link
order therefore reads an absent host as lower than any counter, 0 included.

The same audit found `JournalRepository.createTextEntry` taking a
`required String id` and ignoring it. Every caller passed a fresh `uuid.v1()`
and read the entry's id back from the returned entity, so nothing depended
on the parameter. It only suggested a way to choose the id that did not exist.

## Decision

1. **The receive orders versions by one key.** `JournalDb.upsertEntryLink`
   refuses any version that is older than the stored one under a single
   ordering:
   - the later `updatedAt` wins;
   - on a tie, the clocks are compared host by host in sorted order, and the
     first counter that differs decides. A host absent from a clock ranks
     below every counter, 0 included;
   - if the clocks tie too, the serialized version decides.

   The check runs in the upsert's transaction for every caller: both sync
   handlers and the local writers.
2. **An edit succeeds its predecessor.** A local update reserves its clock
   with the stored link's clock as `previous` (`updateLink` merges the stored
   copy and the caller's). It stamps `updatedAt` with `linkEditTimestamp`:
   now, or the predecessor's stamp when a peer's clock ran ahead. The edit
   therefore has the later stamp, or ties on it. On a tie it ranks higher on
   the clock: the edit's clock is its predecessor's plus this host's next
   counter, which is either larger than before or new.
3. **`createTextEntry` loses its `id` parameter.** The id is minted with the
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
- A version that dominates by clock but is stamped *earlier* than the stored
  one loses. The writers never produce one (Decision 2). A version like that
  can only come from a device whose clock runs behind and which predates
  this change, and it can then be ordered by timestamp alone.
- The zero-counter equality reaches beyond links. Journal entries
  (`JournalDb.updateJournalEntity` applies only `b_gt_a`) and agent entities
  (the resolver and the dominance pre-check keep local on `equal`) read a new
  host's first update of an existing row as equal to that row and keep the
  row. That is a separate fix, in `VectorClockService` or in
  `VectorClock.compare`, and it is left open here.
- Residual, not addressed here: `JournalRepository.removeLink` and
  `removeTypedLink` hard-delete the row on this device and send nothing. Peers
  keep the link, and the next journal-entity message from a peer that embeds
  it re-inserts it here. Unlinking an entry or removing a task relationship
  therefore does not reach other devices. Fixing it means turning those
  deletions into synced tombstones, like the project unlink.

## Related

- [ADR 0068](./0068-model-checked-agent-convergence.md) — the order and the
  writer-side fixes, model-checked for agent entities
- ADR 0077, "A reservation names the id that is written" (in PR #4464)
- `specs/tla/AgentReplication.tla`, `specs/tla/README.md`
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
- [Entry links](../../knowledge/domain/entry-links.md)
