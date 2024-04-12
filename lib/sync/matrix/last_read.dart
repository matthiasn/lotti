import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/consts.dart';

Future<void> setLastReadMatrixEventId(String eventId) =>
    getIt<SettingsDb>().saveSettingsItem(
      lastReadMatrixEventId,
      eventId,
    );

Future<String?> getLastReadMatrixEventId() =>
    getIt<SettingsDb>().itemByKey(lastReadMatrixEventId);
