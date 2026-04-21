import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';

/// Reads the Phase-1 queue feature flag from [SettingsDb]. The flag is
/// stored as a string (`'true'` / `'false'`) under
/// [useInboundEventQueueKey]; missing or malformed values are treated
/// as `false`. Phase 2 reads this flag once at `MatrixService.init`
/// and caches the result on the service; flips require a restart, so
/// a value cached at init time is always authoritative for the
/// lifetime of the current `MatrixService`.
Future<bool> readUseInboundEventQueueFlag(SettingsDb settingsDb) async {
  final raw = await settingsDb.itemByKey(useInboundEventQueueKey);
  if (raw == null) return false;
  return raw.trim().toLowerCase() == 'true';
}

/// Writes the Phase-1 queue feature flag. Exposed so a future Sync
/// Settings UI (or an internal debug menu) can toggle it; the change
/// takes effect on the next `MatrixService` init.
Future<void> writeUseInboundEventQueueFlag(
  SettingsDb settingsDb, {
  required bool enabled,
}) async {
  await settingsDb.saveSettingsItem(
    useInboundEventQueueKey,
    enabled ? 'true' : 'false',
  );
}
