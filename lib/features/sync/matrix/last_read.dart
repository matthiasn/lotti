import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';

bool isServerAssignedMatrixEventId(String? eventId) =>
    eventId != null && eventId.startsWith(r'$');

Future<void> setLastReadMatrixEventId(
  String eventId,
  SettingsDb settingsDb,
) => settingsDb.saveSettingsItem(
  lastReadMatrixEventId,
  eventId,
);

Future<String?> getLastReadMatrixEventId(SettingsDb settingsDb) =>
    settingsDb.itemByKey(lastReadMatrixEventId);

Future<int?> getLastReadMatrixEventTs(SettingsDb settingsDb) async {
  final v = await settingsDb.itemByKey(lastReadMatrixEventTs);
  if (v == null) return null;
  return int.tryParse(v);
}
