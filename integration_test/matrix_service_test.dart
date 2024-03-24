import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/secure_storage.dart';

import '../test/helpers/path_provider.dart';
import '../test/mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixService Tests', () {
    final mockLoggingDb = MockLoggingDb();
    final secureStorageMock = MockSecureStorage();
    const testUserEnv = 'TEST_USER';

    if (!const bool.hasEnvironment(testUserEnv)) {
      debugPrint('TEST_USER not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }
    const testUserName = String.fromEnvironment(testUserEnv);

    setUpAll(() async {
      setFakeDocumentsPath();

      getIt
        ..registerSingleton<LoggingDb>(mockLoggingDb)
        ..registerSingleton<SecureStorage>(secureStorageMock);
    });

    setUp(() {});

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() async {});

    test('Create room & join', () async {
      const config = MatrixConfig(
        homeServer: 'http://localhost:8008',
        user: '@$testUserName:localhost',
        password: '?Secret123@!',
      );
      final matrixService1 = MatrixService(
        matrixConfig: config,
        hiveDbName: 'Alice',
      );
      await matrixService1.login();
      debugPrint(
        'MatrixService 1 - deviceId: ${matrixService1.client.deviceID}',
      );

      final roomId = await matrixService1.createRoom();
      debugPrint('MatrixService 1 - room created: $roomId');

      expect(roomId, isNotEmpty);

      final joinRes = await matrixService1.joinRoom(roomId);
      debugPrint('MatrixService 1 - room joined: $joinRes');

      final matrixService2 = MatrixService(
        matrixConfig: config,
        hiveDbName: 'Bob',
      );
      await matrixService2.login();
      debugPrint(
        'MatrixService 2 - deviceId: ${matrixService2.client.deviceID}',
      );

      final joinRes2 = await matrixService2.joinRoom(roomId);
      debugPrint('MatrixService 2 - room joined: $joinRes2');

      await Future<void>.delayed(const Duration(seconds: 1));

      final unverified1 = matrixService1.getUnverified();
      final unverified2 = matrixService2.getUnverified();

      debugPrint('MatrixService 1 - unverified: $unverified1');
      debugPrint('MatrixService 2 - unverified: $unverified2');

      expect(unverified1.length, 1);
      expect(unverified2.length, 1);

      await matrixService1.logout();
      await matrixService2.logout();
    });
  });
}
