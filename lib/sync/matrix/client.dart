import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:lotti/get_it.dart';
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
