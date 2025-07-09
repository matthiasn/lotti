import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Client> createMatrixClient({
  String? deviceDisplayName,
  String? dbName,
}) async {
  final docDir = getIt<Directory>();
  final name = dbName ?? 'lotti_sync';
  final path = '${docDir.path}/matrix/$name.db';
  final database = await MatrixSdkDatabase.init(
    name,
    database: await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(),
    ),
    sqfliteFactory: databaseFactoryFfi,
  );

  return Client(
    deviceDisplayName ?? 'lotti',
    verificationMethods: {
      KeyVerificationMethod.emoji,
      KeyVerificationMethod.reciprocate,
    },
    sendTimelineEventTimeout: const Duration(minutes: 2),
    database: database,
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

Future<bool> matrixConnect({
  required MatrixService service,
  required bool shouldAttemptLogin,
}) async {
  try {
    final matrixConfig = service.matrixConfig;

    if (matrixConfig == null) {
      getIt<LottiLogger>().event(
        configNotFound,
        domain: 'MATRIX_SERVICE',
        subDomain: 'login',
      );

      return false;
    }

    final homeServerSummary = await service.client.checkHomeserver(
      Uri.parse(matrixConfig.homeServer),
    );

    getIt<LottiLogger>().event(
      'checkHomeserver $homeServerSummary',
      domain: 'MATRIX_SERVICE',
      subDomain: 'login',
    );

    await service.client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    if (!service.isLoggedIn() && shouldAttemptLogin) {
      final initialDeviceDisplayName =
          service.deviceDisplayName ?? await createMatrixDeviceName();

      service.loginResponse = await service.client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: matrixConfig.user),
        password: matrixConfig.password,
        initialDeviceDisplayName: initialDeviceDisplayName,
      );

      getIt<LottiLogger>().event(
        'logged in, userId ${service.loginResponse?.userId},'
        ' deviceId  ${service.loginResponse?.deviceId}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'login',
      );
    }

    final roomId = await service.getRoom();

    if (roomId != null) {
      await service.joinRoom(roomId);
    }

    return true;
  } catch (e, stackTrace) {
    debugPrint('$e');
    getIt<LottiLogger>().exception(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'login',
      stackTrace: stackTrace,
    );
    return false;
  }
}
