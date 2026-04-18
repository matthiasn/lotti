# Slow-Query Investigation — 2026-04-17 / 2026-04-18

Snapshot of two local slow-query logs (`logs/slow_queries-2026-04-17.log`,
`logs/slow_queries-2026-04-18.log`) captured with
`SlowQueryLoggingGate.isEnabled = true` and the default 5ms threshold
(see `lib/database/slow_query_logging.dart:56`, `lib/database/common.dart:105`).

**Volume.** 9.75 MB / 42,097 lines across ~37 hours on a single desktop
install — every line is a query that took **≥ 5ms**. Two days of casual
use producing ~10MB of slow-query evidence is the headline problem: the
steady-state traffic is dominated by a handful of hot shapes that always
sit above the slow threshold, plus occasional WAL-lock stalls that drag
single queries into the multi-second range.

## Top 50 individual slowest queries

Shape shorthand:
- `A` = `getLastSentCounterForEntry` (`sync.sqlite`) — `SELECT MAX(counter) FROM sync_sequence_log WHERE host_id=? AND entry_id=? AND status IN (?,?)` (`sync_db.dart:553`)
- `B` = `sync_sequence_log` actionable scan — `WHERE (status=? OR status=?) AND request_count<? ORDER BY created_at ASC`
- `C` = `countInProgressTasks` (`database.drift:797`)
- `D` = `outbox` next-fetch — `WHERE status=? ORDER BY priority ASC, created_at ASC LIMIT 1`
- `E` = parent/child hydration — `linked_entries ⋈ journal WHERE from_id IN (…) AND hidden=FALSE AND journal.type NOT IN ('Task','AiResponse','JournalAudio')`
- `F` = category+type listing — `SELECT * FROM journal WHERE type IN (…12 types…) AND deleted=FALSE AND category IN (…) ORDER BY date_from DESC LIMIT ? OFFSET ?`
- `G` = `journalEntitiesByIds*` — `SELECT * FROM journal WHERE deleted=FALSE AND id IN (…)`
- `H` = single-row lookup — `SELECT * FROM "journal" WHERE "id"=? AND "deleted"=?;` (drift `getJournalEntityById`)
- `I` = `ratingsForTimeEntries` JOIN (`database.drift:1068`)
- `J` = estimate projection — `SELECT id, json_extract(serialized,'$.data.estimate') FROM journal WHERE deleted=FALSE AND type='Task' AND id IN (…)`
- `K` = linked child fetch — `SELECT journal.* FROM linked_entries ⋈ journal WHERE from_id=? AND hidden=FALSE ORDER BY date_from DESC`
- `L` = all-of-type scan — `SELECT * FROM "journal" WHERE "type"=? AND "deleted"=? ORDER BY "date_from" DESC;`

| # | Duration (ms) | DB | Shape | Args | Timestamp |
|---|-------------:|----|-------|-----:|-----------|
| 1 | 538,168.75 | sync | A | 4 | 2026-04-17T09:19:50 |
| 2 | 2,785.69 | sync | B | 3 | 2026-04-17T10:22:55 |
| 3 | 1,839.96 | db | C | 3 | 2026-04-18T10:39:08 |
| 4 | 1,727.32 | db | C | 3 | 2026-04-17T02:31:39 |
| 5 | 1,702.61 | db | C | 3 | 2026-04-17T14:30:55 |
| 6 | 1,686.91 | db | C | 3 | 2026-04-17T02:49:44 |
| 7 | 1,642.40 | sync | D | 1 | 2026-04-18T02:10:25 |
| 8 | 1,593.86 | sync | B | 3 | 2026-04-17T10:40:53 |
| 9 | 1,584.77 | db | E | 7 | 2026-04-18T10:39:08 |
| 10 | 1,540.14 | db | F | 15 | 2026-04-18T10:39:08 |
| 11 | 1,523.19 | db | F | 15 | 2026-04-18T10:39:08 |
| 12 | 1,510.69 | db | F | 15 | 2026-04-17T02:31:39 |
| 13 | 1,494.51 | db | F | 15 | 2026-04-17T02:31:39 |
| 14 | 1,493.95 | db | F | 15 | 2026-04-17T02:49:44 |
| 15 | 1,487.64 | db | F | 15 | 2026-04-17T14:30:55 |
| 16 | 1,483.75 | db | G | 109 | 2026-04-18T10:39:08 |
| 17 | 1,474.48 | db | F | 15 | 2026-04-17T02:49:44 |
| 18 | 1,466.20 | db | F | 15 | 2026-04-17T14:30:55 |
| 19 | 1,379.99 | sync | B | 3 | 2026-04-18T00:03:00 |
| 20 | 1,376.39 | db | G | 113 | 2026-04-17T02:49:44 |
| 21 | 1,363.88 | db | G | 113 | 2026-04-17T02:31:39 |
| 22 | 1,363.51 | db | G | 6 | 2026-04-17T02:31:51 |
| 23 | 1,327.81 | db | G | 113 | 2026-04-17T14:30:55 |
| 24 | 1,323.39 | db | G | 4 | 2026-04-17T02:31:51 |
| 25 | 1,288.22 | db | G | 9 | 2026-04-17T02:31:51 |
| 26 | 1,254.20 | sync | D | 1 | 2026-04-18T02:10:33 |
| 27 | 1,226.27 | sync | B | 3 | 2026-04-18T02:13:12 |
| 28 | 1,217.33 | db | E | 7 | 2026-04-17T02:31:39 |
| 29 | 1,187.85 | db | E | 7 | 2026-04-17T14:30:55 |
| 30 | 1,175.61 | db | J | 7 | 2026-04-17T02:49:44 |
| 31 | 1,174.65 | db | L | 2 | 2026-04-18T10:39:08 |
| 32 | 1,169.48 | db | H | 2 | 2026-04-18T10:39:08 |
| 33 | 1,168.95 | db | G | 1 | 2026-04-18T10:39:08 |
| 34 | 1,159.13 | db | K | 1 | 2026-04-18T10:39:08 |
| 35 | 1,156.13 | db | H | 2 | 2026-04-17T02:49:44 |
| 36 | 1,155.65 | db | H | 2 | 2026-04-17T02:49:44 |
| 37 | 1,155.58 | db | G | 3 | 2026-04-17T02:31:51 |
| 38 | 1,155.48 | db | H | 2 | 2026-04-17T02:49:44 |
| 39 | 1,154.88 | db | H | 2 | 2026-04-17T02:49:44 |
| 40 | 1,153.51 | db | H | 2 | 2026-04-17T02:49:44 |
| 41 | 1,151.13 | db | H | 2 | 2026-04-17T02:49:44 |
| 42 | 1,140.34 | db | H | 2 | 2026-04-17T02:31:39 |
| 43 | 1,139.51 | db | I | 2 | 2026-04-17T02:31:51 |
| 44 | 1,139.41 | db | I | 3 | 2026-04-17T02:31:51 |
| 45 | 1,132.15 | db | G | 4 | 2026-04-18T02:16:14 |
| 46 | 1,122.55 | db | G | 3 | 2026-04-18T02:16:14 |
| 47 | 1,112.08 | db | H | 2 | 2026-04-18T02:16:14 |
| 48 | 1,112.04 | db | I | 1 | 2026-04-18T02:16:14 |
| 49 | 1,111.80 | db | G | 9 | 2026-04-18T02:16:14 |
| 50 | 1,111.45 | db | G | 4 | 2026-04-18T02:16:14 |

### What the top-50 makes obvious

- **Eight distinct timestamps account for all 50 rows.** The worst
  individual queries are not spread across time — they cluster into
  ~8 correlated bursts (`02:31:39`, `02:31:51`, `02:49:44`, `14:30:55`,
  `09:19:50`, `10:39:08`, `02:10:xx`, `02:16:14`). Within each burst
  ~10–20 queries all finish within a ~400 ms window at near-identical
  durations. That is the shape of **queue-behind-a-writer**, not slow
  plans — they all wait, then all complete together when the lock
  releases.
- **Shape `F` (category+type journal listing) shows up 9 times** in the
  top-50 and always runs 1.4–1.5 s. The `type IN (12 values)` is the
  full set of user-visible journal types — this is the main list
  page. Each hit is ~1.5 s of wall time, and the burst at
  `2026-04-17T02:31:39` runs it **3× back-to-back** with identical
  durations, meaning the page is issuing the query once per overlapping
  build.
- **Shape `H` (single-row `WHERE id=?`) shows up 10 times** in the
  top-50 with 7 of them at the same `2026-04-17T02:49:44` timestamp —
  a detail view or hydration loop is firing ~7 single-row lookups in a
  row while the DB is already contended.
- **Shape `G` (`id IN (…)`) appears 14 times**, ranging from 1 id up to
  113 ids. The 113-id variant is hit 3× in 3 separate bursts at nearly
  identical durations (~1.33–1.38 s) — the caller has a stable set of
  ~113 ids it repeatedly rehydrates on every state change.
- **`sync.sqlite` contributes 6 of the top-50** (entries 1, 2, 7, 8,
  19, 26, 27). Ignoring the 538 s stall, the others all finish in
  1.2–2.8 s — these line up with journaling-WAL checkpoint windows on
  sync.sqlite, not bad plans.
- Entry 1 (the 538 s stall) is **a single outlier**: the same shape's
  p95 is 59 ms. Do not over-index on the plan — investigate what held
  the write lock for 9 minutes.

## Top query shapes by total time

Aggregated across both days (durations in ms, counts are calls):

| Rank | Calls | Total | Mean | p95 | Max | DB | Shape / source |
|-----:|------:|------:|-----:|----:|----:|----|----------------|
| 1 | 4,012 | 1,479,557 | 369 | 832 | 1,484 | db | `journal WHERE deleted=FALSE AND id IN (…)` — `database.drift:960` `journalEntitiesByIds*` |
| 2 | 2,699 | 850,053 | 315 | 682 | 1,140 | db | `ratingsForTimeEntries` JOIN (`database.drift:1068`) |
| 3 | 2,689 | 662,322 | 246 | 59 | **538,168** | sync | `getLastSentCounterForEntry` (`sync_db.dart:553`) |
| 4 | 6,145 | 375,952 | 61 | 240 | 983 | db | `dayPlanById` (`database.drift:1034`) |
| 5 | 4,407 | 335,963 | 76 | 150 | 765 | db | `linked_entries WHERE to_id IN (…) AND type=?` |
| 6 | 3,872 | 228,644 | 59 | 228 | 986 | db | `_selectTasksDue` range branch (`database.dart:2123`) |
| 7 | 1,488 | 206,520 | 139 | 822 | 915 | db | `dayPlansInRange` (`database.drift:1047`) |
| 8 | 1,981 | 201,763 | 102 | 538 | 1,170 | db | `journal WHERE id=? AND deleted=?` (generated single-row lookup) |
| 9 | 917 | 176,423 | 192 | 318 | 1,840 | db | `countInProgressTasks` (`database.drift:797`) |
| 10 | 2,696 | 159,738 | 59 | 247 | 921 | db | `_selectTasksDue` no-startIso branch |

## Two distinct failure modes

The numbers split cleanly along two axes and need **different** fixes.

### A. Sustained N+1 and fat-row scans (dominant total-time)

- `dayPlanById` fires 6,145× in two days, 53 times inside a single second
  on 2026-04-17T20:41:54. Callers at
  `lib/features/daily_os/repository/day_plan_repository.dart:57` and
  `:63` fetch one day-plan per iterated date. A batch
  `dayPlansByIds(ids)` or continued use of the already-existing
  `dayPlansInRange` (`database.drift:1047`) would collapse 53 round-trips
  into 1.
- `journalEntitiesByIds*` (shape #1) returns `SELECT *` on the journal
  table — the `serialized` column is the fat JSON payload. At 369ms mean
  over 4,012 calls this single shape accounts for ~**25 minutes** of DB
  time per two-day window. Candidates: (a) a covering projection for
  callers that only need id/type/date; (b) a row-level hydration cache
  keyed by id+updated_at to cut repeat reads.
- `_selectTasksDue` (shapes #6, #10) uses `json_extract` in both `WHERE`
  and `ORDER BY`. The `idx_journal_tasks_due_active` expression index
  (`database.drift:69`, `database.g.dart:5519`) is only
  `(type, deleted, json_extract(due))` — it orders but does not cover
  the `task_status NOT IN (…)` or the private-status filter, so SQLite
  still reads every matching row. Consider a partial index:
  `CREATE INDEX … ON journal(json_extract(serialized,'$.data.due'))
  WHERE type='Task' AND deleted=0 AND task_status NOT IN ('DONE','REJECTED')`.
- `countInProgressTasks` (`database.drift:797`) has no supporting index
  for `(task=1, deleted=0, task_status, private)` — the partial index
  `idx_journal_tasks` exists but is keyed on `category` first, which
  doesn't help a global count. A tiny partial index on
  `(task_status, private) WHERE type='Task' AND task=1 AND deleted=FALSE`
  would turn this from 192ms mean (max 1.84s) into a few ms.

### B. Occasional multi-second stalls on sync.sqlite (tail latency)

- The 538s outlier on `getLastSentCounterForEntry` is the smoking gun.
  The p50 for that exact query is 40 ms and the p95 is 59 ms — the
  covering index `idx_sync_sequence_log_host_entry_status`
  (`sync_db.dart:98`) is doing its job. A single run taking **9 minutes**
  is not a bad plan; it is a blocked writer (long-held write lock, WAL
  checkpoint, disk sync stall, or a competing `VACUUM`/backup).
- Same signature shows up on `outbox` (#7, 1.6s, mean is 35ms) and on
  `sync_sequence_log` `(status OR status) AND request_count<?` (#2, 2.8s
  worst case, mean 123ms).
- Both of those tables already have matching indexes
  (`idx_outbox_status_priority_created_at` — `sync_db.dart:43`;
  `idx_sync_sequence_log_actionable_status_created_at` —
  `sync_db.dart:88`). The tail is not an index-miss, it is contention.

## Bursts and contention windows

Top minute-buckets by count of slow queries (each entry is already ≥ 5ms):

| Minute | Slow queries |
|--------|-------------:|
| 2026-04-18T11:12 | 191 |
| 2026-04-18T12:24 | 165 |
| 2026-04-17T23:32 | 150 |
| 2026-04-18T01:51 | 132 |
| 2026-04-17T14:34 | 128 |
| 2026-04-17T23:42 | 127 |

These cluster across both databases (db + sync), which is the tell for
WAL checkpoint / filesystem-flush stalls rather than query-plan issues.

## Proposed remedies (ordered by impact / risk)

1. **Kill the `dayPlanById` N+1.** Route all day-plan fetches that walk
   a date range through `dayPlansInRange` or add a new
   `dayPlansByIds(:ids)` drift query. Target file:
   `lib/features/daily_os/repository/day_plan_repository.dart`. Expected
   win: ~6,100 round-trips → ~120, eliminates ~370k ms (~6 min) of DB
   time per two-day session.

2. **Add a partial index for `countInProgressTasks`.** Migration adding
   `idx_journal_tasks_in_progress` on `(private, task_status)` with the
   `WHERE type='Task' AND task=1 AND deleted=FALSE` predicate. Turns the
   1.8s worst case into sub-10ms. No code change beyond the migration.

3. **Tighten `idx_journal_tasks_due_active` to match the filter.** Drop
   or keep the existing expression index and add a partial that
   incorporates `task_status NOT IN ('DONE','REJECTED')`. Measure before
   replacing — partial indexes with `NOT IN` need care. If we cannot
   express `NOT IN` in the partial, an index on
   `(task_status, json_extract(serialized,'$.data.due'))` partial on
   `type='Task' AND deleted=FALSE` is the next-best shape.

4. **Cut the `SELECT *` on `journalEntitiesByIds*` when only metadata
   is needed.** Audit callers at `database.drift:960-981`. Many of them
   feed list UIs that only need id/type/date/flags. Introduce a lean
   `journalMetaByIds` and keep the current fat query for detail views.

5. **Investigate the 538s stall.** Correlate the 2026-04-17T09:19:50
   outlier with: (a) outbox flushes, (b) `VACUUM` / WAL checkpoint
   timers, (c) backup / sync-storm windows. Two likely sources worth
   ruling out:
   - Long write transactions in `sync_sequence_log_service.dart`
     (`lib/features/sync/sequence/sync_sequence_log_service.dart:282`
     calls `getLastSentCounterForEntry` inside a larger flow — if any
     caller holds a write txn around it, the read will queue behind it).
   - PRAGMA `wal_autocheckpoint` / `busy_timeout` settings on
     `sync.sqlite`. Confirm they are set explicitly.
   Consider raising `busy_timeout` and lowering `wal_autocheckpoint` so
   checkpoints happen more often but take less time each.

6. **Batch `linked_entries WHERE to_id IN (…)` callers (shape #5).**
   4,407 calls totalling 336s. Where multiple `to_id` arrays are built
   per render (look at `parent_id/entity_id` JOIN, #9) collapse them
   into a single query per screen.

7. **Keep the slow-query interceptor on a configurable threshold.**
   5 ms is too low for production — it produced 10 MB in 37 hours on
   one machine. For ongoing telemetry, default to 50 ms (catch the user-
   visible stalls) and keep the 5 ms mode behind the advanced toggle
   that's already wired (`SlowQueryLoggingGate`).

## Code map (file:line — for diffing)

- `lib/database/database.drift:797` — `countInProgressTasks`
- `lib/database/database.drift:960` — `journalEntitiesByIds*`
- `lib/database/database.drift:1034` — `dayPlanById`
- `lib/database/database.drift:1047` — `dayPlansInRange` (reuse this)
- `lib/database/database.drift:1068` — `ratingsForTimeEntries`
- `lib/database/database.dart:2123` — `_selectTasksDue` raw SQL
- `lib/database/sync_db.dart:43,88,98` — existing sync indexes
- `lib/database/sync_db.dart:553` — `getLastSentCounterForEntry`
- `lib/features/daily_os/repository/day_plan_repository.dart:57,63` — N+1 callers
- `lib/features/sync/sequence/sync_sequence_log_service.dart:282` — sequence-log hot path
- `lib/database/slow_query_logging.dart` / `lib/database/common.dart:105` — threshold config
