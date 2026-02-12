# Actor-Based Matrix Sync Isolate Plan

## Summary

- Move Matrix sync execution off the UI isolate into a dedicated worker isolate.
- Use an actor model: single mailbox, serialized command handling, explicit event stream back to UI.
- Keep Matrix SDK objects isolate-local and exchange only serializable DTOs.
- Maintain runtime parity (including SAS verification behavior) with production Matrix client paths.

## Goals

- Eliminate sync-induced frame drops by isolating network/crypto/sync work from render thread.
- Preserve current sync correctness guarantees (ordering, retries, catch-up, sent-event suppression).
- Provide observable actor health and deterministic recovery semantics.
- Enable incremental rollout with a quick rollback switch.

## Non-Goals

- No full app isolate migration in this project phase.
- No protocol changes to Matrix payloads.
- No immediate rewrite of all sync internals; initial phases wrap existing services.

## Current Findings (Grounded)

- Existing sync hot paths have been improved (non-blocking file checks, buffered logging writes), but UI isolate still performs substantial sync orchestration.
- Integration coverage now validates isolate actor networking against docker Matrix.
- Runtime-parity isolate integration uses:
  - `createMatrixClient`
  - `MatrixSdkGateway`
  - SDK-based room create/invite/join/send/receive
  - SDK SAS verification flow (with state-safe sequencing)
- Practical SAS hardening lessons:
  - initialize vodozemac (`vod.init()`) in the worker isolate
  - avoid eager SAS derivation while protocol state is not ready
  - keep acceptance/emoji checks state-aware

## Architecture

### Isolate Topology

- **UI isolate (main)**
  - UI, state management, command dispatch.
  - Receives actor events and updates providers/controllers.
- **Sync actor isolate (single worker)**
  - Owns Matrix SDK client(s), gateway, lifecycle coordinator, sync engine, retries, and timers.
  - Processes one command at a time from a mailbox (`ReceivePort`).
  - Emits typed events (`SendPort`) for status/progress/errors/incoming sync outcomes.

### Ownership Rules

- Actor owns all non-thread-safe sync resources:
  - Matrix `Client`, room/timeline handles, key verification objects, retry state, backoff timers.
- UI owns presentation state only.
- Cross-isolate data must be plain JSON-like maps / DTO classes with primitive fields and lists/maps.
- Never pass SDK objects, streams, controllers, DB handles, or closures across isolates.
- **Explicit v1 ownership decision (feasibility):**
  - Phase 1-2: actor owns network/crypto/sync decisioning; UI isolate remains durable DB writer.
  - Phase 3+: DB write ownership can move into actor only behind a dedicated storage abstraction and
    parity test gates.
  - Until DB ownership moves, actor MUST NOT advance durable sync markers unless UI acks apply.

### Actor Mailbox Contract (v1)

- Envelope fields:
  - `schemaVersion` (int, starts at `1`)
  - `requestId` (string, unique per command)
  - `type` (string command type)
  - `payload` (map)
  - `replyTo` (`SendPort`) for direct ack/result
- Command categories:
  - lifecycle: `init`, `start`, `stop`, `dispose`, `ping`
  - auth/session: `login`, `logout`, `setConfig`
  - room: `createRoom`, `joinRoom`, `inviteUser`, `discoverSyncRooms`
  - sync control: `forceRescan`, `retryNow`, `pause`, `resume`
  - outbox: `sendSyncMessage`, `sendAttachment`, `flushOutbox`
  - verification: `startSas`, `acceptVerification`, `acceptSas`, `cancelVerification`
  - diagnostics: `getMetrics`, `getHealth`, `getRecentErrors`
- Event stream categories:
  - lifecycle: `ready`, `started`, `stopped`
  - status: `loginStateChanged`, `roomStateChanged`, `syncProgress`
  - domain: `incomingMessage`, `outboxAck`, `verificationStateChanged`
  - diagnostics: `metrics`, `warning`, `error`
- Compatibility rules:
  - actor rejects unknown `schemaVersion` with `UNSUPPORTED_SCHEMA`
  - additive command/event fields only within a schema version
  - breaking changes require `schemaVersion` bump and dual-reader transition window

## State Model

### Actor Internal States

- `uninitialized`
- `initializing`
- `idle` (initialized but sync loop stopped)
- `running` (sync active)
- `paused`
- `recovering` (transient failure handling)
- `fatal` (requires re-init)

### Command Validity by State

- Reject invalid commands with structured error responses:
  - `code`: e.g. `INVALID_STATE`, `NOT_CONFIGURED`, `IN_FLIGHT`, `TIMEOUT`
  - `message`
  - `retryable` (bool)

### Command QoS and Head-of-Line Avoidance

- Mailbox remains single-actor for correctness, but commands are split by priority:
  - **control (high):** `ping`, `getHealth`, `pause`, `resume`, `stop`
  - **interactive (medium):** `login`, `joinRoom`, `sendSyncMessage`, verification commands
  - **background (low):** `forceRescan`, `retryNow`, periodic maintenance
- Long-running background jobs are cancellable; control commands preempt by setting cancellation flags.
- Every command gets fast ack (`accepted` / `rejected`) before completion event.

## Failure and Recovery

### Expected Failures

- network interruptions/timeouts
- homeserver transient errors
- SAS negotiation races/state mismatches
- actor isolate crash/unhandled exception

### Recovery Strategy

- Actor-level exponential backoff with jitter for retryable operations.
- Circuit-breaker style pause on repeated fatal errors.
- Supervisor on UI isolate:
  - detects actor exit
  - restarts actor with last known config and checkpoint
  - emits degraded-state event until rehydration complete
- Persist minimal checkpoint data in main isolate or durable store:
  - sync room id
  - last processed marker ids/tokens (if available)
  - pending outbox descriptors
- **Expanded checkpoint contract (required for safe restart):**
  - actor epoch (`actorInstanceId`) and `schemaVersion`
  - last emitted apply sequence number
  - last UI-acked apply sequence number
  - last durable marker acknowledged by UI
  - in-flight command ids with retryability metadata
  - retry state (`attempt`, `nextEligibleAt`) per retriable operation
  - sent-event suppression window snapshot (event ids + expiry timestamps)
  - active verification session metadata (transaction id, peer, step) or explicit canceled marker

## Data Boundaries and Persistence

- Keep heavy sync processing in actor.
- UI isolate applies only coarse-grained updates from actor events.
- If DB access remains in UI isolate initially:
  - actor emits validated “apply” DTOs
  - UI applies writes via existing DB services
  - later phase may move DB writes into actor if safe and beneficial

### Apply/Ack Protocol (Phase 1-2, DB in UI)

- Actor emits `applyBatch` with:
  - `applySeq` (monotonic int)
  - `batchId` (uuid)
  - `operations` (idempotent operations with deterministic keys)
  - `proposedMarker` (optional)
- UI writes operations transactionally, then responds `applyAck` or `applyNack`.
- Actor rules:
  - never commit `proposedMarker` before matching `applyAck`
  - on timeout/no-ack, retry same `applySeq` (exact same payload)
  - on `applyNack`, enter `recovering` and request diagnostics
- Idempotency:
  - every operation includes stable `opId`
  - UI deduplicates by `opId` if replayed after restart

## Migration Strategy (Phased)

### Phase 0: Contract and Scaffolding

- Define command/event DTOs and envelope schema.
- Add `SyncActorHost` in UI isolate:
  - spawn/kill actor
  - request/response registry by `requestId`
  - event stream bridge to app state
- Add feature flag:
  - `SYNC_USE_ISOLATE_ACTOR` (default off)
- Implement Apply/Ack protocol skeleton with no-op payloads first.

### Phase 1: Lifecycle + Session Parity

- Move `init/login/logout/start/stop` flows into actor.
- Keep current sync service path as fallback.
- Validate startup/shutdown and reconnect semantics.
- Add supervisor restart flow with checkpoint restore and epoch increment.

### Phase 2: Room + Basic Send/Receive

- Actor handles room create/join/invite/send text.
- Mirror current behavior for sync room discovery and state updates.
- Ensure outbox ack semantics remain monotonic and idempotent.
- Use Apply/Ack for all DB effects while UI still owns durable writes.

### Phase 3: Sync Pipeline Ownership

- Move force-rescan/retry/catch-up orchestration into actor.
- Preserve ordering and sent-event suppression guarantees.
- Integrate connectivity signal handling in actor.
- Optional sub-phase 3b: migrate DB writes into actor behind `SyncStore` abstraction only if:
  - actor-path parity tests pass
  - crash-recovery replay tests pass
  - performance targets are met

### Phase 4: SAS and Verification Ownership

- Move verification command handling completely into actor.
- Publish verification runner state snapshots to UI.
- Preserve current UX behavior with actor-fed state.

### Phase 5: Rollout and Cleanup

- Enable flag for internal/beta cohorts.
- Compare metrics and failure rates against legacy path.
- Remove legacy path once parity and stability targets are met.

## Testing Plan

### Unit Tests

- actor command router state machine
- invalid-state command rejection
- retry/backoff behavior with fake time
- supervisor restart and in-flight request handling
- Apply/Ack replay and idempotency (`applySeq`, `opId`) behavior
- command priority/preemption (control over background)

### Integration Tests

- docker-backed isolate test (existing baseline) extended to assert:
  - lifecycle commands
  - SDK room flow
  - SDK SAS flow
  - send/receive parity
- failure injection:
  - kill actor mid-sync and verify restart/recovery
  - simulated network degradation/reconnect
  - replay same `applySeq` after forced restart and verify no duplicate DB effects

### Regression Tests

- maintain existing matrix service integration tests for non-actor path until retirement
- add parity assertions comparing actor and non-actor outcomes for representative flows

## Observability

- Add actor-scoped metrics:
  - mailbox queue depth
  - command latency p50/p95
  - retry counts and breaker open duration
  - sync batch durations
  - event emit rates
- Add structured logs with `actorInstanceId` and `requestId`.
- Add recovery counters:
  - `apply_replay_count`
  - `apply_nack_count`
  - `restart_count`
  - `verification_recoveries`

## Performance Acceptance Criteria

- UI isolate frame budget unaffected by sync spikes (no additional dropped-frame clusters during sync bursts).
- Actor command latency (non-network) p95 under 30ms.
- No regression in end-to-end sync correctness metrics (message loss/duplication/order).
- Measurement method:
  - baseline: current non-actor path over 3 scripted runs (same docker setup)
  - actor path: same 3 scripted runs
  - compare:
    - dropped-frame clusters during sync windows
    - p95 command latency for `sendSyncMessage`, `getHealth`, `forceRescan`
    - correctness counters (duplicates/missing/order violations)
- Rollout gate: actor path must be >= baseline on correctness and not worse on frame-drop metric.

## Risks and Mitigations

- **Risk:** subtle ordering regressions across isolate boundary.
  - **Mitigation:** single mailbox serialization + sequence IDs for applied sync events.
- **Risk:** restart causes duplicate apply.
  - **Mitigation:** idempotent apply keys and persisted last-applied markers.
- **Risk:** SAS protocol races in asynchronous actor flow.
  - **Mitigation:** state-aware verification sequencing and guarded SAS derivation.
- **Risk:** rollout instability.
  - **Mitigation:** feature-flagged rollout with quick fallback.

## Concrete First Vertical Slice

- Implement actor commands:
  - `init`, `login`, `start`, `createRoom`, `joinRoom`, `sendSyncMessage`, `getHealth`, `stop`
- Wire UI host adapter for request/response and events.
- Add one end-to-end integration test path:
  - spawn actor -> login two users -> room setup -> SAS -> send/receive -> stop.
- Include Apply/Ack plumbing in this slice (even if batch contains one operation) to avoid rework.

## Rollout Checklist

- [ ] DTO contract finalized and documented
- [ ] actor host + supervisor implemented
- [ ] feature flag integrated in sync entrypoint
- [ ] phase-1 integration tests green locally and CI
- [ ] observability dashboards for actor metrics
- [ ] staged rollout with rollback playbook
- [ ] restart/replay/idempotency tests green
- [ ] QoS/preemption tests green
- [ ] baseline-vs-actor performance comparison documented

## Phase 0 Execution Checklist (Concrete)

### 0.1 Protocol and DTOs

- [ ] Create actor protocol package:
  - files:
    - `lib/features/sync/actor/protocol/sync_actor_envelope.dart`
    - `lib/features/sync/actor/protocol/sync_actor_command.dart`
    - `lib/features/sync/actor/protocol/sync_actor_event.dart`
    - `lib/features/sync/actor/protocol/sync_actor_error.dart`
  - classes:
    - `SyncActorEnvelope`
    - `SyncActorCommand` (sealed union)
    - `SyncActorEvent` (sealed union)
    - `SyncActorError`
- [ ] Add `schemaVersion` constant and compatibility validator.
- [ ] Add JSON encode/decode and schema validation tests.
- acceptance:
  - invalid/missing fields rejected with structured error codes
  - unknown `schemaVersion` returns `UNSUPPORTED_SCHEMA`

### 0.2 Apply/Ack Contract (Skeleton)

- [ ] Create apply payload and ack DTOs:
  - files:
    - `lib/features/sync/actor/protocol/sync_apply_batch.dart`
    - `lib/features/sync/actor/protocol/sync_apply_ack.dart`
  - fields:
    - `applySeq`, `batchId`, `operations`, `proposedMarker`, `opId`
- [ ] Implement UI-side dedupe helper by `opId` (in-memory first; durable hook later):
  - file:
    - `lib/features/sync/actor/host/sync_apply_dedupe.dart`
- acceptance:
  - replaying same `applySeq` causes no duplicate side effects in tests

### 0.3 Actor Core (No Matrix Yet)

- [ ] Add actor isolate entrypoint and mailbox loop:
  - files:
    - `lib/features/sync/actor/sync_actor_main.dart`
    - `lib/features/sync/actor/sync_actor.dart`
  - classes:
    - `SyncActor`
    - `SyncActorCommandRouter`
- [ ] Implement baseline commands:
  - `ping`, `getHealth`, `init`, `stop`
- [ ] Implement command priority queues and cancellable background job token.
- acceptance:
  - control command preemption tests pass (`stop` responds while low-priority job active)

### 0.4 UI Host Adapter

- [ ] Add actor host and supervisor:
  - files:
    - `lib/features/sync/actor/host/sync_actor_host.dart`
    - `lib/features/sync/actor/host/sync_actor_supervisor.dart`
  - responsibilities:
    - spawn/terminate isolate
    - request registry by `requestId`
    - event fan-out stream
    - restart policy with epoch increment
- [ ] Add host provider:
  - file:
    - `lib/features/sync/state/sync_actor_host_provider.dart`
- acceptance:
  - request timeout + orphan cleanup tests pass
  - restart increments `actorInstanceId` and re-emits `ready`

### 0.5 Feature Flag + Wiring Point

- [ ] Add config toggle:
  - file:
    - `lib/features/sync/config/flags.dart`
  - key:
    - `SYNC_USE_ISOLATE_ACTOR`
- [ ] Wire branch in DI/bootstrap:
  - primary candidate files:
    - `lib/get_it.dart`
    - `lib/main.dart`
- [ ] Keep legacy non-actor path intact and default.
- acceptance:
  - app starts with flag off (current behavior unchanged)
  - app starts with flag on (actor host initialized)

### 0.6 Compatibility Layer (No Behavior Change)

- [ ] Add thin facade so existing state/controllers can call either backend:
  - files:
    - `lib/features/sync/actor/sync_runtime_adapter.dart`
    - `lib/features/sync/actor/sync_runtime_interface.dart`
- [ ] Map existing calls used by:
  - `lib/features/sync/state/matrix_login_controller.dart`
  - `lib/features/sync/state/matrix_room_provider.dart`
  - `lib/features/sync/state/matrix_stats_provider.dart`
- acceptance:
  - compile-time parity for existing call sites without UI rewrites

### 0.7 Observability Baseline

- [ ] Add actor metrics + structured logs:
  - file:
    - `lib/features/sync/actor/sync_actor_metrics.dart`
  - metrics:
    - queue depth, command latency, restart count, apply replay count
- [ ] Emit `requestId`, `actorInstanceId` in logs/events.
- acceptance:
  - metrics surfaced through existing diagnostics UI path or debug dump

### 0.8 Test Matrix for Phase 0

- [ ] Unit tests:
  - `test/features/sync/actor/protocol/sync_actor_protocol_test.dart`
  - `test/features/sync/actor/sync_actor_router_test.dart`
  - `test/features/sync/actor/sync_actor_qos_test.dart`
  - `test/features/sync/actor/sync_actor_host_test.dart`
- [ ] Integration smoke (no Matrix behavior yet):
  - spawn actor -> ping -> getHealth -> stop
- acceptance:
  - analyzer zero warnings/infos
  - all Phase 0 tests green

### 0.9 Exit Criteria for Phase 0

- [ ] Protocol frozen at `schemaVersion=1`
- [ ] Host/supervisor stable under restart tests
- [ ] Feature-flag path compilable and off by default
- [ ] Apply/Ack skeleton and replay-idempotency tests in place
- [ ] Observability fields present in actor events/logs
