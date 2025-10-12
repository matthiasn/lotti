# Sync Feature Documentation

## Overview

Lotti synchronises encrypted journal data across devices through the Matrix
protocol. Since the 2025-10-06 refactor the sync stack is composed of
constructor-injected services, Riverpod providers, and a coordinated lifecycle
that keeps the pipeline testable and observable.

## Architecture

### Core Services

| Component | Responsibility |
| --- | --- |
| **SyncEngine** (`matrix/sync_engine.dart`) | Owns the high-level lifecycle via `SyncLifecycleCoordinator`, runs login/logout hooks, and surfaces diagnostic snapshots. |
| **MatrixService** (`matrix/matrix_service.dart`) | Wraps the `MatrixSyncGateway`, coordinates verification flows, exposes stats/read markers, and delegates lifecycle work to the engine. |
| **MatrixSyncGateway** (`gateway/matrix_sdk_gateway.dart`) | Abstraction over the Matrix SDK for login, room lookup, invites, timelines, and logout. |
| **MatrixMessageSender** (`matrix/matrix_message_sender.dart`) | Encodes `SyncMessage`s, uploads attachments, increments send counters, and notifies `MatrixService`. |
| **MatrixTimelineListener** (`matrix/matrix_timeline_listener.dart`) | V1 pipeline. Queues timeline refreshes with `ClientRunner`, waits for `UserActivityGate` to report idleness, and invokes `processNewTimelineEvents`. |
| **TimelineDrainer** (`matrix/timeline.dart`) | V1 helper that performs the multi-pass drain: sorts oldest→newest, filters already-processed events, retries at tail, escalates snapshot limits, disposes snapshots, ingests events, and advances the read marker. |
| **MatrixStreamConsumer (V2)** (`matrix/pipeline_v2/matrix_stream_consumer.dart`) | V2 stream-first consumer: attach-time catch-up (SDK pagination/backfill with graceful fallback), micro-batched streaming, attachment prefetch, monotonic marker advancement, retries with TTL + size cap, circuit breaker, and typed metrics. |
| **SyncRoomManager** (`matrix/sync_room_manager.dart`) | Persists the active room, filters invites, validates IDs, hydrates cached rooms, and orchestrates safe join/leave operations. |
| **SyncEventProcessor** (`matrix/sync_event_processor.dart`) | Decodes `SyncMessage`s, mutates `JournalDb`, and emits notifications (e.g. `UpdateNotifications`). |
| **SyncReadMarkerService** (`matrix/read_marker_service.dart`) | Writes Matrix read markers after successful timeline processing and persists the last processed event ID. |
| **OutboxService** (`outbox/outbox_service.dart`) | Stores pending messages, resolves attachments, and hands work to `MatrixMessageSender`. |
| **UserActivityGate** (`features/user_activity/state/user_activity_gate.dart`) | Exposes reactive idleness signals so heavy timeline processing defers while the user is active. |

### Provider Wiring & Lint Guard

- Core sync services are provided via Riverpod (`lib/providers/service_providers.dart`)
  and overridden in `lib/main.dart` when the app boots. Tests override the same
  providers to inject mocks/fakes.
- The custom lint rule `no_get_it_in_sync` (shipping from
  `tool/lotti_custom_lint`) fails analysis if `getIt` is referenced inside
  `lib/features/sync` or `lib/widgets/sync`, preventing regressions.
- Additional documentation is available in `docs/architecture/sync_engine.md`.

### Data Flow (V1)

#### Sending

1. Domain logic enqueues a `SyncMessage` through `OutboxService`.
2. Outbox resolves attachments/documents and calls
   `MatrixMessageSender.sendMatrixMessage(...)`.
3. `MatrixMessageSender` serialises the payload, uploads any files, increments
   `MatrixService` counters, and logs the event.
4. `OutboxService` marks the item as sent or schedules a retry depending on the
   outcome.

#### Receiving

1. `MatrixTimelineListener.enqueueTimelineRefresh()` runs when the room emits a
   new event, when connectivity resumes, or when the client manually requests a
   refresh.
2. `ClientRunner` serialises work; `UserActivityGate` blocks processing while
   the user is actively interacting with the app.
3. `processNewTimelineEvents(...)` resolves the last read Matrix event ID and
   delegates to `TimelineDrainer` to perform a multi-pass drain:
   - prefers the live (attached) timeline first to avoid snapshot lag;
   - orders events **oldest → newest** while preserving the SDK’s sequence for
     equal timestamps; uses a reverse scan to find the last-read position;
   - filters out events at-or-before the last-read marker;
   - at the tail, performs short intra-pass retries (configurable) to allow the
     live timeline to settle;
   - escalates snapshot limits when needed; disposes any unused snapshots;
   - for each remote event that is newer than the stored ID we:
     - download attachments via `save_attachment.dart` before handing the payload
       to `SyncEventProcessor.process(...)`;
     - skip self-emitted events to avoid re-ingesting local changes;
     - track failures and keep retry counts via `_maxTimelineProcessingRetries`;
     - remember the newest successfully processed event so we can advance the
       read marker once at the end of the batch, then queue a short follow-up
       drain to catch any events that landed while we were processing.
4. After the loop the listener persists the newest processed Matrix event ID
   through `SyncReadMarkerService`, ensuring subsequent sessions resume from the
   same timeline position without re-processing older messages.

### Timeline Draining (V1 Details)

- Sorting and selection are implemented in `TimelineDrainer.computeFromTimeline`
  using helpers that:
  - build a stable oldest→newest view of the timeline (tie-break on original
    indices to preserve SDK semantics);
  - locate the last-read event via a reverse scan; and
  - collect only events strictly after last-read.
- Tail retries are governed by `TimelineConfig.retryDelays` and only run when
  we are positioned at the newest event with no candidates yet.
- Multi-pass behaviour calls `client.sync()` each pass and escalates
  `TimelineConfig.timelineLimits` until candidates appear.
- Snapshot timelines created during escalation are disposed immediately when not
  used, and also disposed after processing if they were used (the live attached
  timeline remains attached). This prevents timeline-related memory leaks.

### Backpressure & Debounce

- `MatrixTimelineListener` maintains a bounded buffer of pending SDK events and
  processes them in chronological batches:
  - buffer cap: 1000 (drops oldest when full);
  - batch size: 500 (deduped by eventId within a batch).
- Read marker updates are debounced; a pending marker is flushed on listener
  dispose to avoid losing the latest state.

### Metrics & Configuration

- `TimelineConfig` parameters (production defaults shown):
  - `maxDrainPasses = 3`
  - `timelineLimits = [100, 300, 500, 1000]`
  - `retryDelays = [60ms, 120ms]`
  - `readMarkerFollowUpDelay = 150ms`
  - `collectMetrics = false`
- `TimelineConfig.lowEnd` provides a conservative preset for constrained
  devices (fewer passes, smaller limits, shorter delays).
- Optional `TimelineMetrics` can be passed to collect:
  - `drainPasses`, `eventsProcessed`, `retryAttempts`, `totalProcessingTime`.
  Metrics increments are gated by `collectMetrics` to avoid hot-path overhead.
  A threshold log is emitted when drain passes exceed 2.

### Documentation & Artefacts

- Architecture: `docs/architecture/sync_engine.md`
- Memory audit: `docs/architecture/sync_memory_audit.md`
- Provider wiring (this document) + `lib/providers/service_providers.dart`

## Setup Flow (Multi-Device)

1. **Device A** logs in, creates the encrypted sync room, and displays its user
   QR code.
2. **Device B** logs in with its own Matrix account, scans the QR (or enters
   Device A’s Matrix ID), and waits for the invite surfaced by `SyncRoomManager`.
3. Device A approves the invite. Both devices verify each other using the emoji
   SAS flow.
4. `SyncLifecycleCoordinator` starts the timeline listener once both devices are
   logged in and the room has been hydrated. Synchronisation continues
   automatically while both devices are idle.

## Diagnostics & Logging

- Use `matrixServiceProvider.read().getDiagnosticInfo()` in debug builds to
  inspect saved room IDs, active room state, lifecycle activity, joined rooms,
  and login status. Note: typed V2 metrics are not included in this payload; use
  `MatrixService.getV2Metrics()` or the Matrix Stats UI instead.
- Key log domains: `MATRIX_SERVICE`, `SYNC_ENGINE`, `SYNC_ROOM_MANAGER`,
  `SYNC_EVENT_PROCESSOR`, `SYNC_READ_MARKER`, and `OUTBOX`.
- Typical messages include invite acceptance/filters, hydration retries, send
  attempts, and timeline processing outcomes.

## Testing

- **Integration:** `integration_test/matrix_service_test.dart` exercises the
  full flow with the fake gateway (room creation, invites, verification, message
  exchange). Run with `dart-mcp.run_tests` targeting the file or via the project
  Make target.
- **Unit/Widget:** Coverage includes the client runner queue, activity gating,
  timeline error recovery, verification modals (provider overrides),
  dependency-injection helpers, and the sync pipelines:
  - `timeline_ordering_test.dart` verifies ordering helpers.
  - `process_new_timeline_events_test.dart` covers ingestion + marker updates.
  - `timeline_multipass_test.dart` validates multi-pass sync behaviour.
  - `timeline_drainer_test.dart` covers compute-from-timeline and minimal drain.
  - `matrix_timeline_listener_test.dart` covers debounce flush and backpressure.
  - V2: `pipeline_v2/matrix_stream_consumer_test.dart` covers SDK pagination seam,
    streaming/flush batching, live timeline callbacks, metrics accuracy, lifecycle
    edges, retries/TTL/circuit breaker.
  - V2: `sync_lifecycle_coordinator_v2_test.dart` covers coordinator activation,
    deactivation and login/logout races when a pipeline is provided.
- Always run `dart-mcp.analyze_files` before committing. The custom lint will
  block any reintroduction of `getIt`.

## Troubleshooting

- **One-way sync:** Compare diagnostics across devices (saved room vs active
  room). If they diverge, leave the room via `SyncRoomManager`, clear the stored
  ID, and repeat the invite flow.
- **Stalled sends:** Inspect the Outbox Monitor, verify that all devices are
  trusted/verified, and look for `Unverified devices found` messages in
  `MATRIX_SERVICE`.
- **Verification loops:** Ensure both devices accepted the emoji SAS prompt and
  the verification modal tests still pass (`test/widgets/sync/matrix/verification_modal_test.dart`).
- **Memory concerns:** Re-run the procedure described in
  `docs/architecture/sync_memory_audit.md` and compare against baseline numbers.
  The drain now disposes unused snapshot timelines during escalation to avoid
  leaks; if you see RSS growth, inspect timeline creation/disposal logs.

## Current Status

- V2 (MatrixStreamConsumer) is available behind the `enable_sync_v2` flag; V1
  remains the default. V2 typed metrics can be surfaced in the Matrix Stats UI
  and via `MatrixService.getV2Metrics()`.
- Provider overrides and custom lint rules enforce the new dependency model.
- When extending the sync feature, update both this README and the architecture
  documents so the narrative stays aligned with the implementation.

## Sync V2 – Rollout & Observability

- Enabling V2
  - Set the config flag `enable_sync_v2` (JournalDb flags). Restart so DI can
    construct the V2 pipeline path. V1 remains intact if the flag is false.
- Metrics (typed + diagnostics)
  - Consumer surfaces counters via `metricsSnapshot()` including:
    - processed, skipped, failures, prefetch, flushes, catchupBatches,
      skippedByRetryLimit, retriesScheduled, circuitOpens
    - processed.<type>, droppedByType.<type>
    - dbApplied, dbIgnoredByVectorClock, conflictsCreated
    - heartbeatScans, markerMisses
  - `MatrixService.getV2Metrics()` maps these into a typed `V2Metrics` model
    for UI display. The Matrix Stats page renders them and supports:
    - Refresh
    - Force Rescan (triggers live rescan + focused catch-up)
    - Copy Diagnostics (copies a readable metrics snapshot)
  - `getDiagnosticInfo()` intentionally omits V2 metrics; prefer the typed API
    or diagnostics text for tooling/UI.
- Catch-up and Pagination
  - On attach, V2 attempts SDK pagination/backfill first (best-effort across
    SDK versions); if unavailable, it falls back to escalating snapshot limits.
- Reliability safeguards
  - Streaming micro-batches are ordered oldest→newest; attachments are prefetched
    before processing. Retries apply exponential backoff with TTL and a size cap;
    a circuit breaker opens after sustained failures to prevent thrash.
  - Read-marker advancement is sync-payload only (or valid fallback-decoded JSON)
    to avoid silently skipping payloads when non-sync events arrive late.
  - A heartbeat rescan (every 5s) runs; if the last marker isn’t in the live
    window, a focused catch-up recovers gaps.

### Reliability tracker

For ongoing issues, hypotheses, and the current mitigation plan see:
`docs/progress/2025-10-12-sync-v2-reliability.md`. This document outlines what we
are struggling with in the field, what we’ve landed so far, and how to verify
behaviour using Matrix Stats and logs.

## Implementation Notes & Consistency

- Ordering tie-breakers
  - `TimelineEventOrdering.compare` uses timestamp ordering; on equal timestamps,
    events are ordered lexicographically by event ID. `isNewer` applies the same
    rule to ensure monotonic advancement.
- File operations
  - JSON writes are now atomic: write to a `*.tmp` file and asynchronously rename
    to the final path. Windows-safe fallback cleans up `*.bak`/`*.tmp` on success
    and avoids partial/empty reads. Avoid using `renameSync`.
- Read markers
  - `SyncReadMarkerService` gates updates via `client.isLogged()` and prefers
    room-level `setReadMarker`; falls back to timeline-level when available.


## References

- [Matrix Protocol](https://matrix.org/)
- [matrix-dart-sdk](https://pub.dev/packages/matrix)
- [End-to-End Encryption implementation guide](https://matrix.org/docs/guides/end-to-end-encryption-implementation-guide)
