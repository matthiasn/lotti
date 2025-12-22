import 'dart:convert';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';

Future<MatrixConfig?> loadMatrixConfig({
  required MatrixSessionManager session,
  required SecureStorage storage,
}) async {
  if (session.matrixConfig != null) {
    return session.matrixConfig;
  }
  final configJson = await storage.read(key: matrixConfigKey);
  if (configJson != null) {
    session.matrixConfig = MatrixConfig.fromJson(
      json.decode(configJson) as Map<String, dynamic>,
    );
  }
  return session.matrixConfig;
}

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
