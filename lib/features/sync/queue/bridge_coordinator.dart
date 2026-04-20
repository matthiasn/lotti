import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/sdk_pagination_compat.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Test seam: lets unit tests substitute `CatchUpStrategy`
/// deterministically instead of wiring a full room timeline mock.
@visibleForTesting
typedef CatchUpCollector =
    Future<CatchUpCollection> Function({
      required Room room,
      required String? lastEventId,
      required BackfillFn backfill,
      required LoggingService logging,
      required num preContextSinceTs,
      required int preContextCount,
      required int maxLookback,
    });

const _logDomain = 'sync';
const _logSub = 'queue.bridge';

/// Owns the "limited=true" bridge call for the queue-based pipeline.
/// Subscribes to [Client.onSync], filters to the current room, and
/// (when the sync response arrives with `timeline.limited == true`)
/// invokes [CatchUpStrategy.collectEventsForCatchUp] to pull the
/// gap-span events from the Matrix /messages endpoint, then feeds
/// them into [InboundQueue.enqueueBatch] under
/// `InboundEventProducer.bridge`.
///
/// Single-flight: a second limited-sync that fires while a bridge
/// call is still in-flight is coalesced. The coordinator remembers
/// that another trigger arrived and, once the current bridge
/// completes, re-runs exactly once. This mirrors the legacy
/// pipeline's `_catchUpInFlight` semantics without using a mutable
/// flag stored across three collaborators.
class BridgeCoordinator {
  BridgeCoordinator({
    required Client client,
    required String? Function() currentRoomId,
    required Future<Room?> Function() resolveRoom,
    required InboundQueue queue,
    required Future<String?> Function() getLastReadEventId,
    required Future<int?> Function() getLastReadTs,
    required LoggingService logging,
    BackfillFn? backfill,
    Duration preContextMargin = const Duration(seconds: 1),
    int preContextCount = 20,
    int maxLookback = SyncTuning.catchupMaxLookback,
    Duration incompleteRetryDelay = const Duration(seconds: 10),
    int maxIncompleteRetries = 3,
    @visibleForTesting CatchUpCollector? catchUpCollector,
  }) : _client = client,
       _currentRoomId = currentRoomId,
       _resolveRoom = resolveRoom,
       _queue = queue,
       _getLastReadEventId = getLastReadEventId,
       _getLastReadTs = getLastReadTs,
       _logging = logging,
       _backfill = backfill ?? SdkPaginationCompat.backfillUntilContains,
       _preContextMargin = preContextMargin,
       _preContextCount = preContextCount,
       _maxLookback = maxLookback,
       _incompleteRetryDelay = incompleteRetryDelay,
       _maxIncompleteRetries = maxIncompleteRetries,
       _catchUpCollector =
           catchUpCollector ?? CatchUpStrategy.collectEventsForCatchUp;

  final Client _client;
  final String? Function() _currentRoomId;
  final Future<Room?> Function() _resolveRoom;
  final InboundQueue _queue;
  final Future<String?> Function() _getLastReadEventId;
  final Future<int?> Function() _getLastReadTs;
  final LoggingService _logging;
  final BackfillFn _backfill;
  final Duration _preContextMargin;
  final int _preContextCount;
  final int _maxLookback;
  final Duration _incompleteRetryDelay;
  final int _maxIncompleteRetries;
  final CatchUpCollector _catchUpCollector;

  StreamSubscription<SyncUpdate>? _sub;
  Future<void>? _inFlightBridge;
  bool _pendingRerun = false;
  String? _pendingRerunRoomId;
  bool _stopped = false;
  int _consecutiveIncomplete = 0;
  Timer? _incompleteRetryTimer;

  bool get isRunning => _sub != null;

  void start() {
    _stopped = false;
    _sub ??= _client.onSync.stream.listen(
      _handle,
      onError: (Object error, StackTrace stackTrace) {
        _logging.captureException(
          error,
          domain: _logDomain,
          subDomain: '$_logSub.subscription',
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> stop() async {
    _stopped = true;
    _pendingRerun = false;
    _incompleteRetryTimer?.cancel();
    _incompleteRetryTimer = null;
    _consecutiveIncomplete = 0;
    await _sub?.cancel();
    _sub = null;
    // Await the in-flight bridge so enqueue/capture calls cannot land
    // on a disposed queue after the owner considers shutdown complete.
    final current = _inFlightBridge;
    if (current != null) {
      try {
        await current;
      } catch (_) {
        // Already logged inside `_bridge()`.
      }
    }
  }

  /// Runs a bridge pass explicitly, bypassing the onSync listener.
  /// Used by `MatrixService.forceRescan(includeCatchUp: true)` and by
  /// tests.
  Future<void> bridgeNow() => _bridge(_currentRoomId());

  void _handle(SyncUpdate sync) {
    if (_stopped) return;
    final roomId = _currentRoomId();
    if (roomId == null) return;
    final joined = sync.rooms?.join?[roomId];
    if (joined?.timeline?.limited != true) return;
    // Carry the room id that triggered this limited-sync through the
    // async bridge pass: if the user switches sync rooms (or a
    // settings flip changes `_currentRoomId`) between the trigger and
    // `_runBridgeOnce` resolving a Room, we must not end up running a
    // catch-up against the wrong room.
    unawaited(_bridge(roomId));
  }

  Future<void> _bridge(String? expectedRoomId) async {
    if (_stopped) return;
    if (_inFlightBridge != null) {
      _pendingRerun = true;
      // Remember the room id of the most recent trigger so the rerun
      // after the in-flight pass completes targets the latest room,
      // not a stale one captured on an earlier iteration.
      _pendingRerunRoomId = expectedRoomId;
      return;
    }
    final completer = Completer<void>();
    _inFlightBridge = completer.future;
    try {
      await _runBridgeOnce(expectedRoomId);
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.run',
        stackTrace: stackTrace,
      );
    } finally {
      _inFlightBridge = null;
      completer.complete();
      if (_pendingRerun && !_stopped) {
        _pendingRerun = false;
        final rerunRoomId = _pendingRerunRoomId;
        _pendingRerunRoomId = null;
        unawaited(_bridge(rerunRoomId));
      } else {
        _pendingRerun = false;
        _pendingRerunRoomId = null;
      }
    }
  }

  Future<void> _runBridgeOnce(String? expectedRoomId) async {
    final room = await _resolveRoom();
    if (room == null) {
      _logging.captureEvent(
        'queue.bridge.skip reason=noRoom',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return;
    }
    if (expectedRoomId != null && room.id != expectedRoomId) {
      // The selected sync room changed between the trigger and now;
      // abandon this pass rather than running catch-up against a
      // different room than the one whose `limited=true` sync
      // scheduled the work.
      _logging.captureEvent(
        'queue.bridge.skip reason=roomChanged '
        'expectedRoomId=$expectedRoomId actualRoomId=${room.id}',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return;
    }
    final lastEventId = await _getLastReadEventId();
    final lastTs = await _getLastReadTs();
    // CatchUpStrategy.collectEventsForCatchUp treats lastEventId as
    // legacy/debug context — its real anchor is the timestamp. The
    // processor intentionally leaves `lastReadMatrixEventId` null after
    // applying a placeholder/non-durable event while still advancing
    // `lastReadMatrixEventTs`, so gating on lastEventId would skip
    // bridge catch-up for a reconnect in that legitimate state. Only
    // the timestamp is a hard requirement.
    if (lastTs == null) {
      _logging.captureEvent(
        'queue.bridge.skip reason=noMarker',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return;
    }

    final collection = await _catchUpCollector(
      room: room,
      lastEventId: lastEventId,
      backfill: _backfill,
      logging: _logging,
      preContextSinceTs: lastTs - _preContextMargin.inMilliseconds,
      preContextCount: _preContextCount,
      maxLookback: _maxLookback,
    );

    if (collection.events.isEmpty) {
      _logging.captureEvent(
        'queue.bridge.empty snapshotSize=${collection.snapshotSize} '
        'incomplete=${collection.incomplete}',
        domain: _logDomain,
        subDomain: _logSub,
      );
      // Still evaluate the incomplete retry gate: an incomplete
      // collection can surface with empty events when the fallback
      // budget has been exhausted, and those are exactly the cases
      // where a bounded retry matters most.
      _handleIncompleteFollowUp(collection.incomplete, expectedRoomId);
      return;
    }

    final result = await _queue.enqueueBatch(
      collection.events,
      producer: InboundEventProducer.bridge,
    );

    _logging.captureEvent(
      'queue.bridge.done '
      'snapshotSize=${collection.snapshotSize} '
      'accepted=${result.accepted} '
      'dupes=${result.duplicatesDropped} '
      'filteredOutByType=${result.filteredOutByType} '
      'deferredPendingDecryption=${result.deferredPendingDecryption} '
      'incomplete=${collection.incomplete}',
      domain: _logDomain,
      subDomain: _logSub,
    );

    _handleIncompleteFollowUp(collection.incomplete, expectedRoomId);
  }

  /// Schedules a bounded retry when [CatchUpStrategy] reports an
  /// incomplete catch-up (the lookback budget was exhausted before the
  /// timestamp boundary was reached). Without this the only way older
  /// gap events are picked up is another limited-sync happening to
  /// arrive, which can leave gaps indefinitely on a quiet room.
  ///
  /// The retry targets the room that triggered the original bridge so
  /// a sync-room change during the retry delay cannot redirect the
  /// catch-up to a different room.
  void _handleIncompleteFollowUp(bool incomplete, String? expectedRoomId) {
    if (_stopped) return;
    if (!incomplete) {
      _consecutiveIncomplete = 0;
      _incompleteRetryTimer?.cancel();
      _incompleteRetryTimer = null;
      return;
    }
    _consecutiveIncomplete++;
    if (_consecutiveIncomplete > _maxIncompleteRetries) {
      _logging.captureEvent(
        'queue.bridge.incomplete.giveUp '
        'retries=$_consecutiveIncomplete',
        domain: _logDomain,
        subDomain: _logSub,
      );
      _consecutiveIncomplete = 0;
      return;
    }
    _incompleteRetryTimer?.cancel();
    _incompleteRetryTimer = Timer(_incompleteRetryDelay, () {
      _incompleteRetryTimer = null;
      if (_stopped) return;
      _logging.captureEvent(
        'queue.bridge.incomplete.retry '
        'attempt=$_consecutiveIncomplete',
        domain: _logDomain,
        subDomain: _logSub,
      );
      unawaited(_bridge(expectedRoomId));
    });
  }
}
