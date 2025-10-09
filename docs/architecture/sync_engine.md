# Sync Engine Architecture

## Overview

The sync engine composes the Matrix session, room, and timeline layers into a
single lifecycle-controlled pipeline. Each collaborator is constructor injected
and orchestrated by `SyncLifecycleCoordinator`, with Riverpod providers wiring
them into the UI and controller layer. The following sections document the
current architecture after the milestone 8 dependency-injection refactor.

## Dependency Graph

- `SyncEngine`
  - `MatrixSessionManager`
  - `SyncRoomManager`
  - `MatrixTimelineListener`
  - `SyncLifecycleCoordinator`
  - `LoggingService`
- `MatrixService`
  - `MatrixSyncGateway`
  - `MatrixMessageSender`
  - `UserActivityGate`
  - `SyncEventProcessor`
  - `SyncReadMarkerService`
  - `SyncEngine` (owns lifecycle)
- `MatrixTimelineListener`
  - `MatrixSessionManager`
  - `SyncRoomManager`
  - `UserActivityGate`
  - `JournalDb`
  - `SettingsDb`
  - `SyncReadMarkerService`
  - `SyncEventProcessor`
  - `Directory documentsDirectory`

All sync-facing widgets, controllers, and repositories obtain their
collaborators via the following Riverpod providers:

- `matrixServiceProvider`
- `maintenanceProvider`
- `journalDbProvider`
- `loggingDbProvider`
- `loggingServiceProvider`
- `outboxServiceProvider`
- `aiConfigRepositoryProvider`

These providers are overridden in `main.dart` and in test harnesses to remove
direct `getIt` usage within the sync module.

## Lifecycle

1. `SyncEngine.initialize()` primes `SyncLifecycleCoordinator` with login/logout
   hooks and reconciles the initial lifecycle state.
2. `SyncLifecycleCoordinator` transitions between logged-in/out states by:
   - instructing `MatrixSessionManager` to connect/disconnect
   - starting/stopping `MatrixTimelineListener`
   - hydrating/persisting the active sync room through `SyncRoomManager`
3. `MatrixService.startKeyVerificationListener()` delegates to
   `listenForKeyVerificationRequests`, surfacing verification runners on the new
   provider-backed UI.
4. `MatrixService.dispose()` tears down message controllers before delegating to
   `SyncEngine.dispose()` and the injected collaborators.

## Timeline Flow

```
Matrix client -> MatrixTimelineListener.enqueueTimelineRefresh()
  -> ClientRunner queue (FIFO, one task at a time)
     -> UserActivityGate.waitUntilIdle()
        -> processNewTimelineEvents()
           -> SyncEventProcessor.process()
           -> SyncReadMarkerService.updateReadMarker()
           -> saveAttachment()
```

The new `ClientRunner` queue plus `UserActivityGate` ensures that timeline work
never runs concurrently and pauses when the user is actively interacting with
the app. The FIFO queue is covered by `client_runner_test.dart`, and the
activity gate behaviour is validated in
`matrix_timeline_listener_test.enqueueTimelineRefresh waits for activity gate...`.

## Provider Injection

All sync widgets and controllers now read dependencies via providers. Examples:

- `matrixLoginControllerProvider` reads `matrixServiceProvider`
- `matrixSettingsCard` (UI) is a `ConsumerStatefulWidget`
- `LoginFormController` and `MatrixConfigController` no longer touch `getIt`

This design allows test harnesses to override collaborators without manipulating
global state and unblocks the analyzer guard that prevents `getIt` usage from
creeping back into the module.

## Resilience Improvements

- `processNewTimelineEvents` logs and recovers from event processor failures.
- `SyncRoomManager` filters malformed invites and emits rich `SyncRoomInvite`
  objects for the UI to confirm.
- New tests cover error recovery, invite filtering regressions, and
  race-condition edge cases by leveraging `fake_async`.
