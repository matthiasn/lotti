# Actor-Based Matrix Sync Isolate Plan

## Summary

Move Matrix sync execution off the UI isolate into a dedicated worker isolate, built as a
completely new service under `lib/features/sync/actor/`. Development is driven by an
integration test that evolves from the existing proof-of-concept in
`integration_test/matrix_actor_isolate_network_test.dart`.

Key principles:
- **Vertical-slice first**: get a minimal actor doing login -> room -> SAS -> send/receive
  end-to-end before adding protocol infrastructure.
- **Completely separate**: no dependencies on existing `MatrixService`, `OutboxService`, or
  sync pipeline code. The actor builds on `MatrixSdkGateway` and `createMatrixClient` directly.
- **Integration-test-driven**: the docker-backed integration test is the specification. Each
  phase adds actor capabilities and corresponding test assertions.
- **Actor-owned DB writes**: the actor opens its own connections to `JournalDb`/`SettingsDb`
  (same SQLite files, separate connection) and writes directly. No apply/ack protocol needed.
  The actor sends lightweight `entitiesChanged` events with affected IDs; the host feeds
  them into the existing `UpdateNotifications` system for UI refresh.

## Goals

- Eliminate sync-induced frame drops by isolating network/crypto/sync work from render thread.
- Preserve current sync correctness guarantees (ordering, retries, sent-event suppression).
- Provide observable actor health and deterministic recovery semantics.
- Enable incremental rollout with a quick rollback switch.

## Non-Goals

- No modification of the existing sync pipeline, outbox, or matrix service code.
- No full app isolate migration in this project phase.
- No protocol changes to Matrix payloads.

### On "no compatibility facade" — nuance required

The plan avoids building adapters between the actor and legacy code. However, existing sync
UI controllers are hardwired to `matrixServiceProvider`:
- `MatrixLoginController` (matrix_login_controller.dart:12) reads `matrixServiceProvider`
  for login/logout.
- `MatrixRoomProvider` (matrix_room_provider.dart:11) reads `matrixServiceProvider` for
  room state.
- `MatrixStatsProvider` (matrix_stats_provider.dart:13) reads `matrixServiceProvider` for
  stats.

When actor mode is active and `MatrixService.init()` is not called, these providers will
return stale/empty state. This is acceptable during development (Phases 1-4) since the
feature flag gates the actor path. But **Phase 5 must address this**: either the actor
exposes equivalent state via its event stream (and new actor-backed providers replace these),
or `MatrixService` is kept as a thin read-only wrapper that delegates to the actor. The
two paths do coexist independently at the code level, but the UI needs data from whichever
path is active.

## What Actually Moves Off the Main Thread

The current inbound sync path is DB-heavy on the UI isolate:
- `SyncEventProcessor.process()` does vector clock validation, entity deserialization,
  `JournalDb.updateJournalEntity()`, embedded entry link processing, sequence log writes,
  notification dispatch (~1000+ lines of work per inbound event).
- `MatrixStreamProcessor` orchestrates batched event processing with retry/backoff and
  read-marker advancement — all on the main thread.
- `SettingsDb` writes for theme sync, read markers, etc.

**Everything moves to the actor isolate (off main thread):**
- Matrix SDK sync loop (network I/O + vodozemac-backed Megolm crypto)
- SDK event parsing, deduplication, filtering, sent-event suppression
- Inbound message deserialization and validation (SyncMessage decoding, vector clock comparison)
- **JournalDb writes** — actor opens its own `JournalDb` connection to the same `db.sqlite`
  file and calls `updateJournalEntity()` / `upsertEntryLink()` directly
- **SettingsDb writes** — actor opens its own `SettingsDb` connection to the same
  `settings.sqlite` file and calls `saveSettingsItem()` directly
- Outbound message encoding, encryption, and send with retry/backoff
- SAS verification flow (polling, state guards, emoji derivation)
- Retry scheduling, backoff timers, connectivity-driven rescan logic

**What stays on the main isolate (notification only):**
- `UpdateNotifications.notify(affectedIds, fromSync: true)` — the actor sends
  `entitiesChanged` events with affected entity ID sets back to the host. The host feeds
  them into the existing `UpdateNotifications` singleton which debounces (1s for sync)
  and broadcasts to all Riverpod providers. This is the same mechanism already used by
  `SyncEventProcessor` today (`lib/services/db_notification.dart`).
- `SyncDatabase` access — outbox monitor UI, outbox state controller (stays on UI).
  **Note**: The outbox monitor page is not read-only — it performs writes:
  `_db.updateOutboxItem()` (retry, outbox_monitor_page.dart:43) and
  `_db.deleteOutboxItemById()` (delete, outbox_monitor_page.dart:86). These UI-initiated
  writes to `SyncDatabase` are acceptable because the actor does NOT touch `SyncDatabase`
  in any phase of this plan. There is no concurrent-write conflict.

**Why this works:**
SQLite supports multiple connections to the same file. WAL mode is explicitly enabled via
`PRAGMA journal_mode = WAL` in the `setup` callback (see `common.dart:_setupDatabase()`),
along with `busy_timeout = 5000` and `synchronous = NORMAL`. This ensures readers don't
block writers and writers don't block readers. The actor's connection and the UI's
connection coexist safely. See commit `13fc72f18` and
`docs/implementation_plans/2026-02-13_drift_wal_read_pools.md` for details.

**Drift `watch()` cross-connection limitation — RESOLVED.** All sync-affected Drift
`watch()` methods (`watchCategories()`, `watchHabitDefinitions()`, `watchDashboards()`,
`watchMeasurableDataTypes()`, `watchLabelDefinitions()`, `watchTags()`,
`watchLabelUsageCounts()`, `watchSettingsItemByKey()`) have been removed and replaced with
`UpdateNotifications`-driven streams via `notificationDrivenStream()` (see
`docs/implementation_plans/2026-02-12_remove_sync_affected_drift_watch.md`).

This means **all UI refresh is now driven through `UpdateNotifications`** with type-specific
notification constants (`categoriesNotification`, `habitsNotification`,
`dashboardsNotification`, `measurablesNotification`, `labelsNotification`,
`tagsNotification`, `settingsNotification`, `labelUsageNotification`,
`privateToggleNotification`). The actor simply needs to include the appropriate type
notification keys in its `entitiesChanged` events, and the host feeds them into
`UpdateNotifications.notify()`. No `markTablesUpdated()` or `DriftIsolate` workaround
is needed.

**Local-only watches are unaffected**: `watchConfigFlag()`, `watchActiveConfigFlagNames()`,
and `watchOutboxCount()` (from `SyncDatabase`) remain as Drift `watch()` calls. These are
single-connection and never modified by the sync actor.

**No apply/ack protocol needed.** The actor writes directly to the DBs and sends a
lightweight notification. This eliminates the entire apply/ack complexity from the plan.

## Current Foundations

### Proven in integration test (`matrix_actor_isolate_network_test.dart`)

- `Isolate.spawn` with readyPort -> commandPort handshake pattern
- Map-based command protocol with per-request `replyTo` SendPort
- `vod.init()` in worker isolate for vodozemac crypto
- `createMatrixClient` + `MatrixSdkGateway` for full SDK lifecycle
- Login, room create/join, SAS verification, encrypted send/receive
- Isolate-local SDK DB roots per actor instance (no cross-run contamination)

**Note**: The existing test uses two different Matrix users. The updated integration test
must use the **single-user-across-devices** pattern that matches production: one Matrix user
logged in on two devices, with self-verification between devices of the same user.

### Single-user-across-devices pattern (production)

The production sync model uses **one Matrix user with multiple device sessions**, not two
different users. This is established in the recent sync onboarding/provisioning work:

- Device A creates a Matrix account, creates an encrypted sync room
- Device B receives a provisioning bundle (homeServer, user, password, roomId)
- Device B logs in as the **same Matrix user**, joins the existing sync room
- Both devices self-verify via SAS emoji flow (same-user cross-device verification)
- Messages sent by one device are filtered out on the sending device via `SentEventRegistry`

Key files establishing this pattern:
- `lib/features/sync/state/provisioning_controller.dart` — bundle decode, login, join room
- `lib/features/sync/matrix/sync_room_discovery.dart` — discover existing sync rooms
- `lib/features/sync/matrix/sync_room_manager.dart` — room creation with `m.lotti.sync_room` marker
- `lib/features/sync/ui/provisioned/provisioned_status_page.dart` — auto-verification launcher

### Reusable production code (no changes needed)

- `lib/features/sync/matrix/client.dart` — `createMatrixClient()`
- `lib/features/sync/gateway/matrix_sdk_gateway.dart` — `MatrixSdkGateway`
- `lib/features/sync/gateway/matrix_sync_gateway.dart` — `MatrixSyncGateway` interface
- `lib/features/sync/matrix/sent_event_registry.dart` — `SentEventRegistry`
- `lib/classes/config.dart` — `MatrixConfig`

## Architecture

### Isolate Topology

```
UI isolate (main)                    Sync Actor isolate (worker)
+---------------------------+        +---------------------------+
| UI, state management,     |        | Matrix Client, Gateway,   |
| Riverpod providers,       |  cmds  | SentEventRegistry,        |
| SyncActorHost,            |------->| sync loop, retry state,   |
| UpdateNotifications       |  evts  | key verification,         |
|                           |<-------| inbound processing,       |
+---------------------------+        | JournalDb (own conn),     |
| SyncDatabase (read-only)  |        | SettingsDb (own conn)     |
+---------------------------+        +---------------------------+
                                     |  db.sqlite (shared file)  |
                                     |  settings.sqlite (shared) |
                                     +---------------------------+
```

Both isolates access the same SQLite files via independent connections. WAL mode ensures
readers don't block writers. The actor writes; the UI reads. Change notifications flow
back via `entitiesChanged` events → `UpdateNotifications.notify()`.

### Ownership Rules

- **Actor owns**: Matrix `Client`, gateway, room/timeline handles, key verification objects,
  retry state, backoff timers, `SentEventRegistry`, inbound event processing logic,
  **write access to `JournalDb` and `SettingsDb`** (via its own DB connections).
- **UI owns**: presentation state, **read access to `JournalDb` and `SettingsDb`** (via its
  existing connections), `UpdateNotifications` singleton, `SyncDatabase`.
  - `SyncDatabase` stays UI-owned in all phases of this plan. The actor does not read or
    write `SyncDatabase`. Current UI code that accesses `SyncDatabase` (outbox monitor reads
    and writes: retry/delete items; outbox state controller reads) continues to work unchanged.
    No concurrent-write conflict because the actor never touches `SyncDatabase`.
  - Only when the legacy sync path is fully retired (Phase 6+) would `SyncDatabase` ownership
    transfer to the actor — and that requires a separate design doc.
- **Cross-isolate payloads**: plain maps with primitive fields. Never pass SDK objects,
  streams, controllers, DB handles, or closures.
- **DB connection rule**: Each isolate creates its own `JournalDb` / `SettingsDb` instance.
  DB instances are never shared across isolates. The actor receives the documents directory
  path at init time and passes it to `openDbConnection()` via the
  `documentsDirectoryProvider` parameter — this bypasses `path_provider` (a platform channel)
  and uses the known path directly. See `lib/database/common.dart:79`.

  **RESOLVED (commit `13fc72f18`)**: `JournalDb`, `SettingsDb`, and `SyncDatabase`
  constructors now accept `documentsDirectoryProvider`, `tempDirectoryProvider`,
  `background`, and (for `JournalDb`) `readPool` parameters, all forwarded to
  `openDbConnection()`. The actor passes `() async => Directory(dbRootPath)` for
  documents and a temp provider, and `background: false` to avoid nested isolates.
  UI-side callers continue to omit the parameters (existing behavior, uses
  `path_provider` fallback).

  **Remaining issue for isolate use**:
  - `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` — from `sqlite3_flutter_libs`,
    a Flutter plugin. Only called on Android. The main isolate calls it at startup; the
    actor isolate should skip it (already applied process-wide). The `background: false`
    path still calls it — may need a guard for actor use on Android.

### Host Bridge Contract (Platform APIs)

The actor isolate cannot access Flutter platform channels directly. All platform-dependent
data must be provided by the host (main isolate) via the command protocol:

| Platform API | How it reaches the actor | Notes |
|-------------|--------------------------|-------|
| Documents directory | `dbRootPath` string in `init` command | Already done in existing test |
| Device display name | `deviceDisplayName` string in `init` command | Serializable |
| Matrix credentials | `homeServer`, `user`, `password` in `init` command | Serializable |
| Secure storage | Not needed — credentials passed at init time | Actor never reads secure storage directly |
| Connectivity changes | `connectivityChanged` command from host | Host listens to `Connectivity().onConnectivityChanged` and forwards to actor |
| App lifecycle (pause/resume) | `pause`/`resume` commands from host | Host listens to `AppLifecycleState` and forwards |
| Filesystem (attachment paths) | Absolute path strings in command payloads | Actor reads/writes files via path; no platform channel needed |

**Rule**: The actor isolate must never import `flutter_secure_storage`,
`connectivity_plus`, `package_info_plus`, or any Flutter plugin that requires a platform
channel. All such data flows through the host bridge.

### Actor Command Protocol (v1 — simple)

Commands are maps sent via `SendPort`:
```dart
{
  'command': String,        // command type
  'requestId': String,      // unique per request (UUID)
  'replyTo': SendPort,      // for direct response
  ...payload fields         // command-specific
}
```

Responses are maps sent back via `replyTo`:
```dart
{
  'ok': bool,
  'requestId': String,
  'error': String?,         // if !ok
  'errorCode': String?,     // structured error code
  ...result fields
}
```

Events are maps sent via the actor's event `SendPort` (set during init):
```dart
{
  'event': String,          // event type
  ...payload fields
}
```

### v1 Commands

| Command | Payload | Response | Notes |
|---------|---------|----------|-------|
| `init` | `homeServer`, `user`, `password`, `dbRootPath`, `deviceDisplayName` | `ok` | Creates client, gateway, connects, logs in |
| `startSync` | — | `ok` | Starts the SDK sync loop |
| `stopSync` | — | `ok` | Stops the SDK sync loop |
| `createRoom` | `name`, `inviteUserIds` | `ok`, `roomId` | Creates encrypted sync room |
| `joinRoom` | `roomId` | `ok` | Joins an existing room |
| `sendText` | `roomId`, `message`, `messageType` | `ok`, `eventId` | Sends text message |
| `startVerification` | — | `ok`, `started` | Discovers unverified peer device of same user, starts SAS |
| `acceptVerification` | — | `ok` | Accepts incoming verification |
| `acceptSas` | — | `ok` | Accepts SAS emoji match |
| `cancelVerification` | — | `ok` | Cancels active verification |
| `connectivityChanged` | `connected` (bool) | `ok` | Host forwards connectivity state |
| `getHealth` | — | `ok`, `state`, `roomId`, `loginState` | Actor health snapshot |
| `ping` | — | `ok` | Liveness check |
| `stop` | — | `ok` | Graceful shutdown, disposes resources |

### v1 Events

| Event | Payload | Notes |
|-------|---------|-------|
| `ready` | — | Actor initialized, accepting commands |
| `loginStateChanged` | `loginState` | SDK login state change |
| `syncUpdate` | — | SDK sync tick completed |
| `verificationState` | `step`, `emojis?`, `isDone`, `isCanceled` | Verification progress |
| `entitiesChanged` | `ids` (`List<String>` of entity IDs), `notificationKeys` (`List<String>` of type notification constants, e.g. `categoriesNotification`, `habitsNotification`) | Affected IDs and type keys after DB writes; host converts to `Set<String>` combining both `ids` and `notificationKeys`, then feeds to `UpdateNotifications.notify(combinedSet, fromSync: true)`. This triggers all notification-driven streams that match the type keys (see `lib/services/notification_stream.dart`). Wire format uses `List<String>` (not `Set`) because `Set` is not a guaranteed safe isolate transfer type. |
| `error` | `message`, `code`, `fatal` | Actor-level error |

### DB Write + Notification Flow (No Apply/Ack Protocol)

The actor writes directly to `JournalDb` / `SettingsDb` via its own connections, then
notifies the host of affected entity IDs. No apply/ack handshake is needed.

```
Actor isolate                              Host (main isolate)
─────────────                              ────────────────────
1. Receive Matrix event
2. Decrypt, parse, validate
3. Write to JournalDb (own connection)
4. Send `entitiesChanged` event ─────────> 5. UpdateNotifications.notify(
   with affected entity IDs                      {ids + notificationKeys},
   and type notification keys                    fromSync: true,
                                               )
                                               (debounced 1s broadcast to all
                                               notification-driven streams)
```

This uses a single notification mechanism:
- **`UpdateNotifications`** (`lib/services/db_notification.dart`) — broadcast stream
  that all UI consumers subscribe to. Entity-level providers match on entity IDs.
  Type-level providers (categories, habits, dashboards, etc.) match on type notification
  keys (`categoriesNotification`, `habitsNotification`, etc.) via
  `notificationDrivenStream()` (`lib/services/notification_stream.dart`).
  `EntitiesCacheService` also refreshes its in-memory caches on matching type keys.

**Idempotency**: `JournalDb.updateJournalEntity()` already handles vector clock comparison
and skips writes when the local version is newer. No additional dedup logic needed.

**Hidden `getIt` coupling in `JournalDb`**: The current `updateJournalEntity()` method
(database.dart:358, :379) calls `getIt<LoggingService>()` directly for error reporting.
It also calls `saveJournalEntityJson()` (database.dart:396 → file_utils.dart:78) which
calls `getDocumentsDirectory()` (file_utils.dart:127) → `getIt<Directory>()`. These
globals are NOT initialized in a spawned isolate. **The actor must address this before
Phase 4 DB writes will work.** Options:
1. **Inject dependencies** — add `LoggingService` and `Directory` parameters to `JournalDb`
   (or to the methods that need them), and have the actor pass its own instances. This is
   the cleanest approach but requires modifying `JournalDb`.
2. **Initialize a minimal getIt in the actor isolate** — register just `LoggingService` and
   `Directory` in the actor's isolate before creating `JournalDb`. Pragmatic but couples the
   actor to the global service locator pattern.
3. **Actor-local DB wrapper** — the actor wraps `JournalDb` and handles JSON serialization
   and logging itself, calling only the lower-level `upsertJournalDbEntity()` instead of
   `updateJournalEntity()`. This avoids the getIt calls but requires reimplementing the
   vector clock comparison and JSON save logic.

Decision: to be made during Phase 4 implementation. Phase 1-3 don't touch `JournalDb` writes,
so this is not blocking until then.

**Crash safety**: If the actor crashes mid-batch, the next sync cycle re-discovers the
same Matrix events and re-applies them. The DB writes are individually idempotent.

### State Model

Simple linear states — no priority queues or QoS in v1:
- `uninitialized` — just spawned, waiting for `init`
- `initializing` — running `init` (client creation, login)
- `idle` — initialized but sync not started
- `syncing` — sync loop active
- `stopping` — graceful shutdown in progress
- `disposed` — terminal, isolate will exit

Invalid commands for current state get a structured error response with
`errorCode: 'INVALID_STATE'`.

## Actor-Mode Bootstrap Gate

When the actor feature flag is enabled, the following legacy services MUST NOT start:

| Legacy service | Current auto-start location | Gate mechanism |
|---------------|----------------------------|----------------|
| `MatrixService` constructor | `get_it.dart:245-267` — constructor creates `MatrixStreamConsumer` pipeline (line 127), schedules unawaited `forceRescan()` (line 146), subscribes to `Connectivity().onConnectivityChanged` (line 215). | Must not construct when flag is on |
| `MatrixService.init()` | `get_it.dart:345` `unawaited(getIt<MatrixService>().init())` | Moot if constructor is not called |
| `BackfillRequestService.start()` | `get_it.dart:304` | Skip call when flag is on |
| `OutboxService` constructor | `get_it.dart:269` — constructor calls `_startRunner()` (line 85) and subscribes to `Connectivity().onConnectivityChanged` (line 91), `client.onLoginStateChanged` (line 122), and `_syncDatabase.watchOutboxCount()` (line 135). These auto-start regardless of `MatrixService.init()`. | Must not construct when flag is on |

**Downstream wiring affected by skipping `OutboxService` / `MatrixService` construction:**

| Consumer | Location | Current dependency | Resolution needed |
|----------|----------|-------------------|-------------------|
| Provider override | `main.dart:106` | `getIt<OutboxService>()` | Conditional override or no-op stub |
| Login gate toast | `beamer_app.dart:139` | `outboxLoginGateStreamProvider` → `outboxServiceProvider` | Guard listener or make provider optional |
| Sync maintenance | `sync_maintenance_repository.dart:408` | `ref.watch(outboxServiceProvider)` | Conditional or no-op stub |
| Login controller | `matrix_login_controller.dart:12` | `ref.read(matrixServiceProvider)` | Actor-backed replacement or passive stub |
| Room provider | `matrix_room_provider.dart:11` | `ref.read(matrixServiceProvider)` | Actor-backed replacement or passive stub |
| Stats provider | `matrix_stats_provider.dart:13` | `ref.read(matrixServiceProvider)` | Actor-backed replacement or passive stub |

**WARNING — `OutboxService` self-starts in its constructor.** Unlike `MatrixService` (which
requires an explicit `.init()` call), `OutboxService` begins processing the moment it is
constructed at `get_it.dart:269`. Its constructor:
1. Calls `_startRunner()` which creates a `ClientRunner` and a periodic watchdog timer
   (`SyncTuning.outboxWatchdogInterval`).
2. Subscribes to `Connectivity().onConnectivityChanged` and nudges the send queue on
   connectivity regain.
3. Subscribes to `client.onLoginStateChanged` and nudges on login.
4. Subscribes to `_syncDatabase.watchOutboxCount()` and nudges on new pending items.

Simply skipping `MatrixService.init()` does NOT prevent `OutboxService` from polling,
retrying, and attempting sends. The gate must prevent `OutboxService` construction entirely,
or replace it with a no-op stub, when actor mode is active.

**Invariant**: When actor mode is active, there must be exactly zero legacy sync producers
running. The actor is the sole owner of the Matrix client, sync loop, and outbound sends.
Legacy read-only consumers (outbox monitor page, stats providers) that read from
`SyncDatabase` or `JournalDb` may continue to function.

**Implementation**: Extract a `startSyncServices()` function from `registerSingletons()`.
When the flag is off, register and start all legacy services (current behavior). When the
flag is on:
1. Do NOT construct `OutboxService` (it self-starts in constructor).
2. Do NOT construct `MatrixService` (constructor has side effects — see below).
3. Do NOT call `BackfillRequestService.start()`.
4. Start `SyncActorHost` instead.

**WARNING — `MatrixService` constructor also has side effects.** The constructor
(matrix_service.dart:127-215) creates the `MatrixStreamConsumer` pipeline, schedules a
startup `forceRescan()` via `unawaited(Future.delayed(...))` (line 146), and subscribes to
`Connectivity().onConnectivityChanged` (line 215). Simply skipping `.init()` is not enough
— the constructor itself starts background work. **The gate must prevent `MatrixService`
construction entirely when actor mode is active.**

**Downstream wiring that must change:**
- `main.dart:106` unconditionally resolves `getIt<OutboxService>()` for Riverpod provider
  override. When `OutboxService` is not registered, this will crash.
- `beamer_app.dart:139` listens to `outboxLoginGateStreamProvider` (which reads
  `outboxServiceProvider`). When `OutboxService` is absent, this stream errors.
- `providers/service_providers.dart:61-71` — `outboxServiceProvider` and
  `outboxLoginGateStreamProvider` assume `OutboxService` is available.

**Resolution**: When actor mode is active:
- Register a no-op `OutboxService` stub (or make the provider nullable/optional), OR
- Conditionally skip the `outboxServiceProvider.overrideWithValue(...)` in `main.dart` and
  guard the `outboxLoginGateStreamProvider` listener in `beamer_app.dart`.
- Similarly, register a no-op or passive `MatrixService` stub (for read-only providers like
  `matrixServiceProvider` that UI controllers still reference), or skip registration entirely
  and make dependent providers conditional.

A test must verify that when the flag is on:
- `OutboxService` is either not constructed or is a no-op stub
- `MatrixService` is either not constructed or is a passive stub (no pipeline, no rescan, no
  connectivity subscription)
- `BackfillRequestService.start()` is not called
- App startup completes without crashes (provider resolution succeeds)

## Development Strategy: Integration-Test-Driven

### Driving test: `integration_test/matrix_actor_isolate_network_test.dart`

The existing test already proves the core technical premise. We evolve it in lockstep with
production code:

1. **Refactor existing test** to use the new `SyncActor` production class instead of the
   inline `_matrixNetworkActor` function.
2. **Each phase adds commands** to the actor and corresponding test assertions.
3. **The test remains the source of truth** — if the integration test passes against docker
   Matrix, the actor is correct.

### Phase 1: Minimal Actor (vertical slice)

**Goal**: Replace the inline `_matrixNetworkActor` test function with a production
`SyncActor` class that handles the same flow.

#### Production code (`lib/features/sync/actor/`)

```
lib/features/sync/actor/
  sync_actor.dart              # Isolate entrypoint + command loop
  sync_actor_host.dart         # UI-side: spawn, send commands, receive events
```

- `SyncActor` — isolate entrypoint function and command router
  - `init`: creates `MatrixSdkGateway` via `createMatrixClient`, connects, logs in.
    All platform-dependent data (paths, credentials, device name) received via command payload.
  - `createRoom`, `joinRoom`: delegates to gateway
  - `sendText`: delegates to gateway
  - `startSync`, `stopSync`: starts/stops `client.sync()` loop
  - `ping`, `getHealth`, `stop`: lifecycle
- `SyncActorHost` — runs on UI isolate
  - `spawn()`: launches isolate, waits for ready
  - `send(command)`: sends command map, returns Future with response
  - `events`: Stream of event maps from actor
  - `dispose()`: sends stop, kills isolate
  - Forwards connectivity changes and app lifecycle events to actor

#### Integration test changes

Refactor `integration_test/matrix_actor_isolate_network_test.dart` to:

- Use the **single-user-across-devices** pattern (one Matrix user, two device sessions):
  - Create one test user account on docker Dendrite
  - Spawn two `SyncActor` instances (simulating two devices of the same user)
- Actor 1: `init` (login as user, device "DeviceA") → `createRoom` → `startSync`
- Actor 2: `init` (login as same user, device "DeviceB") → `joinRoom` → `startSync`
- (Current branch behavior: `init` enables background sync implicitly; startSync is idempotent and optional.)
  - Self-verify between the two devices (same-user SAS flow)
  - Actor 1 sends text → Actor 2 receives `incomingMessage` event
  - Actor 2 sends text → Actor 1 receives `incomingMessage` event
  - Both actors `stop`
- Replace inline `_matrixNetworkActor` with production `SyncActor` entrypoint
- Replace `_sendActorCommand` with `SyncActorHost.send()`

#### Unit tests (`test/features/sync/actor/`)

```
test/features/sync/actor/
  sync_actor_test.dart         # Command routing, state transitions
  sync_actor_host_test.dart    # Spawn, send, timeout, dispose
```

#### Acceptance criteria

- [x] Integration test passes against docker Matrix using production `SyncActor`
- [x] Unit tests cover: init, invalid-state rejection, ping, stop, state transitions
- [x] Analyzer zero warnings
- [x] No imports from existing sync service/outbox/pipeline code
- [x] No imports from platform-channel plugins in actor code

### Phase 2: Verification + Inbound Events

**Goal**: Move SAS verification and inbound message detection into the actor, with events
streamed back to the host.

#### Production code additions

```
lib/features/sync/actor/
  verification_handler.dart    # SAS flow management inside actor
```

- Actor commands: `startVerification`, `acceptVerification`, `acceptSas`, `cancelVerification`
- Actor events: `verificationState` (step, emojis, done/canceled), `incomingMessage`
- Verification handler encapsulates the SAS polling/state-guard logic from the integration
  test into a reusable class.
- Inbound message detection: actor listens to SDK sync events and emits `incomingMessage`
  events for messages not in `SentEventRegistry`.

#### Integration test additions

- Test SAS flow via actor commands instead of direct SDK calls.
- Assert `verificationState` events stream back to host.
- Assert `incomingMessage` events for received messages.

#### Unit tests

```
test/features/sync/actor/
  verification_handler_test.dart
```

#### Acceptance criteria

- [ ] Integration test: full SAS flow via actor commands
- [ ] Integration test: inbound message event received on host
- [ ] Unit tests: verification state machine, emoji convergence, cancel
- [ ] Analyzer zero warnings

### Phase 3: Outbound Pipeline

**Goal**: Actor owns outbound send orchestration — retry, backoff, connectivity awareness.
Completely separate from existing `OutboxService`.

#### Production code additions

```
lib/features/sync/actor/
  outbound_queue.dart          # In-memory send queue with retry
```

- New command: `enqueueSend` (UI tells actor to send a sync payload)
- New command: `connectivityChanged` (host forwards connectivity state)
- Actor manages in-memory outbound queue with retry + exponential backoff.
- Actor events: `sendAck` (message sent successfully), `sendFailed` (permanent failure).
- No `SyncDatabase` involvement — queue is in-memory and volatile.
  (Durable outbox persistence is a later phase.)

#### Integration test additions

- Test: enqueue multiple messages, verify all received by peer device.
- Test: actor retries after transient failure (simulate by pausing sync).

#### Acceptance criteria

- [ ] Integration test: multi-message send via enqueue, all received
- [ ] Unit tests: retry logic, backoff timing (fakeAsync), queue ordering
- [ ] Unit tests: connectivity change triggers retry
- [ ] Analyzer zero warnings

### Phase 3.5: DB Isolate Readiness (blocking prerequisite for Phase 4)

**Goal**: Make `JournalDb`, `SettingsDb`, and `openDbConnection` usable from a spawned
isolate without any platform-channel or `getIt` dependencies. This is pure infrastructure
work that can be done independently of actor code — it modifies the existing DB layer to
be isolate-safe while keeping all existing callers working.

**Status**: Tasks 1 & 2 completed in commit `13fc72f18` (WAL mode & read pools). Only
Task 3 (getIt coupling) remains before Phase 4 can begin.

#### Task 1: Add `documentsDirectoryProvider` + `tempDirectoryProvider` to DB constructors [DONE]

**Completed in commit `13fc72f18`** (`docs/implementation_plans/2026-02-13_drift_wal_read_pools.md`).

`JournalDb`, `SettingsDb`, and `SyncDatabase` constructors now accept
`documentsDirectoryProvider` and `tempDirectoryProvider` and forward them to
`openDbConnection()`. `JournalDb` also accepts `readPool` (default 4) and `background`.

**Acceptance criteria:**
- [x] `JournalDb({..., documentsDirectoryProvider, tempDirectoryProvider})` forwards to
  `openDbConnection()`
- [x] `SettingsDb({..., documentsDirectoryProvider, tempDirectoryProvider})` forwards to
  `openDbConnection()`
- [x] Existing callers (main isolate) continue to work with no changes
- [x] WAL pragma verification test added (`test/database/open_db_connection_test.dart`)
- [x] Analyzer zero warnings

#### Task 2: Add isolate-safe `openDbConnection` variant (no `createInBackground`) [DONE]

**Completed in commit `13fc72f18`.**

Added `background` parameter (default `true`) to `openDbConnection()`. When `false`, uses
`NativeDatabase(file, setup: _setupDatabase)` directly instead of `createInBackground()`.
Also added `readPool` parameter for read-pool isolates (used by `JournalDb` with default 4).

WAL mode, `busy_timeout = 5000`, and `synchronous = NORMAL` are applied to all connections
via the `_setupDatabase` callback, including read-pool isolates and `background: false`
connections.

**Acceptance criteria:**
- [x] `openDbConnection(..., background: false)` uses `NativeDatabase(file)` directly
- [x] Existing callers continue to use `createInBackground()` (default behavior)
- [x] Tests verify WAL pragmas for both `background: true` and `background: false`
- [x] Analyzer zero warnings

#### Task 3: Resolve `getIt` coupling in `JournalDb.updateJournalEntity()`

The method calls `getIt<LoggingService>()` (database.dart:358, :379) and
`saveJournalEntityJson()` → `getIt<Directory>()` (file_utils.dart:127). These must work
without the main isolate's `getIt` registry.

**Recommended approach**: Add optional `LoggingService?` and `Directory?` fields to
`JournalDb`. The actor passes its own instances at construction; existing main-isolate code
continues to use the `getIt` fallback.

**Files changed:**
- `lib/database/database.dart` — add optional injected dependencies
- `lib/utils/file_utils.dart` — make `saveJournalEntityJson` accept an explicit `Directory`
  parameter (or extract the actor-compatible version)
- Corresponding test files

**Acceptance criteria:**
- [ ] `updateJournalEntity()` works when called from a context without `getIt` initialized
  (verified by unit test)
- [ ] Existing main-isolate callers continue to work with no changes
- [ ] Analyzer zero warnings

### Phase 4: Inbound Processing + Direct DB Writes

**Goal**: Actor processes inbound sync messages and writes directly to `JournalDb` /
`SettingsDb` via its own connections. Sends `entitiesChanged` events to host for UI refresh.

**Depends on**: Phase 3.5 (DB isolate readiness) must be complete.

This is where the **entire inbound pipeline moves off main thread**:
- Matrix event decryption (SDK)
- SyncMessage JSON parsing and deserialization
- Vector clock comparison and conflict detection
- Entity validation and normalization
- Sent-event filtering
- `JournalDb.updateJournalEntity()` / `upsertEntryLink()` — direct writes
- `SettingsDb.saveSettingsItem()` — direct writes
- Read marker advancement

**On the main thread (single notification path):**
- `UpdateNotifications.notify({...ids, ...notificationKeys}, fromSync: true)` — entity-level
  and type-level refresh via notification-driven streams (all sync-affected Drift `watch()`
  methods have been removed and replaced with `UpdateNotifications`-driven streams)

#### Production code additions

```
lib/features/sync/actor/
  inbound_processor.dart       # Processes SDK events, writes to DB, emits changed IDs
```

- Actor opens its own `JournalDb` and `SettingsDb` connections at init time using the
  Phase 3.5 isolate-safe constructors.
- Actor processes inbound Matrix events → deserializes → validates → writes to DB.
- After each batch of writes, actor emits `entitiesChanged` event with the list of affected
  entity IDs and type-specific notification keys (e.g., `categoriesNotification`,
  `habitsNotification`, `settingsNotification`).
- Host receives `entitiesChanged` and calls
  `UpdateNotifications.notify({...ids, ...notificationKeys}, fromSync: true)`.
  This triggers all notification-driven streams that match the type keys.
- No apply/ack handshake. No cross-isolate DTOs for DB operations.

#### Acceptance criteria

- [ ] Integration test: send from device A → actor writes to DB → `entitiesChanged` event
  received by host → entity appears in DB when read from host's connection
- [ ] Integration test: host receives type notification keys in `entitiesChanged` event and
  can feed them to `UpdateNotifications` for UI refresh
- [ ] Unit tests: inbound processing logic, vector clock handling, entity ID collection,
  correct notification key selection per entity type
- [ ] Analyzer zero warnings

### Phase 5: Feature Flag + Host Provider + Supervisor + Bootstrap Gate

**Goal**: Wire the actor into the app behind a feature flag. Add supervisor for restart.
Implement bootstrap gate to prevent legacy sync producers from running.

#### Production code additions

```
lib/features/sync/actor/
  sync_actor_supervisor.dart   # Restart policy, epoch tracking
```

#### Changes to existing code

- `lib/utils/consts.dart` — add `enableSyncActorIsolate` flag constant (this is where all
  config flags live, not `lib/features/sync/matrix/consts.dart`)
- `lib/database/journal_db/config_flags.dart` — register flag with `insertFlagIfNotExists()`
- `lib/get_it.dart` — extract `startSyncServices()`, guard with feature flag:
  - flag off: construct `MatrixService` + `OutboxService` + call `MatrixService.init()` +
    `BackfillRequestService.start()` (current behavior)
  - flag on: do NOT construct `MatrixService` (constructor has side effects: pipeline
    creation, forceRescan scheduling, connectivity subscription), do NOT construct
    `OutboxService` (constructor self-starts), do NOT call `BackfillRequestService.start()`.
    Start `SyncActorHost` instead.
- `lib/main.dart` — make `outboxServiceProvider.overrideWithValue(...)` conditional on flag,
  or register a no-op stub when actor mode is active
- `lib/beamer/beamer_app.dart` — guard `outboxLoginGateStreamProvider` listener when actor
  mode is active (or provide an empty stream from a no-op stub)
- `lib/providers/service_providers.dart` — consider making `outboxServiceProvider` and
  `matrixServiceProvider` nullable or providing actor-mode alternatives
- `test/database/database_test.dart` — update `expectedFlags`
- Sync UI providers — either:
  (a) Create actor-backed replacements for `MatrixLoginController`, `MatrixRoomProvider`,
      `MatrixStatsProvider` that read from `SyncActorHost.events` stream, OR
  (b) Register passive no-op stubs for `MatrixService` and `OutboxService` that provide
      empty/default state without starting background work.
  Decision to be made during Phase 5 implementation.

#### Acceptance criteria

- [ ] App starts with flag off — existing behavior unchanged, no actor
- [ ] App starts with flag on — actor host starts, `MatrixService` NOT constructed (no
  pipeline, no rescan, no connectivity subscription), `OutboxService` NOT constructed (no
  runner, no watchdog), `BackfillRequestService.start()` NOT called
- [ ] App startup does not crash in actor mode — all provider overrides and listeners
  handle the absence of `OutboxService` and `MatrixService` gracefully
- [ ] Verify: zero legacy sync producers running when flag is on
- [ ] Supervisor restart: kill actor → auto-restart → re-login → resume sync
- [ ] Analyzer zero warnings

### Phase 6: Parity, Hardening, Rollout

**Goal**: Achieve feature parity with existing sync path, then cut over.

- Backfill/gap detection (equivalent to `BackfillRequestService`)
- Vector clock handling (actor writes with full vector clock semantics)
- Attachment send/receive
- Sent-event suppression
- Durable outbox (actor-owned table, replacing in-memory queue)
- Sequence log writes (actor-owned, replacing UI-side `SyncDatabase` sequence log)
- Migrate `SyncDatabase` ownership to actor (requires separate design doc)
- Performance comparison: frame drops, command latency, correctness
- Remove legacy path once parity confirmed

This phase is intentionally underspecified — design decisions should be informed by
experience from phases 1-5.

## File Layout

```
lib/features/sync/actor/
  sync_actor.dart              # Isolate entrypoint + command loop
  sync_actor_host.dart         # UI-side host: spawn, send, events, notification bridge
  sync_actor_supervisor.dart   # Restart policy (phase 5)
  verification_handler.dart    # SAS flow (phase 2)
  outbound_queue.dart          # Send queue with retry (phase 3)
  inbound_processor.dart       # Inbound event processing + direct DB writes (phase 4)

test/features/sync/actor/
  sync_actor_test.dart
  sync_actor_host_test.dart
  verification_handler_test.dart
  outbound_queue_test.dart
  inbound_processor_test.dart

integration_test/
  matrix_actor_isolate_network_test.dart  # Evolves with each phase
  run_matrix_actor_isolate_test.sh        # Existing test runner
```

## Separation Guarantees

The actor code MUST NOT import from:
- `lib/features/sync/matrix/matrix_service.dart`
- `lib/features/sync/outbox/` (any file)
- `lib/features/sync/matrix/pipeline/` (any file)
- `lib/features/sync/matrix/sync_event_processor.dart`
- `lib/features/sync/matrix/sync_engine.dart`
- `lib/features/sync/matrix/sync_lifecycle_coordinator.dart`
- `lib/features/sync/matrix/session_manager.dart`
- `lib/features/sync/matrix/sync_room_manager.dart`
- `lib/features/sync/backfill/` (any file)
- `lib/features/sync/sequence/` (any file)
- `lib/features/sync/secure_storage.dart`
- `lib/features/sync/matrix.dart` (barrel file — re-exports `matrix_service.dart` and other
  forbidden modules)
- `lib/features/sync/matrix/key_verification_runner.dart` (imports `matrix.dart` barrel)
- Any Flutter platform-channel plugin (`flutter_secure_storage`, `connectivity_plus`,
  `package_info_plus`, etc.)

The actor MAY import from:
- `lib/features/sync/matrix/client.dart` (`createMatrixClient`).
  **Note**: This file imports `device_info_plus` and `file_utils.dart` (which imports
  `get_it.dart`), but `createMatrixClient()` itself calls neither — the platform-channel
  code is only in `createMatrixDeviceName()` which the actor must never call. The transitive
  import graph is compile-time safe; no runtime calls to `getIt` or platform channels occur
  within `createMatrixClient()`. Uses `sqflite_common_ffi` (FFI, not platform channels)
  for the Matrix SDK database — isolate-safe.
- `lib/features/sync/gateway/` (`MatrixSdkGateway`, `MatrixSyncGateway`)
- `lib/features/sync/matrix/sent_event_registry.dart` (`SentEventRegistry`)
- `lib/classes/config.dart` (`MatrixConfig`)
- `lib/classes/journal_entities.dart` and other freezed model classes
- `lib/database/database.dart` (`JournalDb`) — actor creates its own instance.
  **Caveat**: this file imports `flutter/foundation.dart` (for `@visibleForTesting`),
  `get_it.dart`, `logging_service.dart`, and `file_utils.dart`. These are compile-time safe
  (annotations don't execute, imports don't trigger platform channels), but the runtime
  calls to `getIt<LoggingService>()` in `updateJournalEntity()` and
  `saveJournalEntityJson()` → `getIt<Directory>()` will crash. See Phase 4 prerequisites.
- `lib/database/settings_db.dart` (`SettingsDb`) — actor creates its own instance
- `lib/database/common.dart` (`openDbConnection`) — actor uses `background: false` to
  avoid nested isolates, and provides `documentsDirectoryProvider` +
  `tempDirectoryProvider` to bypass platform channels. These parameters were added in
  commit `13fc72f18`.
- ~~`lib/features/sync/matrix/key_verification_runner.dart`~~ **REMOVED from allowed list.**
  This file imports `package:lotti/features/sync/matrix.dart` (the barrel file), which
  re-exports `matrix_service.dart`, `session_manager.dart`, `sync_engine.dart`,
  `sync_lifecycle_coordinator.dart`, and other forbidden modules. Importing it in the actor
  would violate separation guarantees by pulling in the entire legacy sync graph.
  **The actor must rewrite verification handling** in `verification_handler.dart` (Phase 2),
  using the Matrix SDK's `KeyVerification` API directly without `KeyVerificationRunner`.
- `lib/features/sync/vector_clock.dart` (`VectorClock`)
- `dart:io` (for `Directory`, `File` — these work in isolates, no platform channel needed)

## Recovery and Failure (v1 — simple)

- **Network failure**: actor catches, logs, emits `error` event. Host can retry via command.
- **Actor crash**: supervisor detects isolate exit, respawns, re-inits with saved config.
- **SAS during crash**: verification state is lost. Actor requires fresh SAS negotiation after
  restart (fail-closed).
- **No durable actor state in v1**: actor is stateless between restarts. `JournalDb` /
  `SettingsDb` writes are durable (SQLite), but actor-internal state (retry queues, sync
  position) is lost on crash. The next sync cycle re-discovers events from Matrix timeline.
- **Partial batch crash**: if the actor crashes mid-batch, some entities may be written but
  not all. On restart, the actor re-processes the same events. DB writes are idempotent
  (vector clock comparison), so re-applying is safe. The host receives `entitiesChanged`
  for whatever IDs the actor writes, whether first-time or replay.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Ordering regressions across isolate boundary | Single mailbox, FIFO processing, sequence IDs on apply events |
| SAS protocol races in async actor | State-aware verification handler with step guards |
| Memory overhead from second Matrix Client | Acceptable trade-off; monitor in phase 6 |
| Actor restart loses in-flight sends | v1 accepts this; durable outbox in phase 6 |
| Legacy producers still running in actor mode | Must gate construction of both `OutboxService` AND `MatrixService` (both have constructor side effects). Must also handle downstream wiring: `main.dart` provider overrides, `beamer_app.dart` login gate listener, UI providers. Verified by test. |
| Actor can't access platform channels | Host bridge contract; all platform data flows via commands |
| Concurrent DB writes from two isolates | SQLite WAL mode explicitly enabled via `_setupDatabase()` callback (commit `13fc72f18`); `busy_timeout = 5000` prevents transient lock errors; writes serialized by SQLite; reads non-blocking |
| UI doesn't see DB changes from actor | **RESOLVED.** All sync-affected Drift `watch()` methods have been removed and replaced with `UpdateNotifications`-driven streams (see `2026-02-12_remove_sync_affected_drift_watch.md`). The actor includes type notification keys in `entitiesChanged` events; the host feeds them to `UpdateNotifications.notify()`. Single notification path — no `markTablesUpdated()` needed. |
| `JournalDb` methods use `getIt` globals | Must inject dependencies or use lower-level DB methods in actor; addressed in Phase 4 prerequisites |
| DB constructors don't accept directory provider | **RESOLVED.** Commit `13fc72f18` added `documentsDirectoryProvider` and `tempDirectoryProvider` to `JournalDb`, `SettingsDb`, and `SyncDatabase` constructors. |
| `NativeDatabase.createInBackground()` in actor isolate | **RESOLVED.** Commit `13fc72f18` added `background: false` parameter to `openDbConnection()` which uses `NativeDatabase()` directly. |
| `common.dart` calls `getTemporaryDirectory()` (platform channel) | **RESOLVED.** Actor provides `tempDirectoryProvider` parameter via the updated `openDbConnection()` signature. |
| `common.dart` calls `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` (Flutter plugin) | Android-only; main isolate calls it at startup; actor isolate should skip it (already applied process-wide). The `background: false` path still calls it — may need a guard for actor use. |
| Sync UI providers hardwired to `matrixServiceProvider` | Actor-backed provider replacements or passive `MatrixService` wrapper; addressed in Phase 5 |
| `key_verification_runner.dart` imports legacy barrel | Removed from allowed imports; actor rewrites verification handling from scratch in Phase 2 |

## Phase 1 Execution Checklist

- [x] Create `lib/features/sync/actor/sync_actor.dart`
  - isolate entrypoint function
  - command loop with state machine
  - init/login/room/send/health/ping/stop commands
  - verification commands (startVerification, acceptVerification, acceptSas, cancelVerification, getVerificationState)
  - no platform-channel imports
- [x] Create `lib/features/sync/actor/sync_actor_host.dart`
  - spawn/ready handshake
  - send command with timeout
  - event stream via `eventSendPort` passed in `init` payload
  - dispose (sends stop best-effort, kills isolate, closes ports)
  - Note: connectivity forwarding deferred — not needed for Phase 1
- [x] Refactor `integration_test/matrix_actor_isolate_network_test.dart`
  - uses production `SyncActorHost` (which spawns `SyncActor` isolate)
  - single-user-across-devices pattern: one Matrix user, two actor instances
  - flow: spawn both → ping → init both → createRoom (DeviceA) → joinRoom (DeviceB) →
    startSync both → sendText with warm-up retries → health checks → stopSync → verify idle
  - Self-verification **deferred** (see findings below)
  - Inbound message verification **deferred** (requires working E2EE)
- [x] Update `integration_test/run_matrix_actor_isolate_test.sh`
  - creates one test user with uuidgen on docker Dendrite
  - passes `TEST_USER` and `TEST_PASSWORD`
- [x] Create `test/features/sync/actor/sync_actor_test.dart` (40 tests)
  - state machine transitions for all states
  - invalid-state command rejection for all commands
  - ping/health responses in all states
  - init, double-init rejection, eventPort delivery
  - createRoom, joinRoom, sendText delegation
  - verification commands (startVerification, acceptVerification, acceptSas, cancelVerification)
  - stop from all states, double-stop rejection
- [x] Create `test/features/sync/actor/sync_actor_host_test.dart` (7 tests)
  - spawn + ping via lightweight test entrypoint
  - command timeout handling
  - event stream delivery
  - dispose cleanup
- [x] Add config flag `enableSyncActorFlag` in consts.dart, config_flags.dart, database_test.dart
- [x] Verify: `dart analyze` zero warnings, `dart format` clean
- [x] Verify: integration test green against docker Matrix (Dendrite)
- [x] Verify: no imports from forbidden list

## Phase 1 Implementation Findings

### vodozemac verification/session bootstrap gap between isolate sessions

When two fresh device sessions are created in separate isolates for the same user,
to-device events (including `m.key.verification.*` messages) can arrive before
vodozemac session state is fully established. The receiver sees the events but the Matrix
SDK may not yet progress to `onKeyVerificationRequest`.

This means **self-verification via SAS between two actor isolates is timing-sensitive**.
The likely root cause is vodozemac session bootstrap ordering when multiple actor isolates
start together. In this state, encrypted to-device messages and send attempts can fail
intermittently.

**Impact**: Self-verification and encrypted message send/receive are now guarded with
sync warm-up and retry behavior instead of hard-failing immediately.

### SQLite concurrent access

When the sync loop and command handler both access the database simultaneously (e.g.,
`sendText` triggering encryption key lookups while sync is writing), `SqliteException(21)`
(library routine called out of sequence) can occur. This is a known issue with sharing
SQLite connections across async operations and will need attention when the actor starts
writing to the DB in later phases.

### Sync loop performance

Against Dendrite with no long-polling timeout, both devices run ~200 syncs/second
(empty sync responses returned immediately). This is expected behavior and will be
gated by a configurable sync filter / long-poll timeout in later phases.

### Config flag added in Phase 1

The plan originally placed config flag registration in Phase 5, but it was added in
Phase 1 to enable early feature-flag gating. The flag is registered in the database
but is **not yet surfaced in the settings UI** — it only exists as a DB entry for now.
