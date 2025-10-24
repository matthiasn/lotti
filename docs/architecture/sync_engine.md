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
  - `SyncLifecycleCoordinator`
  - `LoggingService`
- `MatrixService`
  - `MatrixSyncGateway`
  - `MatrixMessageSender`
  - `UserActivityGate`
  - `SyncEventProcessor`
  - `SyncReadMarkerService`
  - `SyncEngine` (owns lifecycle)
  - `MatrixStreamConsumer` (stream-first pipeline)

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
   - hydrating/persisting the active sync room through `SyncRoomManager`
   - initializing/starting/disposing the streaming pipeline (`SyncPipeline`)
3. `MatrixService.startKeyVerificationListener()` delegates to
   `listenForKeyVerificationRequests`, surfacing verification runners on the new
   provider-backed UI.
4. `MatrixService.dispose()` tears down message controllers before delegating to
   `SyncEngine.dispose()` and the injected collaborators.

## Pipeline Flow

```
MatrixStreamConsumer.forceRescan() / live stream
  -> catch-up (SDK pagination/backfill) until marker present
     -> micro-batch events (oldest→newest, dedupe)
        -> attachment prefetch (when required)
           -> SyncEventProcessor.process()
           -> SyncReadMarkerService.updateReadMarker()
```

The pipeline is cooperative: catch-up runs once at attach time, live streaming
processes new events as they arrive, and retries/circuit breakers ensure
transient failures do not starve fresh work. Metrics and diagnostics are
exposed via `MatrixStreamConsumer.metricsSnapshot()` and surfaced in the Matrix
Stats UI.

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
