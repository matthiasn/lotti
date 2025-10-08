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
    required Timeline timeline,
    required String eventId,
  }) async {
    await setLastReadMatrixEventId(
      eventId,
      _settingsDb,
    );

    final loginState = client.onLoginStateChanged.value;
    if (loginState == LoginState.loggedIn) {
      try {
        await timeline.setReadMarker(eventId: eventId);
      } catch (error, stackTrace) {
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
