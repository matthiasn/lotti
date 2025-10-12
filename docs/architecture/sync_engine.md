# Sync Engine Architecture

## Overview

The sync engine composes the Matrix session, room, and stream pipeline layers into a
single lifecycle-controlled pipeline. Each collaborator is constructor injected
and orchestrated by `SyncLifecycleCoordinator`, with Riverpod providers wiring
them into the UI and controller layer. The following sections document the
current architecture after the V2 stream-first consolidation.

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
  - `MatrixSessionManager`
  - `SyncRoomManager`
  - `LoggingService`
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
   - starting/stopping the stream-first pipeline (`MatrixStreamConsumer`)
   - hydrating/persisting the active sync room through `SyncRoomManager`
3. `MatrixService.startKeyVerificationListener()` delegates to
   `listenForKeyVerificationRequests`, surfacing verification runners on the new
   provider-backed UI.
4. `MatrixService.dispose()` tears down message controllers before delegating to
   `SyncEngine.dispose()` and the injected collaborators.

## Pipeline Flow (stream-first)

1. Attach and catch-up using SDK pagination/backfill when available; fallback to snapshot escalation.
2. Batch events oldest→newest and prefetch attachments for remote events.
3. Process events via `SyncEventProcessor`; retries/backoff with TTL and a circuit breaker protect stability.
4. Advance read marker monotonically and emit typed metrics.

## Provider Injection

All sync widgets and controllers now read dependencies via providers. Examples:

- `matrixLoginControllerProvider` reads `matrixServiceProvider`
- `matrixSettingsCard` (UI) is a `ConsumerStatefulWidget`
- `LoginFormController` and `MatrixConfigController` no longer touch `getIt`

This design allows test harnesses to override collaborators without manipulating
global state and unblocks the analyzer guard that prevents `getIt` usage from
creeping back into the module.

## Resilience Improvements

- Stream pipeline retries with exponential backoff, TTL pruning, and a size cap; a circuit breaker prevents thrashing.
- `SyncRoomManager` filters malformed invites and emits rich `SyncRoomInvite` objects for the UI to confirm.
- Tests cover error recovery, invite filtering regressions, and edge cases.
