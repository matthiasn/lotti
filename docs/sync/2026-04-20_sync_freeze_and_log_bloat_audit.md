# Sync Freeze & Log Bloat Audit

**Date:** 2026-04-20
**Branch context:** `fix/sync_db_lock` (freshly branched off `main`)
**Evidence:**

- `logs/sync-2026-04-20.log` (13.3 MB, 84,251 lines, 17.5 h capture)
- `logs/slow_queries-2026-04-20.log` (3.0 MB, 12,863 entries)
- `lib/features/sync/**` on `main` as of this date
- `lib/features/sync/current_architecture.md` (prior investigation, 2026-03-12)

The user reports three symptoms: (1) the desktop UI freezing for seconds at a time, (2) 12.8 MB of sync log generated in less than a day on moderate usage, and (3) suspected redundant reprocessing of Matrix events.

This document is the audit output. The fix proposals are at the end; they are not yet implemented.

---

## 1. UI freezes — root cause proven

### What the code does

`lib/features/sync/matrix/pipeline/matrix_stream_processor.dart:471` opens a
`JournalDb.transaction` per ordered slice of events and performs, inside that
transaction, awaits that are **not pure DB work**:

| File:line | Await | Class |
| --- | --- | --- |
| `matrix/sync_event_processor.dart:144, 398, 493, 1244` | `event.downloadAndDecryptAttachment()` | Network (Matrix HTTPS + decrypt) |
| `matrix/sync_event_processor.dart:149, 403, 498, 1249` | `decodeAttachmentBytes(...)` | Gzip (inline for <2 KB, `compute()` above 2 KB) |
| `matrix/sync_event_processor.dart:504` | `atomicWriteBytes(...)` | File I/O |
| `matrix/sync_event_processor.dart:1177` | `file.readAsString()` | File I/O |
| `matrix/sync_event_processor.dart:350` | `_descriptorDownloader.download(...)` | Network + gzip |
| `matrix/sync_event_processor.dart:928–931` | `loader.load(jsonPath, incomingVectorClock)` | Network + gzip + file I/O (all of the above, inside the apply path) |

All of these are awaited from inside the writer transaction opened at
`matrix_stream_processor.dart:471`.

### Why that is a freeze

The JournalDb uses `NativeDatabase.createInBackground()` with `readPool: 4` and
`journal_mode = WAL` (see `lib/database/common.dart:73, 168`). WAL lets reads
proceed against snapshots while a writer is open, but **a writer transaction
still holds SQLite's EXCLUSIVE writer lock for the entire duration of the
closure**. Any other write on the same database — a user saving a journal entry,
a settings update, an agent write — has to queue behind it. The default
`busy_timeout` is `5000 ms`; past that the UI just appears frozen.

When `loader.load()` awaits a 50–200 KB agent JSON or a multi-MB media file
over the network inside that transaction, the lock is held for the full
round-trip, not just the DB write.

### Why the logs confirm it

`slow_queries-2026-04-20.log` contains the exact signature of a transaction
that held the writer lock for ~5.6 s:

```
01:01:56.882  sync   5,752 ms   UPDATE sync_sequence_log SET status=…
01:01:56.883  sync   5,589 ms   SELECT * FROM "outbox" WHERE status=? ORDER BY priority, created_at LIMIT 1
01:01:56.882  sync   5,588 ms   SELECT COUNT("outbox"."id") … WHERE status IN(?,?)
```

Three statements, three separate queries, all completing on the same
millisecond at ~5.6 s wall time. That is what it looks like when a transaction
stalls and then flushes: every queued statement in the transaction reports the
total wait as its own duration.

The same pattern appears on `db.sqlite` (JournalDb) at **13:30:07.053–.955**:

- 8 queries, each 2.4–3.4 s, all clustered in a ~900 ms window
- all on `journal` table reads (`SELECT * FROM journal … id IN(?*)`)

That is the user-visible freeze. A widget tree awaiting journal entries had to
wait 2.4–3.4 s while sync-side I/O held the writer lock.

### Separate but related: send-side gzip on the main isolate

`lib/features/sync/matrix/matrix_message_sender.dart:298` calls
`gzip.encode(fileBytes)` synchronously, on the main isolate, with no
`compute()` offload. For payloads larger than ~10 KB this stalls the UI
directly, independent of any DB lock. `attachment_decoding.dart` already uses
the correct pattern (inline for <2 KB, `compute()` above); the outbox send path
does not.

### Confidence

High. Direct code citation + matching log signature at two separate times of
day on two separate databases.

---

## 2. Log bloat — 13 MB / 84k lines / 17.5 h

### File stats

- 13,967,140 bytes, 84,251 lines, 2026-04-20 00:00:03 → 17:30:16
- Sync-family share: ~99.3 %. Non-sync lines are stack frames from 20 errors.
- Top-level domains: `sync` 26,965, `MATRIX_SYNC` 22,304, `OUTBOX` 21,633, `MATRIX_SERVICE` 12,765.

### Volume drivers, ranked

| # | Share | Category | Notes |
| --- | --- | --- | --- |
| 1 | ~41 % | Outbox send chatter | `MATRIX_SERVICE sendMatrixMsg` 12,397 + `OUTBOX sendNext()` 9,574 + `sync outbox.send` 6,379 + `OUTBOX queue` 6,133. ~10 log lines per actual `sequence.recordSent`. |
| 2 | per-burst peak | SDK pagination bursts | `sdkPagination.backfill events=3,596 pages=15` in a single slice produced **3,011 lines/s at 15:12:49**, of which 1,476 were `attachmentIndex.record` + 1,476 `attachment.observe`. 39 seconds crossed 100 lines/s today. |
| 3 | steady | Per-event attachment logging | `attachment.observe` 3,226 + `attachmentIndex.record` 3,280, both ~1.1× per unique event. The March-era 34×/event storm is gone, but per-event emission itself is not coalesced. |

### What is not a problem anymore

- The March replay-wave pattern (5–6 waves × 10–20k events each, single
  `lotti-…` event IDs appearing 5+ times) is mostly gone. Max per-ID
  recurrence today is 7; median is 2–3. The bounded-tail catch-up fix
  is working.
- Raw per-callback `signal.clientStream` / `signal.timeline` lines are **zero**.
  The 2026-03-12 diagnostics restructure is intact — the receive path
  logs one `liveScan.summary` per scan with aggregated `signalSummary`.

### What is still a problem

- **Outbox is extremely chatty.** At info level. One real send should
  produce one summary line, not ten.
- **SDK pagination backfill dumps large slices inline on the hot path.**
  3,596 events in one slice is what drove the 3,011 lines/s peak. The SDK
  is re-delivering pages whose bulk is already-seen; dedupe catches them
  downstream, but only after they are observed, logged, and indexed.
- **Agent-entity churn is still heavy.** Two entities dominate repeat
  traffic:
  - `3bc251b9-41bc-4626-93da-30e8d92eb212` × 195
  - `f027a97f-327c-4c40-b6ea-70f023cec1a0` × 189
  Top download-repeat paths are all `/agent_entities/…`. This matches
  Failure Surface 2 in `current_architecture.md` and is a live concern.

---

## 3. Redundant processing

### Verdicts against the user's hypotheses

1. **Re-reading old Matrix events?** Partially yes, in bursts.
   74 `sdkPagination.backfill` runs over the day pulled 596–3,596 events
   per slice. `batch.summary` lines repeatedly show
   `total=N applied=0 suppressed=N-k` — the SDK re-delivers already-seen
   pages, dedupe catches them, but not before the observe+index+log work
   has run. The per-entity replay amplification is much lower than
   March, but the burst volume is not bounded by user activity.
2. **Attachment observe/download still logging per-event?** Yes, still
   per-event on the observe side. 3,226 observe lines for 2,850 unique
   event IDs (1.13× per event). Worst repeat download paths are all
   `/agent_entities/…`: `13b1fb86…` × 9, `cb97acec…` × 6, `3d086ac7…` × 6.
3. **Sync running while the user is active (UserActivityGate bypass)?**
   The outbox is gated (409 `activityGate.wait`, 207 `drain.paused`,
   46 `sendNext.postSettle.paused`). **The inbound pipeline is not.**
   The 3,011 lines/s burst at 15:12:49 fired during active user time,
   700 ms after an `activityGate.wait ms=1737` — outbox paused, inbound
   ran anyway and held the writer lock.

### Slow-query correlations (`slow_queries-2026-04-20.log`)

| Total ms | Count | Template |
| --- | --- | --- |
| 1,623,939 | 3,586 | `SELECT * FROM journal WHERE deleted = FALSE AND id IN(?*)` — 28 % of all logged time |
| 571,870 | 1,817 | `RatingLink` linked_entries + journal join (IN-list sizes 2..N — N+1 shape) |
| 88,148 | 365 | `SELECT id FROM journal WHERE deleted = FALSE AND id IN(?*) ORDER BY date_from DESC` |
| 71,302 | 339 | `UPDATE sync_sequence_log SET status=?, updated_at=? …` |
| 67,824 | 637 | `journal WHERE type IN(…) AND date_from/date_to` |
| 62,090 | 597 | `Task` list ordered by `task_priority_rank` |
| 59,977 | 881 | `host_counters` CTE (`last_counter` advance) |
| 36,116 | 339 | `SELECT * FROM sync_sequence_log WHERE status … request_count<?` (paired poll for the UPDATE above) |
| 27,098 | **17** | **`custom: UPDATE journal SET project_id = (correlated subquery)` — avg ~1,594 ms per call** |

Duration histogram (all 12,863 entries):

| Bucket | Count | % |
| --- | --- | --- |
| <50 ms | 5,540 | 43.1 % |
| 50–100 ms | 655 | 5.1 % |
| 100–500 ms | 5,044 | **39.2 %** |
| 500 ms – 1 s | 1,314 | 10.2 % |
| 1–5 s | 307 | 2.4 % |
| >5 s | 3 | 0.02 % |

The fat 100–500 ms bucket is where most wall time is actually spent, not
in the rare multi-second outliers. That is consistent with a writer
lock being held for a few hundred ms at a time during apply slices.

---

## 4. Timeline signal sources — still two, still redundant

Code: `lib/features/sync/matrix/pipeline/matrix_stream_signals.dart:65,
103–108`.

Two independent sources trigger catch-up or live-scan:

1. **Client stream** (`sessionManager.timelineEvents`). Triggers initial
   catch-up once, then live-scan in steady state.
2. **Live timeline callbacks** — all five types wired to the same
   `onTimelineSignal()` handler: `onNewEvent`, `onInsert`, `onChange`,
   `onRemove`, `onUpdate`.

In a single-user append-only model, `onChange` / `onRemove` / `onUpdate`
have no legitimate trigger. They are being counted but do the same
`scheduleLiveScan()` work as the others.

Separately, `lib/features/sync/ui/app_lifecycle_rescan_observer.dart:34`
calls `forceRescan(includeCatchUp=true)` on every app focus, overlapping
with the 30-second wake detector in `matrix_stream_live_scan.dart:158–168`.
Today's log shows the guard firing:

- 321 `forceRescan` lines
- 116 of which are `forceRescan.skipped (already in flight)` — callers are
  nudging faster than the rescan completes

### Marker durability

- `lastReadMatrixEventId`: persisted to `settingsDb` only when the Matrix
  server has assigned an event ID (starts with `$`).
  (`matrix/last_read.dart:4–5`, `settingsDb:7–13`.)
- `lastReadMatrixEventTs`: persisted on every marker advance
  (`matrix_stream_processor.dart:648`).
- Marker advancement is per-event within an ordered slice, and is blocked
  for the rest of the slice if any earlier event failed
  (`blockedByFailure` at `matrix_stream_processor.dart:584`).

### Replay-window bounds on resume

Three wake paths all call `_attachCatchUp()`:

- Connectivity regain (`matrix_service.dart:274`)
- App lifecycle resume (`app_lifecycle_rescan_observer.dart:34`)
- Live-scan wake detection after >30 s idle (`matrix_stream_live_scan.dart:158–168`)

`CatchUpStrategy.collectEventsForCatchUp()` uses `preContextSinceTs =
anchorTimestamp - 1000ms` and pages the timeline until that boundary is
crossed. **Failure mode:** the best-effort fallback
(`catch_up_strategy.dart:246–260`) returns all visible events as-is when
the boundary cannot be reached. That is the last remaining path that can
synthesize a full-tail replay on stale markers; it is not currently
capped when `timestampAnchored=true`.

### Dedupe windows

- `_seenEventIds`: 5,000 (`matrix_stream_processor.dart:146`)
- `_completedSyncIds`: 5,000 (`matrix_stream_processor.dart:152`)
- Retry tracker: ~2,000 entries, 10 min TTL

A single SDK pagination slice of 3,596 events does not overflow these,
but repeated overlapping slices in quick succession can.

---

## 5. Hot-loop periods

Seconds exceeding 100 sync-log lines per second today:

| lines/s | timestamp | dominant content |
| --- | --- | --- |
| **3,011** | 15:12:49 | `attachmentIndex.record` 1,476 + `attachment.observe` 1,476, paired 1:1; triggered by `sdkPagination.backfill tsBoundary events=3596 pages=15` at line 46160 |
| 832 | 15:16:57 | same mix |
| 715 | 16:38:44 | same mix |
| 700 | 17:14:18 | same mix |
| 612 | 01:06:26 | same mix |
| 453 | 01:07:34 | same mix |
| 400 | 01:52:49 | same mix |

39 distinct seconds crossed the 100 line/s threshold. Every hot second
is dominated by the same observe+index pair, every time driven by an SDK
pagination backfill slice.

---

## 6. Known-live error paths

From today's log, 20 errors total, clustered into two paired classes:

- 10 × `ERROR AGENT_SYNC resolve.agentEntity.descriptorFetch`
- 10 × `ERROR MATRIX_SYNC process FileSystemException`

All on `/agent_entities/<uuid>.json` paths. Causes reported in context:
"This event hasn't any attachment or thumbnail", "File is no longer
cached", "Connection reset by peer". Spread across 00:08, 01:09, 03:04,
10:14. These do not block the whole pipeline — each is caught and
converted to a retry-tracker entry — but they are real and they are on
the same code path that is holding the DB writer lock.

Backfill VC-validation guard is actively catching stale exact hits
today: 6 `backfill.exactRejected` + 7 `backfill.coveringRejected`. The
March stabilization work is doing its job.

---

## 7. Proposed architecture simplifications

Ordered by impact-vs-risk, smallest first.

### Priority 1 — Freeze fix (the purpose of `fix/sync_db_lock`)

**P1a. Pull I/O out of the apply transaction.**
In `matrix_stream_processor.dart`, resolve all attachment bytes,
descriptor payloads, and media downloads **before** opening
`JournalDb.transaction`. The transaction should contain only synchronous
DB writes plus `recordReceivedEntry` DB ops:

```
for slice in ordered_slices:
    resolved = await Future.wait([resolvePayload(e) for e in slice])
    // network + gzip happens here, no lock is held
    await _journalDb.transaction(() async {
        for (e, payload) in resolved:
            applyToLocalStores(payload)   // pure DB
            recordSequence(payload)       // pure DB
    });
```

**P1b. Offload send-side gzip to `compute()`** at
`matrix_message_sender.dart:298`. Match the existing
`attachment_decoding.dart` strategy: inline for <2 KB, `compute()` above.

**P1c. Add a regression test** that opens `JournalDb.transaction` from
the sync pipeline with an injected 500 ms delay in the mock attachment
fetch, and asserts that a concurrent `JournalDb.watch*` query completes
in under 100 ms.

### Priority 2 — Log volume

**P2a. Roll up outbox send logs** from ~10 lines per send to one info
summary with `{status, size, encoding, ms}`. Keep detailed lines behind a
debug flag.

**P2b. Roll up per-event attachment logs.** Replace per-event
`attachment.observe` + `attachmentIndex.record` lines with a batch-level
summary that already exists in pattern (`liveScan.summary`,
`batch.summary`). One line per SDK pagination slice with
`observed=N indexed=N suppressed=K applied=M`.

### Priority 3 — Signal consolidation

**P3a. Drop `onChange` / `onRemove` / `onUpdate`** timeline callbacks in
`matrix_stream_signals.dart:106–108`. Log a counter if any of them ever
fires so we can re-enable if needed.

**P3b. Remove `AppLifecycleRescanObserver`** or make it conditional on
"wake detector has not fired in the last N seconds." The 30-second wake
detector already covers the normal resume case; the lifecycle observer
is responsible for the `forceRescan.skipped (already in flight)` noise
seen 116 times today.

**P3c. Choose one authoritative timeline source** (prefer the live
timeline). Keep the client-stream signal as a session-alive heartbeat
only, not as a payload trigger.

### Priority 4 — "Read only what is new" on resume

**P4a. Cap the `timestampAnchored` best-effort fallback** in
`catch_up_strategy.dart:246–260` to `missingMarkerFallbackLimit` (1,000),
same as the other fallback path. Emit a single diagnostic when it
triggers.

**P4b. Gate the inbound pipeline** on `UserActivityGate`, at slice
granularity. Option A: defer SDK pagination slices above a threshold
(e.g. >500 events) until idle. Option B: yield per slice and re-check
activity. The 3,011 lines/s attachment burst has no business running
while the user is typing.

### Priority 5 — Agent descriptor model

Still live today, per the `3bc251b9…` and `f027a97f…` repeat counts and
the `/agent_entities/…` download-repeat distribution. This is Failure
Surface 2 from `current_architecture.md`.

**P5a. Short-term:** validate the resolved descriptor's VC against the
envelope's declared coverage before accepting. If the descriptor is
ahead of what the envelope covers, emit a bounded diagnostic and skip
(do not synthesize a gap).

**P5b. Longer-term:** bind text events to their exact descriptor event
ID, not to `jsonPath`, so later attachment writes on the same path
cannot retroactively change what an older text event resolves to.

### Priority 6 — Slow-query follow-ups (not sync-feature-owned)

Not part of this PR; noted for downstream tracking:

- `SELECT * FROM journal WHERE id IN(?*)` at 28 % of all slow time
  across the day. Attribution blocked — slow-query log does not include
  stack frames. Consider enabling caller frames.
- `RatingLink` linked_entries join shows N+1 shape (IN-list sizes
  2, 3, 4, 5, …). 1,817 hits / 572 s cumulative.
- `custom: UPDATE journal SET project_id = (correlated subquery)`
  averages 1,594 ms per call. 17 calls today. Worth profiling.

---

## 8. Recommended sequencing

1. **P1a + P1b + P1c on `fix/sync_db_lock`** — this is the branch
   purpose. Removes the freezes.
2. **P2a + P2b** as a separate PR — cheap, high visibility.
3. **P3a + P3b + P3c** as a "signal sources" PR.
4. **P4a + P4b** as a "strict new-only receive" PR.
5. **P5a, then P5b** as the final correctness pass.
