---
type: Architecture
title: Persistence layer
description: The eleven Drift/SQLite databases, attachment storage, how connections are opened and migrated, and how writes reach the UI.
resource: ../../lib/database
tags: [architecture, persistence, drift, sqlite, migrations]
status: stable
generated: { by: claude-code/fable-5.1, at: 2026-09-05T14:00:00Z }
stale_after: 2027-03-05
sources:
  - id: sync-db
    resource: ../../lib/database/sync_db.dart
    title: SyncDatabase
    last_modified: 2026-09-05
  - id: agent-db
    resource: ../../lib/features/agents/database/agent_database.dart
    title: AgentDatabase
    last_modified: 2026-08-01
  - id: notifications-db
    resource: ../../lib/database/notifications_db.dart
    title: NotificationsDb
    last_modified: 2026-08-01
  - id: consumption-db
    resource: ../../lib/features/ai_consumption/database/consumption_database.dart
    title: ConsumptionDatabase
    last_modified: 2026-07-21
  - id: day-processing-db
    resource: ../../lib/features/daily_os_next/database/day_processing_db.dart
    title: DayProcessingDb
    last_modified: 2026-07-25
  - id: notifications
    resource: ../../lib/services/db_notification.dart
    title: UpdateNotifications token vocabulary
    last_modified: 2026-07-05
  - id: private-gate
    resource: ../../lib/database/database_config_flags.dart
    title: Config-flag cache and the private-visibility gate
    last_modified: 2026-07-26
  - id: db-common
    resource: ../../lib/database/common.dart
    title: openDbConnection, pragmas, backups
    last_modified: 2026-06-05
  - id: journal-db
    resource: ../../lib/database/database.dart
    title: JournalDb
    last_modified: 2026-09-05
  - id: journal-migration
    resource: ../../lib/database/database_migration.dart
    title: JournalDb migration strategy
    last_modified: 2026-09-05
  - id: image-path-migration
    resource: ../../lib/features/journal/service/image_path_migration_service.dart
    title: ImagePathMigrationService
    last_modified: 2026-08-15
  - id: image-paths
    resource: ../../lib/utils/image_utils.dart
    title: Journal image path resolution
    last_modified: 2026-08-15
  - id: backup-catalog
    resource: ../../lib/features/backup_restore/domain/profile_backup_catalog.dart
    title: Profile backup storage catalog
    last_modified: 2026-08-06
  - id: update-notifications
    resource: ../../lib/services/db_notification.dart
    title: UpdateNotifications
    last_modified: 2026-07-05
---

# One store per concern

Lotti is local-first: everything the user owns lives in the documents directory,
and nothing is required to leave the device. Rather than one monolithic schema,
the app runs **eleven Drift databases**, each with its own file, schema version
and migration history.

**Not every byte is in SQLite.** The databases hold structured data and metadata;
**audio recordings and images are separate files** under the documents directory,
referenced by path — the sync sender reads them through `AudioUtils.getAudioPath()`
and `getFullImagePath()` rather than pulling bytes out of a row. Backup and
migration work has to cover both, and embeddings are a third store again (below).

| Database | File | Schema | Owns |
|----------|------|--------|------|
| `JournalDb` | `db.sqlite` | 46 | Journal entities, tasks, links, tags, config flags — the primary store |
| `SyncDatabase` | `sync.sqlite` | 29 | Outbox, sequence log, host activity, inbound event queue, queue markers |
| `AgentDatabase` | `agent.sqlite` | 19 | Agent state, reports, observations, change proposals, wake history |
| `EditorDb` | `editor_drafts_db.sqlite` | 2 | Unsaved rich-text editor drafts |
| `ConsumptionDatabase` | `ai_consumption.sqlite` | 4 | AI token usage and the interaction ledger |
| `SettingsDb` | `settings.sqlite` | 1 | Key/value app settings, sync watermarks, saved filters |
| `Fts5Db` | `fts5_db.sqlite` | 1 | Full-text search index |
| `NotificationsDb` | `notifications.sqlite` | 1 | Scheduled and delivered notifications |
| `OnboardingMetricsDb` | `onboarding_metrics.sqlite` | 1 | First-run and activation measurement |
| `AiConfigDb` | `ai_config.sqlite` | 1 | Providers, models, prompts, inference profiles |
| `DayProcessingDb` | `day_processing.sqlite` | 1 | Daily OS day-processing outbox |

Splitting by concern is what makes a heavy background writer — sync ingestion,
agent wake runs — unable to block a foreground journal read behind the same
write lock. It costs cross-database joins, which the app does not do: features
that need data from two stores read both and combine in Dart.

Embeddings are the exception to "everything is Drift". Vector search uses
**ObjectBox** (`lib/features/ai/database/objectbox_embedding_store.dart`),
because it provides on-device approximate nearest-neighbour search that SQLite
does not.

# Opening a connection

Every database goes through `openDbConnection()`, so they share one set of
decisions:

```mermaid
flowchart TD
  Call["openDbConnection(fileName, background, readPool, slowQueryThreshold)"] --> Lazy["LazyDatabase — nothing opens until first use"]
  Lazy --> Mem{"inMemoryDatabase?"}
  Mem -->|yes, tests| Memory["NativeDatabase.memory()"]
  Mem -->|no| Dir["Resolve documents dir, create parents,<br/>point sqlite3.tempDirectory at the temp dir"]
  Dir --> Bg{"background?"}
  Bg -->|yes| Isolate["NativeDatabase.createInBackground(readPool: n)"]
  Bg -->|no| Same["NativeDatabase() on the calling isolate"]
  Memory --> Intercept
  Isolate --> Intercept
  Same --> Intercept["interceptWith(SlowQueryInterceptor)"]
```

- **Background isolates by default.** `background: true` moves SQLite work off
  the UI isolate. Callers can opt into same-isolate connections with `false`;
  `SettingsDb` defaults to that mode, as do many focused tests.
- **`readPool` offloads heavy reads** to read-only isolates. It only takes
  effect when `background` is true, and `inMemoryDatabase: true` bypasses it —
  a test that wants to exercise a pool must be file-backed.

  | Database | `readPool` |
  |----------|-----------:|
  | `db.sqlite` (`JournalDb`) | 4 |
  | `agent.sqlite` (`AgentDatabase`) | 2 |
  | `notifications.sqlite` (`NotificationsDb`) | 2 |
  | `ai_consumption.sqlite` (`ConsumptionDatabase`) | 1 |
  | `day_processing.sqlite` (`DayProcessingDb`) | 1 |

  Anything not listed — including `sync.sqlite` — takes `openDbConnection`'s
  default of 0.

  **A pool is not a free win, and `readPool: 0` is not a substitute for a
  transaction.** A single executor serialises individual *statements*, not
  *sequences*: a read, an `await`, and a later write can still interleave with
  another caller's statements on the same executor. So a check-then-act pair
  that is not wrapped in a transaction is **already racy at 0**.

  What a pool changes is how easy the race is to hit. Pooled reads can also
  serve a snapshot taken before a queued write commits, which widens the window
  from "interleaved between statements" to "stale by a whole transaction".

  Giving `sync.sqlite` a pool was attempted and abandoned on those grounds
  (#3720): review surfaced four read-after-write pairs in the outbox,
  sequence-log and inbound-queue paths — none inside a transaction — that the
  pool would have made materially more likely to fire, without the PR
  addressing any of them. The durable fix for those sites is a transaction
  around the read and the write, which is worth doing whether or not a pool is
  ever added.
- **Pragmas are applied per connection** through the `setup` callback, so read-
  pool isolates inherit them:

  | Pragma | Value | Why |
  |--------|-------|-----|
  | `journal_mode` | `WAL` | Concurrent readers during writes |
  | `busy_timeout` | `5000` | Wait rather than fail on contention |
  | `synchronous` | `NORMAL` | WAL-appropriate durability/speed trade |
  | `wal_autocheckpoint` | `200` pages | Lowered from SQLite's 1000. Slow-query capture caught a 9-minute stall on a `sync_sequence_log` read whose p95 is under 60 ms — a checkpoint pause, not a bad plan. Shorter WAL means smaller, more frequent checkpoints and a narrower starvation window. |

- **`PRAGMA foreign_keys = ON` is connection-local**, so `JournalDb` re-applies
  it in `beforeOpen` on every connection, not once at migration time.

# Slow-query capture

Every connection is wrapped in a `SlowQueryInterceptor` with a default
threshold of **10 ms** — a fraction of the 16 ms frame budget, so anything it
logs is already a meaningful slice of a frame. Writing is gated behind the
logging domain in *Settings → Advanced → Logging Domains*, so the interceptor
costs nothing until someone is investigating.

**There is a second tier at 200 ms**, and it does more than log louder. A query
crossing `superSlowThreshold` has its **`EXPLAIN QUERY PLAN` captured** (selects
only) and is duplicated into a separate `super_slow_queries` file alongside the
`slow_queries` one. So the 10 ms tier tells you *that* something is slow, while
the 200 ms tier tells you *why* — start with the super-slow file, because it is
the only one carrying a plan.

The threshold deliberately does not catch N+1 chains: each individual link sits
under the bar. Counting round-trips in tests catches those chains;
`JournalDb` coalesces adjacent entity lookups to reduce them. Deep-dive captures pass
`Duration.zero` to surface every query.

# Migrations

`JournalDb`, `SyncDatabase`, and `AgentDatabase` each have substantial migration
histories. The journal strategy lives in `database_migration.dart` and
`database_migration_recent.dart`:

1. `onUpgrade` takes a timestamped backup first — `backup/db.<ts>.sqlite` —
   unless the database is in-memory. A failed backup is logged, not fatal.
2. Version steps run in order, adding tables, columns and partial indexes.
   Current index definitions may reference columns absent in historical schemas:
   the task priority index is created only after v29 adds priority columns, even
   for a journal upgrading from before v25.
3. Partial index DDL lives in top-level constants used by migrations. Callers
   can add `IF NOT EXISTS` with `replaceFirst` where needed.
4. `beforeOpen` repairs the specific indexes named there; it does not rebuild
   every index in the schema.

Historical migration fixtures must describe the schema at their declared
`user_version`, without future columns added merely to make current DDL pass.
The v18 fixture in `test/database/database_test.dart` exercises the complete
upgrade and verifies that its existing row survives with default priority.

The indexes matter: `idx_journal_tasks_due_open` is keyed on the denormalized
`due_at` column added in v41, which replaced an expression index over
`json_extract(serialized,'$.data.due')`. The column lets the planner stream
`ORDER BY due_at ASC` straight from the index instead of parsing JSON per row.

They also cost: every journal upsert rewrites the row, so each index is paid
for on every write. v46 dropped nine that duplicated an index SQLite already
had — the single-column DESC twins of the `date_from`/`date_to` indexes (an
index is walked in either direction), the `idx_*_definitions_id` indexes on
primary keys, the single-column `linked_entries` indexes shadowed by their
composite prefixes, and the lone boolean `idx_linked_entries_hidden`. A new
index needs a query that the planner demonstrably picks it for; the EXPLAIN
tests under `test/database/` are where that is shown.

# Write atomicity

Three write paths do a check before they write, and each runs the check and
the write in **one Drift transaction**. Drift serialises transactions on the
write connection, so the second of two concurrent writes to the same row waits
for the first and then sees its result — a pooled read snapshot cannot slip
between the check and the write.

- **`JournalDb.updateJournalEntity`** reads the stored row, compares vector
  clocks, upserts, records or resolves the conflict row, and reconciles the
  `labeled` table inside the transaction. Two concurrent writes of one id with
  concurrent clocks therefore end with one applied and one recorded in
  `conflicts`, never a silent overwrite. The JSON sidecar — the sync payload —
  is written **after** commit, so it never describes a row that rolled back and
  the writer lock is never held across file I/O. The sync inbound handler wraps
  the same call together with the entity's embedded links in an outer
  transaction; the inner one nests.
- **`JournalDb.upsertEntryLink`** runs its equality pre-read, the
  `(from_id, to_id, type)` duplicate check, the tombstone replacement and the
  upsert the same way, so a local link creation racing the same link arriving by
  sync is blocked as a duplicate instead of colliding on the UNIQUE constraint.
  A failing pre-read propagates; it is not swallowed.
- **Definition upserts** (`upsertEntityDefinition` and the five typed
  variants) refuse a definition that is **strictly older** than the stored one.
  Definitions replicate as whole documents and every local edit path refreshes
  `updatedAt`, so "the later edit wins" — and this gate is where that rule is
  enforced against a delayed sync event or a historical re-send. When both
  sides carry a vector clock that orders them the clock decides; otherwise
  `updatedAt` does, an exact tie applies the incoming copy, and the stored row
  is read by id with no `deleted`/`private` filter so an older live copy cannot
  resurrect a newer deletion. `PersistenceDefinitionOps` re-stamps a local edit
  the gate rejected — a sync landed while the editor was open — and writes it
  again, so a user's action always applies and wins on every peer.

# From write to UI

Journal writes announce themselves to the UI through
`UpdateNotifications`, which fans one write out to three streams:

```mermaid
flowchart LR
  Write["Repository / PersistenceLogic write"] --> Notify["UpdateNotifications.notify(affectedIds, fromSync:)"]
  Notify --> Batch["Debounce: 100 ms local, 1 s sync"]
  Batch --> All["updateStream — everything"]
  Batch --> Local["localUpdateStream — local writes only"]
  Batch --> Sync["syncUpdateStream — sync arrivals only"]
  All --> UI["Riverpod providers, list and detail widgets"]
  Local --> Wake["Agent wake orchestration"]
  Sync --> Audio["Synced-audio auto-trigger dispatcher"]
```

Picking the right stream is a correctness decision, not a preference:

- **`localUpdateStream`** drives agent wakes. If wakes listened to everything,
  a synced change would wake an agent on the receiving device for work the
  originating device already did.
- **`syncUpdateStream`** drives the synced-audio auto-trigger. If it listened to
  local edits, typing in a linked task would re-process the same audio.
- **`updateStream`** is for UI. `notifyUiOnly` exists to refresh widgets without
  reaching the wake orchestrator at all.

Notifications are **batched** — 100 ms for local writes, 1 s for sync arrivals —
so a bulk import or a sync catch-up produces a handful of rebuilds rather than
thousands.

## What a notification carries

The payload is a `Set<String>` of **routing keys**, and they are heterogeneous —
this is the part that surprises people. `JournalEntityExtension.affectedIds` seeds
the set with the **entity's own id**, adds **related ids** (a habit completion adds
its `habitId`, a checklist its items), *and* adds a static type token; a task-agent
notification carries `agentId` and `taskId` the same way. So a listener may be
matching an id, a type, or a change class:

| Kind | Examples |
|------|----------|
| **Entity ids** | the written entity's `id`, plus linked ids the write touched |
| Static type tokens — **most** `JournalEntity` variants, not all sixteen | `TEXT_ENTRY`, `TASK`, `AUDIO`, `IMAGE`, `EVENT`, `SURVEY`, `WORKOUT`, `HABIT_COMPLETION`, `AI_RESPONSE`, `DAY_PLAN`, `RATING`, `PROJECT`. `checklist`, `checklistItem`, `measurement` and `quantitative` have no token of their own |
| Definition and settings changes | `CATEGORIES_CHANGED`, `HABITS_CHANGED`, `DASHBOARDS_CHANGED`, `MEASURABLES_CHANGED`, `LABELS_CHANGED`, `LABEL_USAGE_CHANGED`, `SETTINGS_CHANGED`, `PRIVATE_FLAG_TOGGLED` |
| Cross-cutting | `LINK_CHANGED`, `AGENT_CHANGED`, `AI_CONSUMPTION_CHANGED`, `INBOX_CHANGED` |
| **Dynamic, prefixed** | `PROJECT_ENTITY_UPDATE:<projectId>`, and `PROPAGATED::<token>` below |

**No entity *data* travels** — only identifiers and labels — so a listener always
re-reads. What it must not assume is that a key is one of the static tokens: two of
the five kinds are computed at emit time.

**The `PROPAGATED::` prefix is additive, and it exists for the wake orchestrator.**
When a write is a *fan-out* — the project that gained a task because someone linked
one, rather than the task that was edited — the emitter puts **both** forms in the
same set: the bare token *and* `PROPAGATED::<token>`. The bare one is kept
deliberately, so consumers reacting to the legacy form keep refreshing.

So a UI provider matching only the bare token is **correct and complete** — it
cannot miss a fan-out, because the bare token is always there too. The prefix is
for the one consumer that needs to tell the two apart:
`WakeBatchRouter` **can** defer a propagated-only match to the next morning, so a
project agent does not spend tokens every time a task appears under it.

**That deferral is opt-in per subscription, not a global rule.** `WakeOrchestrator`
defaults `deferPropagatedMatches` to `true`, and subscriptions that need immediacy
pass `false` — task agents and the sync event handlers both opt out.

`agentExecutionZoneKey` is the other half of the same concern. Writes made *inside*
an agent's own execution run in a zone carrying that key, which
`PersistenceLogic` reads as `isAgentExecution` — so an agent's own writes do not
feed back as a reason to wake it again.

# Private visibility is gated three different ways

`_JournalDbConfigFlags` owns the in-memory config-flag cache and
`_queryWithPrivateFilter`, which dispatches a read to an all-private or a
filtered variant:

```mermaid
flowchart TD
  Q["a read that gates"] --> G["_queryWithPrivateFilter"]
  G --> F{"config flag 'private' on?"}
  F -->|yes| All["allPrivate() — the unfiltered query"]
  F -->|no| Filt["filtered([false]) — non-private rows only"]
```

**That helper is only one of three mechanisms**, which is why grepping for it
undercounts the gate badly:

| Mechanism | Where |
|-----------|-------|
| `_queryWithPrivateFilter` | `journal_queries`, `definitions`, `project_queries`, `links_ratings` |
| **`privateStatuses` passed as a parameter**, so the caller decides | `task_queries`, `task_query_builders`, `task_due_queries` |
| **Raw SQL reading the flag directly** | `insights_queries` uses a `private_flag` CTE; `data_queries` uses a direct `config_flags` subquery in `getHabitCompletionsInRange` |

Of the ten query-bearing mixins, **nine gate on private one of these ways**. The
exception is `_JournalDbEntityOps`, which is maintenance and write operations
rather than a read path.

## What is genuinely not filtered

Not "by-id reads" as a class — `getLabelDefinitionById` and the id-**batch**
journal reads (`getJournalEntitiesForIds` and friends) go through the helper.
What does not filter is narrower:

- **`journalEntityById`** — the single-entity read behind every detail page.
- `getDayAudioEntries`.
- `countAllJournalEntries`, which counts deleted rows too.

So the shape is: **lists, searches and batches thin out private entries; fetching
one entity you already have the id for does not.** That is coherent with what the
flag is for — it changes what browsing surfaces, not what you can open when you
already hold the identifier.

Two consequences worth holding on to:

- **The gate is a read filter, not encryption, and not a boundary.** The row is
  stored like any other, a detail page shows it, and a deep link to one resolves.
  See [security and privacy](security-and-privacy.md).
- **A new list or search query must gate deliberately**, by one of the three
  mechanisms above. Nothing in the type system obliges it, so a read that queries
  the journal tables directly simply returns private rows — and looks like a
  working query.

# Backups and maintenance

## Journal image paths and screenshot repair

`JournalImage.data.imageDirectory` stores a platform-neutral,
documents-relative directory with forward slashes and leading/trailing
separators, for example `/images/2026-08-15/`. It is not an absolute filesystem
path. Writers strip the metadata-only leading separator and construct physical
paths with `path.join`; AI image readers resolve only this canonical location
inside the documents directory.

A legacy screenshot writer persisted `images/...` and concatenated it directly
to the documents path. A profile rooted at `Documents` therefore wrote the file
under the sibling `Documentsimages` directory. Inline rendering historically
used the same malformed concatenation, so the screenshot remained visible,
while AI's containment check correctly rejected it as outside the profile.

Settings → Advanced → Maintenance exposes the explicit, repeatable **Repair
screenshot storage** pass implemented by `ImagePathMigrationService`. It scans
all non-deleted `JournalImage` rows, including private, starred, and every flag
state. For each legacy file it:

1. copies to a uniquely named temporary file in the canonical target directory;
2. verifies length and SHA-256 before atomically renaming the temporary file;
3. persists the canonical metadata through `PersistenceLogic`; and
4. deletes the legacy file only after the metadata write succeeds.

If a crash or persistence failure interrupts the pass, the legacy source is
retained and a later run can finish safely. Existing canonical files are never
overwritten with different bytes; conflicts, genuinely missing files, invalid
paths, and failures are counted and reported without aborting the whole pass.
The normal display resolver retains a read-only legacy fallback until repair,
so affected screenshots do not disappear from existing journal entries.

`createDbBackup(fileName)` copies a database to
`backup/db.<yyyy-MM-dd_HH-mm-ss-S>.sqlite`. It runs automatically before a
`JournalDb` migration and on demand from *Settings → Advanced → Maintenance*.
Its timestamp comes from `package:clock`'s `clock.now()`, and so does every
other instant the database layer stamps itself — the `updated_at` on a journal
upsert, conflict rows, outbox enqueue stamps, leases and retries, sync
watermarks, editor drafts and settings — so tests drive all of them with
`withClock`. The one SQL-side
default, the outbox `created_at`/`updated_at` pair, is Drift's
`currentDateAndTime`, which SQLite evaluates on each insert; a
`Constant(DateTime.now())` default would bake the app-launch instant into the
`CREATE TABLE` statement instead.

That helper is a **legacy per-database fallback**, not a supported profile
backup. It copies only the main SQLite file, has no store identity, manifest,
checksum, media coverage, encryption, coordinated quiescence, or restore path.
A raw copy is not safe while WAL-backed writers are active.

The implementation-consumable profile inventory now lives in
`ProfileBackupCatalog`. It includes authoritative databases, media and sync
sidecars; marks FTS, ObjectBox embeddings and waveform previews rebuildable;
excludes logs, sibling guest worlds, the device-global profile registry and the
legacy `backup/` directory. It also excludes the legacy Daily OS file outbox
after its mandatory startup import into `day_processing.sqlite`, including
recovered atomic scratch files retained for rollback. SQLite journal companions
remain a hard rejection because they show that strict quiescence has not been
proven. `QuiescedProfileSnapshotService`
can then copy a closed profile into a partial stage, rehash the source, validate
SQLite integrity and schema versions, verify the manifest against the payload,
and publish with one rename. It does not stop writers; lifecycle orchestration
must satisfy that precondition. The full contract and remaining runtime layers
are in [backup and restore](../features/backup-and-restore.md).

`lib/database/maintenance.dart` owns physical database upkeep: whole-database
deletion (`deleteAgentDb`, `deleteEditorDb`, `deleteSyncDb`), FTS rebuilding,
and the `sent`-outbox purge. Historical re-send orchestration belongs to Sync
and lives in `lib/features/sync/services/historical_sync_service.dart`; it uses
database and repository row APIs without making queueing, retry, or Sync result
types part of the database maintenance layer. **The deleted-entry purge is not
in either service** — `purgeDeleted` lives in
`lib/database/database_entity_ops.dart` alongside the rest of `JournalDb`'s
entity operations, which is where to look for it.

# Where to look

| Concern | File |
|---------|------|
| Connection, pragmas, backup helpers | [`lib/database/common.dart`](../../lib/database/common.dart) |
| Primary store and its query mixins | [`lib/database/database.dart`](../../lib/database/database.dart) |
| Migration steps | [`lib/database/database_migration.dart`](../../lib/database/database_migration.dart), [`database_migration_recent.dart`](../../lib/database/database_migration_recent.dart) |
| Sync-side tables | [`lib/database/sync_db.dart`](../../lib/database/sync_db.dart) |
| Change notification | [`lib/services/db_notification.dart`](../../lib/services/db_notification.dart) |
| Slow-query interceptor | [`lib/database/slow_query_logging.dart`](../../lib/database/slow_query_logging.dart) |
| Maintenance operations | [`lib/database/maintenance.dart`](../../lib/database/maintenance.dart) |
| Historical Sync staging and retry | [`lib/features/sync/services/historical_sync_service.dart`](../../lib/features/sync/services/historical_sync_service.dart) |
| Journal image paths and legacy screenshot repair | [`lib/utils/image_utils.dart`](../../lib/utils/image_utils.dart), [`lib/features/journal/service/image_path_migration_service.dart`](../../lib/features/journal/service/image_path_migration_service.dart) |
| Profile backup inventory, manifest and staging | [Backup and restore](../features/backup-and-restore.md) |

Related: [bootstrap and dependency injection](bootstrap-and-di.md) for when each
database is registered, [the sync feature](../features/sync/) for what fills
`sync.sqlite`.
