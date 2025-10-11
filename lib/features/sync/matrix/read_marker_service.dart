import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

class SyncReadMarkerService {
  /// Persists and publishes Matrix read markers after successful processing.
  ///
  /// Prefers the room-level API (`Room.setReadMarker`) and only falls back to
  /// the timeline-level API when a snapshot is available. Updates are gated by
  /// `client.isLogged()` to avoid failures while the SDK is disconnected.
  SyncReadMarkerService({
    required SettingsDb settingsDb,
    required LoggingService loggingService,
  })  : _settingsDb = settingsDb,
        _loggingService = loggingService;

  final SettingsDb _settingsDb;
  final LoggingService _loggingService;

  /// Updates the read marker to [eventId] for the provided [room].
  ///
  /// - [client]: Matrix client used to check login state.
  /// - [room]: Target room for the read marker.
  /// - [eventId]: The event ID to advance the read marker to.
  /// - [timeline]: Optional timeline snapshot; used as a compatibility fallback
  ///   when the room-level update fails.
  Future<void> updateReadMarker({
    required Client client,
    required Room room,
    required String eventId,
    Timeline? timeline,
  }) async {
    await setLastReadMatrixEventId(
      eventId,
      _settingsDb,
    );

    if (client.isLogged()) {
      try {
        // Prefer room-level API to avoid coupling to a snapshot timeline.
        await room.setReadMarker(eventId);
      } catch (error, stackTrace) {
        // Fallback to timeline-level API for compatibility if provided.
        if (timeline != null) {
          try {
            await timeline.setReadMarker(eventId: eventId);
            return;
          } catch (_) {
            // Fall through to log the original error below.
          }
        }
        _loggingService.captureException(
          error,
          domain: 'MATRIX_SERVICE',
          subDomain: 'setReadMarker ${client.deviceName}',
          stackTrace: stackTrace,
        );
      }
    }
  }
}
