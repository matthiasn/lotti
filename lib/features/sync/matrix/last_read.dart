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

Future<void> setLastReadMatrixEventTs(
  int tsMillis,
  SettingsDb settingsDb,
) =>
    settingsDb.saveSettingsItem(
      lastReadMatrixEventTs,
      tsMillis.toString(),
    );

Future<int?> getLastReadMatrixEventTs(SettingsDb settingsDb) async {
  final v = await settingsDb.itemByKey(lastReadMatrixEventTs);
  if (v == null) return null;
  return int.tryParse(v);
}
