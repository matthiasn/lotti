# Implementation Plan – Matrix Sync Simplification (V2)

**Date:** 2025-10-11  
**Author:** Codex (assistant)  
**Status:** Proposal

## Summary

After reviewing the research document (sync_simplification_research.md) and the current codebase,
the root issue is clear: we’re doing too much work above the SDK’s synchronization model. Our
bespoke drain (snapshot escalation, ordering, multi-pass retries, and backpressure) improves
robustness but invites subtle tail-edge bugs and high maintenance cost.

We will replace the custom drain with a simpler, SDK-first pipeline (V2): subscribe to the SDK’s
event streams, process events in arrival order, and persist a single “last processed” event id for
our own idempotency. We will keep snapshot-based catch-up only on attach/reconnect (bounded) and
otherwise avoid snapshot scans. Note: the stream-first pipeline is now the only implementation; historical references to `enable_sync_v2` are obsolete.
and quick rollback.

## Goals

- Simplicity: Process events as they arrive; avoid scanning and re-sorting snapshots in steady
  state.
- Correctness: Eliminate off-by-one tail issues and double-processing hazards.
- SDK-first: Rely on matrix-dart-sdk for ordering, delivery, and decryption; avoid fighting its
  timeline model.
- Idempotency: Persist a single lastProcessedEventId; make processing safe on retries.
- Observability: Minimal counters and concise logs to debug ordering and delivery.
- Migration safety: Historical note; the pipeline is now the default implementation.

## Non-Goals

- Change to the sync message format, attachment strategy, or concurrency detection (vector clocks) –
  those stay as-is.
- Replace device verification, E2EE, or homeserver assumptions (Synapse/Dendrite) – unchanged.
- Redesign message sending – keep MatrixMessageSender intact.

## Current State (short)

Key parts today (files):

- matrix_service.dart orchestrates gateway/session/room/timeline and read markers.
- sync_engine.dart + sync_lifecycle_coordinator.dart manage login lifecycle and attach a listener.
- matrix_timeline_listener.dart coordinates timeline subscriptions and enqueues refresh work.
- timeline.dart performs multi-pass live/snapshot draining, reorders by (ts, id), and does tail
  retries.
- read_marker_service.dart persists last-read id and writes Matrix read markers.
- sync_event_processor.dart decodes com.lotti.sync.message payloads and updates the DB.

Observations:

- We already rely on the SDK for sync/token handling (no custom prev_batch storage). Our persistence
  is only a last-read/processed event id.
- The tail “one behind” was addressed by ordering fixes, but the architecture still carries
  complexity (snapshot escalation, multi-pass, backpressure) that we can avoid by streaming-first
  processing.

## Proposed Design (V2)

A. Data/state

- lastProcessedEventId (persisted): reuse LAST_READ_MATRIX_EVENT_ID but treat it as “last
  processed” (not a UI read receipt). Rename later if desired.
- Optional: in-memory seenEvents LRU (eventId) bounded (1–2k) to suppress duplicates across
  reconnects.

B. API usage (matrix-dart-sdk)

- Streaming source: use `client.onTimelineEvent` (we already subscribe in V1 for scheduling). Filter
  by current sync room id and message kind.
- Attach-time catch-up: once per attach/reconnect, fetch a bounded snapshot via
  `room.getTimeline(limit: N)`, compute the subset after `lastProcessedEventId`, process
  oldest→newest, then switch to pure streaming.
- Ordering: rely on SDK emission order for streaming; only sort during catch-up.

C. Processing loop

- Single-threaded consumer with a small bounded queue; process events in arrival order.
- Filter early: accept only `m.room.message` with `msgtype == com.lotti.sync.message` and file
  events with expected `extraContent.relativePath` (attachments). Ignore others.
- Idempotency: if `event.eventId` is <= the persisted `lastProcessedEventId` (same ts → compare
  ids), or present in LRU, skip; otherwise process and then update `lastProcessedEventId`.
- Errors: log and do not mark that event as processed. Continue with subsequent events; advancement
  uses the “latest safely processed id” (see micro-batching below).

D. Read markers

- Decouple correctness from Matrix read markers. Optionally call
  `room.setReadMarker(latestProcessedId)` on a debounce to keep UI feeling consistent; correctness
  is driven solely by `lastProcessedEventId` in SettingsDb.

E. Attachments

- Maintain reliability without the heavy drain: use a small micro-batch window inside the stream
  consumer. For each flush window (e.g., up to 200 events or 150ms):
    - First pass: prefetch/save attachments for file events (remote events with `attachmentMimetype`
      or `extraContent.relativePath`).
    - Second pass: process text events (base64 JSON) via `SyncEventProcessor`.
- Compute “latest advancing id” across the window; persist that id and optionally write the read
  marker. This mirrors the current robustness with much less machinery.

F. Lifecycle

- On login/room hydrate: run bounded catch-up once, then attach the streaming consumer.
- On logout/room change: detach, flush any pending debounced read-marker, keep
  `lastProcessedEventId` persisted.

G. What we remove (once V2 is stable)

- `timeline.dart` multi-pass drain logic and snapshot escalation.
- Backpressure and large pending-event queue in `matrix_timeline_listener.dart` (the V2 stream
  consumer will own a small, bounded micro-batch buffer).
- Snapshot disposal intricacy and follow-up scheduling.

## Flag & Switch Strategy

- Historical: prior plan proposed an `enable_sync_v2` feature flag.
    - Add constant in lib/utils/consts.dart
    - Add initializer in lib/database/journal_db/config_flags.dart
    - Surface in Settings > Flags with description: “Enable Matrix Sync V2 (simplified pipeline) –
      requires restart”
- Construction switch in `MatrixService`:
    - The project now always constructs `MatrixStreamConsumer` as the active sync pipeline.
- No DB migration. Same persisted key LAST_READ_MATRIX_EVENT_ID used by v2; semantics widen to
  “processed” instead of strictly “read”.

## High-Level Architecture (proposed types)

- SyncPipeline (interface)
    - initialize(), start(), stop(), dispose()
- Historical: a V1 adapter existed during transition; it has been removed.
  removal).
- V2: `MatrixStreamConsumer` implements `SyncPipeline`
    - Deps: `MatrixSessionManager`, `SyncRoomManager`, `LoggingService`, `JournalDb`, `SettingsDb`,
      `SyncEventProcessor`
    - `startupCatchUp(limits: [200, 500, 1000])`: snapshot once, pick events strictly after
      `lastProcessedEventId`, process oldest→newest
    - `subscribe()`: `client.onTimelineEvent` → filter → enqueue into micro-batch buffer → periodic
      flush (time-or-size)
    - On flush: prefetch attachments, process texts, compute latest advancing id, persist id,
      optional debounced read marker

Notes

- Keep SyncEngine + SyncLifecycleCoordinator; they only decide when to attach/detach. Swap the
  injected pipeline by flag.
- Message sending (MatrixMessageSender) unchanged.

## Implementation Steps

Phase 0 – Verification/Proto (0.5–1 day)

- Confirm `client.onTimelineEvent` ordering/decryption timing in our integration tests.
- Prototype a minimal `MatrixStreamConsumer` that logs event ids for the sync room; validate
  ordering and that events arrive post-decryption.

Phase 1 – Add flag and skeleton (0.5 day)

- Historical: no longer applicable; there is no flag.
- Define `SyncPipeline` interface; add a minimal adapter for V1 so both pipelines share
  initialize/start/stop/dispose.
- Wire `MatrixService` to pick V1 or V2 based on the flag.

Phase 2 – Implement V2 pipeline (1.5–2 days)

- Implement `MatrixStreamConsumer` with:
    - Attach-time bounded catch-up (sorted once, after `lastProcessedEventId`)
    - Streaming consumer with filter + micro-batch flush (attachments first, then texts)
    - Persist latest advancing id; optional debounced read-marker writes
    - Light metrics: processedCount, skippedDuplicates, failures, microBatchFlushes
- Keep code local to `lib/features/sync/matrix/pipeline_v2/*` to simplify revert.

Phase 3 – Tests (1–1.5 days)

- Unit
    - Catch-up ordering and `lastProcessedEventId` advancement
    - Duplicate suppression and failure-no-advance behavior (with retries)
    - Micro-batch: attachments saved before text processing; advancing id computed correctly
    - Read-marker debounce path
- Integration
    - Tail test: device A sends rapid edits; device B (V2) receives all without “last one missing”
    - Reconnect test: offline then reconnect; no gaps and no duplicates

Phase 4 – Rollout (0.5 day)

- Ship disabled by default; enable in dev/integration.
- Observe logs/metrics; compare against V1.

Phase 5 – Cleanup (post‑stabilization)

- If V2 is stable: remove V1 drain, snapshot escalation, and backpressure code.
- Consolidate `lastProcessed` vs read-marker semantics in docs.

## Risks & Mitigations

- Out-of-order arrivals: rely on SDK order for live; sort only during catch-up. Advancement computed
  per micro-batch avoids gaps.
- Attachments arrive after text: micro-batch first-pass saves attachments; if still missing, skip
  advancement for that event and retry next flush.
- Missed events on reconnect: attach-time catch-up bridges the gap; escalate limits conservatively.
- E2EE decryption lag: events are processed post-decryption via SDK stream; skip if not yet
  decryptable and retry next flush.
- Read-marker differences: treat read markers as best-effort; correctness is independent.

## Deliverables (code map)

- `lib/features/sync/matrix/pipeline/sync_pipeline.dart` (interface)
- `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart` (V2)
- `lib/features/sync/matrix/matrix_service.dart` (construct V1 or V2 via flag)
- `lib/utils/consts.dart` (add `enable_sync_v2`)
- `lib/database/journal_db/config_flags.dart` (register flag + description)
- Tests under `test/features/sync/matrix/pipeline_v2/*` and integration tests
- Docs: `lib/features/sync/README.md` and this plan

## Code-change checklist (per file)

- matrix_service.dart: inject `SyncPipeline`; construct V1 or V2 based on flag; replace direct calls
  to the stream-first pipeline calls.
- sync_engine.dart / sync_lifecycle_coordinator.dart: continue to orchestrate lifecycle; use
  pipeline’s `initialize/start/stop/dispose`.
- matrix_timeline_listener.dart: unchanged for V1; later remove backpressure queue when V2 is
  default.
- timeline.dart: no changes now; plan to delete once V2 is stable.
- read_marker_service.dart: no change; called from V2 on debounced update.
- sync_event_processor.dart: unchanged.

## Rollback Plan

- Historical: removed; only the stream pipeline is active.
- No data migration. `lastProcessedEventId` continues to be used by V1 as last read.

## Success Metrics & Acceptance Criteria

- Functional
    - No “last message missing” behavior in tail tests (rapid edits across devices)
    - No duplicate application of the same event id across reconnects
    - Attachments available before or during processing without user-visible gaps
- Reliability
    - No crash loops or stalls while streaming (micro-batch keeps advancing id)
    - On reconnect, catch-up processes all missed events without duplicates
- Performance
    - Lower CPU time vs V1 during idle (no periodic snapshot drains)
    - Stable memory footprint (bounded micro-batch; no large snapshots in steady state)

## References

- Repo code paths reviewed: matrix_service.dart, matrix_timeline_listener.dart, timeline.dart,
  read_marker_service.dart, sync_event_processor.dart, sync_engine.dart,
  sync_lifecycle_coordinator.dart, sync_room_manager.dart
- Related plan: docs/implementation_plans/2025-10-10_matrix_timeline_order_fix.md
- Spec and SDKs: Matrix spec, famedly/matrix-dart-sdk, vodozemac, Synapse

---

Historical plan; the project now ships the stream-first pipeline by default.
we can iterate in code.

## Alignment with research document

We adopt the core guidance from sync_simplification_research.md:

- SDK-first ownership of sync; app subscribes to events (streaming-first design)
- Avoid index/offset arithmetic; rely on event ids and SDK ordering
- Remove custom pagination/snapshot machinery from steady state; only use bounded catch-up on attach
- Keep processing idempotent and async; do not block the SDK loop

Clarifications for Lottie specifics:

- Token persistence: We already rely on the SDK database for tokens; our persistence remains a
  separate `lastProcessedEventId` for app-level idempotency.
- Edit aggregation (`getDisplayEvent`): not applicable to our sync payloads (we send
  `com.lotti.sync.message`), so we keep `SyncEventProcessor` unchanged.
- Notifications/receipts: We treat Matrix read markers as best-effort UX alignment, not correctness.
  Private read receipts can be adopted later if we surface user-facing unread state.
