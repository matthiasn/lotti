# Sync V2 – 2025-10-18 Deep Dive and Implementation Plan

## Scenario Summary
- Created a task on mobile while desktop was offline; multiple checklist items and audio generated.
- After desktop came online with the app running: nothing showed initially; after restart only some items appeared; several checklist items and an audio/time entry were missing.

## Key Evidence (logs)
- Missing JSON descriptor when applying a SyncJournalEntity:
  - `SmartLoader.localRead PathNotFoundException … checklist_item … .json`
  - `attachmentIndex.miss … /checklist_item/…`
  - `SmartLoader.fetch smart.fetch.miss path=/checklist_item/…`
  - `SyncEventProcessor.missingAttachment: attachment descriptor not yet available`
- Retry dropped after cap (contradicts "keep retrying for missing attachments"):
  - `MATRIX_SYNC_V2 retry.cap: dropping after retry cap: $08gMC… (attempts=5)`
- Catch-up appears not to run (or not counted):
  - Metrics samples show `catchup=0` across the period despite backlog.
- Descriptor recording delayed or skipped for older attachments:
  - Many `attachmentIndex.record …` for recent audio entries;
  - No corresponding `attachmentIndex.record` for the missing older checklist_item path.

## Root Causes
1) Missing-attachment events get dropped by the early retry-cap guard
   - File: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:~245–270`
   - Behavior: An early `attempts >= _maxRetriesPerEvent` check marks the event as handled (dropped) before considering that it’s a missing-attachment case. Later logic correctly keeps retrying for missing attachments, but it’s never reached due to the early return.

2) Attachment descriptor recording is gated by timestamp before the record step
   - File: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:~632–669`
   - Behavior: A timestamp gate (`_attachmentTsGate`) skips “attachment” events older than `lastProcessedTs − 2s`. The “Always record descriptors when a relativePath is present” block is placed after this gate, so older descriptor events are never recorded into `AttachmentIndex`. The smart loader can’t locate the JSON descriptor later.

3) Connectivity recovery does not explicitly force a V2 rescan/catch-up
   - File: `lib/features/sync/matrix/matrix_service.dart:~168–206`
   - Current: On connectivity regained, the code triggers legacy timeline listener refresh.
   - Issue: V2 pipeline doesn’t get an explicit `forceRescan(includeCatchUp: true)`, which would help when the app is online again while running.

4) Catch-up visibility and targeting
   - Files: `lib/features/sync/matrix/pipeline_v2/catch_up_strategy.dart`, `matrix_stream_consumer.dart`
   - Observation: Metrics show `catchup=0` throughout the failing window; either catch-up ran and returned empty slices (not counted), or the retry path didn’t trigger. When descriptors are missing for pending jsonPaths, we should bias catch-up to ensure descriptor discovery quickly.

## Implementation Plan

1) Fix early retry-cap drop for missing attachments
- File: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
- Change: In `_processSyncPayloadEvent`, modify the early guard:
  - Before dropping on `attempts >= _maxRetriesPerEvent`, detect if the event’s `jsonPath` is in `_pendingJsonPaths` (i.e., known missing-attachment case).
  - If yes, do NOT treat as handled; schedule the next retry (use existing backoff) and keep the event blocking advancement.
- Outcome: Missing-attachment events keep retrying indefinitely (bounded by TTL) until the descriptor arrives, aligning with the intended behavior.

2) Always record attachment descriptors regardless of the timestamp gate
- File: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
- Change: Move the “record descriptor” block (the `relativePath` → `_attachmentIndex.record(e)`) BEFORE the timestamp-gate `continue` that skips old attachment events. Keep the timestamp gate for media prefetch only.
- Outcome: Even older attachment events populate `AttachmentIndex`; the smart loader can immediately resolve descriptors when retrying text apply.

3) Optional acceleration when descriptor arrives
- File: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
- Current: When a descriptor path is recorded, the code removes it from `_pendingJsonPaths` and schedules a live scan (`_scheduleLiveScan()`).
- Improvement (low-effort): Also call `retryNow()` when a path is cleared from `_pendingJsonPaths` to mark all retries due immediately.
  - Trade‑off: This advances all pending retries, not just the specific event, but keeps implementation simple and responsive.
- Improvement (targeted, future): Track a `Map<String /*jsonPath*/, Set<String> /*eventId*/>` so we can mark only those event IDs due now.

4) Force a V2 rescan + catch-up on connectivity regained
- File: `lib/features/sync/matrix/matrix_service.dart`
- Change: In the `Connectivity().onConnectivityChanged` handler, add:
  - `_v2Pipeline?.forceRescan(includeCatchUp: true);`
- Outcome: When the device transitions online while the app runs, V2 performs a targeted catch-up + live scan, improving recovery from offline creation bursts.

5) Descriptor-focused catch-up when pending jsonPaths persist
- Files: `matrix_stream_consumer.dart`, `catch_up_strategy.dart`
- Add: If `_pendingJsonPaths` is non-empty and hasn’t changed for N seconds, run a descriptor-focused catch-up:
  - Use `CatchUpStrategy.collectEventsForCatchUp` with an expanded limit to ensure we capture descriptor events around the time window of pending texts.
  - This pass does not need to prefetch media; it only needs to traverse and record descriptors into `AttachmentIndex`.
- Outcome: Faster resolution when descriptors lag behind text messages.

6) Metrics and diagnostics
- Files: `lib/features/sync/matrix/pipeline_v2/v2_metrics.dart`, `matrix_stream_consumer.dart`
- Add counters/strings:
  - `pendingJsonPaths` size (and optionally recent keys) in `metricsSnapshot()`.
  - Count `catchupBatches` per startup and upon connectivity-resumed runs; log a brief “catchup.summary events=… idxFound=… escalations=…”
  - Count `retry.missingAttachment` vs generic failures separately (already partially logged).

7) Validation plan
- Reproduce: Create task + 8 checklist items + audio on mobile while desktop offline; let desktop app run, then bring it online.
- Expect:
  - No `retry.cap` for missing attachments; instead, repeated `retry.missingAttachment` with eventual success when descriptor arrives.
  - `attachmentIndex.record` entries for all checklist_item JSON paths, even older ones.
  - Smart loader logs `attachmentIndex.hit` and `smart.json.written` just before successful applies.
  - Metrics show `catchup > 0` at startup and after connectivity regained.
  - All checklist items, audio, and time tracking entries appear without a restart.

## File Touch Points (for implementation)
- `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
  - Early retry-cap guard fix: around lines ~245–270 (`retry.cap`).
  - Move descriptor record ahead of timestamp gate: around lines ~632–669 and ~652–704 (“attachment.observe” / “prefetch”).
  - Optional: call `retryNow()` when clearing `_pendingJsonPaths` on descriptor arrival.
- `lib/features/sync/matrix/matrix_service.dart`
  - Add `_v2Pipeline?.forceRescan(includeCatchUp: true)` in connectivity handler (~line 190).
- `lib/features/sync/matrix/pipeline_v2/catch_up_strategy.dart`
  - Optionally log and slightly tune escalation parameters for descriptor-focused runs.

## Notes
- This plan preserves the V2 design principles: message-driven JSON application (vector-clock aware), minimal rewinds, and stable streaming. The fixes address two correctness gaps (retry drop and descriptor recording) and improve recovery paths (connectivity and catch-up targeting).

---

## Progress Update (Implemented)

Delivered since drafting the plan (key commits referenced by file):

- Descriptor catch-up hardening
  - Added in-flight guard to prevent overlapping runs; reschedules when a run is already executing.
  - File: `lib/features/sync/matrix/pipeline_v2/descriptor_catch_up_manager.dart`
  - Tests: timer stability window, rapid add/remove defers next run, exception logging on cleanup and timer path, and new “no concurrent runs” test.

- Connectivity recovery
  - On connectivity regained, V2 is nudged via an unawaited `forceRescan(includeCatchUp: true)`; errors are logged without blocking the UI thread.
  - File: `lib/features/sync/matrix/matrix_service.dart`

- Attachment ingest and prefetch policy
  - Prefetch now includes JSON descriptors and is sender‑agnostic (still safe due to atomic writes and dedupe). This reduces time‑to‑apply when text arrives before descriptor.
  - File: `lib/features/sync/matrix/utils/timeline_utils.dart`

- SmartLoader local read logging
  - Downgraded the expected “first local read miss” from exception to an info event (`smart.local.miss`), keeping error logs meaningful. Unexpected read failures still log as exceptions.
  - File: `lib/features/sync/matrix/sync_event_processor.dart`

- Observability upgrades
  - Outbox: per‑message type logs on enqueue and send (includes SyncEntryLink with from/to IDs) to trace whether links were actually queued/sent.
    - Files: `lib/features/sync/outbox/outbox_service.dart`, `lib/features/sync/outbox/outbox_processor.dart`
  - V2 metrics: flush line now appends a compact processedByType breakdown (e.g., `byType=entryLink=3,journalEntity=27`).
    - File: `lib/features/sync/matrix/pipeline_v2/metrics_counters.dart`
  - EntryLink apply logging on receiver: `apply.entryLink from=… to=… rows=…`.
    - File: `lib/features/sync/matrix/sync_event_processor.dart`

- Metrics naming and hygiene
  - Fixed `descriptorCatchUpRuns` naming in metrics snapshot.
  - Removed a dead comment and added cleanup error logging in descriptor catch‑up.

- Test coverage
  - Expanded consumer, helper, and service tests including connectivity hooks, pending-jsonPath flows, and in‑flight guard tests.

## What We’re Still Investigating

- EntryLink occasionally missing after offline creation
  - Symptom: entity arrives on mobile, but link is not present immediately when the device comes online.
  - Hypotheses being validated:
    - Sender outbox didn’t enqueue the link for that flow (now visible via new OUTBOX enqueue/send logs).
    - Delivery lag: link sent later and applied after UI snapshot (receiver now logs `apply.entryLink`).
    - UI refresh timing unrelated to pipeline (DB verify via `linksForEntryIds` if needed).
  - Next: reproduce with new logs; if enqueue/send is correct but apply still missing, add a minimal retry around upsertLink (unlikely) or inspect UI refresh path.

- Descriptor/text ordering races
  - We now treat first local JSON reads as expected misses and fetch via `AttachmentIndex`. Logs show the pattern: `smart.local.miss` → `attachmentIndex.hit` → `smart.json.written` → apply.
  - We will keep an eye on rare late descriptor arrivals; descriptor catch‑up guard and JSON prefetch reduce window further.

## Next Steps

- Monitor a desktop→mobile (mobile initially offline) run with new logs:
  - Desktop: OUTBOX `enqueue type=…` and `sending type=…` should include `SyncEntryLink` for the created pair.
  - Mobile: metrics flush `byType=…entryLink=…` increments; `apply.entryLink` lines confirm application.

- If a link is still missing while enqueue/send occurred:
  - Capture the relevant event IDs, confirm DB state on device (`linksForEntryIds`), and instrument UI refresh if needed.

- Optional follow‑ups (post‑stabilization):
  - Move toward targeted `retryNow` by jsonPath→eventId mapping (instead of global retryNow) for sharper recovery.
  - Add a startup log that prints the resolved documents directory path for quick confirmation in field logs.

