---
type: Feature Module
title: Definition clocks
description: How entity definitions — categories, labels, habits, dashboards, measurables and speech dictionary entries — carry vector clocks, settle concurrent edits last-writer-wins under the join of both clocks, take part in sequence-log backfill, and how rows written before they carried clocks are migrated.
resource: ../../../lib/database/database_definitions.dart
tags: [sync, vector-clock, definitions, backfill, migration]
status: draft
generated: { by: claude-code/opus-5.5, at: 2026-10-07T02:00:00Z }
stale_after: 2027-01-07
sources:
  - id: gate
    resource: ../../../lib/database/database_definitions.dart
    title: JournalDb definition recency gate
    last_modified: 2026-10-07
  - id: local-write
    resource: ../../../lib/logic/persistence_definition_ops.dart
    title: Local definition writes and seeds
    last_modified: 2026-10-07
  - id: stamper
    resource: ../../../lib/features/sync/services/definition_clock_stamper.dart
    title: DefinitionClockStamper
    last_modified: 2026-10-07
  - id: receive
    resource: ../../../lib/features/sync/matrix/sync_event_processor_definition_handlers.dart
    title: Definition receive and sequence mapping
    last_modified: 2026-10-07
  - id: maintenance
    resource: ../../../lib/features/sync/repository/sync_maintenance_repository.dart
    title: backfillDefinitionClocks
    last_modified: 2026-10-07
  - id: deep-backfill
    resource: ../../../lib/features/sync/deep_backfill/definition_deep_backfill_store.dart
    title: DefinitionDeepBackfillStore
    last_modified: 2026-10-07
  - id: spec
    resource: ../../../specs/tla/DefinitionClocks.tla
    title: DefinitionClocks TLA+ model
    last_modified: 2026-10-07
  - id: pipeline-spec
    resource: ../../../specs/tla/SyncPipeline.tla
    title: SyncPipeline TLA+ model, entityDefinition family
    last_modified: 2026-10-07
---

Entity definitions replicate as whole documents in
`SyncMessage.entityDefinition`. Each version carries a vector clock, so a
version that was written knowing another supersedes it everywhere, and the
sequence log can tell when one went missing. The decision is recorded in
[ADR 0125](../../../docs/adr/0125-definitions-carry-vector-clocks.md); the
protocol is model-checked in
[`DefinitionClocks`](../../../specs/tla/README.md) and, for transport and
repair, in `SyncPipeline`'s `entityDefinition` family.

# Writing a version

Every local write goes through `PersistenceDefinitionOps._writeLocalEdit`
(categories, labels, habits, measurables and dictionary entries through
`upsertEntityDefinition`, dashboards through `upsertDashboardDefinition`). In
one journal transaction it reads the stored stamp, reserves this host's next
counter **on top of the stored clock** (`getNextVectorClock(previous: …)`,
payload type `entityDefinition`), and writes. The new clock dominates every
version this device holds, so the gate always accepts it and every peer that
receives it takes it. The reservation sits in `withVcScope`: a refused write
releases and burns the counter.

The write's `updatedAt` stays the caller's unless it does not pass the stored
one — a stale editor, a delete that kept the old stamp, a peer whose clock
runs ahead — in which case it is set 1 ms above it. Last-writer-wins only
decides between concurrent versions, and this keeps a write ahead of anything
its device had seen, even through the clockless fallback below.

Seeds — definitions a device derives on its own, today the speech dictionary
migration — reserve a counter only when no copy is stored, and keep their
`updatedAt`, so any real edit made elsewhere wins over them.

# The gate

`JournalDb._upsertDefinitionIfNotOlder` decides, in one transaction, what is
stored when a version arrives — from sync, a seed or a local write. Only the
stored document's `updatedAt` and `vectorClock` are decoded, since a legacy
dashboard may not parse.

```mermaid
flowchart TD
    A[incoming version] --> B{row stored?}
    B -- no --> W[write incoming]
    B -- yes --> C{incoming has a clock?}
    C -- no --> D{stored has a clock?}
    D -- yes --> K[keep stored]
    D -- no --> L1{incoming later?}
    L1 -- yes --> W
    L1 -- no --> K
    C -- yes --> E{stored has a clock?}
    E -- no --> L2{incoming later?}
    L2 -- yes --> W
    L2 -- no --> KS[keep stored;<br/>receive path stamps it]
    E -- yes --> F{compare clocks}
    F -- incoming dominates --> W
    F -- stored dominates --> K
    F -- equal --> L1
    F -- concurrent --> L3{incoming later?}
    L3 -- yes --> WJ[write incoming<br/>under the join]
    L3 -- no --> KJ[keep stored,<br/>rewrite its clock to the join]
```

*Later* is last-writer-wins: the later `updatedAt`, and on an exact tie the
greater canonical JSON of the document **without its clock** — devices that
joined different clocks into one version must still order it the same way.
Identical content counts as later, so a re-delivery of the stored version
rewrites it unchanged. Two different documents under one clock — which no
writer produces, but a hand-written or legacy row can — are ordered the same
way, so every device keeps the same one.

**The join is the resolution.** Two concurrent versions settle on one, stored
under the pointwise maximum of both clocks (`VectorClock.merge`). That clock
is strictly greater than each, so the next edit on either device supersedes
both; no counter is spent on the resolution and nothing is sent because of
it. A kept version's join is written into its stored JSON in place
(`json_set`), leaving the rest of the document untouched.

# Rows from before clocks

Definitions written by builds before this carry no clock. A clockless copy
never displaces a clocked row; a clockless row meets any copy by *later*
alone.

```mermaid
stateDiagram-v2
    [*] --> Clockless: written by an older build
    Clockless --> Clocked: local edit (own counter)
    Clockless --> Clocked: manual migration stamps it
    Clockless --> Clocked: a later clocked copy arrives
    Clockless --> Clocked: kept against a clocked copy, stamped over it
    Clocked --> Clocked: edit, or a dominating or concurrent copy (join)
```

**The manual migration.** *Settings → Sync → Sync health → Advanced
recovery → Repair vector clocks* runs `SyncStep.backfillDefinitionClocks` beside the
agent and entry-link clock steps. `SyncMaintenanceRepository.backfillDefinitionClocks`
lists every clockless definition, deleted and private ones included
(`JournalDb.clocklessDefinitions`), and `DefinitionClockStamper.stamp`s each:
this host's next counter, content and `updatedAt` unchanged. Re-read,
reservation, write and enqueue form one journal transaction, so a failed
enqueue rolls the stamp back, the counter is burned and the next run retries
the row.

**Running it on one device is enough.** When a clocked copy reaches a device
whose row is still clockless and the row is later, the gate keeps the row and
`SyncEventProcessor._stampIfKeptClockless` stamps it **on top of the copy's
clock**: the row now dominates the copy, and its content wins on every device.
Without that a device whose newer clockless row lost its sync before the
migration would keep it while the others kept the older one.

# Sequence log and backfill

Definitions are sequence-tracked under `SyncSequencePayloadType.entityDefinition`
(appended last: the index is persisted).

- **Send.** `prepareMessage` stamps `originatingHostId`;
  `enqueueEntityDefinition` binds this host's counter in the clock to the
  definition's id (`recordSentEntry`). Definitions do not collapse in the
  outbox.
- **Receive.** `_applyEntityDefinition` records the copy's clock
  (`recordReceivedEntry`) whether it was written or kept: a kept version
  supersedes or joins it, so its counters are no gap to ask for.
- **Answer.** A request for a definition counter is answered with the
  definition's current version (`JournalDb.definitionById` searches the six
  tables), through the same path as agent records and consumption events,
  with a hint when the current clock carries a later counter. Because the
  stored clock is the join of everything the row has met, any device that
  holds the definition covers every counter that went into it.
- **Deep backfill.** `DefinitionDeepBackfillStore` reads the six tables as one
  store, merged in id order.

# Gotchas

- **Ids are unique across the six tables.** `definitionById` returns the first
  table holding the id; UUIDs, and v5 UUIDs for dictionary terms, never
  collide.
- **The demo world writes clockless definitions** straight to its own
  database (`WorldHandle.writeEntityDefinition`); a demo world never syncs.
- **Re-sending is not migrating.** *Sync Entities* still re-enqueues every
  stored definition as it is, a clockless one included; that copy never
  displaces a clocked row, but it carries no counter either.

# Related

* [Vector clocks and conflicts](vector-clocks-and-conflicts.md) — the clock
  type and how journal entries resolve concurrency instead.
* [Sequence log and backfill](sequence-and-backfill.md) — the accounting the
  definitions now take part in.
* [Entity definitions](../../domain/entity-definitions.md) — what the six
  types are.
* [Speech dictionary](../speech/dictionary.md) — the one definition type with
  a seeding migration of its own.
