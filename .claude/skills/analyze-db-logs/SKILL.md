---
name: analyze-db-logs
description: Analyze Drift / SQLite slow-query and super-slow-query logs against this app's known stall patterns (read waves, N+1, transaction scoping, MultiExecutor contention, WAL/OS factors)
argument-hint: "<path-to-logs-dir> [optional: date YYYY-MM-DD or relative window]"
---

# Analyze DB Slow-Query Logs

Reads slow-query log files written by `lib/database/slow_query_logging.dart`
and produces an actionable diagnosis grounded in this codebase's stack
(Dart, Flutter, Drift, SQLite).

## Invocation

The user provides the path to the log directory — typically a gitignored
local copy they pulled off a device or simulator. Repository convention is
`./logs/` at the repo root (already in `.gitignore`).

```sh
/analyze-db-logs ./logs/                       # most recent date in ./logs/
/analyze-db-logs ./logs/desktop                # platform-scoped subdir
/analyze-db-logs ./logs/mobile 2026-05-02      # specific date
/analyze-db-logs /tmp/from-device              # any absolute path
```

Treat `$ARGUMENTS` as `<path> [optional date or window]`. The first
positional must be the path; refuse with a one-line prompt if it is
missing — do NOT invent a default location, the user knows where their
logs are. Date is optional and defaults to "the most recent file per
stem found under that path".

Always print the resolved paths and line counts before analysing, so the
user can confirm the right files are loaded.

## Log file shapes

The `SlowQueryInterceptor.fileReporter` writes two daily files per
platform under whatever `documentsDirectoryPath/logs/` the running app
resolved to. The user is responsible for copying them into the path they
hand to this skill. Expect:

- `slow_queries-YYYY-MM-DD.log` — every query above the configured
  threshold (default 10ms; gated by `SlowQueryLoggingGate.isEnabled`).
- `super_slow_queries-YYYY-MM-DD.log` — duplicates of queries above the
  super-slow threshold (default 200ms), enriched with `EXPLAIN QUERY
  PLAN` rows under `PLAN:` and (when first-call stack capture is on)
  filtered application stack frames under `STACK:`.

### Subdirectory layout

By convention this repo's `./logs/` contains one subdirectory per
platform — typically `desktop/` and `mobile/` (sometimes `ios/`,
`android/`). Each subdir holds its own daily files. When the path the
user supplies is a directory that contains *only* subdirectories (no
`*.log` files at its top level), treat each subdirectory as a separate
platform-scoped scan and label every finding with the subdir name so
the user can tell which device it came from.

If the user supplies a more specific path (e.g. `./logs/mobile/`),
respect that and don't go up a level. If they supply the parent and
both `desktop/` and `mobile/` are present, analyse both and produce one
report section per platform plus a brief cross-platform summary at the
end.

Glob discovery rule of thumb:

```text
<path>/{slow_queries,super_slow_queries}-*.log         # path is leaf
<path>/*/{slow_queries,super_slow_queries}-*.log       # path is parent
```

Pick the most recent date per `(subdir, stem)` pair unless a date arg
is given.

## Log line formats

A slow-query line is a single line:

```text
2026-05-02T19:11:48.592 [db.sqlite] select 388.759ms args=0 SELECT * FROM ...
```

A super-slow entry is the same line plus indented continuation lines:

```text
2026-05-02T19:11:48.592 [db.sqlite] select 388.759ms args=0 SELECT ...
  PLAN: 4|0|SEARCH journal USING INDEX idx_journal_browse (deleted=? AND type=?)
  PLAN: 84|0|USE TEMP B-TREE FOR ORDER BY
  STACK: #10     JournalDb.getAllDashboards (package:lotti/database/database.dart:3056:34)
  STACK: #11     dashboardsProvider.<anonymous closure> (package:lotti/features/dashboards/state/dashboards_page_controller.dart:20:14)
```

The interceptor filters `STACK:` lines to drop drift, dart-runtime,
riverpod and the slow-query plumbing itself; only `package:lotti/...`
frames remain.

## Analysis procedure

1. **Resolve the file set.** Honor the platform argument; pick the most
   recent date per stem if no date is given. Tail-load the file (last
   ~2000 lines is usually enough — the interceptor appends, so the wave
   you care about is at the end). Print the resolved paths.

2. **Bucket entries by query shape.** Collapse per-row args; group by
   the normalized statement. For each bucket capture: count, p50/p95/max
   elapsed, the unique `PLAN:` shapes, and the unique `STACK:` heads
   (top app-code frame).

3. **Diagnose against the known patterns below.** For every finding,
   cite the specific log lines (timestamp + elapsed + statement
   prefix). Do not generalize — show the data.

4. **Recommend the fix.** Reference the existing seam (drift query,
   coalescer, transaction wrapper, index, etc.) and where in the code
   the change would land. If a fix is speculative, say so.

## Known stall patterns to look for

These are battle-tested findings from this codebase. Apply them in order;
the first match is usually the dominant cost.

### 1. Read waves — N queries reporting hundreds of ms but finishing in a tight burst

**Signature**: a cluster of 10–20+ queries whose `elapsed` is roughly
identical (e.g., all in the 600–700ms band) but whose timestamps span
only 10–30ms. Each query's plan is fine; the SQL itself is fast.

**Diagnosis**: the queries were *queued* behind something — typically a
write transaction holding the writer lock, an `ANALYZE` on the boot
path, or a slow `beforeOpen` hook. The wall-clock measurement starts
when drift accepts the request, so queue wait shows up as "elapsed".

**Confirm by**:
- Check the `elapsed` band: a 100ms+ spread *across* the wave with
  near-identical *finish* timestamps (use the leading ISO timestamp,
  not the elapsed) means the queries unblocked together. The
  interceptor strips drift / dart-runtime frames so the original
  `STACK: #5 DatabaseConnectionUser.doWhenOpened` boilerplate is
  *not* visible in the log — infer the gate from the timing pattern,
  not from a frame name.
- Look at the line *just before* the wave for a long-running write or
  transaction.
- Boot waves often correlate with `EntitiesCacheService.init` firing
  `Future.wait` of definitions queries — the surviving `STACK:` heads
  for the wave will point at distinct controllers / repositories
  whose initial fetches all queued together.

**Likely fixes**:
- Move `ANALYZE` and other heavy work *off* the boot path (`beforeOpen`
  must return fast).
- Narrow transaction scopes (see pattern 4).
- Raise the read pool size only after confirming isolate-spawn cost is
  the bottleneck — bumping `readPool` adds isolate-spawn cost upfront.

### 2. N+1 reads — a cluster of single-id selects from one call site

**Signature**: many lines like
`SELECT * FROM "journal" WHERE "id" = ? AND "deleted" = ?`, all from the
same `STACK:` head, all reporting nearly identical elapsed times.

**Diagnosis**: a `Future.wait(ids.map(byId))` or a per-row provider
family fanning out single-id reads. Each call queues through the read
pool independently.

**Recurring offenders fixed in this branch**:
- `taskLiveDataProvider` (FutureProvider.family per task) → solved by
  `JournalDb._coalesceEntityById` (microtask-coalesced bulk fetch).
- `LinkedAiResponsesController._fetch` → switched from `Future.wait` to
  `journalRepository.getJournalEntitiesByIds(...)`.
- `EditorStateService.init` drafts loop → switched to
  `journalEntitiesByIdsUnorderedAllPrivate(idList)`.

**Likely fixes**:
- Replace fan-out with a bulk drift query (`journalEntitiesByIdsUnorderedAllPrivate`,
  `getJournalEntitiesForIdsUnordered`, `linksForEntryIds`, etc.).
- For Riverpod families that genuinely need per-row instances, route
  through the existing entity-by-id microtask coalescer.

### 3. Drift MultiExecutor contention — reads inside a transaction run on the writer

**Reminder**: in drift, anything wrapped in `db.transaction(() async { ... })`
runs on the *write* connection — even pure `select(...)` calls inside
the block. The read-pool isolates do NOT pick those up. So a
`transaction { read; read; …; write; commit }` body serialises every
read behind every other write that touches the same writer.

**Confirm by**: look at the `STACK:` head for a frame inside an apply /
upsert / migration path. If the read appears to hit a fast plan but
elapsed is high and other writes are visible nearby, the read was
forced onto the writer.

**Likely fixes**:
- Pull pre-read / post-write side effects *out* of the transaction
  block.
- Only wrap statements that genuinely need atomicity together.
- Cross-DB writes (e.g., to `sync_db`, `settings_db`, `agent_db`,
  `ai_config_db`) cannot be atomic with `JournalDb` writes anyway —
  doing them inside a `JournalDb.transaction` only holds the journal
  writer lock for unrelated work.

### 4. Transaction scoping — broad wrappers around unrelated DB writes

**Signature**: the same wave shape as pattern 1, but the suspected
"writer holding the lock" is a sync apply that's logging a
`SyncJournalEntity`-shaped write while *also* awaiting a
`_sequenceLogService.recordReceivedEntry` (sync_db) or other cross-DB
work inside the same `transaction { ... }`.

**Diagnosis**: this codebase fixed exactly this in
`queue_apply_adapter.dart` via `_writesJournalDb(SyncMessage)` — the
adapter now wraps in `JournalDb.transaction` *only* for payload
families that actually write to JournalDb tables (journal entity,
entry link, entity definitions, outbox bundle, conservatively the
backfill request/response paths). Theming, ai-config, agent
entity/link/bundle writes bypass the wrapper because they target
other databases.

`_persistJournalEntity` was also restructured: the pre-read
diagnostic `journalEntityById`, the post-write
`_sequenceLogService.recordReceivedEntry` (`sync_db`), and the
entry-exists check now run **outside** the narrow journal transaction.

**When inspecting new code**: any new `db.transaction(() async { ... })`
that contains an `await` to a different database, a network call, or a
filesystem write is a candidate for narrowing.

### 5. Wrong-index plans masquerading as slow SQL

**Signature**: a single query reporting hundreds of ms with a plan
that includes `USE TEMP B-TREE FOR ORDER BY`, `SCAN <table>`, or an
index match where the leading column is not the most selective
predicate.

**Recurring offenders already fixed in shipped code** — verify these
still match the current `lib/database/database.drift`,
`lib/database/sync_db.dart`, and `lib/database/database.dart` before
citing them. Treat the list as historical context, not an asserted
current truth:
- `task_priority_rank` ordering with high-cardinality
  `category IN (...)` predicate. The fix shipped as a partial index
  named (at the time) `idx_journal_tasks_status_priority_date`; if it
  is still in `database.drift`, recommend it as the steady-state path,
  otherwise treat the symptom as an open issue.
- `getBulkLinkedTimeSpans` join over `linked_entries`. The fix shipped
  as a covering index `idx_linked_entries_from_id_hidden_to_id`.
- `inbound_event_queue` stats `MIN(enqueued_at)` SCAN. The fix shipped
  as `idx_inbound_event_queue_status_enqueued` plus
  `idx_inbound_event_queue_status_due_lease`.
- `claimNextOutboxBatch` SCAN from
  `status = pending OR (status = sending AND updated_at < cutoff)`.
  The fix shipped as two indexed seeks merged in Dart.

If a query still matches one of these symptom shapes despite the named
index existing, suspect stale stats first (recommend `ANALYZE`) before
proposing a new index.

**When inspecting new logs**: if the plan is suboptimal, recommend
running `ANALYZE` first (planner stats can drift); only after
confirming with fresh stats should you propose a new index. Bad plans
on a freshly-`ANALYZE`d DB are real index gaps.

### 6. WAL / OS-level factors

When patterns 1–5 don't explain a stall, consider:
- **WAL checkpoint storms**: a write that crosses
  `wal_autocheckpoint` (default 1000 pages, ~4MB) triggers a
  checkpoint that briefly takes a more aggressive lock. Bursty write
  workloads can stall reads at checkpoint boundaries.
- **macOS sandboxed file locks**: `fcntl(F_FULLFSYNC)` and BSD locks
  on iCloud-backed paths have shown long tails. Less likely on dev
  but worth flagging.
- **Background isolate spawn (`createInBackground(readPool: N)`)** —
  isolates may spawn on first use; the *first* boot wave can pay
  per-isolate setup cost (~50–200ms each). Subsequent app sessions
  should be much faster — first wave is the worst case.
- **`PRAGMA foreign_keys = ON`** runs per-connection; cheap but real.

### 7. Per-launch repair / housekeeping that shouldn't run every boot

**Signature**: an entry whose `STACK:` head points at a `beforeOpen`,
self-heal, or migration helper — but the user just opened the app
normally. With `readPool: N`, drift calls `beforeOpen` on every
connection, so any repair work done there runs `1 + N` times per
launch.

**Lessons from this branch**:
- Per-launch `ANALYZE` was removed — stats persist in `sqlite_stat1`
  and the v42 migration runs `ANALYZE` once on upgrade.
- The self-heal `CREATE INDEX IF NOT EXISTS` block was removed
  entirely — the recovery path it covered targeted an aborted-migration
  scenario that has not occurred in production.
- `beforeOpen` is now just `PRAGMA foreign_keys = ON`.

When you see boot-time housekeeping in a stack, ask: does this need
to run on every launch, or once per upgrade?

## Output format

Produce a concise report, in this order:

1. **Inputs** — paths read, line counts, date window.
2. **Findings**, each with: severity (high/medium/low), pattern
   matched (numbered above), evidence (specific log lines with
   timestamps), root-cause hypothesis, and the file/seam where the
   fix would land.
3. **Recommended actions**, ordered by impact. Cite specific
   call sites (`lib/...:line`) where possible.
4. **Things you ruled out** (and why), so the user can sanity-check.

Keep the report skimmable. If the log is mostly clean, say so — don't
manufacture findings.

## Guardrails

- **Never** propose schema bumps (`schemaVersion++`) without confirming
  the v42-style migration shape and asking the user. New indices that
  don't need a column change can land via migration; per-launch
  defensive code should not.
- **Never** propose a per-boot `ANALYZE`, `CREATE INDEX IF NOT EXISTS`
  loop, or other "self-heal on every open" — this codebase explicitly
  removed those.
- **Don't assume** an `INDEXED BY` hint solves a planner problem. The
  autoindex names (`sqlite_autoindex_*_1`) are not part of the public
  SQLite contract; recommend `ANALYZE` first.
- **Match real seams**: prefer adding fixes to existing patterns
  (`_PendingEntityByIdWave` for entity-by-id coalescing,
  `_PendingLinksWave` for to-id link batches, `_writesJournalDb` for
  per-payload transaction scoping) over inventing new ones.
- **Show your work**: every finding should cite specific log lines so
  the user can verify.
