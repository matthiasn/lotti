import 'dart:io';

import 'package:clock/clock.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Directory below the active profile root that owns Matrix SDK state.
const matrixDatabaseDirectoryName = 'matrix';

/// Default logical database name passed to the Matrix SDK.
const matrixDatabaseName = 'lotti_sync';

/// Default Matrix SDK database path relative to the active profile root.
const matrixDatabaseRelativePath =
    '$matrixDatabaseDirectoryName/$matrixDatabaseName.db';

Future<Client> createMatrixClient({
  required Directory documentsDirectory,
  String? deviceDisplayName,
  String? dbName,
  bool? singleInstance,
}) async {
  final name = dbName ?? matrixDatabaseName;
  final path =
      '${documentsDirectory.path}/$matrixDatabaseDirectoryName/$name.db';

  sqfliteFfiInit();
  final dbFactory = createDatabaseFactoryFfi(ffiInit: sqfliteFfiInit);

  final database = await MatrixSdkDatabase.init(
    name,
    database: await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: singleInstance ?? true,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA busy_timeout = 5000');
          await db.execute('PRAGMA synchronous = NORMAL');
        },
      ),
    ),
    sqfliteFactory: dbFactory,
  );

  return Client(
    deviceDisplayName ?? 'lotti',
    verificationMethods: {
      KeyVerificationMethod.emoji,
      KeyVerificationMethod.reciprocate,
    },
    // Never hand megolm keys to a device this session has not SAS-verified.
    // Without cross-signing the SDK default degrades to sharing with every
    // non-blocked device, which forced an app-level total send halt as the
    // only confidentiality backstop. With exclusion, an unverified device
    // simply receives ciphertext it can never read while every trusted
    // device keeps syncing. See ADR 0045.
    shareKeysWith: ShareKeysWith.directlyVerifiedOnly,
    sendTimelineEventTimeout: const Duration(minutes: 2),
    database: database,
  );
}

/// Builds the display name this device registers with the homeserver: the
/// platform's own device name (iOS device name, macOS computer name, Android
/// host) or the operating system name elsewhere, followed by the current
/// minute and a short random suffix.
///
/// [operatingSystem] defaults to [Platform.operatingSystem]; tests pass it to
/// exercise every platform's branch from one host.
Future<String> createMatrixDeviceName({
  DeviceInfoPlugin? deviceInfoPlugin,
  @visibleForTesting String? operatingSystem,
}) async {
  final os = operatingSystem ?? Platform.operatingSystem;
  final deviceInfo = deviceInfoPlugin ?? DeviceInfoPlugin();
  final deviceName = switch (os) {
    'ios' => (await deviceInfo.iosInfo).name,
    'macos' => (await deviceInfo.macOsInfo).computerName,
    'android' => (await deviceInfo.androidInfo).host,
    _ => os,
  };

  final dateHhMm = clock.now().toIso8601String().substring(0, 16);
  return '$deviceName $dateHhMm ${uuid.v1().substring(0, 4)}';
}
