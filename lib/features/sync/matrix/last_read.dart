import 'package:lotti/database/sync_key_value_store.dart';
import 'package:lotti/features/sync/matrix.dart';

Future<String?> getLastReadMatrixEventId(SyncKeyValueStore settingsDb) =>
    settingsDb.itemByKey(lastReadMatrixEventId);

Future<int?> getLastReadMatrixEventTs(SyncKeyValueStore settingsDb) async {
  final v = await settingsDb.itemByKey(lastReadMatrixEventTs);
  if (v == null) return null;
  return int.tryParse(v);
}
