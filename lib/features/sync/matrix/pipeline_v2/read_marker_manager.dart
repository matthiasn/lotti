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

  void schedule(Room room, String eventId) {
    _pendingEventId = eventId;
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      final id = _pendingEventId;
      if (id == null) return;
      _pendingEventId = null;
      _onFlush(room, id).catchError((Object error, StackTrace stack) {
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
    _timer?.cancel();
  }
}
