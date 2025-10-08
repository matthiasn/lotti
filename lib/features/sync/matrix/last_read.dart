import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';

Future<void> setLastReadMatrixEventId(
  String eventId,
  SettingsDb settingsDb,
) =>
    settingsDb.saveSettingsItem(
      lastReadMatrixEventId,
      eventId,
    );

Future<String?> getLastReadMatrixEventId(SettingsDb settingsDb) =>
    settingsDb.itemByKey(lastReadMatrixEventId);
