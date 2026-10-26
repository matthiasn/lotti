import 'dart:convert';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/services/secure_storage.dart';

/// The persisted [MatrixConfig] as [storage] (the keychain) holds it, or null
/// when no config has been provisioned. The sync isolate's host reads it this
/// way, once, to boot the worker with it (ADR 0142).
Future<MatrixConfig?> readStoredMatrixConfig(SecureStorage storage) async {
  final configJson = await storage.read(key: matrixConfigKey);
  if (configJson == null) return null;
  return MatrixConfig.fromJson(json.decode(configJson) as Map<String, dynamic>);
}

/// Returns the persisted [MatrixConfig], preferring the one already cached on
/// [session]. On a cache miss it reads and decodes the config JSON from
/// [storage] (the keychain) and memoises it back onto the session. `null` when
/// no config has been provisioned.
Future<MatrixConfig?> loadMatrixConfig({
  required MatrixSessionManager session,
  required SecureStorage storage,
}) async {
  if (session.matrixConfig != null) {
    return session.matrixConfig;
  }
  return session.matrixConfig = await readStoredMatrixConfig(storage);
}

/// Persists [config] to [storage] and caches it on [session] for the rest of
/// the process lifetime.
Future<void> setMatrixConfig(
  MatrixConfig config, {
  required MatrixSessionManager session,
  required SecureStorage storage,
}) async {
  session.matrixConfig = config;
  await storage.write(
    key: matrixConfigKey,
    value: jsonEncode(config),
  );
}

/// Clears the Matrix config from [storage] and [session], then logs the
/// session out of the homeserver. Used when disconnecting/unprovisioning sync.
Future<void> deleteMatrixConfig({
  required MatrixSessionManager session,
  required SecureStorage storage,
}) async {
  await storage.delete(
    key: matrixConfigKey,
  );
  session.matrixConfig = null;
  await session.logout();
}
