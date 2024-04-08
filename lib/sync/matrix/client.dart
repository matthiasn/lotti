import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/consts.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

Client createMatrixClient({
  String? deviceDisplayName,
  String? hiveDbName,
}) {
  return Client(
    deviceDisplayName ?? 'lotti',
    verificationMethods: {
      KeyVerificationMethod.emoji,
      KeyVerificationMethod.reciprocate,
    },
    shareKeysWithUnverifiedDevices: false,
    sendMessageTimeoutSeconds: 120,
    databaseBuilder: (_) async {
      final docDir = getIt<Directory>();
      final path = '${docDir.path}/matrix/';
      final db = HiveCollectionsDatabase(hiveDbName ?? 'lotti_sync', path);
      await db.open();
      return db;
    },
  );
}

Future<String> createMatrixDeviceName() async {
  final operatingSystem = Platform.operatingSystem;
  var deviceName = operatingSystem;

  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    deviceName = iosInfo.name;
  }
  if (Platform.isMacOS) {
    final macOsInfo = await deviceInfo.macOsInfo;
    deviceName = macOsInfo.computerName;
  }
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    deviceName = androidInfo.host;
  }

  final dateHhMm = DateTime.now().toIso8601String().substring(0, 16);
  return '$deviceName $dateHhMm ${uuid.v1().substring(0, 4)}';
}

Future<void> matrixLogin({
  required MatrixService service,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final matrixConfig = service.matrixConfig;

    if (matrixConfig == null) {
      loggingDb.captureEvent(
        configNotFound,
        domain: 'MATRIX_SERVICE',
        subDomain: 'login',
      );

      return;
    }

    final homeServerSummary = await service.client.checkHomeserver(
      Uri.parse(matrixConfig.homeServer),
    );

    loggingDb.captureEvent(
      'checkHomeserver $homeServerSummary',
      domain: 'MATRIX_SERVICE',
      subDomain: 'login',
    );

    await service.client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    if (!service.isLoggedIn()) {
      final initialDeviceDisplayName =
          service.deviceDisplayName ?? await createMatrixDeviceName();

      service.loginResponse = await service.client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: matrixConfig.user),
        password: matrixConfig.password,
        initialDeviceDisplayName: initialDeviceDisplayName,
      );

      loggingDb.captureEvent(
        'logged in, userId ${service.loginResponse?.userId},'
        ' deviceId  ${service.loginResponse?.deviceId}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'login',
      );
    }

    final roomId = matrixConfig.roomId;

    if (roomId != null) {
      await service.joinRoom(roomId);
    }
  } catch (e, stackTrace) {
    debugPrint('$e');
    loggingDb.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'login',
      stackTrace: stackTrace,
    );
  }
}
