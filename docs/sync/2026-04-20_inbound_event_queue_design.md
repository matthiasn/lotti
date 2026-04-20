# Inbound Event Queue — Sync Architecture Redesign

**Date:** 2026-04-20
**Status:** Design proposal — pending diagnostic validation before implementation
**Related:**
- [2026-04-20 freeze + log-bloat audit](./2026-04-20_sync_freeze_and_log_bloat_audit.md)
- [current_architecture.md](../../lib/features/sync/current_architecture.md)

## 1. Motivation

Over the last six weeks, the sync pipeline has absorbed fixes for freezes
(PR #2981), log bloat (#2982), signal chatter (#2983), and most recently a
stuck-scan regression where a single hung attachment download silently
disabled live updates until force-restart (#2984). Each fix was correct
in isolation. The recurrence pattern is the problem.

The recurring cause is **structural, not local**. The receive pipeline
has three overlapping signal sources (client stream, live-timeline
callbacks, catch-up triggers), two convergent pipelines (live scan,
catch-up) that both feed `_processor.processOrdered`, and a matrix of
in-flight flags negotiating between them (`_scanInFlight`,
`_liveScanDeferred`, `_catchUpInFlight`, `_forceRescanCompleter`,
`_deferredCatchup`). Any one flag wedging drops event processing
silently. The classes of bug we keep paying for — stuck flags,
fragmented-timeline holes, catch-up/live-scan divergence, coalescing
heuristics that misfire — are all symptoms of that structural
over-negotiation.

This document proposes a replacement receive architecture:
**one durable inbound queue, one apply worker, two layers of
correctness**. The live stream, the `limited=true` bridge, the
cold-start bootstrap, and the peer-backfill response path all become
producers of the same queue. Completeness stays owned by the
`SyncSequenceLogService` + peer-backfill machinery, which the queue
model does not replace. The design narrows rather than eliminates the
load-bearing pieces.

## 2. Goals and non-goals

### 2.1 Goals

1. **Eliminate the class of bug where one producer silently stops
   feeding the pipeline** (stuck-scan, fragmented-timeline hole,
   signal-callback silently coalesced). All producers write to one
   durable queue; the queue's state is the sole source of truth for
   "what's waiting to apply".
2. **Make the completeness guarantee explicit and separable** from the
   ingestion plumbing. The queue does not decide whether sync is
   "caught up"; the sequence-log does.
3. **Reduce the number of coordination primitives.** Replace
   `_scanInFlight` / `_liveScanDeferred` / `_catchUpInFlight` /
   `_forceRescanCompleter` / `_deferredCatchup` with the queue's own
   empty/non-empty state and a single worker loop.
4. **Preserve today's completeness behaviour** for every scenario that
   already works:
   - Normal live delivery (healthy connection, both devices online).
   - Cold start with a stored marker (bridge call on startup).
   - Reconnect after a network blip.
   - Mid-session `limited=true` sync (server truncation).
   - Peer-backfill on missing counters.
   - User-initiated "fetch all history" from Settings.
5. **Preserve today's correctness invariants:** in-order apply per
   room, exactly-once apply per `(eventId)`, marker advancement only
   after successful apply, all existing vector-clock and gap-detection
   semantics.

### 2.2 Non-goals

1. **Not a change to how events are applied.** `SyncEventProcessor`'s
   prepare/apply split and `MatrixStreamProcessor`'s transaction scope
   stay as-is. The queue sits in front of them.
2. **Not a change to the completeness layer.**
   `SyncSequenceLogService`, vector clocks, `coveredVectorClocks`, and
   the backfill request/response protocol stay unchanged. The queue is
   plumbing.
3. **Not a replacement for peer-assisted backfill.** If the Matrix
   server has purged events (retention policy) and no device still
   holds them, the queue cannot recover them. That is the irreducible
   case where the only source is another device's local storage, and
   `BackfillRequestService` + `BackfillResponseHandler` are the only
   recovery path.
4. **Not a new on-wire protocol.** The Matrix SDK's `onTimelineEvent`,
   `onSync`, `/messages` pagination, and the existing sync-message
   envelope all stay. The refactor is entirely internal to the
   receiving app.

## 3. Invariants the design must uphold

1. **No silent hole.** If an event exists in the Matrix room and any
   live peer still holds its payload, a correct client must eventually
   observe it. "Eventually" is unbounded for the user-cancelled
   bootstrap case; "promptly" for the normal live case.
2. **Exactly-once apply per `eventId`.** The queue's uniqueness
   constraint is load-bearing. Duplicate arrivals from overlapping
   producers must be silently rejected, not re-applied.
3. **In-order apply.** Events must hit `SyncEventProcessor.apply`
   ordered by `originServerTs` ascending (with `eventId` as tie-break,
   matching `TimelineEventOrdering.isNewer`). Cross-producer
   interleaving is allowed on insert; ordering is restored on drain.
4. **Marker durability.** `lastReadMatrixEventId` and
   `lastReadMatrixEventTs` advance only after the corresponding event
   has been successfully applied **and** removed from the queue. Crash
   recovery must not lose events, and must not re-apply applied ones.
5. **Bounded memory.** The queue is disk-backed. Memory holds at most
   a small working window (e.g. ≤ 100 events pending decode/apply).
6. **Back-pressure on producers.** A slow apply worker must cause
   producers (pagination, bootstrap) to pause rather than fill the
   queue unboundedly. The live stream cannot pause the server, so it
   may over-run transient bursts; the queue's durable store absorbs
   these.
7. **The queue does not decide completeness.** A drained queue is not
   equivalent to "caught up". Completeness is decided independently by
   the sequence-log layer, and surfaces to the UI separately.

## 4. Matrix SDK reality check

Design choices follow from what the SDK actually guarantees. Verified
against `matrix-7.0.0` source:

1. **`onTimelineEvent` fires for every event in every successful
   sync response** that the SDK classifies as
   `EventUpdateType.timeline`
   (`matrix-7.0.0/lib/src/client.dart:2967–2968`). Pagination results
   go to `onHistoryEvent`; not our live-path input.
2. **`limited=true` syncs delete the local timeline**
   (`client.dart:2718–2722`: `database.deleteTimelineForRoom(id)`).
   The SDK fires `onTimelineEvent` only for the events it delivered
   in that limited response — the tail. Events before the limited
   boundary are **silently dropped** from the SDK's view. We are
   responsible for bridging the gap via `/messages`.
3. **`CachedStreamController` keeps only the last value, not a
   backlog** (`matrix-7.0.0/lib/src/utils/cached_stream_controller.dart`).
   Events received before our subscriber attached are unrecoverable
   from the stream. Cold start must do one deterministic bridge call
   before relying on live delivery.
4. **The `Timeline` object's in-memory `events` list is NOT
   append-only**. On `limited=true` the SDK purges the whole room
   timeline (`_removeEventsNotInThisSync`,
   `timeline.dart:345–347`). A design that reads `tl.events` as if it
   were a log (which today's `buildLiveScanSlice` effectively does)
   is structurally vulnerable to this purge. The queue model does not
   read `tl.events`.
5. **Wake from background, per se, is fine.** Once the SDK's internal
   sync loop restarts, `onTimelineEvent` fires normally for all new
   events. The risk is the gap *during* wake, which manifests as
   `limited=true` on the first post-wake sync when the gap is large
   enough.
6. **Killed process loses nothing permanently.** Events accumulate
   server-side; first post-restart sync may be `limited=true`,
   handled identically to mid-session limited.

These facts define three distinct producer categories and one distinct
failure mode the design has to handle explicitly. The failure mode is
(2): a running app can receive a `limited=true` sync and silently lose
events if we don't treat it as a first-class trigger.

## 5. Architecture overview

### 5.1 Two-layer model

```
┌─────────────────────────────────────────────────────────────────┐
│                      LAYER 1: INGESTION                         │
│                                                                 │
│  Producers (three)            ┌────────────────────────┐        │
│                               │                        │        │
│  ① onTimelineEvent ──────────▶│                        │        │
│                               │                        │        │
│  ② onSync(limited=true) ─────▶│   InboundEventQueue    │        │
│       ↓                       │  (sync_db-backed,      │        │
│    bridge /messages call  ────▶│   ordered, dedup      │        │
│    (CatchUpStrategy.           │   by eventId)         │        │
│    collectEventsForCatchUp)   │                        │        │
│                               │                        │        │
│  ③ Explicit pagination ──────▶│                        │        │
│     - cold-start bootstrap    │                        │        │
│     - user "fetch all"        │                        │        │
│     - peer-backfill response  │                        │        │
│     (some land on ① directly)│                        │        │
│                               └───────────┬────────────┘        │
│                                           │                     │
│                                 (one worker, drains)            │
│                                           │                     │
│                                           ▼                     │
│                               SyncEventProcessor                │
│                               (prepare outside txn,             │
│                                apply inside — unchanged)        │
└─────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼ on every apply
┌─────────────────────────────────────────────────────────────────┐
│                   LAYER 2: COMPLETENESS                         │
│                                                                 │
│        SyncSequenceLogService                                   │
│             ↓                                                   │
│        gap detection on (hostId, counter)                       │
│             ↓                                                   │
│        BackfillRequestService  ─── asks peers ───▶ Matrix room  │
│                                                         │       │
│        BackfillResponseHandler ◀─ peer replies ─────────┘       │
│             ↓                                                   │
│        (response payloads re-enter via onTimelineEvent → queue) │
└─────────────────────────────────────────────────────────────────┘
```

Layer 1 is the refactor. Layer 2 stays exactly as it is today. The
arrow from Layer 2 back into Layer 1 (peer-backfill responses arrive as
Matrix events on `onTimelineEvent`) is how the layers compose without
cycles.

### 5.2 Why this is not "rely on onTimelineEvent alone"

Three distinct inputs, all writing to the same queue:

1. **Live stream** (`onTimelineEvent`) — the fast path. Lowest
   latency, but not authoritative for completeness.
2. **Limited-sync bridge** (`onSync`-watch + bounded `/messages`
   paginate-from-marker) — covers the single gap class the SDK does
   not cover for us.
3. **Explicit pagination** (cold-start bootstrap, user-initiated
   full-history fetch) — covers the cases where there is no
   marker or the user asks for a deep walk.

The queue's `UNIQUE(eventId)` constraint makes all three safely
composable. A single event delivered by both the live stream and a
bridge call is deduplicated on insert. A single event that is later
also returned by a pagination pass is deduplicated the same way. No
`_seenEventIds` in-memory LRU required.

## 6. InboundEventQueue

### 6.1 Storage

New table in `sync_db` (dedicated DB, not `journalDb`):

```sql
CREATE TABLE inbound_event_queue (
  queue_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id      TEXT    NOT NULL UNIQUE,         -- Matrix event ID
  room_id       TEXT    NOT NULL,
  origin_ts     INTEGER NOT NULL,                -- originServerTs
  producer      TEXT    NOT NULL,                -- 'live' | 'bridge' | 'bootstrap' | 'backfill'
  raw_json      TEXT    NOT NULL,                -- SDK Event.toJson() serialised
  enqueued_at   INTEGER NOT NULL,                -- ms since epoch
  attempts      INTEGER NOT NULL DEFAULT 0,
  next_due_at   INTEGER NOT NULL DEFAULT 0       -- retry backoff (ms since epoch)
);

CREATE INDEX idx_queue_ready ON inbound_event_queue (next_due_at, origin_ts, queue_id);
CREATE INDEX idx_queue_room   ON inbound_event_queue (room_id, origin_ts);
```

**Notes on schema decisions:**

- `event_id UNIQUE`: primary deduplication mechanism. Duplicate
  inserts are silently rejected at the DB level — no application-level
  check required.
- `origin_ts + queue_id` as the drain order: `origin_ts` for causal
  order, `queue_id` as a tie-break (insertion order for
  same-timestamp events, preserving producer ordering).
- `raw_json` stores the SDK's serialised event. The worker deserialises
  via `Event.fromJson(room, json)` at drain time; the in-memory
  `Event` object is not persisted (it holds back-references to
  the SDK's state).
- `attempts` and `next_due_at` absorb the existing `RetryTracker`
  semantics — retries are durable and survive restart.
- Placing this in `sync_db` (not `journal_db`) keeps the queue's
  writer traffic off the journal's write lock. Cross-DB consistency
  is not required because marker durability is what bridges queue
  state to journal state (see §6.5).

### 6.2 Public API sketch

```dart
class InboundEventQueue {
  /// Enqueue a single event received from the live stream.
  /// O(1) on average; duplicate eventIds are silently dropped.
  Future<EnqueueResult> enqueueLive(Event event);

  /// Enqueue a batch of events produced by the limited-sync bridge
  /// or a peer-backfill response. Transactional: either all are
  /// inserted or none.
  Future<EnqueueResult> enqueueBatch(
    List<Event> events, {
    required InboundEventProducer producer,
  });

  /// Page-streaming producer callback, for bootstrap.
  /// The caller invokes this once per page; the queue applies
  /// back-pressure by awaiting the returned Future before the
  /// producer fetches the next page.
  Future<bool> appendBootstrapPage(List<Event> events);

  /// Stream of "queue became non-empty" notifications so the
  /// worker can wake without polling.
  Stream<void> get wakeups;

  /// For the worker: peek the oldest-due-first entry without
  /// removing it.
  Future<InboundQueueEntry?> peekNextReady();

  /// Mark an entry as applied and remove it, advancing
  /// [lastAppliedEventId] and [lastAppliedTs] in settings_db in
  /// the same DB batch.
  Future<void> commitApplied(InboundQueueEntry entry);

  /// Schedule a retry with backoff; does NOT remove from queue.
  Future<void> scheduleRetry(
    InboundQueueEntry entry,
    Duration backoff,
  );

  /// Diagnostic snapshot for the Sync Settings page.
  Future<QueueStats> stats();
}

enum InboundEventProducer { live, bridge, bootstrap, backfill }

class EnqueueResult {
  final int accepted;
  final int duplicatesDropped;
  final int oldestTsAccepted;
  final int newestTsAccepted;
}

class InboundQueueEntry {
  final int queueId;
  final String eventId;
  final String roomId;
  final num originTs;
  final InboundEventProducer producer;
  final int attempts;
  /// Deserialised; construction is deferred until peek time so the
  /// queue itself doesn't hold SDK objects.
  final Event event;
}
```

### 6.3 Ordering and drain semantics

The worker drain loop:

```
repeat:
  entry := peekNextReady()
  if entry is null:
    await wakeups.next  // or a small idle timeout
    continue

  outcome := await apply(entry)

  switch outcome:
    case applied:
      commitApplied(entry)         // durably advances marker
    case retriable (FileSystemException, network):
      scheduleRetry(entry, backoff(entry.attempts))
    case permanently-skipped:      // unrecoverable deserialisation
      markSkipped(entry)           // logs, removes from queue
    case missingBase:              // apply observer flagged base missing
      scheduleRetry(entry, shortBackoff)
```

`peekNextReady()` returns the oldest entry (by `next_due_at ≤ now`,
then `origin_ts`, then `queue_id`) that is not currently leased.
Cross-producer ordering is restored here: an event enqueued by the
live stream with `origin_ts = 100` and another by a bridge with
`origin_ts = 90` both queued — the bridge's event applies first.

### 6.4 Concurrency model

- **Exactly one worker per room** at a time. Enforced by a single
  `_workerLoop` future in `InboundWorker`.
- **Producers do not block each other.** `enqueueLive`,
  `enqueueBatch`, and `appendBootstrapPage` are independent DB
  transactions on `inbound_event_queue`.
- **Producers do not block the worker.** The worker's DB reads for
  `peekNextReady` happen in separate transactions from producer
  inserts. The UNIQUE constraint on `event_id` is the only
  synchronisation primitive required.
- **Back-pressure for bootstrap.** `appendBootstrapPage` returns a
  Future that completes when the queue depth drops below a
  high-water mark (e.g. 1000 entries). The bootstrap producer awaits
  it before fetching the next page. Live and bridge producers do NOT
  apply back-pressure (they cannot slow the server); if the queue is
  deeper than expected, they still insert.
- **Apply work is unchanged.** `SyncEventProcessor.prepare` runs
  before the DB transaction, `apply` runs inside. P1's freeze fix is
  preserved.

### 6.5 Marker advancement

The read marker is the durable bridge between queue state and "how
far we've caught up".

```
commitApplied(entry) := { in one DB batch:
  DELETE FROM inbound_event_queue WHERE queue_id = entry.queueId;
  IF entry.event_id starts with '$':
    settings_db.set('lastReadMatrixEventId', entry.event_id);
  settings_db.set('lastReadMatrixEventTs', entry.origin_ts);
  // Matrix read-marker push is scheduled via the existing
  // ReadMarkerManager debounce.
}
```

This preserves the existing `isServerAssignedMatrixEventId` gate
(only `$`-prefixed IDs are durable across restart) and the existing
debounced push to the Matrix server.

**Crash recovery:**
- On restart, queue entries that were leased to the worker but not
  committed are re-peeked (no lease persists to disk). They re-apply;
  exactly-once still holds because the apply path is idempotent
  against vector-clock comparison.
- `lastReadMatrixEventTs` survives — it's in `settings_db`. Bridge
  call on restart paginates `/messages` from that timestamp forward,
  and the queue's UNIQUE constraint drops any events that already
  applied.

### 6.6 Memory and retention

- The `inbound_event_queue` table is **transient**. An entry's
  lifetime is: enqueue → apply → delete. A healthy queue has O(10)
  entries at any moment.
- A pathological queue (e.g. during bootstrap of a 50k-event room
  where apply is slower than pagination) has entries capped by the
  back-pressure mechanism at ~1000.
- On crash or apply-path-blocked-indefinitely, the queue can grow.
  The Sync Settings page should surface `QueueStats.depth` so the
  user has visibility; `stats()` is cheap (single `COUNT(*)`).

## 7. Producers

### 7.1 Live stream producer

```
sessionManager.timelineEvents.listen((event) {
  if (event.roomId != currentRoomId) return;
  unawaited(queue.enqueueLive(event));
});
```

This replaces today's `MatrixStreamSignalBinder.start` body and its
five overlapping signal paths. Zero flag negotiation.

### 7.2 Limited-sync bridge producer

```
sessionManager.client.onSync.listen((sync) async {
  final joined = sync.rooms?.join?[currentRoomId];
  if (joined?.timeline?.limited != true) return;
  await bridgeFromMarker();
});

Future<void> bridgeFromMarker() async {
  final marker = settingsDb.get('lastReadMatrixEventTs');
  if (marker == null) return;  // cold-start handles this
  final slice = await CatchUpStrategy.collectEventsForCatchUp(
    room: currentRoom,
    lastEventId: settingsDb.get('lastReadMatrixEventId'),
    backfill: SdkPaginationCompat.backfillUntilContains,
    preContextSinceTs: (marker - 1000).toInt(),
    preContextCount: SyncTuning.catchupPreContextCount,
    maxLookback: SyncTuning.catchupMaxLookback,
  );
  await queue.enqueueBatch(slice.events,
                           producer: InboundEventProducer.bridge);
}
```

Coalescing: if a `limited=true` fires while a bridge is already in
flight, the second is deferred to run after the first completes.
One bridge running at a time per room. This is the only concurrency
primitive needed at this layer, and it lives in a thin
`BridgeCoordinator` — not the queue itself.

### 7.3 Bootstrap producer — `collectHistoryForBootstrap`

New entry point in `CatchUpStrategy`. Called on fresh install
(`lastReadMatrixEventTs == null`) and from the Sync Settings "Fetch
all history" action.

```dart
abstract class BootstrapSink {
  /// Called once per page, events sorted oldest-first.
  /// Return true to continue paging, false to stop (user cancel).
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info);
}

class BootstrapPageInfo {
  final int pageIndex;
  final int totalEventsSoFar;
  final num? oldestTimestampSoFar;
  final bool serverHasMore;
  final Duration elapsed;
}

class BootstrapResult {
  final int totalPages;
  final int totalEvents;
  final num? oldestTimestampReached;
  final BootstrapStopReason stopReason;
}

enum BootstrapStopReason { serverExhausted, sinkCancelled, error }

class CatchUpStrategy {
  /// Streams the room's entire visible history into [sink], oldest
  /// first, one page at a time. No lookback cap. Stops when the
  /// server reports no more history or the sink returns false.
  static Future<BootstrapResult> collectHistoryForBootstrap({
    required Room room,
    required BootstrapSink sink,
    required LoggingService logging,
    int pageSize = 200,
    Duration? overallTimeout,
  });
}
```

The bootstrap flow:

```
final sink = _QueueBootstrapSink(queue: queue, cancel: cancelSignal);
final result = await CatchUpStrategy.collectHistoryForBootstrap(
  room: room,
  sink: sink,
  logging: logging,
);
// UI shows result.totalEvents, result.oldestTimestampReached,
// result.stopReason.
```

The `_QueueBootstrapSink.onPage` implementation calls
`queue.appendBootstrapPage(events)`, which awaits back-pressure
before returning true. User cancel signals through a `Completer`
that `onPage` checks.

### 7.4 Peer-backfill response

No new producer. Peer-backfill responses arrive as normal Matrix
events on `onTimelineEvent`. They flow through the live-stream
producer and land in the queue like any other event. The sequence-log
recognises them in `apply` and closes its gap tracking.

## 8. CatchUpStrategy changes

### 8.1 `collectEventsForCatchUp` — narrowed

Called from exactly two places:
- `bridgeFromMarker()` on `limited=true`.
- `bridgeFromMarker()` on startup when `lastReadMatrixEventTs` is
  non-null.

Changes to the function itself:
- **Remove the no-anchor branch** (lines 125–159 today). That case
  is handled by `collectHistoryForBootstrap`.
- **Remove the best-effort fallback** (lines 246–261). Completeness
  is owned by the sequence-log; the bridge's job is only "here are
  the events we can fetch by timestamp walk-back". An unreachable
  boundary is reported as `CatchUpCollection.incomplete` and the
  sequence-log decides whether to trigger a peer-backfill.
- **Keep everything else:** the timestamp-anchored walk-back, the
  pagination-doubling, `_startIndexForTimestampBoundary`, the
  `preContextCount` overlap, `backfillUntilContains`.

### 8.2 `collectHistoryForBootstrap` — new

Contract:
- Streams pages through a `BootstrapSink`, oldest-first within each
  page.
- Unbounded by default (no `maxLookback`). The sink can stop paging
  at any time.
- Applies the same `backfillUntilContains` machinery, but with
  `untilTimestamp: 0` (or a user-supplied horizon) instead of a
  specific anchor.
- Does not accumulate events in memory across pages.
- Does not return events; the sink is the only consumer.

## 9. Completeness layer — unchanged behaviour

`SyncSequenceLogService`, `BackfillRequestService`, and
`BackfillResponseHandler` are untouched. Their inputs (applied
events with vector clocks and covered-clocks metadata) and their
outputs (backfill request/response messages over the Matrix room)
do not change.

What changes is the **signal surface** the UI gets:

- **"Queue empty"** — from `queue.stats()`. Means "no events waiting
  to apply locally". A plumbing signal.
- **"No detectable gaps"** — from `sequenceLogService.getBackfillStats()`.
  Means "sequence-log has no missing counters for any known host".
  A correctness signal.
- **"Bootstrap pagination complete"** — from `BootstrapResult`.
  Means "server returned no more history" (or user cancelled).

All three are now clearly separable. Today they are conflated in
ad-hoc ways across `_initialCatchUpReady`, `_initialCatchUpConverged`,
and the live-scan summary log lines.

## 10. What gets deleted or narrowed

### 10.1 Deleted

- `MatrixStreamLiveScanController` entirely (~430 LOC).
- `MatrixStreamSignalBinder`'s timeline-callback wiring — reduced to a
  bare `sessionManager.timelineEvents` subscription.
- `buildLiveScanSlice` in `matrix_stream_helpers.dart` (~60 LOC).
- `_seenEventIds` LRU, `_completedSyncIds` LRU, and `_inFlightSyncIds`
  set in `MatrixStreamProcessor` — the queue's UNIQUE constraint and
  the worker's one-at-a-time drain make these redundant.
- `_scanInFlight`, `_scanInFlightDepth`, `_scanEpoch`,
  `_scanStartedAt`, `_liveScanDeferred`, `_liveScanTimer`,
  stuck-scan watchdog (new in #2984; unneeded once the queue replaces
  the mechanism it was guarding).
- `CatchUpCollection.complete` and `.incomplete` variants
  (the bootstrap case owns the no-anchor path; the sequence-log owns
  the incomplete case).
- The best-effort fallback at `catch_up_strategy.dart:246–261`.
- `AppLifecycleRescanObserver` was already deleted in #2983; stays
  deleted. Lifecycle triggers are not required because wake manifests
  as either continued `onTimelineEvent` (fine) or a `limited=true`
  sync (handled by the bridge).

Estimated net deletion: ~700–900 LOC across `lib/features/sync/`.

### 10.2 Narrowed

- `CatchUpStrategy.collectEventsForCatchUp` loses its no-anchor and
  best-effort branches (see §8.1).
- `MatrixStreamProcessor.processOrdered` continues to exist but is
  only ever called via the worker on one event at a time — the
  "ordered slice" shape collapses because the queue already guarantees
  order. The chunked-transaction logic (`SyncTuning.processOrderedChunkSize`)
  is no longer needed; each event applies in its own short transaction.
  *(Trade-off: loses the current per-chunk Drift stream coalescing.
  This is acceptable because the worker applies events at a slower
  rate than today's catch-up burst, so user-visible Drift stream
  emissions aren't dominated by bursty apply anyway. Needs measurement.)*
- `MatrixStreamCatchUpCoordinator` shrinks to a `BridgeCoordinator`
  (~80 LOC) that owns the single-flight guard around
  `bridgeFromMarker()` and the `limited=true` listener.

### 10.3 Unchanged

- `SyncEventProcessor` (prepare/apply split, attachment resolution,
  all per-type handlers).
- `SyncSequenceLogService`, vector clocks, covered-clocks, gap
  detection.
- `BackfillRequestService`, `BackfillResponseHandler`.
- `OutboxService`, `OutboxProcessor` — the send path.
- `ReadMarkerManager` — debounced push to the Matrix server.
- `MatrixService` as the top-level orchestrator, though its
  internal wiring (what it composes) changes.

## 11. Sync Settings page changes

Today's `BackfillSettingsPage` has one overloaded "refresh" button
that only reloads sequence-log stats from the local DB. Under the new
design, it gains three clearly-scoped actions:

1. **"Catch up now"** → `matrixService.forceRescan(includeCatchUp: true)`,
   which under the hood calls `bridgeFromMarker()`. Cheap; always
   safe. Essentially free when nothing is new.
2. **"Fetch all history"** → invokes `collectHistoryForBootstrap`
   with a cancellable sink. Progress UI shows pages fetched, oldest
   timestamp reached, queue depth. Expected usage: new-device setup,
   lost-phone recovery.
3. **"Request missing counters from peers"** → the existing full
   backfill button, unchanged. Calls `BackfillRequestService.processFullBackfill()`.

Plus a **status card** with three independent signals from §9:
- Queue depth (+ live/bridge/bootstrap/backfill breakdown).
- Gap count per host from sequence-log.
- Bootstrap progress (only when a bootstrap is running).

## 12. Migration plan

Phased delivery, each phase independently shippable and reversible:

### Phase 0 — Diagnostic PR (pre-requisite)

- Log `sync.limited room=... prevBatch=...` on every `onSync`
  update where any joined room has `timeline.limited == true`.
- Log `onTimelineEvent.ordering` one-line summary per 100 events:
  expected cross-sync interleaving rate.
- Run for ~48 hours on desktop + mobile.
- **Purpose:** confirm (a) that `limited=true` is the primary bridge
  trigger we think it is, not a rare edge case, and (b) that live
  events arrive in sort order within each room, which the queue
  assumes. If (b) fails, the queue's drain logic is still correct
  (it sorts on `origin_ts`), but we'd want to measure the amount of
  reordering.

Rollback: the logs are additive; reverting is a no-op.

### Phase 1 — InboundEventQueue + bridge

- Add `inbound_event_queue` table to `sync_db` with migration.
- Implement `InboundEventQueue` + `InboundWorker` as new code; not
  wired yet.
- Add `BridgeCoordinator` with the `limited=true` listener.
- Add `collectHistoryForBootstrap` to `CatchUpStrategy` (additive;
  existing function untouched).
- **No callers switch yet.** The new code sits alongside the
  existing pipeline. Ship behind a feature flag
  (`useInboundEventQueue`, default false).
- Unit tests: queue enqueue/dedup/drain, bridge coordinator
  coalescing, `collectHistoryForBootstrap` page streaming + cancel.

Rollback: flag to false.

### Phase 2 — Switch live + bridge producers to queue

- `MatrixService.init` path, when flag is on: subscribe live stream
  to `InboundEventQueue.enqueueLive`, wire `BridgeCoordinator` to
  `onSync`, start `InboundWorker`.
- `MatrixStreamLiveScanController` and the entire old signal-binder
  wiring stay in place but only run when flag is off.
- Sync-settings-page "Fetch all history" button hidden behind the
  same flag.
- Dogfood with flag on for one release.

Rollback: flag to false.

### Phase 3 — Delete old paths

- Flag removed. Old paths deleted. Tests for
  `MatrixStreamLiveScanController`, `buildLiveScanSlice`, the
  signal-binder test, stuck-scan regression, etc. — removed.
- Peer-backfill response path re-verified end-to-end: peer sends
  response → arrives on `onTimelineEvent` → queue → apply →
  sequence-log closes gap.
- Sync-settings-page gets the three-action UI.

Rollback: git revert.

## 13. Test coverage plan

- `inbound_event_queue_test.dart` — DB-backed tests with `drift/ffi`:
  enqueue, dedup-by-eventId on insert, peek order (ts + queue_id),
  commit-and-remove, retry scheduling, crash recovery (leased entries
  re-peeked).
- `inbound_worker_test.dart` — in-memory queue, mock apply function,
  covers: drain-until-empty, retry with backoff, missing-base retry,
  permanently-skipped handling, wake-on-enqueue.
- `bridge_coordinator_test.dart` — single-flight guard under
  concurrent `limited=true` fires, marker read, slice enqueued.
- `collect_history_for_bootstrap_test.dart` — fake `Room` with
  paginated `/messages`, oldest-first ordering per page, early
  cancel via sink, server-exhausted termination, `BootstrapResult`
  fields.
- **End-to-end integration tests** (`test/features/sync/scenarios/`):
  1. Normal live delivery — both devices online, one sends 10 events,
     other applies all 10 exactly once, in order.
  2. `limited=true` recovery — simulate a limited sync mid-session;
     assert bridge fires and missing events enter the queue.
  3. Cold-start bootstrap — empty local state, 500-event room; assert
     all 500 apply, in order, queue drains, markers advance.
  4. Peer backfill still works — device A is missing (hostB:42);
     asks B; B responds; A applies and closes gap.
  5. User cancels bootstrap mid-flight — paging stops cleanly, queue
     drains what was delivered, no crash.

Coverage target: every new file ≥95%, consistent with Codecov's
93% patch target.

## 14. Risks and open questions

### 14.1 Risks

- **Writer contention on `sync_db`.** Live stream + bridge + worker
  all write. Mitigation: short transactions, indexed peek,
  `busy_timeout = 5000ms`. Measurement: slow-query log diff pre/post.
- **Event deserialisation cost.** Queue stores `raw_json`; worker
  deserialises on peek. For bootstrap paginate of 50k events, this
  is 50k `Event.fromJson` calls. Mitigation: the apply worker is
  already the bottleneck (attachment I/O), so deserialisation cost
  is dwarfed. But measure.
- **Back-pressure stalls on bootstrap.** If the apply worker hangs
  (despite the P1 + stuck-scan fixes), bootstrap blocks at
  high-water mark and the UI appears frozen. Mitigation:
  `BootstrapSink.onPage` can time out its own back-pressure wait and
  surface "apply is slow" to the user.
- **Drift stream coalescing loss.** Today's chunked-transaction
  logic batches N journal rows into one Drift stream notification.
  Under the new design, each event's apply is its own transaction.
  UI streams may emit more often under bursty apply. Mitigation:
  measure; if material, add a per-apply debounce at the stream
  subscriber level, not at the apply path.

### 14.2 Open questions

- Does the `inbound_event_queue` belong in `sync_db` (aligns with
  existing sync-feature data ownership) or in a fresh DB? Default
  proposal: `sync_db`. Argument for fresh DB: isolates queue writer
  traffic. Argument against: one more migration and cross-DB
  ordering concerns. Default wins unless measurement changes the
  picture.
- Where does the `overallTimeout` for `collectHistoryForBootstrap`
  live — at the function level, at the sink level, or not at all?
  Default: pass-through parameter, default `null` (unbounded).
- Should peer-backfill responses have their own producer path
  instead of flowing through `onTimelineEvent`? Default: no, the
  current design works and having all Matrix-event ingestion go
  through one path is exactly the point of the refactor.

## 15. Decision summary

- **The simplification is real but narrower than "read only what is
  new from onTimelineEvent".** It is: three producers → one queue →
  one worker → unchanged apply + completeness layers.
- **`CatchUpStrategy` doesn't go away; it's narrowed and split.**
  The timestamp-anchored bridge keeps working exactly as it does
  today. A new streaming entry point handles deep-history walks.
- **Completeness stays owned by the sequence-log + peer-backfill
  machinery.** The queue is plumbing; it does not make correctness
  claims.
- **Delivery is phased behind a feature flag** so any phase can be
  rolled back without a deploy. No big-bang switch.
- **Diagnostic data precedes code.** The Phase 0 diagnostic PR
  validates two load-bearing assumptions (`limited=true` is
  frequent enough to be the primary bridge trigger; live events
  arrive mostly in order) before committing to the design.

Sign-off on this document gates Phase 1.
