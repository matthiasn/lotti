---
type: Feature Module
title: Sync
description: Single-user multi-device replication over end-to-end encrypted Matrix, with a durable outbox, an ordered inbound queue, and peer backfill for gaps.
resource: ../../../lib/features/sync
tags: [sync, matrix, replication, outbox, queue]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T23:00:00Z }
stale_after: 2026-11-02
sources:
  - id: sync-src
    resource: ../../../lib/features/sync
    title: Sync feature source
    last_modified: 2026-07-26
  - id: get-it
    resource: ../../../lib/get_it.dart
    title: Default bootstrap wiring
    last_modified: 2026-07-25
  - id: tuning
    resource: ../../../lib/features/sync/tuning.dart
    title: SyncTuning constants
    last_modified: 2026-05-30
  - id: current-architecture
    resource: ../../../docs/architecture/sync_current_architecture.md
    title: Failure history, log-backed investigations, tuning context
    last_modified: 2026-07-26
---

Sync replicates **one user's data across that user's own devices** over Matrix.
It is not a collaboration layer and not a raw event forwarder. It persists
outbound work, replays inbound history in order, tracks `(hostId, counter)`
coverage, and asks peers for counters it never received.

# What it owns

1. Outbound queueing, retries, backoff and send nudges.
2. Matrix session and room lifecycle.
3. Inbound ingestion — a live `timelineEvents` stream plus a `/messages` bridge
   for catch-up.
4. Applying sync payloads into local stores.
5. Sequence-log tracking for sequence-aware payloads.
6. Backfill request and response handling.
7. Provisioning, maintenance, verification and diagnostics UI.
8. The sync-node directory and auto-trigger of local AI inference on synced
   audio.

# Runtime shape

```mermaid
flowchart LR
  Local["Local repositories and services"] --> Outbox["OutboxService"]
  Outbox --> Sender["MatrixService.sendMatrixMsg()"]
  Sender --> Room["Encrypted Matrix room"]

  Room --> QueueCoord["QueuePipelineCoordinator"]
  QueueCoord --> Bridge["BridgeCoordinator (anchored catch-up via /context + /messages)"]
  QueueCoord --> Queue["InboundQueue (Drift-backed)"]
  Bridge --> Queue
  Queue --> Worker["InboundWorker (per-room drain, one entry per batch)"]
  Worker --> Apply["QueueApplyAdapter → SyncEventProcessor"]
  Apply --> Stores["JournalDb / AgentRepository / SettingsDb"]
  Apply --> Sequence["SyncSequenceLogService"]

  Sequence --> BackfillReq["BackfillRequestService"]
  Room --> BackfillResp["BackfillResponseHandler"]
  BackfillReq --> Outbox
  BackfillResp --> Outbox
```

The default bootstrap in `lib/get_it.dart` wires `MatrixService`,
`OutboxService`, `SyncEventProcessor`, `SyncSequenceLogService`,
`BackfillRequestService` and `BackfillResponseHandler`. That is the path these
concepts describe. Construction order matters and is documented in
[bootstrap and dependency injection](../../architecture/bootstrap-and-di.md).

# Code map

| Area | Role |
|------|------|
| `outbox/` | Persist pending payloads in `sync_db`, merge superseded work, enrich sequence metadata, drive send retries |
| `matrix/` | Session management, room discovery and persistence, message sending, read markers, verification, lifecycle. `MatrixPayloadSender` owns wire encoding (gzip, manifest, VC reconcile, size cap); `MatrixMessageSender` delegates to it |
| `gateway/` | `MatrixSyncGateway` interface and the `MatrixSdkGateway` implementation wrapping the Matrix SDK `Client` |
| `matrix/pipeline/` | Attachment ingestion and index, metrics aggregation, the `sync.limited` diagnostic listener |
| `queue/` | Persistent inbound queue, per-room worker, `onSync` catch-up bridge, pending-decryption holding pen |
| `sequence/` | Record `(hostId, counter)` coverage, detect gaps, track lifecycle states |
| `backfill/` | Send missing-counter requests; answer peer requests with resend, deleted, unresolvable or covering-payload hints |
| `state/`, `ui/` | Riverpod controllers and the settings, stats, diagnostics, provisioning and maintenance screens |
| `actor/` | Isolate-based sync implementation — present and tested, **not** wired by the default bootstrap |
| `services/`, `repository/` | Node capability probe, profile broadcaster, node-profile persistence, maintenance repository, synced-audio inference listener and dispatcher |

# Device management

All of a user's devices are sessions on **one Matrix account**; verification
state is per-install local trust (there is no cross-signing). The client is
constructed with `ShareKeysWith.directlyVerifiedOnly` (ADR 0045,
`matrix/client.dart`): a device this session has not SAS-verified receives
**no megolm keys** and cannot read new entries, while every verified device
keeps syncing. Sends are never halted for unverified devices — the sender
only logs the exclusion (`matrix/matrix_message_sender.dart`). A dead
session — an uninstalled app that never logged out — therefore costs
nothing beyond roster noise, and device management exists to explain and
clean it up:

- **Two account models.** The current pairing flow shares **one Matrix
  account** across all devices. Rooms paired under the **legacy model run one
  Matrix user per device**; direct SAS verification works cross-user, so key
  sharing honours it identically there. The unverified set
  (`MatrixSyncGateway.unverifiedDevices()`) deliberately spans every cached
  user, and the roster derives its warning state from that same full set: a
  foreign user's unverified device appears as a **verify-only** entry
  (`SyncDeviceInfo.ownAccount == false`) — it can be SAS-verified cross-user
  but never deleted from this account.
- **Inventory.** `MatrixServiceOps.getSyncDevices()` merges the homeserver's
  session inventory (`MatrixSyncGateway.getDevices()`, i.e. `GET /devices`:
  display name, last-seen) with the E2EE key cache (verification state) into
  `models/sync_device_info.dart`, after waiting (bounded) for an in-flight
  key load. Sessions that never published keys appear with `keys == null`:
  they cannot be verified and hold nothing to exclude — only removed. An
  **own-account unverified cached-keys entry missing from the server list**
  is retained as a **deletion-only** entry (`onServer == false` — a session
  the server no longer knows can never answer a verification): exclusion is
  computed from the key cache, not `GET /devices`, so dropping it would
  clear the warning while the exclusion persists. Display order: excluded
  devices first, then the current device, then recency.

  ```mermaid
  stateDiagram-v2
    [*] --> Excluded: unverified, receives no megolm keys, cannot read new entries
    Excluded --> Verifying: user starts SAS verification (own on-server or legacy foreign device)
    Verifying --> Excluded: cancelled or times out
    Verifying --> Recovering: emoji ceremony completes
    Excluded --> Deleting: user confirms removal (own-account sessions only)
    Deleting --> Excluded: UIA rejected (e.g. stale password)
    Deleting --> Recovering: homeserver accepts the delete
    Recovering --> Trusted: keys refreshed, lifecycle reconciled, rescan
    Recovering --> ConvergesLater: refresh fails or exceeds deleteDeviceRecoveryTimeout
    ConvergesLater --> Trusted: a later sync prunes the cached keys
    Trusted --> [*]
  ```
- **Deletion recovery sequence.** `MatrixServiceOps.deleteDeviceById()` runs,
  in order: cancel any in-flight emoji verification against the device (a
  dead peer can never answer), delete the session on the homeserver
  (UIA-gated with the stored account password), then a **best-effort,
  bounded** recovery — refresh cached device keys, reconcile the lifecycle,
  trigger a catch-up rescan — shared with post-verification recovery
  (`refreshDeviceKeysAndResumeSync`). Recovery failures are logged and
  swallowed, and the whole recovery is capped by
  `SyncTuning.deleteDeviceRecoveryTimeout`: once the homeserver accepted the
  delete, a network drop must not hang the caller; the cache converges on a
  later sync.
- **Guards.** The current session can never delete itself (use logout), and
  the `DeviceKeys`-based wrapper refuses devices of another user. Deletion is
  impossible without a stored password (SSO/token UIA is not implemented).
- **UI.** `ui/widgets/matrix/sync_devices_list.dart` renders the inventory on
  the provisioned-status page with a warning banner while any unverified
  device is excluded from key sharing; `ui/widgets/matrix/device_card.dart` flips its action
  hierarchy for stale unverified devices — removal becomes the labeled
  primary action, verification is demoted — because for a device silent past
  `syncDeviceStaleThreshold` removal is what resumes sync.

# Concepts

* [Message model](message-model.md) - what travels on the wire and which payloads are sequence-tracked.
* [Vector clocks and conflicts](vector-clocks-and-conflicts.md) - causal ordering, supersession, and what happens when two devices diverge.
* [Send path](send-path.md) - outbox staging, dequeue-time bundling, retries.
* [Receive path](receive-path.md) - the inbound queue pipeline, catch-up bridge, and marker advancement.
* [Sequence log and backfill](sequence-and-backfill.md) - causal accounting and gap repair.
* [Node profiles and auto-trigger](node-profiles-and-auto-trigger.md) - capability advertisement and local-only inference on synced audio.

# The isolate actor path

`actor/` holds a separate isolate-based implementation —
`SyncActorCommandHandler`, `SyncActorHost`, an actor-side `OutboundQueue` —
with its own lifecycle:

```mermaid
stateDiagram-v2
  [*] --> Uninitialized
  Uninitialized --> Initializing: init
  Initializing --> Syncing: init succeeds (enables backgroundSync, starts sync stream)
  Initializing --> Uninitialized: init fails (resources cleaned up)
  Syncing --> Idle: stopSync
  Idle --> Syncing: startSync
  Idle --> Stopping: stop
  Syncing --> Stopping: stop
  Stopping --> Disposed: cleanup complete
```

It is documented because it exists and is tested, but nothing in the default
bootstrap reaches it. Do not assume a change to the actor path affects shipping
behaviour.

# Standing constraints

The correctness of the whole feature rests on a few sharp assumptions:

- Sender-side `coveredVectorClocks` enrichment must stay correct, or offline
  convergence stops being sound.
- File-backed payload replay depends on attachment dedupe and ordering in
  `matrix/pipeline/attachment_*`.
- Backfill correctness depends on verified `(hostId, counter) → payloadId`
  mappings, never on "some later vector clock exists".

# Who feeds it

| Producer | Enqueues |
|----------|----------|
| `journal` repositories and `PersistenceLogic` | journal entities and entry links |
| `agents/sync/agent_sync_service.dart` | agent entities and links |
| `ai` repositories | AI config updates and deletes |
| `SavedTaskFiltersRepository` | `savedTaskFilter` / `savedTaskFilterDelete` per item |
| `PersistenceLogic.setConfigFlag(...)` | `configFlag` — only on explicit user change |
| Theming | `themingSelection` |
| `ai_consumption` | `consumptionEvent` |

Startup flag seeding deliberately uses `JournalDb.insertFlagIfNotExists(...)`
and does **not** broadcast, so a device only pushes a flag state when the user
actually changes that setting.

Related: [persistence](../../architecture/persistence.md) for `sync.sqlite`,
[security and privacy](../../architecture/security-and-privacy.md) for the
encryption story.
