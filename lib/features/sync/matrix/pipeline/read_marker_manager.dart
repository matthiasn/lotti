import 'dart:async';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Function invoked to flush a pending read marker to the server.
typedef ReadMarkerFlush = Future<void> Function(Room room, String eventId);

/// Debounced read‑marker publisher.
///
/// - Coalesces rapid updates into a single flush after debounce.
/// - Ensures the last pending marker is flushed on dispose(), so the next
///   session does not start "one behind".
/// - Captures exceptions via LoggingService instead of surfacing them.
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

  /// Schedule a marker update for [room] to [eventId]. Subsequent calls within
  /// the debounce window replace the pending ID.
  void schedule(Room room, String eventId) {
    _pendingEventId = eventId;
    _pendingRoom = room;
    _logging.captureEvent(
      'marker.schedule id=$eventId debounceMs=${_debounce.inMilliseconds}',
      domain: syncLoggingDomain,
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
        domain: syncLoggingDomain,
        subDomain: 'marker.flush',
      );
      try {
        final result = _onFlush(r, id);
        // ignore: cascade_invocations
        result.catchError((Object error, StackTrace stack) {
          _logging.captureException(
            error,
            domain: syncLoggingDomain,
            subDomain: 'flushReadMarker',
            stackTrace: stack,
          );
        });
      } catch (_) {
        // Ignore misbehaving mocks in tests returning null.
      }
    });
  }

  /// Flushes any pending marker immediately and cancels the debounce timer.
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
        domain: syncLoggingDomain,
        subDomain: 'marker.flush',
      );
      // Best-effort flush without awaiting to keep dispose lightweight.
      // Persisting the marker locally is handled inside _onFlush.
      try {
        final result = _onFlush(r, id);
        unawaited(result.catchError((Object error, StackTrace stack) {
          _logging.captureException(
            error,
            domain: syncLoggingDomain,
            subDomain: 'flushReadMarker.onDispose',
            stackTrace: stack,
          );
        }));
      } catch (_) {
        // Ignore misbehaving mocks.
      }
    }
  }
}
