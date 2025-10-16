import 'dart:async';

import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

typedef ReadMarkerFlush = Future<void> Function(Room room, String eventId);

class ReadMarkerManager {
  ReadMarkerManager({
    required Duration debounce,
    required ReadMarkerFlush onFlush,
    required LoggingService logging,
  })  : _debounce = debounce,
        _onFlush = onFlush,
        _logging = logging;

  final Duration _debounce;
  final ReadMarkerFlush _onFlush;
  final LoggingService _logging;

  Timer? _timer;
  String? _pendingEventId;
  Room? _pendingRoom;

  void schedule(Room room, String eventId) {
    _pendingEventId = eventId;
    _pendingRoom = room;
    _logging.captureEvent(
      'marker.schedule id=$eventId debounceMs=${_debounce.inMilliseconds}',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'marker.schedule',
    );
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      final id = _pendingEventId;
      final r = _pendingRoom;
      if (id == null || r == null) return;
      _pendingEventId = null;
      _pendingRoom = null;
      _logging.captureEvent(
        'marker.flush id=$id',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'marker.flush',
      );
      _onFlush(r, id).catchError((Object error, StackTrace stack) {
        _logging.captureException(
          error,
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'flushReadMarker',
          stackTrace: stack,
        );
      });
    });
  }

  void dispose() {
    // If there is a pending marker when disposing, flush it synchronously to
    // avoid starting the next session one event behind.
    _timer?.cancel();
    final id = _pendingEventId;
    final r = _pendingRoom;
    _pendingEventId = null;
    _pendingRoom = null;
    if (id != null && r != null) {
      _logging.captureEvent(
        'marker.disposeFlush id=$id',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'marker.flush',
      );
      // Best-effort flush without awaiting to keep dispose lightweight.
      // Persisting the marker locally is handled inside _onFlush.
      unawaited(
        _onFlush(r, id).catchError((Object error, StackTrace stack) {
          _logging.captureException(
            error,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'flushReadMarker.onDispose',
            stackTrace: stack,
          );
        }),
      );
    }
  }
}
