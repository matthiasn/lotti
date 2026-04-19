# Sync startup — duplicate work, stuck watermark, and notification analysis

Date: 2026-04-19
Logs: `logs/sync-2026-04-19.log` (401 KB, 2,519 lines) from a fresh desktop
restart with no new activity on mobile.

This document captures the root causes of three symptoms seen on this startup
and proposes concrete fixes that should also carry into the Single User Model
migration.

> **Status (PR #2976, 2026-04-19):** the behaviours and code pointers described
> under *Symptom 1*, *Symptom 2*, and *Symptom 3* below describe the
> **pre-fix** state of the tree. The concurrency hazards, per-event
> gap-detection log, `start.catchUpRetry` redundancy, and connectivity
> bootstrap duplication were all fixed by PR #2976. `_attachCatchUp()` now
> owns `_catchUpInFlight` and the deferred-live-scan flush; `forceRescan`,
> `runInitialCatchUpIfReady`, `runGuardedCatchUp`,
> `_scheduleInitialCatchUpRetry`, `startWakeCatchUp`, and `_startCatchupNow`
> all delegate to it rather than managing the flag themselves. The file
> pointers below still indicate where each class lives, but the assertions
> about "does not acquire `_catchUpInFlight`" apply to the tree *before* the
> PR.

## Symptom 1 — 400 KB of sync logs with no new mobile activity

### What the log actually shows

Every observable step of catch-up runs twice, concurrently, with identical
parameters:

| # | Log event | Time (T+ms) |
|---|---|---|
| 1 | `MATRIX_SERVICE forceRescan.connectivity includeCatchUp=true` | +0 |
| 2 | `MATRIX_SYNC forceRescan.start includeCatchUp=true inst=1` | +0 |
| 3 | `MATRIX_SERVICE forceRescan.startup includeCatchUp=true` | +298 |
| 4 | `MATRIX_SYNC forceRescan.skipped (already in flight) inst=1` | +298 |
| 5 | `MATRIX_SYNC catchup.waitForSync synced=true inst=1` | +4508 |
| 6 | `MATRIX_SYNC catchup.waitForSync synced=true inst=1` | +4508 (within 200 µs!) |
| 7 | `sdkPagination.backfill.start events=610 requireServerBoundaryPage=true lastEventId=$Zf1G…` | +4529 |
| 8 | `sdkPagination.backfill.start events=610 requireServerBoundaryPage=true lastEventId=$Zf1G…` | +4538 |
| 9 | `catchup.recovered via=timestampBoundary snapshot=810 slice=89` | +5313 |
| 10 | `catchup.recovered via=timestampBoundary snapshot=810 slice=89` | +5669 |

From this point on every event in the 89-event slice is processed twice.
Each event emits, per pass: `SyncEventProcessor: processing`,
`attachmentIndex.hit`, `attachment.decode`, `processor.resolve`,
`processor.apply`, `sequence.coveredClocks`, `sequence.largeGap`,
`sequence.gapDetected`, `sequence.recordReceived`, `processor.gapDetection`
and a trailing `processing` line. That is the bulk of the 401 KB.

### Root cause — `_attachCatchUp()` is not mutually-excluded with itself

Guards exist but they cover only *some* entry points. The forceRescan
serialisation is done by `_forceRescanCompleter`, but the real work inside
`_attachCatchUp()` is not gated by `_catchUpInFlight` when called from
external force-rescan:

- `lib/features/sync/matrix/pipeline/matrix_stream_catch_up.dart:605`
  — `forceRescan()` calls `_attachCatchUp()` at line 641 without setting
  `_catchUpInFlight = true`. The flag is only *checked*, never *acquired*
  in this path.
- `lib/features/sync/matrix/pipeline/matrix_stream_catch_up.dart:158`
  — `runInitialCatchUpIfReady()` also calls `_attachCatchUp()` directly
  with no guard at all.
- `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart:258`
  — calls `_catchUp.runInitialCatchUpIfReady()` as part of `start()`.

At startup **four** entry points fire within ~500 ms of each other:

1. `MatrixService.init()` subscribes to `Connectivity().onConnectivityChanged`
   (`matrix_service.dart:219`). Dart emits the current connectivity state
   synchronously on subscribe, so this fires immediately and calls
   `pipeline.forceRescan()` → `_attachCatchUp()` (without acquiring
   `_catchUpInFlight`).
2. `MatrixService.init()` unawaited `Future.delayed(300ms)` → another
   `pipeline.forceRescan()` (`matrix_service.dart:149`). This one is
   correctly short-circuited by `_forceRescanCompleter` (log line 4 above).
3. `MatrixStreamConsumer.start()` calls `_catchUp.runInitialCatchUpIfReady()`
   which calls `_attachCatchUp()` directly with **no flag check at all**.
   This races (1).
4. `MatrixStreamSignalBinder.start()` schedules
   `Future.delayed(150ms).then((_) => _catchUp.runGuardedCatchUp('start.catchUpRetry'))`
   (`matrix_stream_signals.dart:129`). That path *does* set
   `_catchUpInFlight`.

So (1) and (3) proceed in parallel: two concurrent `_waitForSyncCompletion`
calls both unblock on the same `client.onSync.stream.first`, two concurrent
`CatchUpStrategy.collectEventsForCatchUp` calls produce the same 89-event
slice, and both call `_processor.processOrdered` back-to-back. The
`processOrdered.serialize` log line at T+5669 ms is the second
`processOrdered` *waiting* for the first to finish; it does not prevent the
re-application.

### Downstream amplification

Inside the processor, the second batch does recognise completed events
(`skippedCompleted=44` in the second `batch.summary`), but the
`SyncEventProcessor.process()` call at `sync_event_processor.dart:617` still
runs all of its ingestion logging for every event in both passes because
the completion check happens *after* it emits `processing …` and after it
calls `_handleMessage` for sync-payload events. Each event therefore logs
~12 lines in the first pass and ~6 in the second pass.

### Recommendations

> **Applied in PR #2976.** Recommendations 1 and parts of 2 have landed; see
> the *Status* note at the top of this document. The remaining items
> (processOrdered batch dedup, per-event log demotion) are follow-ups.

1. **Acquire `_catchUpInFlight` once for the whole external catch-up run.**
   *(Applied in PR #2976.)* `_attachCatchUp()` now sets and clears
   `_catchUpInFlight` and calls `_flushDeferredLiveScan`; every external
   call site (`forceRescan`, `runInitialCatchUpIfReady`,
   `runGuardedCatchUp`, `startWakeCatchUp`, `_scheduleInitialCatchUpRetry`,
   `_startCatchupNow`) delegates to it. If the flag is already set, the
   method short-circuits with a `catchup.skipped (in flight)` log and
   returns `false` so the caller can reschedule.
2. **Collapse the startup-time triggers.** *(Applied in PR #2976 for 2.2
   and 2.3; 2.1 retained — see note.)* Today the sequence is
   *connectivity-bootstrap → unawaited 300 ms → consumer.start →
   signals.start 150 ms*. Three of those four used to end up invoking
   catch-up; after PR #2976 only one actual catch-up runs:
   - The unawaited `Future.delayed(300 ms)` in `matrix_service.dart:149`
     is **retained** as a belt-and-suspenders trigger in case the consumer
     starts before the room is ready; since `_attachCatchUp()` now
     self-guards, a concurrent run just no-ops instead of racing.
   - The connectivity listener in `matrix_service.dart` now swallows the
     first emission (`service.forceRescan.connectivity.bootstrapSkipped`)
     regardless of whether the device starts online or offline, so the
     initial `connectivity_plus` snapshot does not duplicate the startup
     flow.
   - The 150 ms `runGuardedCatchUp('start.catchUpRetry')` in
     `matrix_stream_signals.dart` now only fires when the initial
     catch-up has not yet completed. Once `catchup.initial.completed`
     fires, the retry is skipped instead of kicking a second full
     `_waitForSyncCompletion` + event-replay pass.
3. **De-duplicate `processOrdered` at the batch level.** In
   `matrix_stream_processor.dart:335`, hash the ordered slice
   `(firstEventId, lastEventId, length)` and, when a waiting caller
   presents an already-applied batch, short-circuit to a single
   `batch.summary` line instead of re-entering
   `_processOrderedInternal` for the whole slice.
4. **Reduce per-event log volume in the steady state.** Demote the
   `attachment.decode`, `attachment.save`, `processor.resolve`,
   `processor.apply`, and `sequence.coveredClocks` lines from
   `captureEvent` (INFO) to trace. Keep only the batch-level summaries
   (`catchup.slice`, `batch.summary`, `liveScan.summary`) at INFO. With
   the duplication fixed, startup on an idle device should be ~20–40
   lines.

## Symptom 2 — slow initial catch-up

### What the log shows

`waitForSync` blocks for ~4.5 seconds at startup (T+0 → T+4508). After that,
the slice of 89 events takes 14.9 seconds end-to-end because each event is
processed twice serially (T+5313 → T+20 s). On a clean "nothing to sync"
restart the user-visible catch-up latency is therefore dominated by:

1. The Matrix SDK `onSync.stream.first` wait (~4.5 s). This is the one-shot
   initial server sync and is unavoidable.
2. The duplicate processing pass (~7.5 s) — directly removed by Symptom 1
   fix #1.
3. The gap-detection side effects per event (~150–250 ms each). See
   Symptom 2 follow-up below.

### The 7,344-counter pre-history gap keeps the watermark pinned

Every event emits `sequence.largeGap gapSize=7344 (lastSeen=81982,
counter=89327) - recording full gap` with `gapSize` growing by 1 on each
subsequent event. The numbers tell a very specific story:

- `lastSeen` is the output of
  `SyncDatabase.getLastCounterForHost` (`lib/database/sync_db.dart:404`),
  which is the **contiguous-prefix watermark** for that host (largest N
  such that counters 1..N are all resolved). It is deliberately *not*
  `MAX(counter)`.
- `lastSeen=81982` means counters 81 983…89 326 for that host are still
  in `missing` status in `sync_sequence_log`. They have never been
  resolved by a backfill response.
- Every new event at counter 89 327, 89 328, … therefore triggers
  `largeGapDetected` with a gap of 7 344+N. The
  `_materializedUpperBound[hostId]` cache (service `:462–487`) already
  keeps the *DB cost* bounded (`inserted=0` for the already-materialised
  range), but the logging and the log-service fan-out still fire for
  every single event.

In other words: *nothing new happened on mobile, but the local sequence
log has never recovered from a permanent pre-history gap, so every
incoming event on this host re-emits the full gap-detection trace.*

### Recommendations

1. **Quiet the gap-detection log in the already-materialised case.** In
   `sync_sequence_log_service.dart` around line 466, the
   `alreadyMaterialized` branch currently skips the DB write but still
   emits `largeGapDetected` / `gapDetectedRange` / the
   `sequence.recordReceived detected N gaps` summary. Move the `_trace`
   calls inside the `!alreadyMaterialized` branch so the log is silent
   when we have nothing new to record.
2. **Stop counting already-materialised ranges as "newMissingDetected".**
   Today every event on a host with a pre-history gap flips
   `newMissingDetected = true` through the small-gap path even when
   `insertedCount == 0`, which then emits a backfill nudge. Guard the
   assignment with `if (insertedCount > 0)` (the large-gap path already
   does; the small-gap loop needs the same).
3. **Add a one-shot "here is your backfill watermark" catch-up on first
   contact.** When a host has an unresolved pre-history gap at startup,
   emit a single targeted backfill request for the earliest unresolved
   range instead of materialising 7 344 rows. This closes the root issue
   (the watermark is stuck because nobody ever asked for those counters)
   rather than just quieting the symptom.

## Symptom 3 — receiving side misses live updates

### What the log shows

When both devices are active in steady state (after T+30 s in the log) the
live-scan pipeline does pick up remote events (e.g. `afterSlice=4
deduped=4 processed=4`). The places where it *fails* to advance are:

- `batch.summary … blocked=true` (log T+59 s). This corresponds to the
  `blockedByFailure` path in
  `matrix_stream_processor.dart:_processOrderedInternal`: if any event in
  the slice hits a retry-scheduled failure (e.g. missing attachment), the
  slice stops advancing `lastProcessedEventId`, and subsequent
  `scheduleLiveScan` runs compute `afterSlice` against the same marker —
  which can still be in the user's view because the "new" event is
  exactly the one blocked.
- `liveScan.skipped initialCatchUpIncomplete` / `catchUpInFlight`. The
  live-scan controller *defers* signals while `_isCatchUpInFlight()` is
  true and only flushes from four specific completion paths
  (`_startCatchupNow.whenComplete`, `runGuardedCatchUp` finally,
  `_scheduleInitialCatchUpRetry` whenComplete, `startWakeCatchUp`
  then-branch). The external `forceRescan()` path, which actually runs
  `_attachCatchUp()` in this log, never flushes the deferred live-scan
  because it never sets or clears `_catchUpInFlight` at all (see Symptom
  1). If a remote event arrives during such a catch-up, the signal is
  stored in `_liveScanDeferred` and is never flushed until the *next*
  guarded path completes — which may be much later, or never in a quiet
  session.

### Recommendations

1. **Make `forceRescan()` participate in the deferred-live-scan contract.**
   Either acquire `_catchUpInFlight` for its internal `_attachCatchUp()`
   call (and call `_flushDeferredLiveScan('forceRescan')` in the
   `finally`), or route external callers through `runGuardedCatchUp`
   which already does both. Symptom 1 fix #1 subsumes this.
2. **Do not let "blocked=true" suppress newer work indefinitely.** In
   `_processOrderedInternal`, when a slice ends with `blockedByFailure`
   and a *newer* eventId was seen but not applied, advance
   `lastProcessedEventId` *only* past the blocked event and keep the
   retry tracker responsible for the failed one. Today any failure in
   the tail re-blocks the whole slice, which is why the live-scan
   summary keeps reporting `afterSlice=0 latest=<older marker>` after a
   transient attachment failure.
3. **Treat `onTimelineEvent` as the authoritative notification signal.**
   The `timelineEvents` listener in `matrix_stream_signals.dart:65` is
   the only notification the receiver gets between catch-ups. Today it
   calls `handleFirstStreamEvent` (no-op after first event) and then
   `handleClientStreamSignal` (returns `true` and only sets
   `_deferredCatchup` while `_catchUpInFlight` — the signal is
   effectively dropped). The invariant should be: if
   `_initialCatchUpReady` is true, always schedule a live scan — the
   scan's own guard will defer it correctly; if it is false, record the
   event id so the completing catch-up path can confirm coverage
   instead of needing a trailing catch-up.

## Applying this to the Single User Model migration

The unified account model removes the per-device room routing, which makes
the concurrency hazards above *worse*: with a single shared user, every
device ingests every event, and the startup-time "three concurrent
catch-ups" pattern multiplies by the number of devices observing the same
room. The migration should adopt, before cutover:

- A single `catchUp.acquire()` / `catchUp.release()` primitive that every
  external entry point must use. Document the state machine
  (`idle → inFlight → trailingPending → idle`) in a
  `stateDiagram-v2` in the sync feature README.
- A `SyncSequence.ensureForHost(hostId)` that kicks exactly one targeted
  backfill per host with an unresolved pre-history gap, so a freshly
  provisioned user does not generate a 7 344-line log on first sync.
- A per-slice `batch.summary` at INFO and per-event trace-only logging by
  default, with a developer toggle (`SyncTuning.verboseSyncLogging`) to
  reinstate the per-event lines when debugging.

## File pointers

Line numbers below refer to the tree **before PR #2976**. After the PR the
affected behaviours have moved or been removed as indicated; the files
themselves still exist at the same paths.

- `lib/features/sync/matrix/matrix_service.dart:149` — startup
  unawaited forceRescan *(retained; safe under the new self-guard)*.
- `lib/features/sync/matrix/matrix_service.dart:219` — connectivity
  listener used to emit the bootstrap state; now skipped on first
  emission regardless of online/offline status.
- `lib/features/sync/matrix/pipeline/matrix_stream_catch_up.dart:605` —
  `forceRescan()` *used to* not acquire `_catchUpInFlight`; now delegates
  to the self-guarded `_attachCatchUp()`.
- `lib/features/sync/matrix/pipeline/matrix_stream_catch_up.dart:158` —
  `runInitialCatchUpIfReady()` *used to* call `_attachCatchUp()`
  unguarded; now the guard lives inside `_attachCatchUp()`.
- `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart:258` —
  consumer start *used to* race with force-rescan; now serialised via
  the shared guard.
- `lib/features/sync/matrix/pipeline/matrix_stream_signals.dart:129` —
  unconditional `start.catchUpRetry` guarded catch-up; now conditional
  on `!_catchUp.initialCatchUpReady`.
- `lib/features/sync/matrix/pipeline/matrix_stream_processor.dart:335` —
  `processOrdered` serialisation (no batch-level dedup). *Still
  outstanding — see follow-ups.*
- `lib/features/sync/matrix/pipeline/matrix_stream_live_scan.dart:98`,
  `:141` — deferred live-scan gates tied to `_isCatchUpInFlight`. Now
  reliably flushed because `_attachCatchUp()` itself invokes
  `_flushDeferredLiveScan` on exit.
- `lib/features/sync/sequence/sync_sequence_log_service.dart:443–498` —
  `largeGapDetected` / `gapDetectedRange` *used to* fire even when
  `_materializedUpperBound` already covered the range. After PR #2976
  incremental extensions stay silent and `gaps` only contains the newly
  materialised subrange; `newMissingDetected` still fires when the
  materialise pass actually inserts rows.
- `lib/database/sync_db.dart:404` — `getLastCounterForHost` returns the
  contiguous-prefix watermark (by design), which explains the pinned
  `lastSeen=81982`. *Unchanged.*
