# ADR 0044: Day Processing Outbox Storage

## Status

Accepted

## Date

2026-07-24

## Context

### What the outbox is

`DayProcessingOutboxRepository` is the device-local durable record of
pending derived work for Daily OS: transcribe this recording, parse this
capture, draft this day, refine this plan. ADR 0031 introduced it for
transcription; ADR 0032 phase 1 extended it to agent jobs. It carries
deterministic job ids (`transcribe_<recordingSessionId>`,
`parse_<captureId>`, `draft_<dayId>`, `refine_<dayId>_<n>`), lease/claim
fencing, attempt counters, failure classification, and hard
`retryNotBefore` boundaries.

It has a second, deliberate role. From the class docstring: *"Jobs remain
after success as the local processing ledger consumed by Activity and
startup repair."* Terminal rows are kept on purpose —
`DayActivityRepository` (`day_activity_repository.dart:85`) and
`DayAudioReviewFence` (`day_audio_review_fence.dart:57`) both read the
whole set.

### The storage choice was never evaluated

ADR 0031 section 3 asserts the mechanism without comparing storage: *"A
checksummed, file-backed job store (deterministic job id per recording
session) with lease/claim semantics, exponential jittered backoff, hard
`retryNotBefore` boundaries, and failure classification."*

Its rejected-alternatives list contains two entries, both sound and
neither about a table:

- *"Matrix sync outbox as the job queue — the sync outbox transports
  already-durable entities; it does not represent pending inference."*
- *"In-memory wake/processing intent — an app exit must not lose the
  user's request to have a recording transcribed."*

The first argues against reusing **that** table. The second argues against
**no** durability. Neither argues against a device-local table, which was
never considered.

### What the filesystem design costs

`_readAllUnsafe()` (`day_processing_outbox_repository.dart:698`) does
`rootDirectory.listSync()` and, for every `*.json`, reads it,
JSON-decodes the envelope, verifies its SHA-256, decodes the payload, and
then sorts the whole list. It backs `claimNext` (`:447`), `getAll`
(`:417`), and `signalConnectivityRestored` (`:668`).

`DayProcessingRuntime.drainAndSchedule` (`day_processing_runtime.dart:74`)
calls `drain()` — a `claimNext` per processed job plus one idle
`claimNext` — and then `getAll()` to choose the next schedule. So one
nudge costs several full-directory scans. Nudges fire on every outbox
mutation (`runtime.dart:44` subscribes to `repository.changes`), on
connectivity restore, at startup, and on retry wakeups.

Because terminal jobs are retained as the ledger, that scan set grows for
the life of the install. Every recording adds at least two job files;
every planned day adds more. **Per-action work on the main isolate grows
linearly with app age**, and the ledger — the part that is retained on
purpose — is what grows.

The design also hand-rolls what a database provides: SHA-256 integrity
envelopes, atomic-rename writes, partial-file recovery
(`_recoverPartials`), corrupt-file quarantine (`_quarantine`), and a
tail-chained mutex (`_serialize`) to keep mutations from interleaving.

### We already learned this lesson, with numbers

`SyncDatabase` (`lib/database/sync_db.dart`) is device-local and already
runs two durable job queues in SQLite.

The `Outbox` table (`sync_db_tables.dart:85`) has `status`, `retries`,
`priority`, timestamps and a dedup key, with
`idx_outbox_status_priority_created_at ON outbox (status, priority,
created_at)` — the index shape that makes prioritized claiming an
`ORDER BY … LIMIT 1`. ADR 0013 is its decision record.

`inbound_event_queue` is a closer analogue still. Its columns map almost
one-to-one onto `DayProcessingJob`: `attempts`, `next_due_at`,
`lease_until` (*"0 = not leased; peek stamps this to `now +
leaseDuration` atomically"*), a text `status`, `committed_at`,
`last_error_reason`. Its `applied` status is documented as *"kept as an
append-only ledger for traceability"* — the same ledger role, solved with
partial indexes that exclude terminal rows from every hot query:

> Drain-path index. Partial on active statuses so the applied ledger
> (which can grow unbounded over time) is excluded from the index and the
> worker's peek query scans only the rows it can actually drain.

And the cost of *not* doing that was measured in this codebase
(`sync_db_tables.dart:287-296`):

> Without this partial the query full-scans the entire queue table on
> every worker idle tick — on a desktop mid-drain we measured 3500+ scans
> totalling 73s of DB time per hour with p95=46ms and max=2.3s.

That is the day-processing outbox's failure mode exactly: a full scan of
a ledger-bearing store on every idle tick. The sync queue fixed it with a
partial index. A directory of JSON files has no equivalent — there is no
way to index a subset of files, so the ledger and the drain path are
inseparable by construction.

## Decision

Move the day-processing outbox into a device-local Drift table.

### 1. A feature-owned database, not an existing one

A new `DayProcessingDb` under
`lib/features/daily_os_next/database/`. This matches how features own
their storage here (`features/agents/database/agent_database.dart`,
`features/ai_consumption/database/consumption_database.dart`,
`features/ai/database/ai_config_db.dart`).

Not `SyncDatabase`: ADR 0031's rejection of the sync outbox stands — that
database is the Matrix transport's domain. Not the agent database:
`agent_entities` rows sync between devices, and job state (claims,
leases, attempt counts) is strictly device-local and must never leave the
device.

### 2. Schema mirrors the existing job envelope

One row per job, primary key on the existing deterministic `id`, so
enqueue stays an idempotent upsert and the intent-conflict check is a
column comparison. The envelope columns (`status`, `day_id`, `kind`,
`created_at`, `updated_at`, `requested_at`, `next_attempt_at`,
`attempts`, `generation`, `claim_token`, `lease_until`,
`retry_not_before`, `last_failure_class`, `last_error`,
`result_transcript`, `result_entity_id`, `completed_at`) become real
columns; the kind-specific payload and `run_keys` stay serialized JSON,
as they are today.

### 3. Partial indexes separate the drain path from the ledger

Modelled directly on `inbound_event_queue`:

- Drain index over active statuses only — `queued`, `running`,
  `waitingForNetwork`, the three states `isDue` can return true for —
  keyed on the due-time ordering the claim uses. Terminal ledger rows
  are excluded, so ledger growth cannot slow claiming.
- A `(day_id, …)` index for Activity.

An index only helps if the readers change with it, so the callers are
part of this decision rather than a follow-up. All three current
whole-store readers become bounded queries:

- `DayActivityRepository` (`day_activity_repository.dart:85`) calls
  `outbox.getAll()` and keeps `job.dayId == dayId && job.activityEntryId
  != null`. It gains a day-scoped repository method backed by the day
  index (`WHERE day_id = ?`), so Activity stops reading the ledger of
  every other day.
- `DayAudioReviewFence._sweep()` (`day_audio_review_fence.dart:57`)
  calls `outbox.getAll()` and immediately skips every terminal job. It
  gains an active-status transcription query — served by the drain index
  — so sweep cost tracks outstanding work rather than install age.
- `DayProcessingRuntime.drainAndSchedule`
  (`day_processing_runtime.dart:82`) calls `getAll()` only to find the
  next due time. That becomes a `MIN(next_attempt_at)` probe over the
  drain index, the same shape as `inbound_event_queue`'s
  `earliestReadyAt`.

With those three converted, no caller reads the whole store and
`getAll()` is removed rather than left as a trap for the next reader.

### 4. Claiming becomes one conditional statement

Claim is `UPDATE … SET status='running', claim_token=?, lease_until=? …
WHERE id=? AND <due predicate>` guarded by affected-row count; fenced
mutations become `WHERE id=? AND claim_token=? AND status='running'`.
This is strictly stronger than today's read-then-write under a Dart
mutex.

**Ordering contract.** Selection is `SELECT … WHERE <active statuses>
AND <due predicate> ORDER BY … LIMIT 1`. The order key is deliberately
*not* a stored `priority` column. The sync outbox can store one
(ADR 0013) because its priorities are intrinsic to the message type;
day-processing priority is relative to the day the user is currently
looking at, so a stored column would have to be rewritten on every
navigation. The key is therefore a query-time expression bound to the
viewed day, ahead of the due-time ordering:

```sql
ORDER BY CASE day_id WHEN :viewedDay THEN 0
                     WHEN :today     THEN 1
                     WHEN :tomorrow  THEN 2
                     ELSE 3 END,
         next_attempt_at
```

The partial index serves the `WHERE`, so that expression is only
evaluated over rows that are actually claimable — bounded by outstanding
work, not by install age. Until priority-aware claiming ships as its own
change, the clause is `next_attempt_at` alone and the index serves it
directly. Moving between the two needs no schema change.

**What replaces the integrity machinery, precisely.** `_serialize` is
replaced by transactions. `_recoverPartials` and the atomic-rename write
are replaced by transaction atomicity: they exist to make a half-written
record impossible, which is what a rollback journal and WAL guarantee.

The SHA-256 envelope and `_quarantine` are **not** replaced, and that is
an accepted trade-off rather than an equivalence. They detect corruption
of an individual job record at rest and isolate the bad record so the
rest still drain. SQLite does not checksum data pages by default — WAL
frame checksums protect recovery, not stored pages — so the failure mode
changes shape, from one unreadable job file to a malformed-database
error, and the unit of recovery becomes the database rather than the
record.

That is acceptable here because the outbox already has a
record-independent recovery path: startup repair rebuilds jobs from
persisted `dayContext` provenance in the journal, which is the authority
for what the user actually recorded. A corrupt processing database can
therefore be discarded and rebuilt, where per-record checksums would only
have identified which single job to drop. If corruption is ever observed
in practice, `PRAGMA integrity_check` on open — or SQLite's checksum VFS
— restores detection without revisiting this decision.

Job lifecycle is unchanged; only its storage moves:

```mermaid
stateDiagram-v2
    [*] --> queued: enqueue (deterministic id)
    queued --> running: claim (lease + token)
    running --> succeeded: markSucceeded
    running --> queued: markFailure (retryable / missingAsset)
    running --> waitingForNetwork: markFailure (network)
    running --> waitingForUser: markFailure (setupRequired)
    running --> failed: markFailure (deterministic)
    running --> queued: lease expiry (crash recovery)
    waitingForNetwork --> queued: connectivity restored
    failed --> queued: retryNow / re-enqueue
    waitingForUser --> queued: retryNow / re-enqueue
    queued --> cancelled: cancel (recording deleted)
    succeeded --> ledger: no further processing
    cancelled --> ledger: no further processing
    ledger --> queued: re-enqueue (re-arm, fresh attempts)
    ledger --> [*]: retention prune
    note right of ledger
        Retained, not deleted. Activity and
        startup repair read these rows; the
        drain index excludes them. Only the
        retention prune removes them.
    end note
```

### 5. Retention becomes a policy, not a rewrite

Independently of any window, the partial indexes keep the ledger off the
hot path, so retention stops being a performance necessity and becomes a
disk-footprint and product question: how far back should Activity show
processing history?

The starting policy:

- **Eligible:** rows in a terminal status (`succeeded`, `cancelled`)
  whose `completed_at` is older than **90 days**.
- **Never eligible:** every non-terminal row, regardless of age. A job
  parked in `failed`, `waitingForUser` or `waitingForNetwork` is
  outstanding user intent that `retryNow` and re-enqueue can still
  resurrect, so age alone must never delete it. This keeps ADR 0031's
  durability guarantee intact.
- **Trigger:** one `DELETE` on the existing startup-repair pass, which
  already runs once per app start before the runtime drains
  (`DayProcessingRuntime.drainAndSchedule` gates on `_repairComplete`).
  No separate scheduler, no periodic timer.

90 days is chosen to comfortably outlive Activity's practical scroll-back
and to survive a long offline gap; it is a number to revisit if Activity
ever grows a longer history surface, not a constant to treat as load
bearing. The prune is a single indexed `DELETE` and is safe to interrupt
— a partial prune simply leaves rows for the next start.

### 6. Migration preserves in-flight work

A database transaction cannot span filesystem changes, so the cutover
needs a write barrier — otherwise a job enqueued after the scan but
before the sentinel would exist only on disk and become invisible the
moment the repository switches. Counting rows does not close that race,
because the count can match while the *identities* differ.

1. **Quiesce first.** Migration runs during app start, before
   `DayProcessingRuntime.start()` and before any enqueue path is wired
   up, so no writer is active against either store. This is the write
   barrier; everything below assumes it.
2. Import every job file into the table in one transaction. Deterministic
   ids make this an idempotent upsert.
3. **Verify by identity, not by count.** Re-scan the directory and
   compare the *set of job ids* against the table. If the re-scan turns
   up ids the table lacks, import those and repeat. Publish the sentinel
   only after a re-scan that adds nothing.
4. Write the sentinel. The repository reads the table from that point on.
   Until the sentinel exists the filesystem remains authoritative, so a
   crash at any point before step 4 simply re-runs the whole migration on
   the next start.
5. Leave the job files in place for one release, then delete them in a
   follow-up. They are dead weight, and they are also a free rollback.
6. Startup repair — which rebuilds jobs from persisted `dayContext`
   provenance in the journal — is unchanged and remains the second safety
   net for anything that still slips through.

The durability guarantee from ADR 0031 is unchanged: nothing the user
recorded loses its pending transcription across the migration.

## Consequences

- Claim cost stops depending on install age; it becomes an indexed lookup
  over active rows only.
- Priority-aware claiming (the fix for head-of-line blocking, where the
  day the user is looking at waits behind unrelated days) becomes an
  `ORDER BY` clause over a candidate set the partial index already
  bounds, with no schema change. Note this is weaker than the sync
  outbox's fully-indexed `idx_outbox_status_priority_created_at`: our
  order key is viewer-relative, so it is a query-time expression and the
  sort is not index-served. The sort input is bounded by outstanding
  jobs, which is the property that matters.
- Activity reads one day instead of the full ledger, and the review-fence
  sweep reads only non-terminal transcription jobs.
- The concurrency and torn-write machinery (`_serialize`,
  `_recoverPartials`, atomic-rename writes) is deleted outright.
  Per-record corruption detection (SHA-256 envelope, `_quarantine`) is
  given up rather than replaced — see the threat model in decision 4.
- Costs: one schema migration, one more database connection, and the loss
  of on-disk inspectability during debugging. The last is mitigated by a
  debug dump if it is ever missed in practice.
- Risk is concentrated in the migration. It is bounded by idempotent
  deterministic ids, verify-then-sentinel, retaining the files for a
  release, and the existing startup repair path.

## Rejected alternatives

- **Keep files, add pruning and an in-memory index.** This was the
  original shape of the fix. It rebuilds a database badly: the index can
  diverge from disk (sync, restore, external mutation), cold start has to
  rebuild it, there is no partial-index equivalent so the ledger cannot
  be separated from the drain path, and priority ordering stays bespoke.
  It also keeps every line of the integrity machinery.
- **Reuse `SyncDatabase`'s `Outbox` table.** ADR 0031's reasoning stands:
  that queue transports already-durable entities and does not represent
  pending inference.
- **Store jobs as agent entities.** `agent_entities` sync between
  devices; claims and leases must not.
- **Do nothing.** The cost is not static — it grows with every recording
  the user makes, and the ledger role guarantees the store only ever
  grows.

## Related

- ADR 0013 (outbox priority queue — the in-repo precedent for a
  prioritized durable queue in SQLite)
- ADR 0031 (batch-first day audio capture — introduced the file-backed
  outbox this ADR supersedes on storage; every other decision in it
  stands)
- ADR 0032 (hierarchical day agents — extended the outbox to agent jobs)
