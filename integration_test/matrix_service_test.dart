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
      debugPrint('--- Alice goes live');
      final alice = MatrixService(
        matrixConfig: config,
        hiveDbName: 'Alice',
        deviceDisplayName: 'Alice',
      );

      await alice.login();
      await alice.listen();

      debugPrint(
        'Alice - deviceId: ${alice.client.deviceID}',
      );

      final roomId = await alice.createRoom();
      debugPrint('Alice - room created: $roomId');

      expect(roomId, isNotEmpty);

      await Future<void>.delayed(const Duration(seconds: 1));

      final joinRes = await alice.joinRoom(roomId);
      debugPrint('Alice - room joined: $joinRes');

      await Future<void>.delayed(const Duration(seconds: 1));

      debugPrint('--- Bob goes live');
      final bob = MatrixService(
        matrixConfig: config,
        hiveDbName: 'Bob',
        deviceDisplayName: 'Alice',
      );

      await bob.login();
      await bob.listen();
      debugPrint('Bob - deviceId: ${bob.client.deviceID}');

      final joinRes2 = await bob.joinRoom(roomId);
      debugPrint('Bob - room joined: $joinRes2');

      await Future<void>.delayed(const Duration(seconds: 1));

      final unverifiedAlice = alice.getUnverified();
      final unverifiedBob = bob.getUnverified();

      debugPrint('Alice - unverified: $unverifiedAlice');
      debugPrint('Bob - unverified: $unverifiedBob');

      expect(unverifiedAlice.length, 1);
      expect(unverifiedBob.length, 1);

      final outgoingKeyVerificationStream = alice.keyVerificationStream;
      final incomingKeyVerificationRunnerStream =
          bob.incomingKeyVerificationRunnerStream;

      await alice.verifyDevice(unverifiedAlice.first);

      var emojisFromBob = '';
      var emojisFromAlice = '';

      unawaited(
        incomingKeyVerificationRunnerStream.forEach((runner) async {
          debugPrint(
              'Bob - incoming verification runner step: ${runner.lastStep}');
          if (runner.lastStep == 'm.key.verification.request') {
            await runner.acceptVerification();
          }
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromAlice = extractEmojiString(runner.emojis);
            debugPrint('Bob received emojis: $emojisFromAlice');
          }
        }),
      );

      unawaited(
        outgoingKeyVerificationStream.forEach((runner) {
          debugPrint('Alice - outgoing verification step: ${runner.lastStep}');
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromBob = extractEmojiString(runner.emojis);
            debugPrint('Alice received emojis: $emojisFromBob');
          }
        }),
      );

      await Future<void>.delayed(const Duration(seconds: 5));

      expect(emojisFromAlice, isNotEmpty);
      expect(emojisFromBob, isNotEmpty);
      expect(emojisFromAlice, emojisFromAlice);

      debugPrint('--- Logging out Alice and Bob');
      await alice.logout();
      await bob.logout();
    });
  });
}

String extractEmojiString(Iterable<KeyVerificationEmoji>? emojis) {
  final buffer = StringBuffer();
  if (emojis != null) {
    for (final emoji in emojis) {
      buffer.write(emoji.emoji);
    }
  }
  return buffer.toString();
}
