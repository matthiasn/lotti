import 'dart:convert';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';

Future<MatrixConfig?> loadMatrixConfig({
  required MatrixSessionManager session,
}) async {
  if (session.matrixConfig != null) {
    return session.matrixConfig;
  }
  final configJson = await getIt<SecureStorage>().read(key: matrixConfigKey);
  if (configJson != null) {
    session.matrixConfig = MatrixConfig.fromJson(
      json.decode(configJson) as Map<String, dynamic>,
    );
  }
  return session.matrixConfig;
}

Future<void> logout({
  required MatrixSessionManager session,
}) async {
  if (session.client.isLogged()) {
    await session.client.logout();
  }
}

Future<void> setMatrixConfig(
  MatrixConfig config, {
  required MatrixSessionManager session,
}) async {
  session.matrixConfig = config;
  await getIt<SecureStorage>().write(
    key: matrixConfigKey,
    value: jsonEncode(config),
  );
}

Future<void> deleteMatrixConfig({
  required MatrixSessionManager session,
}) async {
  await getIt<SecureStorage>().delete(
    key: matrixConfigKey,
  );
  session.matrixConfig = null;
  await session.logout();
}
