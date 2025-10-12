# Sync Feature Documentation

## Overview

Lotti synchronises encrypted journal data across devices through the Matrix
protocol. Since the 2025-10-06 refactor the sync stack is composed of
constructor-injected services, Riverpod providers, and a coordinated lifecycle
that keeps the pipeline testable and observable.

## Architecture

### Core Services (V2-only)

| Component | Responsibility |
| --- | --- |
| **SyncEngine** (`matrix/sync_engine.dart`) | Owns the high-level lifecycle via `SyncLifecycleCoordinator`, runs login/logout hooks, and surfaces diagnostic snapshots. |
| **MatrixService** (`matrix/matrix_service.dart`) | Wraps the `MatrixSyncGateway`, coordinates verification flows, exposes stats, and delegates lifecycle work to the engine. |
| **MatrixSyncGateway** (`gateway/matrix_sdk_gateway.dart`) | Abstraction over the Matrix SDK for login, room lookup, invites, and logout. |
| **MatrixMessageSender** (`matrix/matrix_message_sender.dart`) | Encodes `SyncMessage`s, uploads attachments, increments send counters, and notifies `MatrixService`. |
| **MatrixStreamConsumer** (`matrix/pipeline/matrix_stream_consumer.dart`) | Stream-first consumer: attach-time catch-up (SDK pagination/backfill with graceful fallback), micro-batched streaming, attachment prefetch, monotonic marker advancement, retries with TTL + size cap, circuit breaker, and typed metrics. |
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

### Data Flow (V2)

#### Sending

1. Domain logic enqueues a `SyncMessage` through `OutboxService`.
2. Outbox resolves attachments/documents and calls
   `MatrixMessageSender.sendMatrixMessage(...)`.
3. `MatrixMessageSender` serialises the payload, uploads any files, increments
   `MatrixService` counters, and logs the event.
4. `OutboxService` marks the item as sent or schedules a retry depending on the
   outcome.

#### Receiving (stream-first)

1. `MatrixStreamConsumer` attaches and performs catch-up using SDK pagination/backfill when available, with a snapshot-based fallback.
2. The consumer batches events oldest→newest, de-duplicates by event ID, and prefetches attachments for remote events.
3. Each event is handed to `SyncEventProcessor.process(...)`. Retries use exponential backoff with TTL and a bounded queue; a circuit breaker prevents thrashing.
4. The consumer advances the Matrix read marker monotonically after successful batches and emits typed metrics.

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
4. `SyncLifecycleCoordinator` starts the V2 stream pipeline once both devices are
  logged in and the room has been hydrated. Synchronisation continues
  automatically while both devices are idle.

## Diagnostics & Logging

- Use `matrixServiceProvider.read().getDiagnosticInfo()` in debug builds to
  inspect saved room IDs, active room state, lifecycle activity, joined rooms,
  and login status. Note: typed V2 metrics are not included in this payload; use
  `MatrixService.getMetrics()` or the Matrix Stats UI instead.
- Key log domains: `MATRIX_SERVICE`, `SYNC_ENGINE`, `SYNC_ROOM_MANAGER`,
  `SYNC_EVENT_PROCESSOR`, `SYNC_READ_MARKER`, and `OUTBOX`.
- Typical messages include invite acceptance/filters, hydration retries, send
  attempts, and timeline processing outcomes.

## Testing

- **Integration:** `integration_test/matrix_service_test.dart` exercises the
  full flow with the fake gateway (room creation, invites, verification, message
  exchange). Run with `dart-mcp.run_tests` targeting the file or via the project
  Make target.
- **Unit (key files by component)**
  - Lifecycle
    - `test/features/sync/matrix/sync_engine_test.dart` — engine hooks, connect/logout delegation, diagnostics.
    - `test/features/sync/matrix/sync_lifecycle_coordinator_test.dart` — initialize/activate/deactivate; onLogin/onLogout hook ordering.
  - Matrix service layer
    - `test/features/sync/matrix/matrix_service_unit_test.dart` — service wiring, counters, diagnostics mapping.
    - `test/features/sync/gateway/matrix_sdk_gateway_test.dart` — gateway behaviours (login state, invites, logout).
    - `test/features/sync/matrix/read_marker_service_test.dart` — read-marker writes and fallbacks.
    - `test/features/sync/matrix/sync_room_manager_test.dart` — room persistence, invite filtering, hydration.
    - `test/features/sync/matrix/key_verification_runner_test.dart` — emoji SAS flows.
  - V2 pipeline (stream-first)
    - `test/features/sync/matrix/pipeline_v2/matrix_stream_consumer_test.dart` — attach, batch ordering, prefetch, processing.
    - `test/features/sync/matrix/pipeline_v2/matrix_stream_helpers_test.dart` — helper behaviours for batching and markers.
    - `test/features/sync/matrix/pipeline_v2/catch_up_strategy_test.dart` — pagination/backfill fallback logic.
    - `test/features/sync/matrix/pipeline/read_marker_manager_test.dart` — monotonic marker advancement.
    - `test/features/sync/matrix/pipeline_v2/metrics_counters_test.dart` — typed metrics increments and snapshots.
    - `test/features/sync/matrix/pipeline/retry_and_circuit_test.dart` — retry policy and circuit breaker.
    - `test/features/sync/matrix/pipeline_v2/retry_and_circuit_integration_test.dart` — end-to-end failure/ recovery path.
    - `test/features/sync/matrix/pipeline/sync_metrics_test.dart` — metrics model mapping.
    - `test/features/sync/matrix/timeline_ordering_test.dart` — deterministic ordering and comparators.
  - Outbox
    - `test/features/sync/outbox/outbox_service_test.dart` — enqueue/send lifecycle, attachments resolution.
    - `test/features/sync/outbox/outbox_processor_test.dart` — retry scheduling and completion.
    - `test/features/sync/matrix/matrix_message_sender_test.dart` — payload encoding, upload, and counters.
  - UI + widgets (selection)
    - `test/features/sync/ui/matrix_stats_page_test.dart` — metrics UI and actions.
    - `test/features/sync/ui/matrix_settings_modal_test.dart`, `room_config_page_test.dart`, `matrix_logged_in_config_page_test.dart` — configuration and logout/login flows.
    - `test/widgets/sync/outbox_monitor_test.dart`, `outbox_badge_test.dart` — outbox indicators.

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

- V2 (MatrixStreamConsumer) is the only sync path; there is no flag.
- Typed metrics are available via `MatrixService.getMetrics()` and diagnostics text.
- When extending the sync feature, update both this README and the architecture docs.

## Sync V2 – Observability

- Metrics (typed + diagnostics)
  - Consumer surfaces counters via `metricsSnapshot()` including:
    - processed, skipped, failures, prefetch, flushes, catchupBatches,
      skippedByRetryLimit, retriesScheduled, circuitOpens
    - processed.<type>, droppedByType.<type>
    - dbApplied, dbIgnoredByVectorClock, conflictsCreated
    - heartbeatScans, markerMisses
  - `MatrixService.getMetrics()` maps these into a typed `SyncMetrics` model
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
