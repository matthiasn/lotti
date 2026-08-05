import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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

Future<String> createMatrixDeviceName({
  DeviceInfoPlugin? deviceInfoPlugin,
}) async {
  final operatingSystem = Platform.operatingSystem;
  var deviceName = operatingSystem;

  final deviceInfo = deviceInfoPlugin ?? DeviceInfoPlugin();
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
