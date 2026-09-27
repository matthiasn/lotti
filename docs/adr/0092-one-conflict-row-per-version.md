# ADR 0092: One Conflict Row per Concurrent Version

- Status: Accepted
- Date: 2026-09-27

## Context

When the write decision (`JournalDb.updateJournalEntity`, ADR 0083) finds an
incoming version concurrent with the stored row, `detectConflict` stores it
in the `conflicts` table for the user to decide, and refuses it. The table
was keyed by the entry's id alone, so each entry could hold one open
conflict. A second concurrent version replaced the first.

Two things produce a second concurrent version. One is a third device's
edit. The other is this device's own save when the editor built it on an
entry it read before a peer's version landed. `MetadataService.updateMetadata`
extends the clock the editor holds, so the save is concurrent with the stored
row, and the decision refuses it and parks it as the conflict. A refused save
is never sent. If another concurrent version then replaced it in the table,
it was gone from every device, and nothing told the user.

ADR 0083 recorded this as a residual that needed a product decision, with
three options. The first was a conflict table keyed by entry and version,
with the page listing every open version. The second was folding the second
version into the open conflict as a three-way choice. The third was refusing
a local save while its entry has an open conflict.

`specs/tla/JournalReplication.tla` kept the loss visible as a ghost,
`displaced`, and claimed `NothingDropped` and `ConflictNotStale` with that
exception. With the exception removed and the one-row table kept, TLC
violates `NothingDropped` in five steps: A and B edit; C receives A's edit,
then saves an edit built on the version it read before, which is refused and
parked as the conflict; B's edit arrives and replaces it. C's save now exists
nowhere.

## Decision

The `conflicts` table is keyed by the entry's id and a `version_key`: the
version's vector clock as `node:counter` pairs in sorted node order
(`VectorClock.canonicalKey`). Schema v50 rebuilds the table and derives the
key of every existing row from the clock of the version it holds.

`_recordConflict` keeps the set of open conflicts to the versions nobody has
superseded:

- nothing is stored when an open conflict already holds the same version or
  a newer one (the rule ADR 0083 added);
- an open conflict that the incoming version follows is replaced by it;
- every other open conflict stays, and the incoming version is added beside
  it.

An applied write marks resolved every open conflict it includes, and leaves
the others open.

The conflict page resolves one pair at a time: the stored row against one
open version, written with `VectorClock.merge` of the two. That write
includes the version the user decided, so it settles that one. Another open
version is concurrent with it and stays open for the next decision. The list
shows each open version as its own row. A row opens the page on its version
through a `version` query parameter. Without one, the page shows the entry's
oldest open version. The sync-conflict notification counts and alerts on
rows, so a second version of an entry already in conflict is a new alert.

We chose the first option because it is the only one that never drops a
version and asks nothing new of the user. The page, its choices and the
merge it writes are unchanged. The second option would need a three-way
comparison UI. The third would still lose the text a user typed into an
editor that had fallen behind, unless the editor learned to rebase, which is
a larger change of its own.

## Consequences

- A version a device received or wrote is always kept by its row or by an
  open conflict. `NothingDropped` and `ConflictNotStale` hold with no
  exception on all four `JournalReplication` configurations. The ghost
  `displaced` is gone, and the switch `ConflictPerVersion` restores the old
  table and its counterexample.
- A save built on a stale read is still refused and not sent until the user
  resolves it. It now waits in the conflict list instead of being liable to
  vanish.
- An entry can show more than one row in the conflict list, and resolving
  one leaves the next. Resolving in any order converges: each resolution's
  clock covers what it decided, and the last one covers them all.
- The residual that a deletion displaced on a third device could leave
  devices holding different deletions no longer has a cause, because nothing
  is displaced.
- The replication conformance test
  (`test/database/journal_replication_model_conformance.dart`) checks every
  open conflict, with no displaced exception. Restoring the one-row
  behaviour fails it on a three-step trace.
- Schema v50 rebuilds `conflicts`. A row whose payload cannot be read keeps
  the key `''`, which stays unique because the table held one row per entry
  before.

## Related

- [ADR 0083](./0083-model-checked-journal-replication.md): the write decision,
  and the residual this closes
- [ADR 0080](./0080-a-present-counter-ranks-above-an-absent-host.md): how
  clocks compare
- `specs/tla/JournalReplication.tla`, `specs/tla/README.md`
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
