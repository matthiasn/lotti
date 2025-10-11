import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

class SyncReadMarkerService {
  SyncReadMarkerService({
    required SettingsDb settingsDb,
    required LoggingService loggingService,
  })  : _settingsDb = settingsDb,
        _loggingService = loggingService;

  final SettingsDb _settingsDb;
  final LoggingService _loggingService;

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
