import 'dart:convert';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';

Future<MatrixConfig?> loadMatrixConfig({
  required MatrixService service,
}) async {
  if (service.matrixConfig != null) {
    return service.matrixConfig;
  }
  final configJson = await getIt<SecureStorage>().read(key: matrixConfigKey);
  if (configJson != null) {
    service.matrixConfig = MatrixConfig.fromJson(
      json.decode(configJson) as Map<String, dynamic>,
    );
  }
  return service.matrixConfig;
}

Future<void> logout({
  required MatrixService service,
}) async {
  if (service.client.isLogged()) {
    await service.client.logout();
  }
}

Future<void> setMatrixConfig(
  MatrixConfig config, {
  required MatrixService service,
}) async {
  service.matrixConfig = config;
  await getIt<SecureStorage>().write(
    key: matrixConfigKey,
    value: jsonEncode(config),
  );
}

Future<void> deleteMatrixConfig({
  required MatrixService service,
}) async {
  await getIt<SecureStorage>().delete(
    key: matrixConfigKey,
  );
  service.matrixConfig = null;
  await service.logout();
}
