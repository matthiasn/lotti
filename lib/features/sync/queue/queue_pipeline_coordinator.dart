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
import 'package:lotti/features/sync/queue/bootstrap_sink.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/features/sync/queue/queue_marker_seeder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

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
    AttachmentIndex? attachmentIndex,
    UpdateNotifications? updateNotifications,
    AttachmentIngestor? attachmentIngestor,
    SentEventRegistry? sentEventRegistry,
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
       _attachmentIndex = attachmentIndex,
       _updateNotifications = updateNotifications,
       _attachmentIngestor = attachmentIngestor,
       _sentEventRegistry = sentEventRegistry,
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

  StreamSubscription<Event>? _liveSub;
  StreamSubscription<SyncUpdate>? _syncSub;
  StreamSubscription<String>? _attachmentPathSub;
  StreamSubscription<Set<String>>? _journalUpdateSub;
  bool _started = false;

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

  Future<void> _safeStartupBridge() async {
    try {
      await _bridge.bridgeNow();
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.startupBridge',
        stackTrace: stackTrace,
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
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.onRoomChanged',
        stackTrace: stackTrace,
      );
    }
    _logging.captureEvent(
      'queue.coordinator.onRoomChanged roomId=$roomId',
      domain: _logDomain,
      subDomain: _logSub,
    );
  }

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
      // Signal-driven resurrection of abandoned ledger rows. These
      // subscriptions convert out-of-band events (attachment JSON
      // landed, journal-db entry updated) into `resurrect*` calls so
      // a row that was retired by the worker's retry cap becomes
      // drainable again the instant its blocking dependency is
      // available — no polling, no user action required for the
      // common cases.
      _attachmentPathSub = _attachmentIndex?.pathRecorded.listen(
        (path) async {
          try {
            await _queue.resurrectByPath(path);
          } catch (error, stackTrace) {
            _logging.captureException(
              error,
              domain: _logDomain,
              subDomain: '$_logSub.resurrectByPath',
              stackTrace: stackTrace,
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _logging.captureException(
            error,
            domain: _logDomain,
            subDomain: '$_logSub.pathRecorded',
            stackTrace: stackTrace,
          );
        },
      );
      _journalUpdateSub = _updateNotifications?.updateStream.listen(
        (_) async {
          try {
            await _queue.resurrectByReason('missingBase');
          } catch (error, stackTrace) {
            _logging.captureException(
              error,
              domain: _logDomain,
              subDomain: '$_logSub.resurrectByReason',
              stackTrace: stackTrace,
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _logging.captureException(
            error,
            domain: _logDomain,
            subDomain: '$_logSub.journalUpdates',
            stackTrace: stackTrace,
          );
        },
      );
      _started = true;
      // Phase-2 equivalent of the legacy pipeline's 300 ms startup
      // `forceRescan`. `connect()` runs before `_maybeStartQueuePipeline`
      // in `MatrixService.init`, so events delivered during the login
      // round trip land on a coordinator that was not yet subscribed.
      // The bridge otherwise only fires on organic `limited=true` syncs;
      // on reconnects where the server does not flag the timeline as
      // limited, those events would be silently missed. Fire-and-forget
      // so `start()` does not block on a slow /messages walk.
      if (roomId != null) {
        unawaited(_safeStartupBridge());
      }
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
      await _attachmentPathSub?.cancel();
      _attachmentPathSub = null;
      await _journalUpdateSub?.cancel();
      _journalUpdateSub = null;
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
  Future<void> drainUntilEmpty({Duration? timeout}) async {
    final deadline = clock.now().add(timeout ?? drainUntilEmptyTimeout);
    while (true) {
      // 1. Flush the pen first so any event the SDK has decrypted
      //    since the last sweep lands in the queue before we ask it
      //    for stats — otherwise the loop can declare the queue empty
      //    while held events are waiting to enter it.
      final room = await _resolveRoom();
      if (room != null) {
        try {
          await _pen.flushInto(queue: _queue, room: room);
        } catch (error, stackTrace) {
          _logging.captureException(
            error,
            domain: _logDomain,
            subDomain: '$_logSub.drainUntilEmpty.pen',
            stackTrace: stackTrace,
          );
        }
      }

      // 2. Apply every row that is ready right now.
      try {
        await _worker.drainToCompletion();
      } catch (error, stackTrace) {
        _logging.captureException(
          error,
          domain: _logDomain,
          subDomain: '$_logSub.drainUntilEmpty.drain',
          stackTrace: stackTrace,
        );
      }

      final stats = await _queue.stats();
      if (stats.total == 0 && _pen.size == 0) {
        _logging.captureEvent(
          'queue.coordinator.drainUntilEmpty.done',
          domain: _logDomain,
          subDomain: _logSub,
        );
        return;
      }

      final remaining = deadline.difference(clock.now());
      if (!remaining.isNegative && remaining > Duration.zero) {
        // Prefer the queue's own scheduling signal over a fixed poll.
        final readyAtMs = await _queue.earliestReadyAt();
        Duration wait;
        if (readyAtMs == null) {
          // Nothing in the queue but the pen is non-empty — the pen has
          // its own sweep interval, so back off for a short tick and
          // re-flush rather than busy-loop.
          wait = const Duration(milliseconds: 200);
        } else {
          final nowMs = clock.now().millisecondsSinceEpoch;
          wait = Duration(milliseconds: math.max(0, readyAtMs - nowMs));
        }
        final capped = wait > remaining ? remaining : wait;
        if (capped > Duration.zero) {
          await Future<void>.delayed(capped);
        }
      }

      if (!clock.now().isBefore(deadline)) {
        _logging.captureEvent(
          'queue.coordinator.drainUntilEmpty.timeout '
          'remaining=${stats.total} penSize=${_pen.size}',
          domain: _logDomain,
          subDomain: _logSub,
        );
        return;
      }
    }
  }

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
      await tryRun('attachmentPathSub', () async {
        await _attachmentPathSub?.cancel();
        _attachmentPathSub = null;
      });
      await tryRun('journalUpdateSub', () async {
        await _journalUpdateSub?.cancel();
        _journalUpdateSub = null;
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

      final gapRecovery = _gapRecoveryInFlight;
      if (gapRecovery != null) {
        await tryRun('gapRecovery', () async => gapRecovery);
      }

      if (drainFirst) {
        await tryRun('drain', drainUntilEmpty);
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
    // Self-echo suppression: every message this device sends via the
    // outbox comes right back through the live timeline. Without this
    // check the queue enqueues, prepares and applies every self-sent
    // event — on a large outbox drain that floods the worker with
    // tens of thousands of self-echoes, re-downloads their
    // attachments, and hammers the DB for no net work (the local VC
    // already dominates). The legacy pipeline consulted
    // `SentEventRegistry` for the same reason; wire it here too. Lotti
    // uses a single shared Matrix userID across devices so a
    // `senderId == client.userID` check would also drop legitimate
    // peer events — the registry is the only correct source of truth.
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
        // The queue pipeline does not use the legacy descriptor
        // catch-up manager — missing-descriptor retries are driven
        // by `AttachmentIndex.pathRecorded` → `queue.resurrectByPath`.
        descriptorCatchUp: null,
        // Neither callback has a queue-side analogue:
        //  - `scheduleLiveScan` is for the legacy scan loop.
        //  - `retryNow` is subsumed by the resurrection signal fan-out.
        scheduleLiveScan: _noopScheduleLiveScan,
        retryNow: _noopRetryNow,
        // Queue the download so a burst of attachment events does
        // not serialize one download at a time; the ingestor's
        // internal concurrency cap bounds the parallel count.
        scheduleDownload: true,
      );
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.attachmentIngestor',
        stackTrace: stackTrace,
      );
    }
  }

  void _noopScheduleLiveScan() {}

  Future<void> _noopRetryNow() async {}

  void _countSuppressedSelfEcho() {
    _suppressedSelfEchoes++;
    final now = DateTime.now();
    final last = _lastSuppressedLogAt;
    if (last == null || now.difference(last) >= _suppressionLogInterval) {
      final flushed = _suppressedSelfEchoes;
      _suppressedSelfEchoes = 0;
      _lastSuppressedLogAt = now;
      _logging.captureEvent(
        'queue.coordinator.selfEchoSuppressed count=$flushed',
        domain: _logDomain,
        subDomain: '$_logSub.selfEcho',
      );
    }
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
    // Wrap the queue sink so attachment descriptor events in each
    // paginated page get fed to `AttachmentIngestor.process()` before
    // the queue's own enqueue drops them as non-payload. Without
    // this, catch-up on a room with historical attachments would
    // enqueue the sync-payload events while their descriptor
    // JSONs never land on disk, producing the pendingAttachment
    // skip cascade we just fixed.
    final innerSink = _attachmentIngestor == null
        ? QueueBootstrapSink(queue: _queue, logging: _logging)
        : _AttachmentAwareBootstrapSink(
                inner: QueueBootstrapSink(queue: _queue, logging: _logging),
                processAttachment: _processAttachment,
              )
              as BootstrapSink;
    // Count accepted events across every page so we can detect the
    // "boundaryReached with totalAccepted==0" case that marks the
    // bridge barren — the gap-recovery trigger reads this flag.
    final countingSink = _TotalAcceptedCountingSink(innerSink);
    final result = await CatchUpStrategy.collectHistoryForBootstrap(
      room: room,
      sink: countingSink,
      logging: _logging,
      untilTimestamp: untilTimestamp,
    );
    _updateBarrenBridgeFlag(
      untilTimestamp: untilTimestamp,
      result: result,
      totalAccepted: countingSink.totalAccepted,
    );
    return switch (result.stopReason) {
      BootstrapStopReason.serverExhausted ||
      BootstrapStopReason.boundaryReached => true,
      BootstrapStopReason.sinkCancelled || BootstrapStopReason.error => false,
    };
  }

  void _updateBarrenBridgeFlag({
    required num? untilTimestamp,
    required BootstrapResult result,
    required int totalAccepted,
  }) {
    // Only reconnect-mode walks (bounded by `untilTimestamp`) can be
    // barren. A fresh-client walk (`untilTimestamp == null`) that
    // accepts nothing just means the server has nothing for us — a
    // later gap cannot be recovered by re-running the same walk.
    if (untilTimestamp == null) {
      _lastBarrenBridgeAt = null;
      return;
    }
    final isBarren =
        result.stopReason == BootstrapStopReason.boundaryReached &&
        totalAccepted == 0;
    if (isBarren) {
      _lastBarrenBridgeAt = clock.now();
      _logging.captureEvent(
        'queue.coordinator.bridgeBarren '
        'untilTimestamp=$untilTimestamp totalPages=${result.totalPages} '
        'totalEvents=${result.totalEvents}',
        domain: _logDomain,
        subDomain: _logSub,
      );
    } else {
      // Any productive bridge clears the flag so a later gap is not
      // attributed to a long-since-healed cache wedge.
      _lastBarrenBridgeAt = null;
    }
  }

  /// Triggered from the sequence-log gap-detected callback. When the
  /// most recent bridge finished barren (boundary reached, zero
  /// accepted) and a live event's vector clock now reveals a missing
  /// counter, close the hole aggressively by running an unbounded
  /// history walk instead of waiting for the normal backfill cadence.
  ///
  /// Fire-and-forget from the caller's perspective — the sequence
  /// log's `onMissingEntriesDetected` is `void`. A concurrent trigger
  /// coalesces onto the in-flight recovery so a burst of gap signals
  /// does not spawn parallel /messages walks.
  void maybeStartGapRecovery() {
    if (!_started) return;
    if (_gapRecoveryInFlight != null) return;
    final at = _lastBarrenBridgeAt;
    if (at == null) return;
    if (clock.now().difference(at) > barrenBridgeTtl) {
      _lastBarrenBridgeAt = null;
      return;
    }
    // Consume the signal up-front. If the recovery walk itself finds
    // nothing and leaves the cache still wedged, the next live event
    // will not re-trigger until a new barren bridge arrives — which
    // is the right behaviour: we already tried the unbounded walk
    // once and burning a second one immediately wastes the peer's
    // /messages quota without new information.
    _lastBarrenBridgeAt = null;
    final completer = Completer<void>();
    _gapRecoveryInFlight = completer.future;
    unawaited(
      _runGapRecovery().whenComplete(() {
        _gapRecoveryInFlight = null;
        completer.complete();
      }),
    );
  }

  Future<void> _runGapRecovery() async {
    try {
      final room = await _resolveRoom();
      if (room == null) {
        _logging.captureEvent(
          'queue.coordinator.gapRecovery.skip reason=noRoom',
          domain: _logDomain,
          subDomain: _logSub,
        );
        return;
      }
      _logging.captureEvent(
        'queue.coordinator.gapRecovery.start',
        domain: _logDomain,
        subDomain: _logSub,
      );
      final completed = await _runBootstrap(room: room, untilTimestamp: null);
      _logging.captureEvent(
        'queue.coordinator.gapRecovery.done completed=$completed',
        domain: _logDomain,
        subDomain: _logSub,
      );
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.gapRecovery',
        stackTrace: stackTrace,
      );
    }
  }

  @visibleForTesting
  bool get hasBarrenBridgeSignal => _lastBarrenBridgeAt != null;

  @visibleForTesting
  bool get gapRecoveryInFlight => _gapRecoveryInFlight != null;

  @visibleForTesting
  Future<void>? get gapRecoveryFuture => _gapRecoveryInFlight;

  /// Test-only entry point for `_runBootstrap`. Lets tests exercise the
  /// barren-tracking + gap-recovery logic without wiring a real
  /// [BridgeCoordinator] — the `triggerBridge` path funnels through the
  /// live `onSync` listener and computes `untilTimestamp` itself, which
  /// makes it awkward to pin down a test scenario.
  @visibleForTesting
  Future<bool> runBootstrapForTest({
    required Room room,
    required num? untilTimestamp,
  }) => _runBootstrap(room: room, untilTimestamp: untilTimestamp);

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
  int? get lastAcceptedCount => _inner.lastAcceptedCount;

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

/// Bootstrap sink wrapper that funnels each paginated event through
/// the coordinator's attachment ingestor *before* forwarding to the
/// inner sink. This is the catch-up equivalent of the live-stream
/// `_handleLiveEvent` hook: every attachment descriptor observed
/// during `collectHistoryForBootstrap` is recorded + downloaded so
/// the companion sync-payload events that the inner sink enqueues
/// have their JSON on disk by the time the worker applies them.
///
/// `processAttachment` is fire-and-forget — the ingestor queues its
/// own downloads and must not block pagination. The inner sink's
/// return value flows through unchanged.
class _AttachmentAwareBootstrapSink implements BootstrapSink {
  _AttachmentAwareBootstrapSink({
    required BootstrapSink inner,
    required Future<void> Function(Event event) processAttachment,
  }) : _inner = inner,
       _processAttachment = processAttachment;

  final BootstrapSink _inner;
  final Future<void> Function(Event event) _processAttachment;

  @override
  int? get lastAcceptedCount => _inner.lastAcceptedCount;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    for (final event in events) {
      // `processAttachment` is internally a no-op for non-attachment
      // events (the ingestor checks `content['relativePath']`). Fire
      // them all and let the ingestor decide.
      unawaited(_processAttachment(event));
    }
    return _inner.onPage(events, info);
  }
}

/// Accumulates the inner sink's `lastAcceptedCount` across every page
/// so the coordinator can tell whether a bridge pass accepted zero
/// events overall — the precise signal that a reconnect catch-up
/// wedged on a stale SDK cache and the gap-recovery unbounded walk
/// needs to fire on the next live gap. Pure pass-through otherwise.
class _TotalAcceptedCountingSink implements BootstrapSink {
  _TotalAcceptedCountingSink(this._inner);

  final BootstrapSink _inner;
  int totalAccepted = 0;

  @override
  int? get lastAcceptedCount => _inner.lastAcceptedCount;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    final shouldContinue = await _inner.onPage(events, info);
    final accepted = _inner.lastAcceptedCount;
    if (accepted != null) totalAccepted += accepted;
    return shouldContinue;
  }
}
