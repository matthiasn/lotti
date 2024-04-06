import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  // description and how to run in https://github.com/matthiasn/lotti/pull/1695
  group('MatrixService Tests', () {
    final mockLoggingDb = MockLoggingDb();
    final secureStorageMock = MockSecureStorage();
    const testUserEnv1 = 'TEST_USER1';
    const testUserEnv2 = 'TEST_USER2';
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    const testSlowNetwork = bool.fromEnvironment(testSlowNetworkEnv);

    if (!const bool.hasEnvironment(testUserEnv1)) {
      debugPrint('TEST_USER1 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    if (!const bool.hasEnvironment(testUserEnv2)) {
      debugPrint('TEST_USER2 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    const testUserName1 = String.fromEnvironment(testUserEnv1);
    const testUserName2 = String.fromEnvironment(testUserEnv1);

    const testHomeServer = bool.hasEnvironment(testServerEnv)
        ? String.fromEnvironment(testServerEnv)
        : testSlowNetwork
            ? 'http://localhost:18008'
            : 'http://localhost:8008';
    const testPassword = bool.hasEnvironment(testPasswordEnv)
        ? String.fromEnvironment(testPasswordEnv)
        : '?Secret123@';

    const config1 = MatrixConfig(
      homeServer: testHomeServer,
      user: testUserName1,
      password: testPassword,
    );

    const config2 = MatrixConfig(
      homeServer: testHomeServer,
      user: testUserName2,
      password: testPassword,
    );

    const delayFactor = bool.hasEnvironment(testSlowNetworkEnv) ? 5 : 1;

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

    test(
      'Create room & join',
      () async {
        debugPrint('\n--- AliceDevice goes live');
        final aliceDevice = MatrixService(
          matrixConfig: config1,
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

        final joinRes = await aliceDevice.joinRoom(roomId);
        debugPrint('AliceDevice - room joined: $joinRes');

        debugPrint('\n--- BobDevice goes live');
        final bobDevice = MatrixService(
          matrixConfig: config2,
          hiveDbName: 'BobDevice',
          deviceDisplayName: 'BobDevice',
        );

        await bobDevice.login();
        await bobDevice.listen();
        debugPrint('BobDevice - deviceId: ${bobDevice.client.deviceID}');

        final joinRes2 = await bobDevice.joinRoom(roomId);
        debugPrint('BobDevice - room joined: $joinRes2');

        await Future<void>.delayed(
          const Duration(seconds: 1 * delayFactor),
        );

        await waitUntil(() => aliceDevice.getUnverified().length == 1);
        await waitUntil(() => bobDevice.getUnverified().length == 1);

        final unverifiedAlice = aliceDevice.getUnverified();
        final unverifiedBob = bobDevice.getUnverified();

        debugPrint('\nAliceDevice - unverified: $unverifiedAlice');
        debugPrint('\nBobDevice - unverified: $unverifiedBob');

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

              await waitUntil(
                () =>
                    emojisFromAlice == emojisFromBob &&
                    emojisFromAlice.isNotEmpty,
              );

              await runner.acceptEmojiVerification();
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

              await waitUntil(
                () =>
                    emojisFromAlice == emojisFromBob &&
                    emojisFromBob.isNotEmpty,
              );

              await runner.acceptEmojiVerification();
            }
          }),
        );

        await waitUntil(() => emojisFromAlice.isNotEmpty);
        await waitUntil(() => emojisFromBob.isNotEmpty);

        expect(emojisFromAlice, isNotEmpty);
        expect(emojisFromBob, isNotEmpty);
        expect(emojisFromAlice, emojisFromAlice);

        debugPrint(
          '\n--- AliceDevice and BobDevice both have no unverified devices',
        );

        await waitUntil(() => aliceDevice.getUnverified().isEmpty);
        await waitUntil(() => bobDevice.getUnverified().isEmpty);

        expect(aliceDevice.getUnverified(), isEmpty);
        expect(bobDevice.getUnverified(), isEmpty);

        await Future<void>.delayed(
          const Duration(seconds: 1 * delayFactor),
        );

        debugPrint('\n--- Logging out AliceDevice and BobDevice');
        await aliceDevice.logout();
        await bobDevice.logout();
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
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

Future<void> waitUntil(
  bool Function() condition,
) async {
  while (!condition()) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
