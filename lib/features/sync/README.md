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
| **MatrixTimelineListener** (`matrix/matrix_timeline_listener.dart`) | Queues timeline refreshes with `ClientRunner`, waits for `UserActivityGate` to report idleness, and invokes `processNewTimelineEvents`. |
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

### Data Flow

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
3. `processNewTimelineEvents(...)` fetches the relevant timeline slice, calls
   `SyncEventProcessor.process(...)`, saves attachments (via
   `save_attachment.dart`), and updates read markers through
   `SyncReadMarkerService`.
4. The listener records the last processed event ID so a fresh session can
   resume from the correct position.

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
  and login status.
- Key log domains: `MATRIX_SERVICE`, `SYNC_ENGINE`, `SYNC_ROOM_MANAGER`,
  `SYNC_EVENT_PROCESSOR`, `SYNC_READ_MARKER`, and `OUTBOX`.
- Typical messages include invite acceptance/filters, hydration retries, send
  attempts, and timeline processing outcomes.

## Testing

- **Integration:** `integration_test/matrix_service_test.dart` exercises the
  full flow with the fake gateway (room creation, invites, verification, message
  exchange). Run with `dart-mcp.run_tests` targeting the file or via the project
  Make target.
- **Unit/Widget:** New coverage exists for the client runner queue, activity
  gating, timeline error recovery, verification modals (provider overrides), and
  dependency-injection helpers.
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

## Current Status

- Milestones 1–10 are complete; no outstanding regressions remain from the
  legacy `getIt`-driven architecture.
- Provider overrides and custom lint rules enforce the new dependency model.
- When extending the sync feature, update both this README and the architecture
  documents so the narrative stays aligned with the implementation.

## References

- [Matrix Protocol](https://matrix.org/)
- [matrix-dart-sdk](https://pub.dev/packages/matrix)
- [End-to-End Encryption implementation guide](https://matrix.org/docs/guides/end-to-end-encryption-implementation-guide)
