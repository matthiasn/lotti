import 'dart:async';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Phase-0 diagnostic listener.
///
/// The queue pipeline (`QueuePipelineCoordinator` + `BridgeCoordinator`) owns
/// live ingestion. This binder only attaches the `sync.limited` observer used
/// by the queue as a reconnect trigger source and to log the gap since the
/// previous successful sync for the current sync room.
class MatrixStreamSignalBinder {
  MatrixStreamSignalBinder({
    required this._sessionManager,
    required this._roomManager,
    required this._loggingService,
  });

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;

  StreamSubscription<SyncUpdate>? _syncSub;

  // Tracks last successful sync response to correlate `limited=true` events
  // with the gap since the previous sync for the current sync room.
  DateTime? _lastSyncAt;

  Future<void> start() async {
    await _syncSub?.cancel();
    _syncSub = null;
    _lastSyncAt = null;

    // Detect `timeline.limited == true` for the current sync room. A
    // limited sync means the SDK truncated local timeline state and
    // delivered only the tail via onTimelineEvent; events before the
    // limited boundary are silently dropped unless we bridge them via
    // /messages. The queue's `BridgeCoordinator` consumes the same
    // signal to trigger catch-up.
    _syncSub = _sessionManager.client.onSync.stream.listen(
      (update) {
        final roomId = _roomManager.currentRoomId;
        final now = DateTime.now();
        final prev = _lastSyncAt;
        _lastSyncAt = now;
        if (roomId == null) return;
        final joined = update.rooms?.join?[roomId];
        final timeline = joined?.timeline;
        if (timeline == null || timeline.limited != true) return;
        final sinceMs = prev == null
            ? 'initial'
            : '${now.difference(prev).inMilliseconds}';
        _loggingService.captureEvent(
          'sync.limited roomId=$roomId '
          'prevBatch=${timeline.prevBatch} '
          'eventCount=${timeline.events?.length ?? 0} '
          'sinceMs=$sinceMs',
          domain: syncLoggingDomain,
          subDomain: 'sync.limited',
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _loggingService.captureException(
          error,
          domain: syncLoggingDomain,
          subDomain: 'sync.limited.stream',
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> dispose() async {
    await _syncSub?.cancel();
    _syncSub = null;
  }
}
