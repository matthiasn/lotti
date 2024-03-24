import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:matrix/encryption/utils/key_verification.dart';

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
      debugPrint('\n--- AliceDevice goes live');
      final aliceDevice = MatrixService(
        matrixConfig: config,
        hiveDbName: 'AliceDevice',
        deviceDisplayName: 'AliceDevice',
      );

      await aliceDevice.login();
      await aliceDevice.listen();

      debugPrint(
        'AliceDevice - deviceId: ${aliceDevice.client.deviceID}',
      );

      final roomId = await aliceDevice.createRoom();
      debugPrint('AliceDevice - room created: $roomId');

      expect(roomId, isNotEmpty);

      await Future<void>.delayed(const Duration(seconds: 1));

      final joinRes = await aliceDevice.joinRoom(roomId);
      debugPrint('AliceDevice - room joined: $joinRes');

      await Future<void>.delayed(const Duration(seconds: 1));

      debugPrint('\n--- BobDevice goes live');
      final bobDevice = MatrixService(
        matrixConfig: config,
        hiveDbName: 'BobDevice',
        deviceDisplayName: 'BobDevice',
      );

      await bobDevice.login();
      await bobDevice.listen();
      debugPrint('BobDevice - deviceId: ${bobDevice.client.deviceID}');

      final joinRes2 = await bobDevice.joinRoom(roomId);
      debugPrint('BobDevice - room joined: $joinRes2');

      await Future<void>.delayed(const Duration(seconds: 1));

      final unverifiedAlice = aliceDevice.getUnverified();
      final unverifiedBob = bobDevice.getUnverified();

      debugPrint('AliceDevice - unverified: $unverifiedAlice');
      debugPrint('BobDevice - unverified: $unverifiedBob');

      expect(unverifiedAlice.length, 1);
      expect(unverifiedBob.length, 1);

      final outgoingKeyVerificationStream = aliceDevice.keyVerificationStream;
      final incomingKeyVerificationRunnerStream =
          bobDevice.incomingKeyVerificationRunnerStream;

      debugPrint('\n--- AliceDevice verifies BobDevice');
      await aliceDevice.verifyDevice(unverifiedAlice.first);

      var emojisFromBob = '';
      var emojisFromAlice = '';

      unawaited(
        incomingKeyVerificationRunnerStream.forEach((runner) async {
          debugPrint(
            'BobDevice - incoming verification runner step: ${runner.lastStep}',
          );
          if (runner.lastStep == 'm.key.verification.request') {
            await runner.acceptVerification();
          }
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromAlice = extractEmojiString(runner.emojis);
            debugPrint('BobDevice received emojis: $emojisFromAlice');

            await Future<void>.delayed(const Duration(seconds: 1));
            if (emojisFromAlice == emojisFromBob &&
                emojisFromAlice.isNotEmpty) {
              await runner.acceptEmojiVerification();
            }
          }
        }),
      );

      unawaited(
        outgoingKeyVerificationStream.forEach((runner) async {
          debugPrint(
            'AliceDevice - outgoing verification step: ${runner.lastStep}',
          );
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromBob = extractEmojiString(runner.emojis);
            debugPrint('AliceDevice received emojis: $emojisFromBob');

            await Future<void>.delayed(const Duration(seconds: 1));
            if (emojisFromAlice == emojisFromBob && emojisFromBob.isNotEmpty) {
              await runner.acceptEmojiVerification();
            }
          }
        }),
      );

      await Future<void>.delayed(const Duration(seconds: 5));

      expect(emojisFromAlice, isNotEmpty);
      expect(emojisFromBob, isNotEmpty);
      expect(emojisFromAlice, emojisFromAlice);

      debugPrint(
        '\n--- AliceDevice and BobDevice both have no unverified devices',
      );
      expect(aliceDevice.getUnverified(), isEmpty);
      expect(bobDevice.getUnverified(), isEmpty);

      debugPrint('\n--- Logging out AliceDevice and BobDevice');
      await aliceDevice.logout();
      await bobDevice.logout();
    });
  });
}

String extractEmojiString(Iterable<KeyVerificationEmoji>? emojis) {
  final buffer = StringBuffer();
  if (emojis != null) {
    for (final emoji in emojis) {
      buffer.write('${emoji.emoji} ');
    }
  }
  return buffer.toString();
}
