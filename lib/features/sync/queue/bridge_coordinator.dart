import 'dart:async';

import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/sdk_pagination_compat.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

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
       _maxLookback = maxLookback;

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

  StreamSubscription<SyncUpdate>? _sub;
  bool _inFlight = false;
  bool _pendingRerun = false;

  bool get isRunning => _sub != null;

  void start() {
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
    await _sub?.cancel();
    _sub = null;
  }

  /// Runs a bridge pass explicitly, bypassing the onSync listener.
  /// Used by `MatrixService.forceRescan(includeCatchUp: true)` and by
  /// tests.
  Future<void> bridgeNow() => _bridge();

  void _handle(SyncUpdate sync) {
    final roomId = _currentRoomId();
    if (roomId == null) return;
    final joined = sync.rooms?.join?[roomId];
    if (joined?.timeline?.limited != true) return;
    unawaited(_bridge());
  }

  Future<void> _bridge() async {
    if (_inFlight) {
      _pendingRerun = true;
      return;
    }
    _inFlight = true;
    try {
      await _runBridgeOnce();
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.run',
        stackTrace: stackTrace,
      );
    } finally {
      _inFlight = false;
      if (_pendingRerun) {
        _pendingRerun = false;
        unawaited(_bridge());
      }
    }
  }

  Future<void> _runBridgeOnce() async {
    final room = await _resolveRoom();
    if (room == null) {
      _logging.captureEvent(
        'queue.bridge.skip reason=noRoom',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return;
    }
    final lastEventId = await _getLastReadEventId();
    final lastTs = await _getLastReadTs();
    if (lastEventId == null || lastTs == null) {
      _logging.captureEvent(
        'queue.bridge.skip reason=noMarker',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return;
    }

    final collection = await CatchUpStrategy.collectEventsForCatchUp(
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
        'queue.bridge.empty snapshotSize=${collection.snapshotSize}',
        domain: _logDomain,
        subDomain: _logSub,
      );
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
  }
}
