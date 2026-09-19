import 'dart:io';

import 'package:clock/clock.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart' show ShareKeysWith;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createMatrixClient', () {
    test(
      'creates client with custom identifiers and database location',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'matrix_client_custom',
        );
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final client = await createMatrixClient(
          documentsDirectory: tempDir,
          deviceDisplayName: 'unit-device',
          dbName: 'custom_db',
        );
        addTearDown(() async => client.dispose());

        expect(client.clientName, 'unit-device');
        expect(
          client.verificationMethods,
          containsAll(<KeyVerificationMethod>{
            KeyVerificationMethod.emoji,
            KeyVerificationMethod.reciprocate,
          }),
        );
        // ADR 0045: megolm keys go only to directly verified devices — an
        // unverified device is excluded instead of halting all sends.
        expect(client.shareKeysWith, ShareKeysWith.directlyVerifiedOnly);

        final dbFile = File(
          '${tempDir.path}/$matrixDatabaseDirectoryName/custom_db.db',
        );
        expect(dbFile.existsSync(), isTrue);
      },
    );

    test('defaults device name and database name when not provided', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'matrix_client_default',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final client = await createMatrixClient(
        documentsDirectory: tempDir,
      );
      addTearDown(() async => client.dispose());

      expect(client.clientName, 'lotti');
      expect(matrixDatabaseRelativePath, 'matrix/lotti_sync.db');
      final dbFile = File('${tempDir.path}/$matrixDatabaseRelativePath');
      expect(dbFile.existsSync(), isTrue);
    });
  });

  group('createMatrixDeviceName', () {
    MockDeviceInfoPlugin platformPlugin() {
      final plugin = MockDeviceInfoPlugin();
      final ios = MockIosDeviceInfo();
      when(() => ios.name).thenReturn('Waddle iPhone');
      final android = MockAndroidDeviceInfo();
      when(() => android.host).thenReturn('waddle-android');
      when(() => plugin.iosInfo).thenAnswer((_) async => ios);
      when(() => plugin.androidInfo).thenAnswer((_) async => android);
      when(() => plugin.macOsInfo).thenAnswer(
        (_) async => MacOsDeviceInfo.setMockInitialValues(
          computerName: 'Waddle Mac',
          hostName: 'waddle-host',
          arch: 'arm64',
          model: 'Model',
          modelName: 'Model Name',
          kernelVersion: 'kernel',
          osRelease: 'release',
          majorVersion: 1,
          minorVersion: 0,
          patchVersion: 0,
          activeCPUs: 8,
          memorySize: 16,
          cpuFrequency: 1000,
          systemGUID: 'guid',
        ),
      );
      return plugin;
    }

    for (final (os, expectedName) in [
      ('ios', 'Waddle iPhone'),
      ('macos', 'Waddle Mac'),
      ('android', 'waddle-android'),
      ('linux', 'linux'),
      ('windows', 'windows'),
    ]) {
      test(
        'names a $os device "$expectedName" plus minute and suffix',
        () async {
          final deviceName = await withClock(
            Clock.fixed(DateTime(2024, 3, 15, 9, 41)),
            () => createMatrixDeviceName(
              deviceInfoPlugin: platformPlugin(),
              operatingSystem: os,
            ),
          );

          expect(
            deviceName,
            matches(
              RegExp('^${RegExp.escape(expectedName)} 2024-03-15T09:41 .{4}\$'),
            ),
          );
        },
      );
    }

    test(
      'falls back to a default DeviceInfoPlugin when none is provided',
      () async {
        // Exercises the `deviceInfoPlugin ?? DeviceInfoPlugin()` default
        // branch. On non-iOS/macOS/Android hosts none of the platform getters
        // are awaited, so constructing the real plugin is safe and the device
        // name is derived purely from Platform.operatingSystem.
        final datePattern = RegExp(r'\d{4}-\d{2}-\d{2}');

        final deviceName = await createMatrixDeviceName();

        expect(deviceName.startsWith(Platform.operatingSystem), isTrue);

        final segments = deviceName.split(' ');
        expect(segments.length, greaterThanOrEqualTo(3));
        expect(datePattern.hasMatch(segments[1]), isTrue);
        // The trailing uuid fragment is always 4 characters long.
        expect(segments.last.length, 4);
      },
      // On iOS/macOS/Android hosts the default DeviceInfoPlugin's real
      // platform getters (iosInfo/macosInfo/androidInfo) are awaited, which is
      // host-dependent and brittle in test environments. Skipping there keeps
      // this test hermetic while still covering the `?? DeviceInfoPlugin()`
      // default-construction branch on Linux/Windows CI, where no platform
      // getter is awaited.
      skip: (Platform.isIOS || Platform.isMacOS || Platform.isAndroid)
          ? 'createMatrixDeviceName awaits the real DeviceInfoPlugin platform '
                'getters on this host'
          : false,
    );
  });
}
