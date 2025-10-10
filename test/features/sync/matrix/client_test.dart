import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:matrix/encryption/utils/key_verification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createMatrixClient', () {
    test('creates client with custom identifiers and database location',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('matrix_client_custom');
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

      final dbFile = File('${tempDir.path}/matrix/custom_db.db');
      expect(dbFile.existsSync(), isTrue);
    });

    test('defaults device name and database name when not provided', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('matrix_client_default');
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
      final dbFile = File('${tempDir.path}/matrix/lotti_sync.db');
      expect(dbFile.existsSync(), isTrue);
    });
  });

  group('createMatrixDeviceName', () {
    test('builds readable device identifier with timestamp and suffix',
        () async {
      final nowPrefix = DateTime.now().toIso8601String().substring(0, 10);
      var expectedPrefix = Platform.operatingSystem;
      var plugin = DeviceInfoPlugin.setMockInitialValues();

      if (Platform.isMacOS) {
        expectedPrefix = 'UnitMac';
        plugin = DeviceInfoPlugin.setMockInitialValues(
          macOsDeviceInfo: MacOsDeviceInfo.setMockInitialValues(
            computerName: expectedPrefix,
            hostName: 'unit-host',
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
      } else if (Platform.isIOS) {
        expectedPrefix = 'Unit iPhone';
        plugin = DeviceInfoPlugin.setMockInitialValues(
          iosDeviceInfo: IosDeviceInfo.fromMap({
            'name': expectedPrefix,
            'systemName': 'iOS',
            'systemVersion': '17.0',
            'model': 'iPhone',
            'localizedModel': 'iPhone',
            'identifierForVendor': 'vendor',
            'utsname': {
              'sysname': 'Darwin',
              'nodename': 'node',
              'release': 'release',
              'version': 'version',
              'machine': 'machine',
            },
          }),
        );
      } else if (Platform.isAndroid) {
        expectedPrefix = 'UnitAndroid';
        plugin = DeviceInfoPlugin.setMockInitialValues(
          androidDeviceInfo: AndroidDeviceInfo.fromMap({
            'id': 'id',
            'host': expectedPrefix,
            'version': {
              'sdkInt': 34,
              'incremental': '0',
              'codename': 'T',
              'release': '14',
              'baseOS': 'Android',
              'previewSdkInt': 0,
              'securityPatch': '2024-01-01',
            },
            'board': 'board',
            'bootloader': 'bootloader',
            'brand': 'brand',
            'device': 'device',
            'display': 'display',
            'fingerprint': 'fingerprint',
            'hardware': 'hardware',
            'manufacturer': 'manufacturer',
            'model': 'model',
            'product': 'product',
            'supported32BitAbis': <String>[],
            'supported64BitAbis': <String>[],
            'supportedAbis': <String>[],
            'tags': 'tags',
            'type': 'type',
            'isPhysicalDevice': true,
            'serialNumber': 'serial',
          }),
        );
      }

      final deviceName = await createMatrixDeviceName(
        deviceInfoPlugin: plugin,
      );
      expect(deviceName.startsWith(expectedPrefix), isTrue);

      final segments = deviceName.split(' ');
      expect(segments.length, greaterThanOrEqualTo(3));
      expect(segments[1].startsWith(nowPrefix), isTrue);
      expect(segments.last.length, 4);
    });
  });
}
