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
        user: '@lotti-test:localhost',
        password: 'Secret123@',
      );
      final matrixService = MatrixService(matrixConfig: config);
      await matrixService.login();

      final roomId = await matrixService.createRoom();
      debugPrint('Room created: $roomId');

      final room = matrixService.getRoom(roomId);
      debugPrint('Room created: $room');

      expect(
        roomId,
        isNotEmpty,
      );

      final joinRes = await matrixService.joinRoom(roomId);
      debugPrint('Room joined: $joinRes');
    });
  });
}
