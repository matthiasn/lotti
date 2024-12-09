import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';

Future<void> setLastReadMatrixEventId(
  String eventId,
  SettingsDb? overriddenSettingsDb,
) =>
    (overriddenSettingsDb ?? getIt<SettingsDb>()).saveSettingsItem(
      lastReadMatrixEventId,
      eventId,
    );

Future<String?> getLastReadMatrixEventId(SettingsDb? overriddenSettingsDb) =>
    (overriddenSettingsDb ?? getIt<SettingsDb>())
        .itemByKey(lastReadMatrixEventId);
