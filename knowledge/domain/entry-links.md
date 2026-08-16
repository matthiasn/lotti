---
type: Domain Model
title: Entry links
description: One row per relationship, nine variants sharing one shape, and why the type column is what keeps old consumers working.
resource: ../../lib/classes/entry_link.dart
tags: [domain, links, relationships]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T16:00:00Z }
stale_after: 2027-07-12
sources:
  - id: entry-link
    resource: ../../lib/classes/entry_link.dart
    title: EntryLink union and EntryLinkType
    last_modified: 2026-07-25
  - id: adr-0042
    resource: ../../docs/adr/0042-typed-task-relationship-links.md
    title: ADR 0042 — Typed task relationship links
    last_modified: 2026-07-24
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

That is a real constraint, not an encoding detail: **a soft-deleted link cannot be
excluded by a column predicate.** It would take
`json_extract(serialized, '$.deletedAt')` — a shape this codebase does use
elsewhere, including an index on `json_extract(serialized, '$.data.due')` — but no
link query does it.

So the filtering happens in Dart instead: `TaskDependencyResolver`,
`TaskBlockersController` and `TaskLinkGroupsController` each **keep only rows whose
`deletedAt` is null**, after deserializing every row the query returned. Any new
link consumer inherits that obligation, and forgetting it means silently treating
removed relationships as live.

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
(`entryLink`), sequence-tracked like journal entities.

# Related

* [Typed relationships and blockedness](../features/tasks/relationships.md) - how the task layer presents and derives from these.
* [Dependency-aware planning](../features/daily_os_next/dependency-aware-planning.md) - how the planner consumes `blocks`.
