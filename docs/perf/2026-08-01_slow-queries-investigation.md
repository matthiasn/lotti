# Slow-Query Investigation — 2026-06-16 → 2026-08-01

Successor to [slow-queries-investigation.md](slow-queries-investigation.md)
(2026-04-17/18). That snapshot covered 37 hours; this one covers **47 days**.

## Corpus

| | |
|---|---|
| `logs/slow_queries-2026-{06-16..08-01}.log` | 47 files, 94 MB, **263,600 entries** (2 unparsable) |
| `logs/super_slow_queries-2026-{06-16..08-01}.log` | 47 files, 1.4 MB, **2,175 entries** |

Thresholds: **slow ≥ 10 ms** (`lib/database/common.dart:121`), **super-slow ≥ 200 ms**
(`lib/database/slow_query_logging.dart:24`). Super-slow entries additionally carry
`EXPLAIN QUERY PLAN` rows, which is what makes plan-level conclusions possible here.

## The measurement caveat — read this before prioritising anything

The interceptor is installed **client-side of the isolate boundary**: `common.dart:173`
wraps the `DatabaseConnection` returned by `NativeDatabase.createInBackground`. The
`Stopwatch` in `SlowQueryInterceptor._measure` (`slow_query_logging.dart:234`) therefore
measures **round-trip time** — IPC + time queued behind other statements on that
database's isolate + actual SQLite execution.

It is *not* query execution time. The logged durations prove it:

| Shape (`agent.sqlite`) | n | p50 | p75 | p95 |
|---|---:|---:|---:|---:|
| `SELECT * FROM agent_entities WHERE id = ?` (PK lookup) | 92,787 | 19.0 ms | 30.8 ms | 77.6 ms |
| `ROW_NUMBER()` ranked over ~900 `agent_id`s | 23,662 | 18.2 ms | 32.7 ms | 76.1 ms |
| `agent_links WHERE to_id = ? AND type = ?` | 9,152 | 18.4 ms | 27.6 ms | 59.0 ms |
| `journal WHERE deleted = FALSE AND id IN (…)` (`db.sqlite`) | 9,707 | 15.7 ms | 26.8 ms | 65.6 ms |

A single-row primary-key lookup and a 901-parameter window function have **the same
latency distribution**. That is a fixed ~15–20 ms per-round-trip floor.

The query plans agree. Across all 2,175 super-slow entries, nearly every plan row is a
clean `SEARCH … USING INDEX`. The only genuine full scans are:

| Occurrences | Plan row |
|---:|---|
| 55 | `SCAN outbox USING INDEX idx_outbox_actionable_priority_created_at` |
| 50 | `SCAN inbound_event_queue USING COVERING INDEX idx_inbound_event_queue_status_producer_enqueued` |
| 201 | `USE TEMP B-TREE FOR ORDER BY` (`db.sqlite`, mostly the habit heatmap query) |

**Conclusion: this is a round-trip-count problem, not a missing-index problem.**
Adding indexes will buy almost nothing. Reducing the number of statements will buy
almost everything.

## Ranking correction — the naive #1 is already fixed

Aggregating over all 47 days puts `habitCompletionsInRange` at
#1 with 1,458 s. That is an artefact:

- Its **last execution was 2026-07-05**. It was superseded by the deduplicating
  `ROW_NUMBER` variant `getHabitCompletionsInRange`
  (`lib/database/database_data_queries.dart:40`, landed in d36221b06, 2026-06-06).
- 1,356 s of its 1,458 s comes from **two** outlier events (see "Mode C" below).
- The drift query now has **no callers** and only generates dead code at
  `database.g.dart:6986`. **Deleted in #3723** — it was never worth optimising.

Everything below is therefore ranked over **2026-07-19 → 2026-08-01**, which reflects
the code as it actually stands.

## Top shapes by total time — last 14 days

| # | Total | n | avg | p95 | max | DB | Shape |
|--:|------:|--:|----:|----:|----:|----|-------|
| 1 | 134.1 s | 4,211 | 32 ms | 87 ms | 494 ms | agent | `ROW_NUMBER()` latest-per-agent over ~900 ids |
| 2 | 127.1 s | 4,201 | 30 ms | 75 ms | 1,068 ms | agent | `agent_entities WHERE id = ?` |
| 3 | 90.8 s | 357 | 254 ms | 3,252 ms | 5,070 ms | sync | `COUNT(*) FROM outbox INDEXED BY …` |
| 4 | 90.2 s | 4,127 | 22 ms | 41 ms | 251 ms | agent | `json_extract(serialized,'$.taskId') = ?` |
| 5 | 89.0 s | 163 | 546 ms | 3,515 ms | 5,054 ms | sync | `outbox WHERE status=0 ORDER BY … LIMIT 1` |
| 6 | 87.4 s | 1,734 | 50 ms | 163 ms | 982 ms | agent | `WHERE type='agent'` (loads every agent) |
| 7 | 86.0 s | 31 | **2,775 ms** | 4,024 ms | 5,070 ms | sync | `sync_sequence_log WHERE host_id=? AND status=?` |
| 8 | 72.7 s | 26 | **2,797 ms** | 3,590 ms | 4,785 ms | sync | `queue_markers WHERE room_id=?` |
| 9 | 49.6 s | 1,067 | 47 ms | 130 ms | 1,257 ms | db | `journal WHERE deleted=FALSE AND id IN (…)` |
| 10 | 47.1 s | 74 | 636 ms | 1,667 ms | 1,753 ms | db | habit heatmap `ROW_NUMBER` query |
| 11 | 38.4 s | 1,472 | 26 ms | 44 ms | 1,256 ms | agent | `agent_entities WHERE agent_id=? AND type=?` |
| 12 | 37.3 s | 316 | 118 ms | 417 ms | 687 ms | db | task `COUNT(*)` with correlated `labeled` subqueries |
| 13 | 33.8 s | 1,514 | 22 ms | 41 ms | 295 ms | agent | `agent_links WHERE to_id=? AND type=?` |
| 14 | 31.7 s | 527 | 60 ms | 114 ms | 149 ms | db | `linked_entries WHERE to_id IN (…) AND type=?` |
| 15 | 31.4 s | 483 | 65 ms | 148 ms | 157 ms | db | `journal WHERE type IN (…) AND date_from/date_to` |

`agent.sqlite` alone is ~half of all recent logged time, spread over ~16,000 calls
averaging 22–50 ms — none of which has a bad plan.

## Three failure modes

### Mode A — N+1 round-trip storms (dominant total time)

The headline number: `agent_entities WHERE id = ?` fired **92,787 times** across the
window for **2,660 s (44 min)** of logged time. Burst structure:

- **80.7%** of calls arrive in seconds containing **≥ 20** calls.
- Worst single second: **606 calls** at `2026-07-08 14:51:12`.
- Next worst: 597 (`06-17 11:28:16`), 592 (`06-20 23:27:27`), 586 (`07-05 22:24:14`).

Every one of those is an indexed PK lookup that SQLite answers in microseconds. The
44 minutes is ~92k × ~19 ms of isolate round-trip.

Call sites: `agent_repo_core.dart:88`, `agent_attention_projection.dart:430`,
`agent_attention_projection.dart:524`.

A second, subtler N+1 hides inside a batch-shaped API: `journal WHERE deleted = FALSE
AND id IN (?)` — the **single-argument** form — ran **5,791 times** (985 in the last 14
days). A batch query invoked with one id per call is an N+1 wearing a batch costume.

### Mode B — `sync.sqlite` lock convoys (tail latency)

`sync.sqlite` is the only hot database opened with **no read pool** (`readPool: 0`);
`db.sqlite` uses 4, `agent.sqlite` 2 (`lib/database/database.dart`,
`lib/features/agents/database/agent_database.dart`). Reads therefore serialize behind
writes on a single isolate.

The convoy signature at `2026-07-01 19:29:48` — nine queries that all *started* within
one second and all *finished* within 150 ms of each other:

| Duration | Query |
|---:|---|
| 25,666.9 ms | `outbox WHERE status=0 ORDER BY … LIMIT 1` |
| 25,666.9 ms | `COUNT(id) FROM outbox WHERE status IN (?,?)` |
| 25,666.8 ms | `inbound_event_queue … LIMIT 1` |
| 24,765.6 ms | `outbox WHERE status=0 …` |
| 15,069.6 ms | `outbox WHERE status=0 …` |
| 5,348.5 ms | `outbox WHERE status=0 …` |

They waited together and released together — the shape of queue-behind-a-writer, not of
slow plans. `PRAGMA busy_timeout = 5000` (`common.dart:76`) explains the dense cluster of
maxima at ~5,069 ms across shapes 3, 5, 7 and 8.

Entries 7 and 8 are the clearest proof: `queue_markers WHERE room_id = ?` is a
single-row lookup on a unique index averaging **2.8 s**. No plan change can fix that.

### Mode C — two isolated multi-minute stalls (real, but not contention)

| Duration | Window | Query |
|---:|---|---|
| 909,870 ms | 2026-06-25 15:21:43 → 15:36:53 | habit completions |
| 446,318 ms | 2026-06-23 19:40:16 → 19:47:42 | habit completions |

Both had **zero overlapping writes** and near-zero overlapping queries (3 and 16
logged statements respectively across a 7–15 minute span). That rules out lock
contention: if the database were held, the queue would be full of waiters, as it
visibly is in the sync convoys.

**These were nevertheless real elapsed time, not host suspend.** An earlier
version of this document guessed suspend. That is ruled out by the measurement
itself: the durations come from `Stopwatch`, which is monotonic, and on a
suspended host the monotonic clock does not advance — it could not have recorded
909 seconds that the process spent asleep. So the process really was stuck for
15 minutes of running time.

Comparing wall clock against the monotonic timer therefore **cannot** identify
these events, which is why that approach was built and then abandoned (#3724,
closed unmerged). The open question is what blocked the database isolate for
that long with nothing else queued behind it — isolate starvation, a blocking
call on the DB isolate, or platform-level throttling. Answering it needs
app-lifecycle and platform evidence, not clock comparison.

These two events contribute 1,356 s and still distort any all-window ranking;
exclude them when aggregating, but do not treat them as explained.

## What the April remedies achieved

Several April top-10 shapes are **absent** from the current window — `dayPlanById`
(then 6,145 calls / 376 s), `ratingsForTimeEntries` (2,699 / 850 s) and
`getLastSentCounterForEntry` (2,689 / 662 s) no longer appear. Those fixes landed and
held. The April diagnosis of `countInProgressTasks` also holds up: it now runs behind
`idx_journal_task_status_private` and no longer appears near the top.

What did *not* get addressed is the round-trip floor, which is why `agent.sqlite` —
barely present in April — now dominates.

## Remedies, ordered

1. **Batch the `agent_entities` by-id N+1** (mode A, entry 2). Add a by-ids read and
   route `agent_repo_core.dart:88` and both `agent_attention_projection.dart` call
   sites through it.
2. **Stop re-reading all ~900 agents' latest state on every invalidation** (entry 1).
   `latestEntitiesByAgentIds` (`agent_repo_core.dart:162`) is already chunked and
   correctly indexed; the cost is that it runs 4,211 times in 14 days. Callers:
   `agent_repo_queries.dart:141`, `agent_repo_core.dart:388`, `:456`.
3. **Collapse the per-task `json_extract($.taskId)` lookups** (entry 4).
4. **Cache / narrow `getAllAgentIdentities`** (entry 6) — 1,734 full-table reads of
   every agent identity. Callers: `agent_service.dart:130`,
   `profile_usage_provider.dart:23`, `agent_template_metrics.dart:228`,
   `embedding_backfill_controller.dart:256`.
5. **Fix the single-id `journal … id IN (?)` N+1** (entry 9).
6. **Give `sync.sqlite` a read pool** (mode B) — the single highest-leverage change for
   entries 3, 5, 7 and 8, none of which is individually fixable.
7. **Replace the two `outbox` counting full-index scans** with a maintained counter or
   a predicate-matching partial index (entry 3).
8. **Audit write-transaction scope in the sync pipeline** — what holds the write lock
   long enough to produce 25 s convoys.
9. **Speed up the habit heatmap query** (entry 10) — 636 ms avg with
   `USE TEMP B-TREE FOR ORDER BY` on 54 of 78 super-slow captures.
10. ~~**Delete the dead `habitCompletionsInRange` drift query.**~~ Done in #3723;
    the query and its generated output are gone.
11. ~~**Add wall-clock/monotonic divergence detection**~~ — attempted in #3724
    and **abandoned**. It cannot work: the outlier durations were themselves
    measured by the monotonic `Stopwatch`, so the monotonic clock advanced
    throughout and the wall-vs-monotonic skew is ~0. See Mode C.

## Code map

- `lib/database/common.dart:73-79` — pragmas (`busy_timeout`, `wal_autocheckpoint`)
- `lib/database/common.dart:116-185` — `openDbConnection`, interceptor installation, `readPool`
- `lib/database/slow_query_logging.dart:24` — super-slow threshold
- `lib/database/slow_query_logging.dart:234` — the `Stopwatch` whose semantics this doc turns on
- `lib/database/database_data_queries.dart:40` — live habit heatmap query
- `lib/features/agents/database/agent_repo_core.dart:88` — by-id read (N+1)
- `lib/features/agents/database/agent_repo_core.dart:162` — `latestEntitiesByAgentIds`
- `lib/features/agents/database/agent_attention_projection.dart:430,524` — by-id reads (N+1)
- `lib/features/agents/database/agent_database.drift:214,253` — `getAgentEntityById`, `getAllAgentIdentities`
- `lib/database/sync_db_tables.dart:26` — `idx_outbox_actionable_priority_created_at`
