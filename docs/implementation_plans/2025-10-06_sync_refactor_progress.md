# Sync Refactor Progress – 2025-10-06

## Completed Milestones

- **Gateway & Lifecycle Foundation** (Milestone 1)
  - Added `MatrixSyncGateway` interface, `MatrixSdkGateway` concrete implementation, and `FakeMatrixGateway` for tests.
  - Refactored `MatrixService` to consume the gateway, introduced a `dispose()` method, and wired through `get_it`.
  - Added dedicated tests to confirm compatibility with existing code paths.

- **UserActivityGate** (Milestone 2)
  - Enhanced `UserActivityService` with a broadcast stream and `dispose()`.
  - Introduced `UserActivityGate` for reactive idle gating and integrated it into `MatrixService` and `OutboxService`.
  - Added comprehensive gate unit tests and adjusted existing sync tests to use the new abstractions.

- **Outbox Processor Extraction** (Milestone 3)
  - Created `OutboxRepository` abstraction (`DatabaseOutboxRepository`) with configurable retry limits.
  - Added `OutboxProcessor` and `MatrixOutboxMessageSender`, refactoring `OutboxService` to delegate queue handling.
  - Added `OutboxProcessingResult` for scheduling decisions and a suite of processor tests covering success, retry, and error scenarios.

- **Sync Read Marker Service** (Milestone 4)
  - Extracted read-marker persistence into `SyncReadMarkerService` with dedicated unit tests.
  - `processNewTimelineEvents` now delegates marker updates instead of inlining persistence and Matrix API calls.

- **Sync Event Processor** (Milestone 5)
  - Introduced `SyncEventProcessor` with injectable `SyncJournalEntityLoader` abstraction.
  - Replaced `processMatrixMessage` usage in the timeline pipeline and added comprehensive unit coverage for each message type.
  - Added targeted timeline tests to ensure the processor is invoked prior to read-marker updates.
  - Deleted legacy `processMatrixMessage` wrapper (no call sites remaining after timeline migration).

- **Session & Room Management** (Milestone 6)
  - Split responsibilities into `MatrixSessionManager`, `MatrixTimelineListener`, and the new `SyncRoomManager` with invite filtering and persisted room caching.
  - Rebuilt `MatrixService` to delegate to the new managers, removing the legacy `listenToMatrixRoomInvites` auto-join logic and the `room.dart` helper APIs.
  - Added exhaustive unit coverage for invite handling, hydration retries, error propagation, and session edge cases.
  - Updated sync readme documentation to reflect the fix for the auto-join bug and the improved join error handling.
- **Sync Engine Assembly** (Milestone 7)
  - Added `SyncLifecycleCoordinator` and `SyncEngine` to compose session, room, timeline, and diagnostics responsibilities with constructor-driven injection.
  - Refactored `MatrixService` lifecycle to delegate startup/shutdown to the engine, centralizing diagnostics and login hooks.
  - Expanded automated coverage with lifecycle unit tests and a multi-device invite integration scenario backed by the fake gateway.
- **Extension Method Removal** (Milestone 9)
  - Introduced `MatrixMessageSender` with injected `LoggingService`, `JournalDb`, and documents directory, replacing the legacy `send_message.dart` extension.
  - Updated `MatrixService`, `MatrixTimelineListener`, `SyncEngine`, and the associated tests to consume the new service via constructor injection.
  - Refreshed `get_it.dart`, unit tests, and the integration flow to register the sender explicitly; added context registration helpers for mocks.

## Recent Fixes & Enhancements

- `UserActivityGate` now initializes `canProcess` correctly and only emits meaningful transitions.
- `OutboxService.dispose()` disposes the gate when the service owns it, preventing leaks.
- `MatrixSdkGateway.dispose()` now always disposes the underlying Matrix client.
- Added configurable `maxRetries` support in the repository and corresponding tests.
- `MatrixService.dispose()` now tears down controllers before collaborators, ensuring the new message sender and session managers are released cleanly.
- Matrix service unit tests register explicit mocktail fallbacks for `Timeline`, `Event`, and `MatrixMessageContext`, avoiding brittle matcher usage.
- Added dedicated `MatrixMessageSender` unit tests covering room overrides, attachment resend rules, and error propagation, eliminating the silent failure paths from earlier commits.

## Next Up

- **Milestone 8:** Finish dependency injection cleanup: audit remaining sync UI/controllers for `getIt` lookups, introduce providers or constructor wiring, and add an analyzer guard to prevent regressions.

This progress log will be updated as each milestone is completed.
