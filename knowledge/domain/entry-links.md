---
type: Domain Model
title: Entry links
description: One row per relationship, nine variants sharing one shape, and why the type column is what keeps old consumers working.
resource: ../../lib/classes/entry_link.dart
tags: [domain, links, relationships]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-09-27T13:00:00Z }
stale_after: 2026-12-27
sources:
  - id: entry-link
    resource: ../../lib/classes/entry_link.dart
    title: EntryLink union, EntryLinkType and linkEditTimestamp
    last_modified: 2026-09-27
  - id: link-creation
    resource: ../../lib/logic/entry_link_creation.dart
    title: entryLinkId and linkCreationBase — a new link's derived id, or the row it succeeds
    last_modified: 2026-09-27
  - id: adr-0042
    resource: ../../docs/adr/0042-typed-task-relationship-links.md
    title: ADR 0042 — Typed task relationship links
    last_modified: 2026-07-24
  - id: link-upsert
    resource: ../../lib/database/database_links_ratings.dart
    title: JournalDb.upsertEntryLink, linksBetween and the live-link reads
    last_modified: 2026-09-27
  - id: link-queries
    resource: ../../lib/database/database.drift
    title: Link queries that exclude removed links
    last_modified: 2026-09-25
  - id: journal-repository
    resource: ../../lib/features/journal/repository/journal_repository.dart
    title: JournalRepository — updateLink, updateLinkType, removeLink and removeTypedLink
    last_modified: 2026-09-27
  - id: create-link
    resource: ../../lib/logic/persistence_entries.dart
    title: PersistenceEntries.createLink — a derived id, or the next version of a removed link
    last_modified: 2026-09-27
  - id: adr-0078
    resource: ../../docs/adr/0078-entry-link-versions-are-ordered.md
    title: ADR 0078 — entry-link versions are ordered; 2026-09-25 addendum on removals
    last_modified: 2026-09-27
  - id: adr-0096
    resource: ../../docs/adr/0096-an-entry-link-is-its-natural-key.md
    title: ADR 0096 — an entry link is its natural key
    last_modified: 2026-09-27
---

# Nine variants, one shape

`EntryLink` is a union of `basic`, `rating`, `project`, `relationship`,
`blocks`, `followsUp`, `duplicates`, `fixes`, `supersedes` — mirrored by
`EntryLinkType`.

**Every variant has the same shape**: id, `fromId`, `toId`, timestamps, vector
clock. The relationship lives entirely in the **type column**.

That is the load-bearing design decision: because the shape is identical, every
existing `type = 'BasicLink'` consumer — recorded-time attribution, capture
attachment, the generic linked-entries list — stays **structurally blind** to
typed edges. Typed relationships were added without migrating a single consumer.

```mermaid
erDiagram
  JOURNAL_ENTITY ||--o{ LINKED_ENTRIES : "from_id"
  JOURNAL_ENTITY ||--o{ LINKED_ENTRIES : "to_id"

  LINKED_ENTRIES {
    TEXT id PK "NOT NULL UNIQUE"
    TEXT from_id "indexed — the canonical source"
    TEXT to_id "indexed — the canonical target"
    TEXT type "indexed — the whole relationship"
    TEXT serialized "the EntryLink variant as JSON"
    BOOLEAN hidden "DEFAULT FALSE"
    DATETIME created_at
    DATETIME updated_at
  }
```

`UNIQUE(from_id, to_id, type)` is what lets one pair hold several different
relationships while keeping each one singular.

**A type does not always imply an endpoint type.** `relationship` binds a
`RelationshipEntry` to *both* its check-ins and its linked tasks, so a
`RelationshipLink` row alone does not say which it is. Consumers that want one
of the two must resolve the endpoint's journal `type` — see
`JournalDb.getLiveTasksByIds`, which filters on the indexed column so a
person's whole check-in history is never deserialized just to be discarded.

**Only these columns are queryable.** Everything else an `EntryLink` carries —
`vectorClock`, `collapsed`, `deletedAt` — lives inside `serialized`.

That matters for removed links, which stay in the table as tombstones (below).
Every tombstone is `hidden`, so a query that requires `hidden = false` already
excludes it. A query that also returns links the user hid has to test
`json_extract(serialized, '$.deletedAt') IS NULL`. The live-link queries do:
backlinks, parent ids, `linksForIds`, the "show hidden" linked-entries list,
basic links, `typedLinksForTaskIds` and `linksForEntryIdsBidirectional`
(`_linkIsLive` in Dart, the same predicate in `database.drift`).

Replication reads keep tombstones on purpose: `entryLinkById`, `linksBetween`,
`linkRowsFromIdsIncludingHidden` and
`linksForEntryIdsBidirectionalIncludingRemoved`. **A consumer that reads through
one of those must skip `deletedAt != null` itself.** `TaskDependencyResolver`,
`TaskBlockersController` and `TaskLinkGroupsController` also skip removed rows in
Dart, as a second guard over a query that has already excluded them.

# One row per relationship

"Is blocked by" and "has follow-up" are **rendering labels for the reverse
direction of the same row**, never separate rows. Picking an inverse phrase in the
UI swaps `fromId`/`toId` before persisting, so the canonical stored direction is
always the primary one — a `blocks` link's `fromId` is always the blocker.

The schema's `UNIQUE(from_id, to_id, type)` lets one pair hold several different
relationships, and **direction is part of the identity**, so the inverse of an
existing link stays offerable.

`PersistenceLogic.createLink` runs a best-effort local cycle guard for `blocks`
only. **Read-time traversal tolerates cycles regardless**, because two offline
devices can always race one into existence.

# Links are synced first-class

Updating a link emits `UpdateNotifications` **and** writes a sync outbox message
with a fresh vector clock. Links are their own `SyncMessage` family
(`entryLink`), sequence-tracked like journal entities, and every
journal-entity message also embeds a snapshot of its entry's links.

So the same link arrives many times, in any order. `JournalDb.upsertEntryLink`
keeps the newest version and refuses older ones: the later `updatedAt`, then
the larger clock, then the serialized version. An edit — `updateLink`, a
removal, a revival — extends the stored link's clock and is never stamped
earlier than it (`linkEditTimestamp`), so it outranks every copy of what it
replaced
([ADR 0078](../../docs/adr/0078-entry-link-versions-are-ordered.md); the
order is drawn in
[vector clocks and conflicts](../features/sync/vector-clocks-and-conflicts.md#entry-links-one-version-on-every-device)).

# A removal is a synced tombstone

Removing a link writes its next version with `deletedAt` set and `hidden` true,
and sends it like any edit. Every removal path does this.
`JournalRepository.removeTypedLink` removes one type between a pair. It backs
the Undo on the "link created" message, unlinking a row in a task's
relationships, and swapping a new task's plain link for the chosen type.
`removeLink` removes every type between a pair and backs the linked-entries
list's unlink. Both go through `updateLink`. The project unlink
(`ProjectRepository._prepareDeletedLink`) and
`RelationshipRepository.unlinkTask` write the same tombstone. No removal
path deletes a link row, so the removal reaches the peers. It outranks their copy
of the live link, including the one embedded in their journal-entity
messages, which carry tombstones too.

**Linking the same pair and type again revives the tombstone** rather than
minting a second id. `linkCreationBase` (`lib/logic/entry_link_creation.dart`),
used by `PersistenceLogic.createLink`, `ProjectRepository.linkTaskToProject`
and the rating link, makes the new link the next version of a removed or
hidden row: its id, its clock as `previous`, stamped by `linkEditTimestamp`.
Creating a link that is live and visible writes nothing.

# A link is its natural key

A link never stored here takes the id derived from its `(fromId, toId, type)`
(`entryLinkId`, a uuid v5), so two devices that create it offline write two
versions of one link. The derived id can belong to another row only when a
link created under it was retyped or turned around since, because
`updateLinkType` keeps the id. The new link then takes a random id.

Links from before ADR 0096, and from a device on an older build, carry random
ids. So `upsertEntryLink` orders the versions of a triple by the same key
whatever their ids, and the greater one takes the row. A removal succeeds the
row its writer held, the greatest version it had seen under any id, and
outranks every one of them wherever it arrives. Before, a live row refused
another id as a duplicate and a hidden one gave way to any version, so a
removal was refused where the other id was live, and that device's next
snapshot brought the link back
([ADR 0096](../../docs/adr/0096-an-entry-link-is-its-natural-key.md),
`specs/tla/EntryLinkIdentity.tla`).

Because the triple is the identity, `updateLinkType` refuses to move a link
onto a relationship another live link already is: the receive would replace
that link rather than keep both. One residual remains. When a version moved
by a retype loses at its new triple, its old row is deleted, and a late copy
of its version from before the retype can be inserted again there.

```mermaid
stateDiagram-v2
  [*] --> Live: createLink / linkTaskToProject (derived id)
  [*] --> Hidden: createLink(hidden true)
  Live --> Hidden: updateLink(hidden true)
  Hidden --> Live: updateLink(hidden false) / createLink (same id, next version)
  Live --> Removed: removeLink / removeTypedLink / project or relationship unlink
  Hidden --> Removed: removeLink / removeTypedLink
  Removed --> Live: createLink / linkTaskToProject (same id, next version)
  note right of Removed
    deletedAt set, hidden true; kept and synced,
    excluded from every live-link read
  end note
```

# Related

* [Typed relationships and blockedness](../features/tasks/relationships.md) - how the task layer presents and derives from these.
* [Dependency-aware planning](../features/daily_os_next/dependency-aware-planning.md) - how the planner consumes `blocks`.
