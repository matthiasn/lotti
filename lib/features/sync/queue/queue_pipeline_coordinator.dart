import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/bootstrap_sink.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/features/sync/queue/queue_marker_seeder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

const _logDomain = 'sync';
const _logSub = 'queue.coordinator';

/// Top-level owner of the Phase-2 queue pipeline. Wires the four
/// collaborators the design review approved — `InboundQueue`,
/// `InboundWorker`, `BridgeCoordinator`, and `PendingDecryptionPen` —
/// into a single start/stop lifecycle that `MatrixService` can manage
/// behind the `useInboundEventQueue` flag.
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
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required SyncEventProcessor eventProcessor,
    required SyncSequenceLogService sequenceLogService,
    required UserActivityGate? activityGate,
    required LoggingService logging,
    InboundQueue? queueOverride,
    InboundWorker? workerOverride,
    BridgeCoordinator? bridgeOverride,
    PendingDecryptionPen? penOverride,
    QueueMarkerSeeder? seederOverride,
  }) : _syncDb = syncDb,
       _settingsDb = settingsDb,
       _sessionManager = sessionManager,
       _roomManager = roomManager,
       _sequenceLogService = sequenceLogService,
       _activityGate = activityGate,
       _logging = logging,
       _queue = queueOverride ?? InboundQueue(db: syncDb, logging: logging),
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
          getLastReadTs: _readMarkerTs,
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
  final LoggingService _logging;
  final InboundQueue _queue;
  final PendingDecryptionPen _pen;
  final QueueMarkerSeeder _seeder;
  final QueueApplyAdapter _applyAdapter;
  late final InboundWorker _worker;
  late final BridgeCoordinator _bridge;

  StreamSubscription<Event>? _liveSub;
  StreamSubscription<SyncUpdate>? _syncSub;
  bool _started = false;

  /// Tracks in-flight `enqueueLive` calls spawned from the live
  /// subscription so `stop()` can await every outstanding write. Without
  /// this, a racy shutdown can dispose the queue while a producer is
  /// mid-insert and trip drift's "used after close" guard.
  final Set<Future<void>> _inFlightEnqueues = <Future<void>>{};

  /// Tracks which room ids we have un-partialled via `room.postLoad()`
  /// so we only pay the DB load cost once per room.
  final Set<String> _postLoadedRoomIds = <String>{};

  InboundQueue get queue => _queue;
  InboundWorker get worker => _worker;

  bool get isRunning => _started;

  /// Manually triggers a bridge pass (equivalent to a `limited=true`
  /// sync arriving). Exposed so the "Catch up now" action in the Sync
  /// Settings UI can force a /messages walk back to the stored
  /// marker without waiting for the next organic `limited=true`.
  Future<void> triggerBridge() => _bridge.bridgeNow();

  Future<void> start() async {
    if (_started) return;

    final roomId = _roomManager.currentRoomId;
    if (roomId != null) {
      // Seed + prune are best-effort one-shots. If they throw (e.g. a
      // transient SQLite error) the worker + bridge should still come
      // up — next call to `start()` re-runs seed/prune, and a future
      // session sweep can catch up. A throw that aborts `start()`
      // would leave `_started = false` and every subsequent caller
      // would get the same behaviour; swallow-and-log keeps the
      // pipeline from being dead-in-the-water.
      try {
        await _seeder.seedIfAbsent(roomId);
        await _queue.pruneStrandedEntries(roomId);
      } catch (error, stackTrace) {
        _logging.captureException(
          error,
          domain: _logDomain,
          subDomain: '$_logSub.start.seed',
          stackTrace: stackTrace,
        );
      }
    } else {
      _logging.captureEvent(
        'queue.coordinator.start.noRoom',
        domain: _logDomain,
        subDomain: _logSub,
      );
    }

    // Flip `_started` only after the live subscription, bridge and
    // worker are fully attached, so a throw from any of them leaves
    // the coordinator in the "not started" state and a caller can
    // retry `start()`. The unwind catch below mops up whatever did
    // come up before the failure.
    try {
      _liveSub = _sessionManager.timelineEvents.listen(_handleLiveEvent);
      // Subscribe to onSync so we can un-partial the current room
      // (via `room.postLoad()`) the first time we see it. Without
      // this, Matrix SDK skips `RoomMember` state events on partial
      // rooms — so `_trackedUserIds` never grows to include new
      // joiners, `updateUserDeviceKeys` never queries their keys,
      // and SAS / E2EE cannot discover them. The legacy signal
      // binder relied on `room.getTimeline(onNewEvent: …)` for this
      // side effect; the queue pipeline replicates the un-partial
      // step on its own, independent of timeline subscriptions.
      _syncSub = _sessionManager.client.onSync.stream.listen(
        (_) => _maybePostLoadCurrentRoom(),
        onError: (Object error, StackTrace stackTrace) {
          _logging.captureException(
            error,
            domain: _logDomain,
            subDomain: '$_logSub.syncSub',
            stackTrace: stackTrace,
          );
        },
      );
      _bridge.start();
      await _worker.start();
      _started = true;
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.start',
        stackTrace: stackTrace,
      );
      await _liveSub?.cancel();
      _liveSub = null;
      await _syncSub?.cancel();
      _syncSub = null;
      try {
        await _bridge.stop();
      } catch (_) {
        // Already logged on the bridge side; no recovery available.
      }
      try {
        await _worker.stop();
      } catch (_) {
        // Same: log-and-continue so unwind always completes.
      }
      rethrow;
    }

    _logging.captureEvent(
      'queue.coordinator.started roomId=${roomId ?? 'null'}',
      domain: _logDomain,
      subDomain: _logSub,
    );
  }

  /// Stops every collaborator in the reverse order they were started.
  /// If [drainFirst] is true (the flag-off flow), the worker drains
  /// the queue to completion before the coordinator tears down — this
  /// closes the F7 data-loss hole the design review flagged.
  ///
  /// Every teardown step is wrapped in its own try/catch so a throw
  /// from one stage cannot orphan the stages that follow. `_started`
  /// is flipped only after the full best-effort cleanup so a thrown
  /// teardown leaves the coordinator in a state a caller can retry
  /// `stop()` against, rather than a half-dismantled one where the
  /// second `stop()` is a no-op.
  Future<void> stop({bool drainFirst = false}) async {
    if (!_started) return;

    Future<void> tryRun(
      String stage,
      Future<void> Function() action,
    ) async {
      try {
        await action();
      } catch (error, stackTrace) {
        _logging.captureException(
          error,
          domain: _logDomain,
          subDomain: '$_logSub.stop.$stage',
          stackTrace: stackTrace,
        );
      }
    }

    try {
      await tryRun('liveSub', () async {
        await _liveSub?.cancel();
        _liveSub = null;
      });
      await tryRun('syncSub', () async {
        await _syncSub?.cancel();
        _syncSub = null;
      });
      // Wait for fire-and-forget enqueues spawned from the now-
      // cancelled subscription before we tear the queue down.
      if (_inFlightEnqueues.isNotEmpty) {
        await tryRun(
          'inFlightEnqueues',
          () async => Future.wait(_inFlightEnqueues.toList()),
        );
      }
      await tryRun('bridge', _bridge.stop);

      if (drainFirst) {
        await tryRun('drain', _worker.drainToCompletion);
      }

      await tryRun('worker', _worker.stop);
      await tryRun('pen', _pen.stop);
      await tryRun('queue', _queue.dispose);
    } finally {
      _started = false;
    }

    _logging.captureEvent(
      'queue.coordinator.stopped drainFirst=$drainFirst',
      domain: _logDomain,
      subDomain: _logSub,
    );
  }

  void _handleLiveEvent(Event event) {
    final currentRoomId = _roomManager.currentRoomId;
    if (currentRoomId == null || event.roomId != currentRoomId) return;
    // Un-partial the Matrix SDK's room — otherwise `RoomMember` state
    // events arriving via /sync are silently skipped (see
    // `client.dart:3138` in matrix-7.0.0), which leaves
    // `_trackedUserIds` empty and breaks device-key discovery / SAS
    // / E2EE for new joiners. Share the `_maybePostLoadCurrentRoom`
    // check with the onSync listener so either path triggers it.
    _maybePostLoadCurrentRoom();
    // F3: encrypted events live in the pen until decryption completes;
    // the worker's decryptionPen flush on every drain iteration picks
    // them up as soon as the SDK has the session key.
    if (_pen.hold(event)) return;
    _trackEnqueue(_safeEnqueue(event));
  }

  Future<void> _safePostLoad(Room room, String roomId) async {
    final wasPartial = room.partial;
    try {
      await room.postLoad();
      _logging.captureEvent(
        'queue.coordinator.postLoad roomId=$roomId '
        'wasPartial=$wasPartial nowPartial=${room.partial}',
        domain: _logDomain,
        subDomain: '$_logSub.postLoad',
      );
    } catch (error, stackTrace) {
      // If the post-load fails, drop the "done" marker so a later
      // event retries. Device discovery is important enough to retry.
      _postLoadedRoomIds.remove(roomId);
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.postLoad',
        stackTrace: stackTrace,
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
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.enqueue',
        stackTrace: stackTrace,
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

  /// Walks the current room's entire visible history into the queue
  /// through a [QueueBootstrapSink], awaiting drain back-pressure
  /// between pages. Invoked by the "Fetch all history" action in the
  /// Sync Settings page. The caller receives a
  /// [BootstrapPageInfo] via [onProgress] after every page and can
  /// pre-empt pagination by completing [cancelSignal].
  ///
  /// Throws [StateError] if no sync room is currently joined.
  Future<BootstrapResult> collectHistory({
    void Function(BootstrapPageInfo info)? onProgress,
    Future<void>? cancelSignal,
    Duration? overallTimeout,
  }) async {
    final room = await _resolveRoom();
    if (room == null) {
      throw StateError('collectHistory: no current room');
    }
    final sink = _ProgressForwardingSink(
      inner: QueueBootstrapSink(
        queue: _queue,
        logging: _logging,
        cancelSignal: cancelSignal,
      ),
      onProgress: onProgress,
    );
    return CatchUpStrategy.collectHistoryForBootstrap(
      room: room,
      sink: sink,
      logging: _logging,
      overallTimeout: overallTimeout,
    );
  }

  /// Streams the room's visible history through [QueueBootstrapSink]
  /// (page-by-page with back-pressure) into the queue. Invoked by
  /// [BridgeCoordinator] for every catch-up:
  ///
  /// - `untilTimestamp == null`: fresh client — walk the entire
  ///   visible history. Stops when the server runs out.
  /// - `untilTimestamp != null`: reconnect — stop after the first
  ///   page whose oldest event timestamp is at or below the marker.
  ///
  /// Returns `true` when the walk completed (server exhausted OR
  /// boundary reached) and `false` on sink cancellation / pagination
  /// error so the bridge can schedule a bounded retry.
  Future<bool> _runBootstrap({
    required Room room,
    required num? untilTimestamp,
  }) async {
    final sink = QueueBootstrapSink(
      queue: _queue,
      logging: _logging,
    );
    final result = await CatchUpStrategy.collectHistoryForBootstrap(
      room: room,
      sink: sink,
      logging: _logging,
      untilTimestamp: untilTimestamp,
    );
    return switch (result.stopReason) {
      BootstrapStopReason.serverExhausted ||
      BootstrapStopReason.boundaryReached => true,
      BootstrapStopReason.sinkCancelled || BootstrapStopReason.error => false,
    };
  }

  Future<int?> _readMarkerTs() async {
    final roomId = _roomManager.currentRoomId;
    if (roomId == null) return null;
    final marker = await (_syncDb.select(
      _syncDb.queueMarkers,
    )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();
    if (marker != null && marker.lastAppliedTs > 0) {
      return marker.lastAppliedTs;
    }
    return getLastReadMatrixEventTs(_settingsDb);
  }
}

class _ProgressForwardingSink implements BootstrapSink {
  _ProgressForwardingSink({
    required BootstrapSink inner,
    this.onProgress,
  }) : _inner = inner;

  final BootstrapSink _inner;
  final void Function(BootstrapPageInfo info)? onProgress;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    // `onProgress` is purely observational (UI progress dot, log line).
    // A throw from the callback — e.g. `setState` on an unmounted
    // widget — must not abort `collectHistoryForBootstrap` mid-walk
    // and leave the queue partially filled. Swallow-and-continue.
    try {
      onProgress?.call(info);
    } catch (_) {
      // Intentionally empty: progress is diagnostic, not load-bearing.
    }
    return _inner.onPage(events, info);
  }
}
