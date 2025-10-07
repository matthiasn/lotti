# Sync Refactor Plan – 2025-10-06

## 1. Responsibility & Pain-Point Map

- **MatrixService**
  - Manages session lifecycle, connectivity monitoring, room discovery, timeline polling, verification streams.
  - Pain points: global `getIt` access, no disposal of controllers/streams, busy wait on `UserActivityService`, hardcoded call to `listenToMatrixRoomInvites` bug.
- **Timeline Processing**
  - `listenToTimelineEvents`/`processNewTimelineEvents` combine transport, client sync calls, persistence, read-marker writes.
  - Pain points: repeated `client.sync()` in loops, embedded read-marker logic with swallowed errors, `getIt` dependencies.
- **Message Processing**
  - `processMatrixMessage` handles decoding and writes directly to DB/repos.
  - Pain points: direct file I/O, global dependencies, no separation per entity.
- **OutboxService**
  - Handles queue persistence, connectivity listening, attachment resolution, retry policy, Matrix send.
  - Pain points: busy wait on user activity, direct Matrix send/attachment logic, no disposal.
- **Room Handling (`listenToMatrixRoomInvites`)**
  - Subscribes to `client.onRoomState` for all room events – auto-joins incorrect rooms (root cause bug).
- **Extensions (`send_message.dart`)**
  - Adds major features to `MatrixService` via extensions; mixes concerns and hides dependencies.

## 2. Target Architecture

### Core Interfaces & Services
- `MatrixSyncGateway`
  - Session: `connect`, `login`, `logout`, `loginStateChanges`.
  - Rooms: `createRoom`, `joinRoom`, `leaveRoom`, `getRoomById`, `invites` (filtered invite stream).
  - Timeline: `timelineEvents(roomId)`.
  - Sending: `sendText`, `sendFile`.
  - Verification: `keyVerificationRequests`, `verifyDevice`, `unverifiedDevices`.
  - Lifecycle: `dispose`.
- `SyncLifecycleCoordinator`
  - Orchestrates startup/shutdown, owns subscriptions, invokes disposals.
- `UserActivityGate`
  - Reactive gate (`Stream<bool> canProcess`) replacing busy-wait loops.
- `SyncReadMarkerService`
  - Persists last-read event ID and updates Matrix read markers.
- `SyncEventProcessor`
  - Decodes `SyncMessage` and delegates to entity-specific handlers (journal, tags, AI config, etc.).
- `MatrixMessageSender`
  - Handles text/file sends via gateway with injected `AttachmentResolver` and policies.
- `OutboxProcessor`
  - Orchestrates pending queue using `OutboxRepository`, `MatrixMessageSender`, retry policy, connectivity monitor, and `UserActivityGate`.
- `MatrixSessionManager`
  - Login/config, connectivity monitoring, verification lifecycle.
- `SyncRoomManager`
  - Persists/validates room ID, uses gateway `invites` stream, prompts/validates before join.
- `MatrixTimelineListener`
  - Subscribes to `timelineEvents`, applies gating, forwards to `SyncEventProcessor`.
- `SyncEngine`
  - Composes managers/processors, provides status metrics, ensures cleanup.

### Cross-Cutting Requirements
- Constructor injection for all dependencies; remove direct `getIt` usage from sync modules.
- Every service exposes `dispose()`/`close()`; coordinator ensures teardown.
- Gateway implementation wraps Matrix SDK; fake gateway supports tests.

## 3. Milestone Roadmap

1. **Gateway & Lifecycle**
   - Define `MatrixSyncGateway`, implement SDK wrapper and fake.
   - Retrofit existing services to delegate to gateway without changing public APIs.
   - Add dispose methods and call them.
   - Run existing Matrix integration tests.

2. **UserActivityGate**
   - Introduce reactive activity gate used by timeline listener/outbox.
   - Remove busy-wait polling; unit-test gating behaviour.

3. **OutboxProcessor**
   - Extract queue processing into dedicated service with injected collaborators.
   - Add unit tests with fake gateway/outbox repositories.

4. **SyncReadMarkerService**
   - Move read-marker persistence/Matrix updates into dedicated service with tests.

5. **SyncEventProcessor**
   - Build processor + per-entity handlers + attachment reader abstraction.
   - Cover with unit tests.

6. **Session & Room Management**
   - Split `MatrixService` into `MatrixSessionManager` and `MatrixTimelineListener`.
   - Create `SyncRoomManager` using filtered `gateway.invites`, validate room IDs, prompt user, update persisted room.
   - Delete `listenToMatrixRoomInvites`; manual multi-device testing for invites.

7. **SyncEngine Assembly**
   - Compose all services, integrate lifecycle coordinator, expose diagnostics.
   - Add integration tests with fake gateway to simulate multi-device scenarios.

8. **Dependency Injection Cleanup**
   - Replace `getIt` usage in sync modules with constructor injection/provider overrides.
   - Enforce via static analysis.

9. **Extension Method Removal**
   - Replace `send_message` extension with `MatrixMessageSender` service, ensure attachments/policies injected.
   - Add disposal and behaviour tests.

10. **Regression & Documentation**
    - Add lifecycle, invite filtering, activity gating, race-condition (fake_async), and error recovery tests.
    - Measure memory usage pre/post Milestone 5 to confirm leak fixes.
    - Update documentation (README/feature docs) with architecture diagram, data flow, dependency graph, extension points.

## 4. Testing Strategy

- **Characterization Tests**: capture current behaviours, especially invite auto-join bug and setup flow.
- **Unit Tests**: gateways (fake), activity gate, outbox processor, read-marker service, event handlers, message sender.
- **Integration Tests**: sync engine with fake gateway, multi-device invite flow, error recovery.
- **Lifecycle Tests**: verify all streams/controllers disposed.
- **Performance Tests**: ensure no regressions in message throughput.

## 5. Risk Mitigation & Checkpoints

- After Milestone 1: run full integration suite (`integration_test/matrix_service_test.dart`).
- After Milestone 4: manual dual-device invite flow validation.
- After Milestone 5: monitor memory usage for leaks.
- After Milestone 6: ensure static analysis shows no residual `getIt` usage in `lib/features/sync`.
- Ongoing: coverage tracking to measure progress.

## 6. Preparatory Tasks (Before Coding)

1. Write characterization tests for invite bug and existing setup flow.
2. Document current device setup steps.
3. Build integration harness using fake gateway for two-clients simulation.
4. Enable coverage reporting for sync modules.
