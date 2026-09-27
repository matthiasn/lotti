# ADR 0096: An Entry Link Is Its Natural Key

- Status: Accepted
- Date: 2026-09-27

## Context

`linked_entries` holds one row per `(from_id, to_id, type)`, enforced by a
UNIQUE constraint, and one row per id.
[ADR 0078](./0078-entry-link-versions-are-ordered.md) orders the versions of
one link id by `updatedAt`, then the canonical clock, then the content. Its
writers make every edit extend the stored row's clock and never stamp it
earlier. Its 2026-09-25 addendum turned removals into synced tombstones and
made a re-link revive the tombstone under its id.

The addendum left one residual. Every new link took a random id
(`uuid.v1()`), so two devices that created the same link offline minted two
ids for one triple. `JournalDb.upsertEntryLink` compared versions only within
one id. A version with another id was refused as a duplicate while the stored
row was live, and it replaced the row outright, whatever its age, when the
stored row was hidden. So:

1. Device A creates the link under id `a`, device B under id `b`.
2. Each receives the other's. Each refuses it: its own row is live.
3. A removes the link, a tombstone of `a`, which extends `a`'s clock.
4. B refuses the tombstone: its row `b` is live under another id.
5. B's next journal-entity message embeds its snapshot, the live `b`. On A
   the stored row is now a hidden tombstone, so `b` replaces it.

The link is back on the device that removed it, and live on both. The same
thing happens without the timing coincidence when one device runs a build
that predates the fix, and to every pair of duplicates already stored.

`specs/tla/EntryLinkIdentity.tla` models one link on three replicas, created,
removed and re-created on any of them, every version delivered in any order,
any number of times. With the old id choice and the old receive, TLC finds
`NoLostSuccessor` violated in five steps: the sequence above.

## Decision

1. **A new link takes an id derived from its natural key.** `entryLinkId` is
   the uuid v5 of `(type, fromId, toId)`, through
   `MetadataService.deterministicId`. `linkCreationBase` chooses how a link
   is created. If a row for the triple is stored and removed or hidden, the
   new link is that row's next version: its id, its clock as `previous`,
   stamped by `linkEditTimestamp`. If the row is live and visible, creating
   the link again writes nothing and reserves no clock. Otherwise the link
   takes the derived id. That id belongs to another row only when a link
   created under it was retyped or turned around since, because
   `updateLinkType` keeps the id. Then the new link takes a random id.
   `PersistenceLogic.createLink`, `ProjectRepository.linkTaskToProject` and
   the rating link use it.
2. **The receive orders every version of a triple, whatever its id.** When
   `upsertEntryLink` finds the triple held under another id, it compares the
   two versions under the ADR 0078 order, and the greater one takes the row.
   A live row no longer refuses another id outright, and a hidden one no
   longer gives way to any. A version whose id moved to this triple by a
   retype, and that loses there, takes the row it superseded under its own
   id with it, as the device where it lost has already done. The receive
   records a refused version as received when the link is stored under
   either id, so backfill stops asking for it.
3. **A retype cannot land on another live link.** Once the triple is the
   identity, retyping a link onto a relationship that another live link
   already is would replace that link. `updateLinkType` refuses it, as the
   duplicate rule did before.

Together, a removal succeeds the row its writer held, which is the greatest
version of the link it had seen under any id. So it outranks every one of
them wherever it arrives.

## Consequences

- Two devices that create the same link offline write two versions of one
  link. A removal on either stays removed on both, and a late snapshot from
  the other does not bring it back.
- Links stored before this change keep their random ids. Duplicate pairs
  across devices converge on the greater version the next time either is
  delivered. Only the version that loses is dropped, and only where it was
  the stored row. Nothing is migrated and the schema does not change.
- A device on an older build still mints random ids and still receives with
  the duplicate rule. Devices on this build order its versions correctly,
  and a removal made here outranks its copy. The older device itself can
  still bring a link back until it updates. Because new links carry derived
  ids, an older device that already has ADR 0078 orders them within one id,
  so concurrent creations converge there too
  (`EntryLinkIdentityLegacyReceiver`).
- A replaced row is deleted. A backfill request for the counters of the
  version that lost is answered `deleted`, which settles the gap; the winner
  carries the link.
- `createLink` on a link that is already live now returns false without
  reserving a clock, instead of reserving one and releasing it when the
  upsert refused the duplicate.
- Creating a link the user hid makes it visible again, as the next version
  of the hidden row. Before, the hidden row was deleted and replaced by a
  new id.
- Residual: if a version moved to another triple by a retype loses there,
  its old row is deleted, on every device. A late copy of its version from
  before the retype can then be inserted again at the old triple, since no
  row there refuses it. That requires a retype that races a concurrent
  creation of the same target relationship, followed by a delivery older
  than both.

## Model

`specs/tla/EntryLinkIdentity.tla` has two switches.

| Switch | FALSE restores | Counterexample |
|---|---|---|
| `DerivedId` | a fresh link takes a random id | with `TripleIsIdentity` also FALSE, `EntryLinkIdentity` violates `NoLostSuccessor` in five steps. In `EntryLinkIdentityLegacyReceiver` it fails alone, in seven steps: a replica on the older build keeps a version the removal covered |
| `TripleIsIdentity` | the receive refuses a live row's other id and lets any version replace a hidden one | `EntryLinkIdentityLegacy` violates `NoLostSuccessor` in five steps: a replica on the older build creates the link under a random id |

Either switch alone fixes the case where every device runs this build. Both
are needed: `DerivedId` for devices on the older build that receive, and
`TripleIsIdentity` for links that already carry random ids and for devices on
the older build that write.

## Related

- [ADR 0078](./0078-entry-link-versions-are-ordered.md): the order of one
  link's versions, and the 2026-09-25 addendum on removals, whose residual
  this closes
- [ADR 0081](./0081-model-checked-evolution-sessions-and-agent-links.md):
  the agent-link slot swap, which is a related open question for agent links
- `specs/tla/EntryLinkIdentity.tla`, `specs/tla/README.md`
- [Entry links](../../knowledge/domain/entry-links.md)
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
