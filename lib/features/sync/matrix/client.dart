import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Client> createMatrixClient({
  required Directory documentsDirectory,
  String? deviceDisplayName,
  String? dbName,
}) async {
  final name = dbName ?? 'lotti_sync';
  final path = '${documentsDirectory.path}/matrix/$name.db';
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
