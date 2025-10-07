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

## Recent Fixes & Enhancements

- `UserActivityGate` now initializes `canProcess` correctly and only emits meaningful transitions.
- `OutboxService.dispose()` disposes the gate when the service owns it, preventing leaks.
- `MatrixSdkGateway.dispose()` now always disposes the underlying Matrix client.
- Added configurable `maxRetries` support in the repository and corresponding tests.

## Next Up

- **Milestone 6:** Split session & room management (SessionManager, TimelineListener, SyncRoomManager with invite filtering) and remove the legacy `listenToMatrixRoomInvites` path; prepare characterization/integration tests for invite flows beforehand.
- Cleanup: remove legacy `processMatrixMessage` wrapper once all call sites are migrated to `SyncEventProcessor`.

This progress log will be updated as each milestone is completed.
