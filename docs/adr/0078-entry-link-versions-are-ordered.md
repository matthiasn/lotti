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
`upsertEntryLink()`". They did not. An audit during PR #4464
([ADR 0077](./0077-a-reservation-names-the-id-written.md)) found two holes:

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
   metadata, where the reservation names it, as
   [ADR 0077](./0077-a-reservation-names-the-id-written.md) requires.

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
  `VectorClock.compare`, and it is left open here. It was made in
  [ADR 0080](./0080-a-present-counter-ranks-above-an-absent-host.md), in
  both places: `compare` ranks an absent host below 0, and new hosts start
  at 1. The link order now uses the shared `VectorClock.compareCanonically`.
- Residual, not addressed here: `JournalRepository.removeLink` and
  `removeTypedLink` hard-delete the row on this device and send nothing. Peers
  keep the link, and the next journal-entity message from a peer that embeds
  it re-inserts it here. Unlinking an entry or removing a task relationship
  therefore does not reach other devices. Fixing it means turning those
  deletions into synced tombstones, like the project unlink. Closed by the
  2026-09-25 addendum below.

## Addendum (2026-09-25): a removal is a synced tombstone

The residual above is closed. The decision was that link tombstones must
sync. Found in PR #4467: `JournalRepository.removeLink` and `removeTypedLink`
deleted the row on this device and sent nothing. They back unlinking an entry
in the linked-entries list, removing a task relationship (the row in manage
mode), and the Undo on the "link created" message. The peers kept the link.
Every journal-entity message a peer sends embeds its snapshot of the entry's
links. So the next one put the link back on the device that removed it.

1. **Every removal writes the link's next version.** `removeLink` (every type
   between the pair) and `removeTypedLink` (one type) write each live link
   again with `deletedAt` set and `hidden` true, through `updateLink`. So a
   tombstone follows Decision 2 like any other edit: it reserves its clock
   with the stored link's as `previous`, is stamped by `linkEditTimestamp`,
   is upserted under Decision 1, and is sent as an `entryLink` update. The
   project unlink and `RelationshipRepository.unlinkTask` already did this.
   `JournalDb.deleteLink` and `deleteTypedLink` are removed. Nothing deletes
   a link row now except `upsertEntryLink`: it drops a hidden row when a
   version with a different id arrives for the same `(from_id, to_id, type)`.
   Entries are soft-deleted, so deleting an entry does not delete its links.
2. **Linking a removed link again revives its tombstone.**
   `PersistenceLogic.createLink` and `ProjectRepository.linkTaskToProject`
   look for a removed version of the same `(fromId, toId, type)`
   (`JournalDb.linksBetween`, `removedVersion`). If one exists, the new link
   takes its id, extends its clock and is stamped by `linkEditTimestamp`.
   Re-linking is then one more version of the same link, ordered by
   Decision 1 whatever the arrival order. A fresh id would be a second row
   for the same triple. A peer that still holds the live link refuses that
   row as a duplicate. When the tombstone arrives later, the peer has no link
   while this device keeps its new one.
3. **Reads of live links exclude removed ones.** Every tombstone is hidden,
   so queries that already require `hidden = false` exclude it. The
   queries that also return user-hidden links now test
   `json_extract(serialized, '$.deletedAt') IS NULL`: backlinks, parent ids,
   `linksForIds`, the "show hidden" linked-entries list, basic links,
   typed-relationship links and the bidirectional neighbourhood. Drift's
   analyzer gets the `json1` module for this. Reads that serve replication
   keep tombstones: `entryLinkById`, `linkRowsFromIdsIncludingHidden`,
   the sequence-log stream, and
   `linksForEntryIdsBidirectionalIncludingRemoved`. The last one is the
   snapshot a journal-entity message embeds, so a removal travels with the
   entry.
4. **No new model.** A tombstone is not terminal, since linking again
   revives it. A link therefore stays one last-writer-wins register under
   the Decision 1 order, and the writer-side rules that `AgentReplication.tla`
   checks cover it. Nothing new is checked.

Consequences:

- A removal reaches every device and stays removed there. A late copy of the
  live version, including a peer's embedded snapshot, cannot bring it back.
  Removing a link and linking it again converges on every device, whatever
  order the versions arrive in. So does an undo followed by a redo.
- Undo stays local and instant. The link is gone on this device before
  anything is sent. It is now a synced removal like any other.
- `linked_entries` keeps one tombstone per removed link. Linking the same
  pair and type again reuses that row. Nothing purges tombstones.
- A link removed before this change is still on the peers. Their snapshots
  can bring it back once more. Removing it again now reaches every device.
- Residual: two devices that create the same link offline, at the same time,
  mint two ids for one triple. Each device refuses the other's as a
  duplicate. A removal on one device is then refused on the other, where the
  triple is live under the other id. That device's next snapshot replaces
  the tombstone with its live row. The fix would make the triple the link's
  identity, for example with a deterministic id. That changes the data model
  and is left open.

## Related

- [ADR 0068](./0068-model-checked-agent-convergence.md) — the order and the
  writer-side fixes, model-checked for agent entities
- [ADR 0077](./0077-a-reservation-names-the-id-written.md) — a reservation
  names the id that is written
- `specs/tla/AgentReplication.tla`, `specs/tla/README.md`
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
- [Entry links](../../knowledge/domain/entry-links.md)
