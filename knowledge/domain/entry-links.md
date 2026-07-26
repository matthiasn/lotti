---
type: Domain Model
title: Entry links
description: One row per relationship, eight variants sharing one shape, and why the type column is what keeps old consumers working.
resource: ../../lib/classes/entry_link.dart
tags: [domain, links, relationships]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T02:30:00Z }
stale_after: 2027-07-26
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

# Eight variants, one shape

`EntryLink` is a union of `basic`, `rating`, `project`, `blocks`, `followsUp`,
`duplicates`, `fixes`, `supersedes` — mirrored by `EntryLinkType`.

**Every variant has the same shape**: id, `fromId`, `toId`, timestamps, vector
clock. The relationship lives entirely in the **type column**.

That is the load-bearing design decision: because the shape is identical, every
existing `type = 'BasicLink'` consumer — recorded-time attribution, capture
attachment, the generic linked-entries list — stays **structurally blind** to
typed edges. Typed relationships were added without migrating a single consumer.

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
