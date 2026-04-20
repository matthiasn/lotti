# Sync Feature

`sync` replicates one user's data across that user's devices over Matrix.

This is single-user, multi-device sync. It is not a collaboration layer, and
it is not a raw event forwarder. The feature persists outbound work, replays
inbound Matrix history in order, tracks `(hostId, counter)` coverage, and asks
peers for missing counters when gaps appear.

## Default Runtime Wiring

The default app bootstrap in `lib/get_it.dart` wires the sync feature through
these services:

- `MatrixService`
- `OutboxService`
- `SyncEventProcessor`
- `SyncSequenceLogService`
- `BackfillRequestService`
- `BackfillResponseHandler`

That is the runtime path this README describes.

```mermaid
flowchart LR
  Local["Local repositories and services"] --> Outbox["OutboxService"]
  Outbox --> Sender["MatrixService.sendMatrixMsg()"]
  Sender --> Room["Encrypted Matrix room"]

  Room --> Consumer["MatrixStreamConsumer"]
  Consumer --> Processor["SyncEventProcessor"]
  Processor --> Stores["JournalDb / AgentRepository / SettingsDb"]
  Processor --> Sequence["SyncSequenceLogService"]

  Sequence --> BackfillReq["BackfillRequestService"]
  Room --> BackfillResp["BackfillResponseHandler"]
  BackfillReq --> Outbox
  BackfillResp --> Outbox
```

## What This Feature Owns

At runtime, the sync feature owns:

1. outbound queueing, retries, backoff, and send nudges
2. Matrix session and room lifecycle
3. catch-up and live scanning of room history
4. applying sync payloads into local stores
5. sequence-log tracking for sequence-aware payloads
6. backfill request and response handling
7. provisioning, maintenance, verification, and diagnostics UI/state

## Code Map

| Area | Role |
| --- | --- |
| `outbox/` | Persist pending payloads in `sync_db`, merge superseded work, enrich sequence metadata, and drive send retries |
| `matrix/` | Session management, room discovery/persistence, message sending, read markers, verification, and high-level lifecycle |
| `matrix/pipeline/` | Catch-up, live scan, signal coalescing, attachment ingestion, retry, and ordered processing |
| `sequence/` | Record `(hostId, counter)` coverage, detect gaps, and track missing/requested/backfilled/deleted/unresolvable states |
| `backfill/` | Send missing-counter requests and answer peer requests with resend, deleted, unresolvable, or covering-payload hints |
| `state/` and `ui/` | Riverpod controllers and sync-facing settings, stats, diagnostics, provisioning, and maintenance screens |
| `actor/` | Separate isolate-based sync implementation; present in the repo, but not wired by the default bootstrap path above |

## Message Model

Transport payloads are `SyncMessage` values.

Current message families in `model/sync_message.dart`:

- `journalEntity`
- `entityDefinition`
- `entryLink`
- `aiConfig`
- `aiConfigDelete`
- `themingSelection`
- `backfillRequest`
- `backfillResponse`
- `agentEntity`
- `agentLink`

Sequence-tracked payloads are narrower:

- `journalEntity`
- `entryLink`
- `agentEntity`
- `agentLink`

Those payloads can carry:

- `originatingHostId`
- `coveredVectorClocks`

`coveredVectorClocks` are not optional decoration. `SyncSequenceLogService`
pre-marks covered counters before normal gap detection so a newer payload can
prove that older counters were semantically superseded instead of simply lost.

## Vector Clock Mechanism

`VectorClock` in this feature is a `Map<String, int>` from host id to that
host's monotonic counter.

For locally written payloads, the map answers:

> "When this payload version was written, what counters were already present in
> the version it was derived from, plus the current host's next counter?"

`VectorClockService.getNextVectorClock(previous: ...)` keeps the previous clock
entries and advances only the current host's counter. For a brand-new local
payload with no previous clock, the map contains only the current host's
counter.

That is different from `originatingHostId`:

- `originatingHostId` identifies the host that created or modified the current
  payload version
- `vectorClock` carries the causal snapshot that payload was created from, and
  it can mention other hosts too

### Compare Rules

`vector_clock.dart` implements four comparison outcomes for
`VectorClock.compare(a, b)`:

- `equal`: both clocks contain the same counters
- `a_gt_b`: `a` dominates `b`; every host counter in `a` is greater than or
  equal to `b`, and at least one is greater
- `b_gt_a`: the same relation in the other direction
- `concurrent`: neither clock dominates the other

Important details from the implementation:

- missing host entries compare as `0`
- negative counters are invalid and throw `VclockException`
- `VectorClock.merge(a, b)` takes the per-host maximum

### Compare Examples

| A | B | `compare(A, B)` | Why |
| --- | --- | --- | --- |
| `{A: 5}` | `{A: 5}` | `equal` | Same counter for every host |
| `{A: 7}` | `{A: 5}` | `a_gt_b` | `A` moved forward |
| `{A: 5}` | `{A: 7}` | `b_gt_a` | Same case in reverse |
| `{A: 1, B: 1}` | `{A: 1}` | `a_gt_b` | Missing hosts count as `0`, so `B:1 > 0` |
| `{A: 3, B: 1}` | `{A: 1, B: 3}` | `concurrent` | `A` is ahead on one host and behind on another |

Merge example:

```text
merge({A:5, B:1}, {A:3, B:4, C:2}) == {A:5, B:4, C:2}
```

### How Sync Uses Vector Clocks

The feature uses vector clocks in three separate ways.

1. Conflict and freshness checks

   `SyncEventProcessor` and `MatrixMessageSender` compare clocks to decide
   whether the payload on disk, in memory, or already stored locally is older,
   newer, equal, or concurrent.

2. Gap detection

   `SyncSequenceLogService.recordReceivedEntry()` iterates every host in the
   incoming clock except the receiver's own host, not only the originator.
   It only turns those observations into gaps for the originator and for hosts
   the receiver has already seen online. That means a payload written by Alice
   can still reveal that Bob's counter `7` is missing if the clock carries
   Bob at `8` and the receiver already has Bob in host activity.

3. Supersession tracking

   `coveredVectorClocks` carries the counters that a newer payload
   semantically replaces. The receiver processes those covered clocks before
   normal gap detection.

### Example: Rapid Updates On One Host

Suppose host `A` updates the same journal entry several times before the outbox
drains:

1. first version: `{A:5}`
2. second version: `{A:6}`
3. third version: `{A:7}`

The outbox merge path can collapse those into one pending message with:

```text
vectorClock = {A:7}
coveredVectorClocks = [{A:5}, {A:6}, {A:7}]
```

On receive, `SyncSequenceLogService` filters out the covered clock equal to the
current payload clock before pre-marking. The practical result is:

- counters `5` and `6` are marked as covered/received first
- counter `7` is recorded as the payload being applied now
- the receiver does not leave `5` and `6` behind as permanent "missing" rows

That behavior is covered by the outbox and sequence-log tests.

### Example: Multi-Host Clock, Single Originator

Suppose the previous stored version already had:

```text
{Alice:9, Bob:8}
```

That can happen because Bob edited earlier, synced that version, and Alice
later edited the same payload locally.

When Alice writes the next local version, `getNextVectorClock(previous: ...)`
preserves Bob's counter and advances Alice's own counter, producing:

```text
originatingHostId = Alice
vectorClock = {Alice:10, Bob:8}
```

This means:

- the current payload version was produced on Alice
- Bob's `8` was inherited causal history from the previous version, not a
  counter Alice invented locally
- by the time this Alice-authored version was written, it still carried the
  fact that Bob's counter `8` was already part of that payload's history

If another device has already seen Bob online and its local sequence log says
Bob only reached `6`, then receiving Alice's payload can legitimately create a
gap for Bob's counter `7`. If Bob has never been seen online by that receiver,
the code still records Bob's counter from the vector clock but skips gap
detection for Bob.

That is why gap detection walks all hosts in the vector clock, not only the
originator.

### Example: Why A Later Clock Is Not Enough

Later clock alone is insufficient:

```text
missing counter: {A:11}
new payload clock: {A:20}
```

`{A:20}` proves that the sender knows about later work. It does not prove that
counter `11` was semantically superseded by the payload currently being
received.

That proof has to come from explicit covered clocks. A realistic message may
look like:

```text
vectorClock = {A:20}
coveredVectorClocks = [{A:10}, {A:12}, {A:15}, {A:20}]
```

The receiver will pre-mark the covered counters `10`, `12`, and `15`, then
handle `20` as the current payload. Any non-covered counters between them can
still remain missing and can still trigger backfill.

In this feature, vector clocks describe causal knowledge.
`coveredVectorClocks` describes semantic replacement.

## Send Path

`OutboxService` stages local work in `sync_db`, merges superseded work when it
can, enriches sequence-aware payloads with covered clocks, and nudges a
`ClientRunner`-driven `OutboxProcessor`.

`OutboxProcessor` then:

1. fetches the pending head of the queue
2. refreshes it before send so merged metadata is not stale
3. sends it through `MatrixService`
4. marks it sent, retryable, or errored in `sync_db`

The send path is also nudged by:

- connectivity regain
- Matrix login completion
- outbox row-count changes
- a watchdog for pending-but-idle queues

Sending is gated by `UserActivityGate`, so the queue waits for idle time before
running a send pass.

```mermaid
sequenceDiagram
  participant Local as "Local change"
  participant Outbox as "OutboxService"
  participant Repo as "OutboxRepository"
  participant Proc as "OutboxProcessor"
  participant Matrix as "MatrixService"

  Local->>Outbox: enqueueMessage(syncMessage)
  Outbox->>Outbox: merge/enrich covered clocks
  Outbox->>Repo: persist pending row
  Outbox->>Proc: nudge runner
  Proc->>Repo: fetchPending(head)
  Proc->>Repo: refreshItem(head)
  Proc->>Matrix: sendMatrixMsg(syncMessage)
  alt send succeeds
    Proc->>Repo: markSent()
  else send fails
    Proc->>Repo: markRetry() or markError()
  end
```

## Receive Path

`MatrixService` composes `SyncEngine`, `SyncRoomManager`,
`MatrixStreamConsumer`, and `SyncEventProcessor`.

The important runtime rules are:

- `MatrixStreamConsumer.initialize()` hydrates room state and restores the last
  processed marker
- `start()` runs catch-up before binding the live signal path
- client-stream and timeline callbacks act as scheduling signals, not as the
  payload-processing path
- marker advancement happens inside ordered batches, not per callback
- the per-event apply loop in `MatrixStreamProcessor._processOrderedInternal`
  runs inside a single `JournalDb.transaction`, so a slice of N events
  commits once and Drift emits one journal-table stream notification per
  slice instead of N. Per-event errors are still caught locally and
  converted to retry-tracker entries, so the transaction only rolls back
  when a commit itself fails.

`SyncEventProcessor` decodes `SyncMessage`, resolves file-backed payloads,
applies them to local stores, records sequence state, and delegates backfill
messages to `BackfillResponseHandler`.

Journal entities and agent payloads can be file-backed via `jsonPath`. Those
payloads are resolved through the attachment/index loader path before they are
applied, which is why attachment ordering and dedupe matter to sync behavior.

### Attachment Encoding

Attachment events may carry a `com.lotti.encoding` key in the Matrix event
content that declares an on-wire encoding applied by the sender. The only
value currently defined is `gzip`, which signals that the raw bytes returned
from `event.downloadAndDecryptAttachment()` are a gzip stream and must be
decompressed before the file is written to the local documents directory.
The `relativePath` in the event is still the logical target path, unchanged
by the encoding.

Receivers decode this header unconditionally, so the receive path is
forward-compatible with senders that later opt in. On the send side, gzip
compression is gated by the `use_compressed_json_attachments` config flag
(off by default) and only applies when the attachment's `relativePath` ends
in `.json`, since media files are already compressed and would not benefit.
When the flag is on, the uploaded file name gains a `.gz` suffix and the
event content includes the encoding header; otherwise bytes are sent
verbatim with no header and no suffix.

```mermaid
flowchart TD
  Event["Matrix event"] --> Decode["Decode SyncMessage"]
  Decode --> Resolve["Resolve inline or file-backed payload"]
  Resolve --> Apply["SyncEventProcessor applies to local stores"]
  Apply --> Sequence["SyncSequenceLogService.recordReceivedEntry(...)"]
  Sequence --> Gap{"Missing counters?"}
  Gap -->|no| Done["Continue ordered processing"]
  Gap -->|yes| Request["BackfillRequestService.nudge()"]
  Request --> Room["Encrypted Matrix room"]
  Room --> Response["BackfillResponseHandler"]
```

## Inbound Event Queue (Phase 2, feature-flagged)

An alternate receive path gated on the `USE_INBOUND_EVENT_QUEUE` settings
flag. When the flag is on, the legacy `MatrixStreamSignalBinder` does not
subscribe to `timelineEvents` (see `suppressLiveIngestion`) and the two
pipelines are mutually exclusive.

Components (all under `lib/features/sync/queue/`):

- **`InboundQueue`** — Drift-backed queue in `sync_db`
  (`inbound_event_queue` table + `queue_markers` per-room table). `event_id`
  UNIQUE is the sole cross-producer dedupe primitive; `lease_until` is a
  durable worker lease that survives crashes.
- **`InboundWorker`** — per-room drain loop. Wraps each batch in
  `SyncSequenceLogService.runWithDeferredMissingEntries` so per-slice gap
  detections coalesce into one `onMissingEntriesDetected` emission — the
  F1 concern from the design review. Honours `UserActivityGate`.
- **`BridgeCoordinator`** — subscribes to `Client.onSync` and, on any
  joined room's `timeline.limited == true`, walks `/messages` back to the
  stored marker via `CatchUpStrategy.collectEventsForCatchUp`, feeding
  the result to `enqueueBatch` with `producer=bridge`. Single-flight.
- **`PendingDecryptionPen`** — LRU holding pen for Megolm-encrypted events
  that arrive before their session key. The worker re-resolves them via
  `room.getEventById` on every drain iteration; only fully-decrypted
  events ever reach `raw_json` (F3).
- **`QueueApplyAdapter`** — bridges the worker to
  `SyncEventProcessor.prepare`/`apply`. Prepare runs outside the writer
  transaction, apply inside — preserving the P1 freeze fix (#2981).
- **`QueuePipelineCoordinator`** — owns the above plus the live producer
  subscription; exposed on `MatrixService.queueCoordinator`.
- **`QueueMarkerSeeder`** — one-shot migration copying the legacy
  `lastReadMatrixEventTs`/`Id` into `queue_markers` on first enable.
  Never overwrites an existing row.

### Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Stopped
    Stopped --> Starting: coordinator.start()
    Starting --> Running: marker seeded · stranded rows pruned · worker + bridge started
    Running --> Running: live event → pen? yes: hold / no: enqueueLive<br/>worker drains K≤20 / batch
    Running --> Draining: coordinator.stop(drainFirst: true)
    Draining --> Stopped: worker.drainToCompletion()
    Running --> Stopped: coordinator.stop(drainFirst: false)
```

### Worker batch drain (F1 coalescing preserved)

```mermaid
flowchart TD
    Tick["Worker tick"] --> Gate["activityGate.waitUntilIdle"]
    Gate --> Flush["Pen.flushInto(queue, room)"]
    Flush --> Peek["queue.peekBatchReady(maxBatch=20)"]
    Peek --> Empty{"batch empty?"}
    Empty -->|yes| Wait["wait for depthChanges or 5s tick"]
    Wait --> Tick
    Empty -->|no| Window["runWithDeferredMissingEntries →"]
    Window --> Apply["SyncEventProcessor.prepare + apply per entry"]
    Apply --> Outcome{"outcome"}
    Outcome -->|applied| Commit["queue.commitApplied<br/>(delete + marker advance if monotonic)"]
    Outcome -->|retriable/missingBase| Retry["scheduleRetry with backoff"]
    Outcome -->|decryptionPending| DecryptRetry["scheduleRetry (short backoff)"]
    Outcome -->|permanentSkip| Skip["markSkipped"]
    Commit --> NextEntry["next entry in batch"]
    Retry --> NextEntry
    DecryptRetry --> NextEntry
    Skip --> NextEntry
    NextEntry --> WindowClose{"batch drained?"}
    WindowClose -->|no| Apply
    WindowClose -->|yes| Emit["window closes → at most one<br/>onMissingEntriesDetected emission"]
    Emit --> Tick
```

### Marker advancement is monotonic (F2)

`commitApplied` reads the existing `queue_markers` row and only advances
`last_applied_ts` / `last_applied_event_id` when
`TimelineEventOrdering.isNewer` returns true — so an out-of-order apply
(live event at ts=100 applied first, then a bridge event at ts=60 from
the same burst) cannot regress the stored marker.

### UI (flag-gated on `backfill_settings_page.dart`)

- `QueueDepthCard` — subscribes to `InboundQueue.depthChanges`, shows
  total + per-producer breakdown + empty-state message.
- `FetchAllHistoryDialog` — drives
  `QueuePipelineCoordinator.collectHistory` with an in-dialog cancel
  button and page-by-page progress.

### Observability

Pipeline-tagged log lines let a log analyzer compare apply rates:

- Queue pipeline: `queue.commit pipeline=queue eventId=... originTs=... markerAdvanced=...`
- Legacy pipeline: `marker.local id=... ts=... pipeline=legacy`

The Phase-2 ±15% gate compares event/sec rates between the two.

## Sequence Log And Backfill

`SyncSequenceLogService` is the causal accounting layer. It records which
`(hostId, counter)` pairs are known locally and tracks transitions through
states such as:

- `missing`
- `requested`
- `received`
- `backfilled`
- `deleted`
- `unresolvable`

Important implementation details:

- gap detection runs for hosts that have been seen online, plus the current
  originating host
- sent entries from this device are recorded so peers can request them later
- later vector clocks do not automatically close gaps; explicit coverage still
  matters
- verified covering entries are used as hints when an exact payload is no
  longer the best answer

`BackfillRequestService` periodically sends bounded batches of missing
counters, supports manual full historical backfill, and can re-request entries
that were previously requested but never resolved.

`BackfillResponseHandler` can answer a request with one of four outcomes:

- exact payload resend
- `deleted`
- `unresolvable`
- a verified covering payload hint

Responses are rate-limited and cooled down per `(hostId, counter)` so repair
traffic does not turn into its own loop.

## Isolate Actor Path

`actor/` contains a separate isolate-based implementation:

- `SyncActorCommandHandler`
- `SyncActorHost`
- actor-side `OutboundQueue`

That code has a real lifecycle in `actor/sync_actor.dart`:

```mermaid
stateDiagram-v2
  [*] --> Uninitialized
  Uninitialized --> Initializing: init
  Initializing --> Idle: init succeeds
  Idle --> Syncing: startSync
  Syncing --> Idle: stopSync
  Idle --> Stopping: stop
  Syncing --> Stopping: stop
  Stopping --> Disposed: cleanup complete
```

The actor path is worth documenting because it is in the repo and tested, but
it is not the default bootstrap path described above.

## Current Constraints

The code still depends on a few sharp assumptions:

- sender-side `coveredVectorClocks` enrichment has to stay correct for offline
  convergence to stay sound
- file-backed payload replay depends on attachment dedupe and ordering in
  `matrix/pipeline/attachment_*`
- backfill correctness depends on verified `(hostId, counter) -> payloadId`
  mappings, not on "some later vector clock exists"
- the detailed performance and failure analysis lives in
  [current_architecture.md](./current_architecture.md), not in this overview

## Relationship To Other Features

- `journal` repositories and `PersistenceLogic` enqueue journal entities and
  links
- `agents/sync/agent_sync_service.dart` enqueues agent entities and links
- `ai` repositories enqueue AI config updates and deletes
- theming changes enqueue `themingSelection`
- sync-facing settings, verification, maintenance, and diagnostics UI live
  under `lib/features/sync/ui/` and `lib/features/sync/state/`

## Further Reading

- [current_architecture.md](./current_architecture.md)
- [docs/implementation_plans/2026-03-13_sender_offline_convergence.md](../../../docs/implementation_plans/2026-03-13_sender_offline_convergence.md)

Read this README first for the runtime shape. Read
[current_architecture.md](./current_architecture.md) when you need the recent
failure history, log-backed investigations, and tuning context.
