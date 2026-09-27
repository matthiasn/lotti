# ADR 0095: A Purge Keeps the Deletion

- Status: Accepted
- Date: 2026-09-27

## Context

Deleting a journal entry stamps `deletedAt` on its row and gives the row a new
vector clock. The deletion is a version like any other (ADR 0083): the write
decision refuses a late copy of the version it replaced, an edit made
concurrently with it is a conflict for the user, and the backfill responder
serves it to a device whose delivery was lost.

*Settings → Advanced → Maintenance → Purge deleted items*
(`JournalDb.purgeDeleted`) then removed every deleted row, along with its
files. After that nothing on the device remembered the deletion:

- **A device that missed the deletion kept the entry for good.** It asked for
  the lost counter, and the backfill responder, finding no row, answered
  `deleted`. The requester records that answer as final and never asks again.
- **A late copy brought the entry back.** With no row to compare against, the
  write decision applied any version of the entry, including one the deletion
  had replaced.
- **An edit made concurrently with the deletion replaced it silently**, with
  no conflict for the user.
- **An open delete-versus-edit conflict could no longer be opened.** The
  conflict page found no local entry.

ADR 0083 recorded the first of these as a residual ("hard deletes leave
nothing to serve"). `specs/tla/JournalReplication.tla` now has a `Purge`
action and the switch `PurgeKeepsTombstone`. With the switch off, TLC finds
each hole: `Converged` in four steps (A deletes and purges, B's delivery is
lost, backfill answers `deleted`, B keeps the entry), `NoLostSuccessor` in
five, `NothingDropped` in four, `ConflictResolvable` in four and
`ConflictNotStale` in five.

## Decision

A purge keeps each deleted journal row as a **tombstone** and drops everything
else. The tombstone holds the entry's id, its dates, its vector clock and its
`deletedAt`, plus `Metadata.purgedAt` to mark it. It is stored as a
`JournalEntry` with no text, whatever the entry was, because that variant has
no required fields to keep. The entry's files are deleted as before, and so
are its labels. Dashboards and measurable types a purge still removes outright.

The tombstone keeps the deletion's clock unchanged. It is the same version with
its fields dropped, so nothing is sent when a device purges. Every reader that
already treats a soft deletion as a version reads the tombstone the same way:
the write decision, the backfill responder, the payload sender and the conflict
page. So a device that missed the deletion receives it by backfill, a late
copy is refused, and a concurrent edit is a conflict for the user.

Two rules in `updateJournalEntity` (`_overStored`) handle a tombstone meeting a
copy that still has its fields:

- **A tombstone applied over a stored copy deletes that copy.** The row keeps
  its own fields, and its files, under the tombstone's clock and deletion.
  This device's own purge then removes them. Storing the bare tombstone
  instead would strand an image or audio file that no purge could find any
  more.
- **A deletion applied over a tombstone is compacted in turn.** Fields a purge
  removed do not come back with a peer's copy of the deletion. A live version
  newer than the deletion replaces the tombstone as it would any deleted row.

The conflict page shows a tombstone against an edit as a delete-versus-edit
choice, not as a type change, even though the tombstone is a `JournalEntry`
and the edit may be a task.

A later purge skips tombstones, so it does not rewrite them or count them
again.

We chose this over the alternative of having the purge send a fresh deletion
first. That alternative still leaves nothing to compare a late copy against,
and a device whose delivery is lost still gets `deleted` from backfill.
Keeping the tombstone needs no new message type, no schema change, and nothing
new from the user: the purge still removes the content and the files, which is
what it promises, and the row it leaves is a few hundred bytes.

## Consequences

- `JournalReplication`'s properties hold on all four configurations with
  purges enabled. The residual about hard deletes is gone from
  `specs/tla/README.md`.
- A purged entry can no longer be revived by a peer's stale copy. A peer can
  still bring it back with a version that follows the deletion, such as a
  resolution that keeps the edit. Its fields come from that peer.
- Deleted rows now stay in the `journal` table as tombstones, so the table
  keeps one small row per entry that was ever deleted and purged. Every
  user-facing query already filters `deleted = 0`.
- A deterministic id whose entry was deleted and purged is still taken, as
  it was before the purge. The checklist repository moves past a deleted row
  to the next generation of the id, and now past a tombstone too. The AI
  batch checklist handler counts an id that has any row as already created,
  deleted or purged alike.
- The relationship dispatcher restores a deleted task on its tombstone's
  clock. A tombstone is not a task, so after a purge it creates a new task
  under the id instead, as it would where no row existed. This is the existing
  residual about creations under a reused id.
- Rows removed by a purge before this change are gone, and nothing can bring
  their deletions back. On those ids backfill still answers `deleted`.
- A build without this change that receives a tombstone stores it as a deleted
  `JournalEntry`. It is still a deletion, but that device's purge will not
  find the media files of the copy it replaced.
- The replication conformance test
  (`test/database/journal_replication_model_conformance.dart`) runs the real
  purge in its generated traces.

## Related

- [ADR 0083](./0083-model-checked-journal-replication.md): soft deletions as
  versions, and the residual this closes
- [ADR 0092](./0092-one-conflict-row-per-version.md): conflict rows per version
- `specs/tla/JournalReplication.tla`, `specs/tla/README.md`
- [Journal entity](../../knowledge/domain/journal-entity.md)
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
