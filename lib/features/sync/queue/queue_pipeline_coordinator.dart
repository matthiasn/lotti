import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/attachment_aware_bootstrap_sink.dart';
import 'package:lotti/features/sync/queue/bootstrap_sink.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/features/sync/queue/queue_bootstrap_sinks.dart';
import 'package:lotti/features/sync/queue/queue_marker_seeder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

part 'queue_gap_recovery.dart';
part 'queue_lifecycle.dart';

const _logSub = 'queue.coordinator';

/// Top-level owner of the queue pipeline. Wires the four collaborators
/// — `InboundQueue`, `InboundWorker`, `BridgeCoordinator`, and
/// `PendingDecryptionPen` — into a single start/stop lifecycle that
/// `MatrixService` manages.
///
/// Responsibilities:
/// - Subscribe the live-stream producer to the session manager's
///   `timelineEvents` stream.
/// - Route encrypted events through the decryption pen so pre-decryption
///   ciphertext never lands in `inbound_event_queue.raw_json` (F3).
/// - Seed `queue_markers` from the legacy `settings_db` on first start
///   so the queue resumes wherever the legacy pipeline stopped.
/// - Drain stranded rows whenever the current room changes (F6).
/// - Expose the queue (for UI depth signals) and the worker (for
///   drain-before-disable on flag-off).
class QueuePipelineCoordinator {
  QueuePipelineCoordinator({
    required SyncDatabase syncDb,
    required SettingsDb settingsDb,
    required JournalDb journalDb,
    required this._sessionManager,
    required this._roomManager,
    required SyncEventProcessor eventProcessor,
    required this._sequenceLogService,
    required this._activityGate,
    required DomainLogger logging,
    this._attachmentIndex,
    this._updateNotifications,
    this._attachmentIngestor,
    this._sentEventRegistry,
    SyncActivitySignaler? activitySignaler,
    InboundQueue? queueOverride,
    InboundWorker? workerOverride,
    BridgeCoordinator? bridgeOverride,
    PendingDecryptionPen? penOverride,
    QueueMarkerSeeder? seederOverride,
  }) : _syncDb = syncDb,
       _settingsDb = settingsDb,
       _logging = logging,
       _queue =
           queueOverride ??
           InboundQueue(
             db: syncDb,
             logging: logging,
             activitySignaler: activitySignaler,
           ),
       _pen = penOverride ?? PendingDecryptionPen(logging: logging),
       _seeder =
           seederOverride ??
           QueueMarkerSeeder(
             syncDb: syncDb,
             settingsDb: settingsDb,
             logging: logging,
           ),
       _applyAdapter = QueueApplyAdapter(
         processor: eventProcessor,
         journalDb: journalDb,
         logging: logging,
       ) {
    _worker =
        workerOverride ??
        InboundWorker(
          queue: _queue,
          sequenceLogService: _sequenceLogService,
          resolveRoom: _resolveRoom,
          apply: _applyAdapter.bind(),
          prepareBatch: _applyAdapter.bindPrepareBatch(),
          logging: _logging,
          activityGate: _activityGate,
          decryptionPen: _pen,
        );
    _bridge =
        bridgeOverride ??
        BridgeCoordinator(
          client: _sessionManager.client,
          currentRoomId: () => _roomManager.currentRoomId,
          resolveRoom: _resolveRoom,
          readMarker: _readMarker,
          bootstrapRunner: _runBootstrap,
          logging: _logging,
        );
  }

  final SyncDatabase _syncDb;
  final SettingsDb _settingsDb;
  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final SyncSequenceLogService _sequenceLogService;
  final UserActivityGate? _activityGate;
  final DomainLogger _logging;
  final AttachmentIndex? _attachmentIndex;
  final UpdateNotifications? _updateNotifications;
  final AttachmentIngestor? _attachmentIngestor;
  final SentEventRegistry? _sentEventRegistry;

  /// Counts self-echoed events suppressed since the last log flush so
  /// the observability line drops from one-per-event (tens of
  /// thousands during a big outbox drain) to one summary entry per
  /// interval. Paired with [_lastSuppressedLogAt].
  int _suppressedSelfEchoes = 0;
  DateTime? _lastSuppressedLogAt;
  static const Duration _suppressionLogInterval = Duration(seconds: 30);
  final InboundQueue _queue;
  final PendingDecryptionPen _pen;
  final QueueMarkerSeeder _seeder;
  final QueueApplyAdapter _applyAdapter;
  late final InboundWorker _worker;
  late final BridgeCoordinator _bridge;

  // These subscriptions are assigned in [QueueLifecycle.startImpl] and
  // cancelled in its error-unwind and [QueueLifecycle.stopImpl]; the
  // cancel_subscriptions lint cannot trace the cancels across the extension
  // boundary, so it is suppressed per field here.
  // ignore: cancel_subscriptions
  StreamSubscription<Event>? _liveSub;
  // ignore: cancel_subscriptions
  StreamSubscription<SyncUpdate>? _syncSub;
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _attachmentPathSub;
  // ignore: cancel_subscriptions
  StreamSubscription<Set<String>>? _journalUpdateSub;
  bool _started = false;

  /// Accumulates `pathRecorded` paths between flushes of
  /// [_attachmentPathFlushTimer]. A burst of attachment downloads
  /// (matrix-sync catch-up) used to fan out one
  /// `resurrectByPath` call per path; each opened a writer
  /// transaction whose lock starved the next call's SELECT. The
  /// 2026-05-12 desktop super_slow log captured 222 hits/day of
  /// `inbound_event_queue WHERE … json_path = ?` at ~384 ms each,
  /// often ten back-to-back in the same millisecond span. Coalescing
  /// into one bulk [InboundQueue.resurrectByPaths] call per debounce
  /// window removes the writer-lock chain entirely.
  final Set<String> _pendingPathResurrections = <String>{};
  Timer? _attachmentPathFlushTimer;

  /// Tracks an in-flight [_flushPendingPathResurrections] call so
  /// [stop] can await it before tearing the queue down. Without this,
  /// a flush kicked off by the debounce timer right before the
  /// listener cancels could still be running its
  /// `_queue.resurrectByPaths` call when the queue is disposed,
  /// producing a "used after close" error on shutdown.
  Future<void>? _attachmentPathFlushInFlight;

  /// Debounce window for [_pendingPathResurrections]. Tuned wide
  /// enough to fold an attachment download burst together (the
  /// observed bursts span 10–30 ms) but short enough that an isolated
  /// attachment landing still resurrects within a single user-visible
  /// frame.
  @visibleForTesting
  static const Duration attachmentPathDebounce = Duration(milliseconds: 100);

  /// Set when the most recent reconnect-mode bridge pass finished with
  /// `stopReason == boundaryReached` AND the sink accepted zero events
  /// across every page. That is the precise signal that the SDK's local
  /// timeline cache wedged on a stale wake-up window — the walk
  /// exhausted its `boundaryContinuationCap` without finding anything
  /// the queue didn't already have. When [maybeStartGapRecovery] fires
  /// on a subsequent gap detection it pulls history unbounded to close
  /// the hole instead of waiting for the normal backfill cadence.
  DateTime? _lastBarrenBridgeAt;

  /// Single-flight guard for the gap-triggered unbounded walk. A burst
  /// of gap signals on the same barren-bridge episode coalesces into
  /// one recovery pass so we do not spawn concurrent /messages walks.
  Future<void>? _gapRecoveryInFlight;

  /// How long a barren-bridge signal stays valid. After the window
  /// expires, a late gap no longer triggers the unbounded walk — by
  /// then the worker has had time to burn through any transient
  /// replay lag and a gap more likely indicates a different root
  /// cause (e.g. genuine packet loss) that normal backfill should own.
  @visibleForTesting
  static const Duration barrenBridgeTtl = Duration(minutes: 5);

  /// Tracks in-flight `enqueueLive` calls spawned from the live
  /// subscription so `stop()` can await every outstanding write. Without
  /// this, a racy shutdown can dispose the queue while a producer is
  /// mid-insert and trip drift's "used after close" guard.
  final Set<Future<void>> _inFlightEnqueues = <Future<void>>{};

  /// Tracks which room ids we have un-partialled via `room.postLoad()`
  /// so we only pay the DB load cost once per room.
  final Set<String> _postLoadedRoomIds = <String>{};

  InboundQueue get queue => _queue;

  bool get isRunning => _started;

  /// Manually triggers a bridge pass (equivalent to a `limited=true`
  /// sync arriving). Exposed so the "Catch up now" action in the Sync
  /// Settings UI can force a /messages walk back to the stored
  /// marker without waiting for the next organic `limited=true`.
  Future<void> triggerBridge() => _bridge.bridgeNow();

  /// True while the bridge coordinator is mid-walk (forward-reading
  /// new timeline events from the last applied event id). Exposed so
  /// the backfill request service can skip analysis+dispatch until
  /// the walk concludes — gaps observed mid-walk may be closed by
  /// events still in the pipe.
  bool get isBridgeInFlight => _bridge.isBridgeInFlight;

  /// Callback that fires once per terminal bridge pass. Intended for
  /// the backfill request service to be nudged the moment the walk
  /// settles, so it can dispatch requests for any entries still
  /// missing.
  void Function()? get onBridgeCompleted => _bridge.onBridgeCompleted;
  set onBridgeCompleted(void Function()? callback) =>
      _bridge.onBridgeCompleted = callback;

  Future<void> _safeStartupBridge() async {
    try {
      await _bridge.bridgeNow();
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.startupBridge',
      );
    }
  }

  /// Seeds the marker for a new room and prunes queue rows that belong
  /// to other rooms. Invoked by `MatrixService.saveRoom` so a coordinator
  /// that started before the user picked a sync room — or that is now
  /// switching to a different room — (1) has a baseline `queue_markers`
  /// row so `_readMarkerTs` returns something sensible, (2) does not
  /// leave stranded rows from the previous room that the worker would
  /// replay against the wrong room (`InboundWorker._runBatch` resolves a
  /// single current room per batch), and (3) drops the dedupe bookkeeping
  /// so the next sync re-attempts `room.postLoad()` on the new room.
  Future<void> onRoomChanged(String roomId) async {
    _postLoadedRoomIds.clear();
    try {
      await _seeder.seedIfAbsent(roomId);
      await _queue.pruneStrandedEntries(roomId);
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.onRoomChanged',
      );
    }
    _logging.log(
      LogDomain.sync,
      'queue.coordinator.onRoomChanged roomId=$roomId',
      subDomain: _logSub,
    );
  }

  Future<void> start() => startImpl();

  /// Upper bound on how long [stop] waits for `drainFirst` to empty the
  /// queue before tearing down anyway. Chosen so a wedged pen or a
  /// retriable row with a long backoff can't block shutdown indefinitely
  /// on a user-visible path (flag-off, logout), while still giving a
  /// cold-start catch-up enough headroom to finish under normal load.
  static const Duration drainUntilEmptyTimeout = Duration(seconds: 30);

  /// Drains the queue until every persisted row has applied (or has
  /// been permanently skipped), or the [timeout] elapses.
  ///
  /// Unlike [InboundWorker.drainToCompletion], this does sleep through
  /// retry leases and pen attempts: the F7 contract of
  /// `stop(drainFirst: true)` is "don't strand rows on restart", so a
  /// single ready-at-call-time pass is not enough. Rows with a future
  /// `nextDueAt`/`leaseUntil`, rows held by [PendingDecryptionPen], and
  /// rows the worker is currently looping through a `noRoom` retry on
  /// all survive a single `drainToCompletion()` — this loop closes that
  /// gap by flushing the pen, sleeping until the next ready timestamp,
  /// and re-peeking until the queue is empty or time runs out.
  Future<void> drainUntilEmpty({Duration? timeout}) =>
      drainUntilEmptyImpl(timeout: timeout);

  /// Stops every collaborator in the reverse order they were started.
  /// If [drainFirst] is true (the flag-off flow), the coordinator waits
  /// until the persisted queue is empty (bounded by
  /// [drainUntilEmptyTimeout]) before tearing down — this closes the F7
  /// data-loss hole the design review flagged. Unlike the legacy
  /// "drain ready rows once" primitive, rows with future retry leases,
  /// decryption-pending rows, and rows stuck in the noRoom loop are all
  /// waited out up to the timeout.
  ///
  /// Every teardown step is wrapped in its own try/catch so a throw
  /// from one stage cannot orphan the stages that follow. `_started`
  /// is flipped only after the full best-effort cleanup so a thrown
  /// teardown leaves the coordinator in a state a caller can retry
  /// `stop()` against, rather than a half-dismantled one where the
  /// second `stop()` is a no-op.
  Future<void> stop({bool drainFirst = false}) =>
      stopImpl(drainFirst: drainFirst);

  void _handleLiveEvent(Event event) {
    final currentRoomId = _roomManager.currentRoomId;
    if (currentRoomId == null || event.roomId != currentRoomId) return;
    // Pre-sync fake-sync suppression. `Room.sendEvent` in matrix-sdk
    // 7.0.0 calls `_handleFakeSync` TWICE on every send (room.dart
    // lines 1274 + 1327) — once with a client-side transaction id
    // and `status=sending` BEFORE the HTTP post, and again with the
    // real `$`-prefixed id and `status=sent` AFTER the server
    // responds but BEFORE `sendEvent` returns. Both fake-sync
    // emissions fire `onTimelineEvent`, so our live handler receives
    // them. Neither can be caught by `SentEventRegistry.consume`:
    //   - The `sending` emission carries a temp id the registry
    //     never sees (the sender only learns the real id once
    //     `sendEvent` returns).
    //   - The `sent` emission carries the real id but races
    //     `MatrixMessageSender`'s `_sentEventRegistry.register(id)`
    //     call which runs AFTER `sendEvent` returns — so the
    //     registry is still empty when `_handleLiveEvent` consults
    //     it on this tick.
    // The only status that actually comes from the real `/sync`
    // loop is `synced`; the rest are SDK-generated fake syncs for
    // UI progress and never represent a new inbound event. Drop
    // them here before any downstream work runs.
    if (event.status != EventStatus.synced) return;
    // Self-echo suppression for the REAL `/sync` echo: when the
    // server loops our own sent event back on the next /sync it
    // arrives as `status=synced` — by then the registry has the id
    // (registered after the in-tick race cleared) so `consume`
    // matches and we skip the repeat enqueue / prepare / apply
    // cycle. Lotti uses a single shared Matrix userID across
    // devices so a `senderId == client.userID` check would also
    // drop legitimate peer events; the registry is the only
    // correct source of truth.
    final registry = _sentEventRegistry;
    if (registry != null && registry.consume(event.eventId)) {
      _countSuppressedSelfEcho();
      return;
    }
    // Un-partial the Matrix SDK's room — otherwise `RoomMember` state
    // events arriving via /sync are silently skipped (see
    // `client.dart:3138` in matrix-7.0.0), which leaves
    // `_trackedUserIds` empty and breaks device-key discovery / SAS
    // / E2EE for new joiners. Share the `_maybePostLoadCurrentRoom`
    // check with the onSync listener so either path triggers it.
    _maybePostLoadCurrentRoom();
    // Attachment side-effect: record the descriptor in the
    // AttachmentIndex (which fires `pathRecorded` so abandoned queue
    // rows resurrect) and kick off the download to
    // `documentsDirectory`. The queue's `enqueueBatch` will filter
    // the descriptor event out as `filteredOutByType` on the next
    // step — that is correct: attachments never belong in the queue
    // as payloads. Without this call the queue pipeline has no
    // in-band equivalent of the legacy `AttachmentIngestor.process`
    // hook, and companion sync-payload events get stuck in
    // `pendingAttachment` forever.
    _trackEnqueue(_processAttachment(event));
    // F3: encrypted events live in the pen until decryption completes;
    // the worker's decryptionPen flush on every drain iteration picks
    // them up as soon as the SDK has the session key.
    if (_pen.hold(event)) return;
    _trackEnqueue(_safeEnqueue(event));
  }

  /// Fire-and-forget ingestor hook. No-op when either the ingestor
  /// is not wired (tests without attachment paths) or the event is
  /// not an attachment descriptor (the ingestor gates internally on
  /// `content['relativePath']`).
  Future<void> _processAttachment(Event event) async {
    final ingestor = _attachmentIngestor;
    if (ingestor == null) return;
    try {
      await ingestor.process(
        event: event,
        logging: _logging,
        attachmentIndex: _attachmentIndex,
        // Queue the download so a burst of attachment events does
        // not serialize one download at a time; the ingestor's
        // internal concurrency cap bounds the parallel count.
        scheduleDownload: true,
      );
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.attachmentIngestor',
      );
    }
  }

  void _countSuppressedSelfEcho() {
    _suppressedSelfEchoes++;
    // clock.now() so tests can drive the suppression window with withClock.
    final now = clock.now();
    final last = _lastSuppressedLogAt;
    if (last == null || now.difference(last) >= _suppressionLogInterval) {
      final flushed = _suppressedSelfEchoes;
      _suppressedSelfEchoes = 0;
      _lastSuppressedLogAt = now;
      _logging.log(
        LogDomain.sync,
        'queue.coordinator.selfEchoSuppressed count=$flushed',
        subDomain: '$_logSub.selfEcho',
      );
    }
  }

  Future<void> _safePostLoad(Room room, String roomId) async {
    final wasPartial = room.partial;
    try {
      await room.postLoad();
      _logging.log(
        LogDomain.sync,
        'queue.coordinator.postLoad roomId=$roomId '
        'wasPartial=$wasPartial nowPartial=${room.partial}',
        subDomain: '$_logSub.postLoad',
      );
    } catch (error, stackTrace) {
      // If the post-load fails, drop the "done" marker so a later
      // event retries. Device discovery is important enough to retry.
      _postLoadedRoomIds.remove(roomId);
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.postLoad',
      );
    }
  }

  /// Accumulator hook for the `pathRecorded` subscription. Adds [path]
  /// to the pending set and arms a one-shot flush timer; subsequent
  /// paths arriving within [attachmentPathDebounce] reset the timer
  /// without firing another DB call, so a burst of attachment
  /// downloads folds into a single bulk
  /// [InboundQueue.resurrectByPaths] round-trip.
  void _onAttachmentPathRecorded(String path) {
    if (path.isEmpty) return;
    _pendingPathResurrections.add(path);
    _attachmentPathFlushTimer?.cancel();
    _attachmentPathFlushTimer = Timer(
      attachmentPathDebounce,
      _kickPendingPathResurrectionFlush,
    );
  }

  /// Starts a flush and records the resulting future on
  /// [_attachmentPathFlushInFlight] so [stop] can await it before
  /// disposing the queue. Clears the field once the flush settles —
  /// using `identical` to avoid clobbering a newer in-flight future
  /// scheduled by a follow-up path event.
  void _kickPendingPathResurrectionFlush() {
    final flush = _flushPendingPathResurrections();
    _attachmentPathFlushInFlight = flush;
    unawaited(
      flush.whenComplete(() {
        if (identical(_attachmentPathFlushInFlight, flush)) {
          _attachmentPathFlushInFlight = null;
        }
      }),
    );
  }

  /// Resolves the pending-path batch by passing the accumulated set
  /// to [InboundQueue.resurrectByPaths] in a single SELECT + UPDATE
  /// round-trip. Exposed for tests so a fakeAsync run can deliver the
  /// flush synchronously without waiting on a real timer.
  @visibleForTesting
  Future<void> flushPendingPathResurrectionsForTest() {
    _attachmentPathFlushTimer?.cancel();
    _attachmentPathFlushTimer = null;
    _kickPendingPathResurrectionFlush();
    return _attachmentPathFlushInFlight ?? Future<void>.value();
  }

  Future<void> _flushPendingPathResurrections() async {
    _attachmentPathFlushTimer = null;
    if (_pendingPathResurrections.isEmpty) return;
    // Drain the set into a local copy so any path that lands while
    // the bulk call is in flight gets its own next-cycle batch
    // instead of being silently dropped.
    final paths = _pendingPathResurrections.toList(growable: false);
    _pendingPathResurrections.clear();
    try {
      await _queue.resurrectByPaths(paths);
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.resurrectByPaths',
      );
    }
  }

  void _maybePostLoadCurrentRoom() {
    final roomId = _roomManager.currentRoomId;
    if (roomId == null) return;
    final room = _roomManager.currentRoom;
    if (room == null) return;
    // Re-postLoad as long as the room is still partial — once it
    // flips to non-partial the SDK's `_updateRoomsByEventUpdate` stops
    // silently dropping `RoomMember` events, and subsequent syncs can
    // grow `_trackedUserIds`. Using `room.partial` as the sentinel
    // instead of our own dedupe set means a room that becomes
    // partial again (e.g. after a rejoin) still gets un-partialed.
    if (!room.partial) {
      _postLoadedRoomIds.add(roomId);
      return;
    }
    _trackEnqueue(_safePostLoad(room, roomId));
  }

  Future<void> _safeEnqueue(Event event) async {
    try {
      await _queue.enqueueLive(event);
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.enqueue',
      );
    }
  }

  void _trackEnqueue(Future<void> future) {
    _inFlightEnqueues.add(future);
    future.whenComplete(() => _inFlightEnqueues.remove(future));
  }

  Future<Room?> _resolveRoom() async {
    // Prefer the cached reference, but fall back to the gateway's live
    // lookup when it is null. Cold-start timing leaves
    // `_roomManager.currentRoom` null until the SDK emits a /sync that
    // contains the room — so a bridge trigger from `saveRoom` or the
    // first limited-sync can fire before the cache is populated. The
    // gateway's `getRoomById` resolves off the SDK's room table, which
    // is updated synchronously inside `handleSync` before `onSync`
    // fires; checking there rescues the common case where the bridge
    // would otherwise log `noRoom` and stall.
    final cached = _roomManager.currentRoom;
    if (cached != null) return cached;
    final roomId = _roomManager.currentRoomId;
    if (roomId == null) return null;
    return _sessionManager.client.getRoomById(roomId);
  }

  /// Collect full history through the bootstrap sink; see [QueueGapRecovery].
  Future<BootstrapResult> collectHistory({
    void Function(BootstrapPageInfo info)? onProgress,
    Future<void>? cancelSignal,
    Duration? overallTimeout,
  }) => collectHistoryImpl(
    onProgress: onProgress,
    cancelSignal: cancelSignal,
    overallTimeout: overallTimeout,
  );

  /// Kick gap recovery if the bridge marker shows a gap;
  /// see [QueueGapRecovery].
  void maybeStartGapRecovery() => maybeStartGapRecoveryImpl();
}
