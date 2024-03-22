import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/secure_storage.dart';

import '../test/helpers/path_provider.dart';
import '../test/mocks/mocks.dart';
import '../test/utils/env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixService Tests', () {
    final mockLoggingDb = MockLoggingDb();
    final secureStorageMock = MockSecureStorage();

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

    test('Create room', () async {
      final config = MatrixConfig(
        homeServer: await getEnv('MATRIX_HOME_SERVER'),
        user: await getEnv('MATRIX_USER'),
        password: await getEnv('MATRIX_PASSWORD'),
      );
      final matrixService = MatrixService(matrixConfig: config);
      await matrixService.loginAndListen();

      final roomId = await matrixService.createRoom();
      debugPrint('Room created: $roomId');

      final room = matrixService.getRoom(roomId);
      debugPrint('Room created: $room');

      expect(roomId, isNotEmpty);
    });
  });
}
