# ADR 0083: Model-Checked Journal Replication

- Status: Accepted
- Date: 2026-09-25

## Context

Journal entries — tasks, notes, habit completions, checklists, the user's own
data — sync between devices through one write decision,
`JournalDb.updateJournalEntity` with `detectConflict`: the stored row, read in
the write's transaction, against the incoming vector clock. A newer version
applies, an equal or older one is refused, and a concurrent one is stored as
the entry's `Conflict` row for the user to decide. Deleting an entry is a
version too: `deletedAt` set under the next clock. Unlike agent entities
(ADR 0068, ADR 0081's addendum), journal entries never merge on their own.
The question is therefore not only whether devices converge, but whether a
divergence is ever silent, with a version dropped and no conflict to show for
it.

No spec covered this. We wrote the code as it stood in
`specs/tla/JournalReplication.tla` — two or three devices, edits and
deletions of the stored row and of an entry a screen read earlier, restores,
label writes, the user's resolutions, deliveries in any order and any number of
times, lost deliveries recovered by backfill, and the JSON sidecar that is a
device's sync payload — and model-checked it. TLC found these holes:

1. **A late copy undid a deletion.** The write decision read the stored row
   with `entityById`, which filters `deleted = false`, so a deletion read as no
   row and any version replaced it (`NoLostSuccessor`, six steps: A edits and
   deletes an entry, and A's edit, arriving late at B after the deletion,
   brings it back there). The same read let an edit made concurrently with a
   deletion replace it without a conflict (`NothingDropped`).
2. **Backfill could not serve a deletion.** The responder and the verifier
   read the same way, so a device that lost a deletion was answered `deleted`,
   settled the gap with nothing applied, and kept the entry (`Converged`, four
   steps).
3. **The conflict page could not open a deletion made here.** With 1 fixed, an
   edit arriving over a local deletion is a delete-versus-edit conflict, but
   the page read the local side with `journalEntityById` and showed "entry not
   found" (`ConflictResolvable`). The delete-versus-edit view existed and was
   unreachable.
4. **Any applied write settled the open conflict.** A local edit, or any newer
   version received, marked the entry's conflict resolved even when it did not
   include the conflicting version, which then vanished from the device without
   the user choosing (`NothingDropped`, five steps).
5. **A late copy regressed an open conflict.** A concurrent version always
   replaced the conflict row, so an older copy arriving late replaced the newer
   version the user was shown (`ConflictNotStale`, seven steps).
6. **Label writes overwrote what synced in.** `LabelsRepository.setLabels`
   retried a refused write with `overrideComparison`, over a version that had
   arrived meanwhile (`NothingDropped`, four steps).
   `suppressLabelOnTask` wrote the task under its stored clock, which every
   device refuses as equal, and forced it locally with `overrideComparison`: a
   suppressed label never synced, and the devices differed for good
   (`Converged`, three steps).
7. **A clockless copy replaced a clocked row.** `detectConflict` read a missing
   clock on either side as "incoming is newer", so a late copy of an entry
   created before clocks existed undid every later edit and deletion
   (`NoLostSuccessor`, three steps).
8. **A refused receive left the sender's JSON in the sidecar.** For an older
   peer's envelope, which names only a path, `SmartJournalEntityLoader` saves
   the incoming JSON over the sidecar before the write decision; when the
   decision refused it, the sidecar described a version the device does not
   hold (`SidecarMatchesRow`).
9. **The outbox's sidecar refresh could write an older row.**
   `OutboxEnqueueWriter.enqueueJournalEntity` read the row with
   `journalEntityById` and saved it outside the sidecar queue, so a refresh that
   read before a newer commit could land after that commit's write
   (`SidecarMatchesRow`).

Two suspected gaps did not hold up. The sidecar queue itself
(`_publishSidecar`'s tickets) keeps the newest committed version on disk in
any call order. And the sidecar is written before the receive's enclosing
transaction commits, so a receive rolled back by a failed embedded link leaves
the sidecar describing a version that is not stored — but the event is
retried, and the model's rollback configuration shows the retry heals it.

## Decision

1. **Sync orders versions against the stored row, deletion included.**
   `JournalDb.entityByIdIncludingDeleted` / `journalEntityByIdIncludingDeleted`
   is what the write decision, the backfill responder and verifier, the
   receive's stale-descriptor check and its sequence-log receipt, and the
   conflict page read. A creation (`overwrite: false`) still replaces a deleted
   row, as before.
2. **Two concurrent deletions are merged, not a conflict.** Each device keeps
   the canonically greater deletion's fields under the join of both clocks
   (`VectorClock.compareCanonically`, `VectorClock.merge`), so every device
   computes the same row and it covers both. There is nothing for the user to
   choose.
3. **An applied write settles only a conflict it includes.** The entry's
   unresolved conflict is marked resolved when the written version's clock
   covers the conflict's — the user's resolution, or any later version built
   on it — and stays open otherwise.
4. **A conflict row is not replaced by an older version.** A concurrent
   version is stored as the conflict only when the open conflict does not
   already hold it or a newer one.
5. **A label write builds on the stored row, never over it.** `setLabels` and
   `suppressLabelOnTask` go through `LabelsRepository._writeOnStored`: the
   change is built on the stored entry under a new clock and applied with a
   `precondition` that the stored row is still that one; otherwise it is built
   again on the newer row, three times at most. `overrideComparison` had no
   other caller and is gone from `updateJournalEntity`,
   `PersistenceLogic.updateDbEntity` and the contract.
6. **A clockless version never replaces a clocked row.** It is refused as
   older; it still replaces a row without a clock, and a clocked version still
   replaces a clockless row.
7. **The sidecar has one writer: the queue.** `JournalDb.restoreSidecar`
   reads the stored row, deletion included, and takes a ticket in one
   transaction, then writes through `_publishSidecar`. The receive calls it
   when it refused a path-only envelope, and the outbox's refresh is it.
8. **Resolving over a deletion made here keeps the entry's labels.**
   `PersistenceLogic.updateJournalEntity` reads the stored row with its
   deletion to preserve labels, as it does for a live one.
9. **The model gates the code**, as in ADR 0065: `specs/tla/JournalReplication.tla`
   with six configurations in CI, and a Glados trace in the `JournalDb`
   entity-ops suite that drives three real databases through generated
   interleavings and checks the model's invariants.

## Consequences

- `Converged`, `NoLostSuccessor`, `NothingDropped`, `ConflictNotStale` and
  `ConflictResolvable` hold for three devices with stale reads, restores and
  resolutions; for two with lossy delivery, with label writes, and with a
  clockless original; and `SidecarMatchesRow` with path-only receives, the
  outbox refresh and a rolled-back receive. Each switch set back has a
  counterexample (`specs/tla/README.md`).
- A deleted entry now stays deleted on every device: a late copy of an older
  version is refused, a lost deletion arrives by backfill, and an edit made
  concurrently with a deletion is a delete-versus-edit conflict for the user
  on both devices, where before the edit silently won on the deleting device.
  Users see those conflicts where they used to see a deleted entry come back.
- An open conflict stays open until a version that includes it is written. A
  local edit no longer dismisses a peer's concurrent edit.
- A label assignment or suppression made while another version syncs in is
  applied on top of it instead of replacing it, and a suppression now syncs.
- Each refused receive from an older peer, and each outbox enqueue of a
  journal entry, costs one primary-key read and a sidecar write in the queue.
- Residuals needing a decision, recorded in `specs/tla/README.md`:
  - **One conflict row per entry.** A second concurrent version (a third
    device, or this device's own save refused while a conflict is open)
    displaces the first on this device. A peer's displaced version is raised
    again from its own device; a displaced local save was never sent and is
    lost. Options: conflicts keyed by entry and version with the page listing
    them all, a three-way choice, or refusing a local save while its entry has
    an open conflict.
  - **Concurrent edits never merge on their own.** Auto-merging disjoint
    fields, or last-writer-wins, would change what the user is asked.
  - **A creation under a reused id replaces a deleted row** under a clock that
    does not cover it, so peers ask the user. Whether a re-creation wins, loses
    or asks is open.
  - A deletion displaced from the conflict table on a third device may never
    meet a concurrent deletion; the devices then hold different deletions of
    the entry, all deleted.
- Not changed: hard deletes (`purgeDeleted`) leave nothing to serve, so a
  device that never received the deletion keeps the entry; on one device the
  last save supersedes an earlier one it did not read.

## Related

- [ADR 0065](./0065-model-checked-sync-sequence-reservations.md): the sequence
  log and backfill
- [ADR 0068](./0068-model-checked-agent-convergence.md) and
  [ADR 0081](./0081-model-checked-evolution-sessions-and-agent-links.md)
  (addendum): the same tombstone holes for agent entities
- [ADR 0078](./0078-entry-link-versions-are-ordered.md): entry links
- [ADR 0080](./0080-a-present-counter-ranks-above-an-absent-host.md): how
  absent hosts compare
- `specs/tla/JournalReplication.tla`, `specs/tla/README.md`
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
