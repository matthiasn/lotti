# Actor-Based Matrix Sync Isolate Plan

## Summary

- Move Matrix sync execution off the UI isolate into a dedicated worker isolate.
- Use an actor model: single mailbox, serialized command handling, explicit event stream back to UI.
- Keep Matrix SDK objects isolate-local and exchange only serializable DTOs.
- Move both inbound and outbound sync orchestration into the actor path.
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
- Additional isolate-integration learnings from `integration_test/matrix_actor_isolate_network_test.dart`:
  - use an explicit actor readiness handshake (`readyPort` -> `commandPort`) before first command dispatch
  - keep command protocol map-based with per-request `replyTo` ports for strict request/response correlation
  - poll/sync in bounded loops with explicit timeouts; never assume one sync tick is sufficient
  - accept incoming verification only from valid early steps (`request`/`ready`/`start`)
  - require SAS emoji convergence before `acceptSas`, then allow incoming-side fallback acceptance if needed
  - discover peer device keys from either side (user1->user2 or user2->user1) to avoid initiator bias
  - isolate-local SDK DB roots per actor instance prevent cross-run state contamination

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
- Actor owns `SyncDatabase` exclusively (outbox, sequence log, inbound apply journal).
- UI owns presentation state plus durable app DBs (`JournalDb`, `SettingsDb`).
- Cross-isolate command/event payloads must be plain JSON-like maps / DTO classes with primitive fields and lists/maps.
- Never pass SDK objects, streams, controllers, DB handles, or closures across isolates.
- **Explicit v1 ownership decision (feasibility):**
  - actor owns network/crypto/sync decisioning, outbound orchestration, and `SyncDatabase` writes.
  - UI isolate remains owner of `JournalDb` / `SettingsDb` writes for this project phase.
  - actor MUST NOT advance durable sync markers unless UI acks successful apply into app DBs.

### Actor Mailbox Contract (v1)

- Envelope fields:
  - `schemaVersion` (int, starts at `1`)
  - `requestId` (string, unique per command)
  - `type` (string command type)
  - `payload` (map)
  - `replyTo` (`SendPort`) for direct ack/result
- Transport layering rule:
  - `SyncActorEnvelope` is transport-only and may carry transferable primitives (`SendPort`).
  - command/event DTO payloads remain JSON-only and are independently encoded/validated.
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
- Preemption is cooperative only:
  - each long-running command must define cancellation checkpoints and a command timeout/deadline
  - if blocked in non-cancellable SDK/network await, control commands are queued and executed at the next checkpoint
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
- Persist minimal checkpoint data in actor-owned durable store (`SyncDatabase`) and host config:
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
  - highest actor-journal-applied `applySeq` and pending batch ids (for reconciliation after actor restart)
- SAS restart policy (fail-closed):
  - if actor restarts during active SAS, mark verification as canceled and require re-negotiation
  - never assume SAS session can be resumed from app-level metadata alone

## Data Boundaries and Persistence

- Keep heavy sync processing in actor.
- UI isolate applies only coarse-grained updates from actor events.
- DB boundary for this plan:
  - actor writes only `SyncDatabase`
  - UI writes only `JournalDb` / `SettingsDb`
  - actor emits validated “apply” DTOs; UI applies via existing DB services and replies with ack/nack

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
- Nack policy:
  - UI MUST return explicit `applyNack` on apply failures (no silent failure/timeout-as-error path)
  - actor treats timeout as transport failure only; semantic apply failures are represented by `applyNack`
- Idempotency:
  - every operation includes stable `opId`
  - UI deduplicates by `opId` using durable app-DB storage (not `SyncDatabase`) for restart-safe replay handling

### Durable Apply Journal (Required for Retryable DB Effects)

- Actor persists every inbound `applyBatch` to `SyncDatabase` before requesting apply in app DBs.
- Proposed storage:
  - `inbound_apply_batches` table:
    - `applySeq` (unique, monotonic)
    - `batchId` (unique)
    - `operationsJson` (serialized deterministic operations payload)
    - `proposedMarkerJson` (nullable)
    - `status` (`pending`, `applying`, `applied`, `failed`)
    - `attemptCount`, `lastError`, `createdAt`, `updatedAt`, `lastAttemptAt`
  - `inbound_apply_ops` (or equivalent durable dedupe index):
    - `opId` (unique)
    - `applySeq`
    - optional per-op status/metadata for diagnostics
  - main-isolate app DB dedupe table (`JournalDb`):
    - `sync_apply_op_dedupe`:
      - `opId` (primary key)
      - `applySeq`
      - `appliedAt`
    - written in the same transaction as app DB effects
- Apply execution flow:
  1. actor persists batch as `pending` in `SyncDatabase`
  2. actor emits `applyBatch` to UI (with `applySeq`, `batchId`, `operations`, `proposedMarker`)
  3. UI applies operations transactionally to `JournalDb` / `SettingsDb`
  4. UI replies `applyAck` or `applyNack` (including error metadata on nack)
  5. actor marks `applied`/`failed` in `SyncDatabase`; marker advancement only after `applyAck`
- Restart/recovery flow:
  - on actor startup, load unapplied batches (`pending|failed|applying`) in `applySeq` order
  - actor re-emits batches; UI replays effects idempotently using `opId` dedupe
  - actor advances sync markers only once a batch is durably `applied` in actor-owned journal
- Actor/UI contract addition:
  - actor may resend same `applySeq`; UI must treat replays as idempotent and return consistent ack outcome
  - actor short-circuits resend if its journal already marks `applySeq` as `applied`
  - actor must not advance durable sync marker beyond the highest actor-journal-applied `applySeq`
- Dedupe retention policy:
  - main-isolate dedupe rows are pruned by checkpoint watermark plus a 30-day safety window
  - rows newer than 30 days are retained regardless of watermark to protect delayed/replayed batches

### Two-DB Saga State Machine (Explicit Invariants)

| State (`inbound_apply_batches.status`) | Owner | Meaning | Allowed Next States |
| --- | --- | --- | --- |
| `pending` | actor | batch persisted in `SyncDatabase`, not yet in-flight to UI apply | `applying`, `failed` |
| `applying` | actor/UI | batch dispatched to UI for `JournalDb`/`SettingsDb` transaction | `applied`, `failed`, `pending` (timeout rollback) |
| `failed` | actor | last apply attempt failed or timed out, retryable unless classified fatal | `pending`, `applying` |
| `applied` | actor | UI confirmed durable apply into app DBs; marker can advance | terminal |

- Saga invariants:
  - `applySeq` ordering invariant:
    - actor MUST dispatch and finalize batches in ascending `applySeq`; no out-of-order marker advancement.
  - Ack safety invariant:
    - actor records `applied` only after receiving `applyAck` for the same `applySeq` and `batchId`.
  - Idempotency invariant:
    - replay of an already-applied `applySeq` MUST be a no-op in app DB effects.
  - Single-writer invariant:
    - only actor mutates `inbound_apply_batches` / `inbound_apply_ops`; UI reports outcome via ack/nack only.
  - Crash-recovery invariant:
    - actor restart must recover from `pending|applying|failed` and eventually converge to `applied` or stable `failed` with diagnostics.

### Verification Trust Gate (Fail-Closed)

- Actor is source of truth for per-device verification trust state.
- Outbound send policy:
  - verified trust: send normally
  - unknown/unverified/regressed trust: block send or queue in outbox with explicit reason until trust is restored
- Never silently downgrade to unverified send behavior.

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
- Move outbound orchestration into actor (`flushOutbox`, retry scheduling, connectivity/login nudges).
- Move `SyncDatabase` access behind actor-owned APIs; UI stops direct `SyncDatabase` mutations in actor mode.
- Keep current sync service path as fallback.
- Validate startup/shutdown and reconnect semantics.
- Add supervisor restart flow with checkpoint restore and epoch increment.

### Phase 2: Room + Basic Send/Receive

- Actor handles room create/join/invite/send text.
- Mirror current behavior for sync room discovery and state updates.
- Ensure outbox ack semantics remain monotonic and idempotent.
- Include SAS verification commands in actor path for production trust parity.
- Use Apply/Ack for all DB effects while UI still owns durable writes.

### Phase 3: Sync Pipeline Ownership

- Move force-rescan/retry/catch-up orchestration into actor.
- Preserve ordering and sent-event suppression guarantees.
- Integrate connectivity signal handling in actor.
- Keep `JournalDb` / `SettingsDb` apply on UI isolate with Apply/Ack barrier for this project phase.
- Any migration of app DB writes into actor is explicitly out-of-scope for this plan and requires a separate design doc.

### Phase 4: Verification Hardening + UX Parity

- Harden verification recovery/fail-closed behavior under crash/restart paths.
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
- durable apply-journal state transitions and restart replay ordering
- command priority/preemption (control over background)

### Integration Tests

- docker-backed isolate test (existing baseline) extended to assert:
  - lifecycle commands
  - SDK room flow
  - SDK SAS flow
  - send/receive parity
  - actor startup handshake semantics (ready before command send)
  - two-sided device-discovery and SAS step-guard behavior
  - actor mode enforces single outbound owner (no parallel legacy outbox sender activity)
- failure injection:
  - kill actor mid-sync and verify restart/recovery
  - simulated network degradation/reconnect
  - replay same `applySeq` after forced restart and verify no duplicate DB effects
  - kill actor during SAS and verify re-negotiation is required before trusted send resumes
  - crash host after journal persist but before DB commit; verify replay resumes and applies once

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
  - baseline: current non-actor path over at least 10 scripted runs (same docker setup)
  - actor path: same run count and workload seed
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
- **Risk:** trust regression after restart allows unverified outbound sends.
  - **Mitigation:** fail-closed trust gate; require re-verification on unknown state.
- **Risk:** rollout instability.
  - **Mitigation:** feature-flagged rollout with quick fallback.

## Concrete First Vertical Slice

- Implement actor commands:
  - `init`, `login`, `start`, `createRoom`, `joinRoom`, `sendSyncMessage`,
    `startSas`, `acceptVerification`, `acceptSas`, `cancelVerification`, `getHealth`, `stop`
- Wire UI host adapter for request/response and events.
- Add one end-to-end integration test path:
  - spawn actor -> login two users -> room setup -> SAS -> send/receive -> stop.
- Include Apply/Ack plumbing in this slice (even if batch contains one operation) to avoid rework.
- Include trust gate behavior in this slice:
  - unverified/unknown trust blocks or queues send
  - trusted send resumes only after SAS success

## Rollout Checklist

- [ ] DTO contract finalized and documented
- [ ] actor host + supervisor implemented
- [ ] feature flag integrated in sync entrypoint
- [ ] actor mode enforces single-owner rules (`SyncDatabase` actor-only, app DBs UI-only)
- [ ] phase-1 integration tests green locally and CI
- [ ] fail-closed trust-gate behavior validated in restart scenarios
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
  - transport envelope tests cover `SendPort` transferability separately from JSON payload tests

### 0.2 Apply/Ack Contract (Skeleton)

- [ ] Create apply payload and ack DTOs:
  - files:
    - `lib/features/sync/actor/protocol/sync_apply_batch.dart`
    - `lib/features/sync/actor/protocol/sync_apply_ack.dart`
  - fields:
    - `applySeq`, `batchId`, `operations`, `proposedMarker`, `opId`
- [ ] Add durable apply-journal persistence in `SyncDatabase`:
  - add table(s) for inbound apply batches and op dedupe index
  - wire repository/service for journal write/replay/mark-applied
- [ ] Implement main-isolate dedupe helper by `opId` with durable app-DB persistence for restart-safe replay:
  - file:
    - `lib/features/sync/actor/host/sync_apply_dedupe.dart`
- acceptance:
  - replaying same `applySeq` causes no duplicate side effects in tests
  - crash/restart between `pending` and `applied` replays correctly and eventually acks

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
- [ ] Add per-command timeout/deadline policy + cooperative cancellation checkpoints.
- acceptance:
  - control command preemption tests pass (`stop` responds while low-priority job active)
  - non-cancellable SDK/network waits are bounded by timeout policies

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
- [ ] In actor mode, disable legacy UI-owned outbox runner/schedulers to prevent dual-send ownership.
- [ ] Keep legacy non-actor path intact and default.
- acceptance:
  - app starts with flag off (current behavior unchanged)
  - app starts with flag on (actor host initialized, no duplicate outbox runners)

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
