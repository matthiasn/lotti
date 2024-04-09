import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../test/mocks/mocks.dart';
import '../test/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // description and how to run in https://github.com/matthiasn/lotti/pull/1695
  group('MatrixService Tests', () {
    final secureStorageMock = MockSecureStorage();
    const testUserEnv1 = 'TEST_USER1';
    const testUserEnv2 = 'TEST_USER2';
    const testUserEnv3 = 'TEST_USER3';
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    // create separate databases for each simulated device & suppress warning
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final aliceDb = JournalDb(overriddenFilename: 'alice_db.sqlite');
    final bobDb = JournalDb(overriddenFilename: 'bob_db.sqlite');
    final carolDb = JournalDb(overriddenFilename: 'carol_db.sqlite');

    const testSlowNetwork = bool.fromEnvironment(testSlowNetworkEnv);

    if (testSlowNetwork) {
      debugPrint('Testing with degraded network.');
    }

    if (!const bool.hasEnvironment(testUserEnv1)) {
      debugPrint('TEST_USER1 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    if (!const bool.hasEnvironment(testUserEnv2)) {
      debugPrint('TEST_USER2 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    if (!const bool.hasEnvironment(testUserEnv3)) {
      debugPrint('TEST_USER3 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    const testUserName1 = String.fromEnvironment(testUserEnv1);
    // TODO: multi-user setup
    const testUserName2 = String.fromEnvironment(testUserEnv1);
    const testUserName3 = String.fromEnvironment(testUserEnv1);

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

    const config3 = MatrixConfig(
      homeServer: testHomeServer,
      user: testUserName3,
      password: testPassword,
    );

    const defaultDelay = 1;
    const delayFactor = testSlowNetwork ? 5 : 1;

    setUpAll(() async {
      final tmpDir = await getTemporaryDirectory();
      final docDir = Directory('${tmpDir.path}/${uuid.v1()}')
        ..createSync(recursive: true);
      debugPrint('Created temporary docDir ${docDir.path}');

      getIt
        ..registerSingleton<Directory>(docDir)
        ..registerSingleton<LoggingDb>(LoggingDb())
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
          overriddenJournalDb: aliceDb,
        );

        await aliceDevice.login();
        await aliceDevice.startKeyVerificationListener();
        debugPrint('AliceDevice - deviceId: ${aliceDevice.client.deviceID}');

        final roomId = await aliceDevice.createRoom();
        debugPrint('AliceDevice - room created: $roomId');

        expect(roomId, isNotEmpty);

        final joinRes = await aliceDevice.joinRoom(roomId);
        debugPrint('AliceDevice - room joined: $joinRes');
        await aliceDevice.listenToTimeline();

        debugPrint('\n--- BobDevice goes live');
        final bobDevice = MatrixService(
          matrixConfig: config2,
          hiveDbName: 'BobDevice',
          deviceDisplayName: 'BobDevice',
          overriddenJournalDb: bobDb,
        );

        await bobDevice.login();
        await bobDevice.startKeyVerificationListener();
        debugPrint('BobDevice - deviceId: ${bobDevice.client.deviceID}');

        final joinRes2 = await bobDevice.joinRoom(roomId);
        debugPrint('BobDevice - room joined: $joinRes2');
        await bobDevice.listenToTimeline();
        await waitSeconds(defaultDelay * delayFactor);

        await waitUntil(() => aliceDevice.getUnverified().length == 1);
        await waitUntil(() => bobDevice.getUnverified().length == 1);

        final unverifiedAlice = aliceDevice.getUnverified();
        final unverifiedBob = bobDevice.getUnverified();

        debugPrint('\nAliceDevice - unverified: $unverifiedAlice');
        debugPrint('\nBobDevice - unverified: $unverifiedBob');

        expect(unverifiedAlice.length, 1);
        expect(unverifiedBob.length, 1);

        await waitSeconds(defaultDelay * delayFactor);

        debugPrint('\n--- AliceDevice verifies BobDevice');
        await aliceDevice.verifyDevice(unverifiedAlice.first);

        await waitSeconds(defaultDelay * delayFactor);

        var emojisFromBobForAlice = '';
        var emojisFromAliceForBob = '';

        unawaited(
          bobDevice.incomingKeyVerificationRunnerStream.forEach((runner) async {
            debugPrint(
              'BobDevice - incoming verification runner step: ${runner.lastStep}',
            );
            if (runner.lastStep == 'm.key.verification.request') {
              await runner.acceptVerification();
            }
            if (runner.lastStep == 'm.key.verification.key') {
              emojisFromAliceForBob = extractEmojiString(runner.emojis);
              debugPrint('BobDevice received emojis: $emojisFromAliceForBob');

              await waitUntil(
                () =>
                    emojisFromAliceForBob == emojisFromBobForAlice &&
                    emojisFromAliceForBob.isNotEmpty,
              );

              await runner.acceptEmojiVerification();
            }
          }),
        );

        unawaited(
          aliceDevice.keyVerificationStream.forEach((runner) async {
            debugPrint(
              'AliceDevice - outgoing verification step: ${runner.lastStep}',
            );
            if (runner.lastStep == 'm.key.verification.key') {
              emojisFromBobForAlice = extractEmojiString(runner.emojis);
              debugPrint('AliceDevice received emojis: $emojisFromBobForAlice');

              await waitUntil(
                () =>
                    emojisFromAliceForBob == emojisFromBobForAlice &&
                    emojisFromBobForAlice.isNotEmpty,
              );

              await runner.acceptEmojiVerification();
            }
          }),
        );

        await waitUntil(() => emojisFromAliceForBob.isNotEmpty);
        await waitUntil(() => emojisFromBobForAlice.isNotEmpty);

        expect(emojisFromAliceForBob, isNotEmpty);
        expect(emojisFromBobForAlice, isNotEmpty);
        expect(emojisFromAliceForBob, emojisFromBobForAlice);

        debugPrint(
          '\n--- AliceDevice and BobDevice both have no unverified devices',
        );

        await waitUntil(() => aliceDevice.getUnverified().isEmpty);
        await waitUntil(() => bobDevice.getUnverified().isEmpty);

        expect(aliceDevice.getUnverified(), isEmpty);
        expect(bobDevice.getUnverified(), isEmpty);

        await waitSeconds(defaultDelay * delayFactor);

        debugPrint('\n--- CarolDevice goes live');
        final carolDevice = MatrixService(
          matrixConfig: config3,
          hiveDbName: 'CarolDevice',
          deviceDisplayName: 'CarolDevice',
          overriddenJournalDb: carolDb,
        );

        await carolDevice.login();
        await carolDevice.startKeyVerificationListener();
        debugPrint('CarolDevice - deviceId: ${bobDevice.client.deviceID}');

        final joinResCarol = await carolDevice.joinRoom(roomId);
        debugPrint('CarolDevice - room joined: $joinResCarol');
        await carolDevice.listenToTimeline();
        await waitSeconds(defaultDelay * delayFactor);

        await waitUntil(() => carolDevice.getUnverified().length == 2);
        final unverifiedCarol = carolDevice.getUnverified();

        debugPrint('\nCarolDevice - unverified: $unverifiedCarol');
        expect(unverifiedCarol.length, 2);

        var emojisFromCarolForBob = '';
        var emojisFromBobForCarol = '';

        unawaited(
          carolDevice.incomingKeyVerificationRunnerStream
              .forEach((runner) async {
            debugPrint(
              'CarolDevice - incoming verification runner step: ${runner.lastStep}',
            );
            if (runner.lastStep == 'm.key.verification.request') {
              await runner.acceptVerification();
            }
            if (runner.lastStep == 'm.key.verification.key') {
              emojisFromBobForCarol = extractEmojiString(runner.emojis);
              debugPrint('CarolDevice received emojis: $emojisFromBobForCarol');

              await waitUntil(
                () =>
                    emojisFromBobForCarol == emojisFromCarolForBob &&
                    emojisFromBobForCarol.isNotEmpty,
              );

              await runner.acceptEmojiVerification();
            }
          }),
        );

        unawaited(
          bobDevice.keyVerificationStream.forEach((runner) async {
            debugPrint(
              'BobDevice - outgoing verification step: ${runner.lastStep}',
            );
            if (runner.lastStep == 'm.key.verification.key') {
              emojisFromCarolForBob = extractEmojiString(runner.emojis);
              debugPrint('Bob received emojis: $emojisFromCarolForBob');

              await waitUntil(
                () =>
                    emojisFromBobForCarol == emojisFromCarolForBob &&
                    emojisFromCarolForBob.isNotEmpty,
              );

              await runner.acceptEmojiVerification();
            }
          }),
        );

        final unverifiedBob2 = bobDevice.getUnverified();

        debugPrint('\nBobDevice - unverified: $unverifiedBob2');
        expect(unverifiedBob2.length, 1);

        debugPrint('\n--- BobDevice verifies CarolDevice');
        await bobDevice.verifyDevice(unverifiedBob2.first);

        await waitUntil(() => emojisFromBobForCarol.isNotEmpty);
        await waitUntil(() => emojisFromCarolForBob.isNotEmpty);

        expect(emojisFromBobForCarol, isNotEmpty);
        expect(emojisFromCarolForBob, isNotEmpty);
        expect(emojisFromBobForCarol, emojisFromCarolForBob);

        debugPrint(
          '\nAliceDevice - unverified: ${aliceDevice.getUnverified()}',
        );
        debugPrint('\nBobDevice - unverified: ${bobDevice.getUnverified()}');
        debugPrint(
          '\nCarolDevice - unverified: ${carolDevice.getUnverified()}',
        );

        await waitUntil(() => aliceDevice.getUnverified().isEmpty);
        await waitUntil(() => bobDevice.getUnverified().isEmpty);
        await waitUntil(() => carolDevice.getUnverified().isEmpty);

        expect(aliceDevice.getUnverified(), isEmpty);
        expect(bobDevice.getUnverified(), isEmpty);
        expect(carolDevice.getUnverified(), isEmpty);

        debugPrint(
          '\n--- AliceDevice, BobDevice, and CarolDevice have no unverified devices',
        );

        Future<void> sendTestMessage(
          int index, {
          required MatrixService device,
          required String deviceName,
        }) async {
          final id = const Uuid().v1();
          final now = DateTime.now();

          await device.sendMatrixMsg(
            SyncMessage.journalEntity(
              journalEntity: JournalEntry(
                meta: Metadata(
                  id: id,
                  createdAt: now,
                  dateFrom: now,
                  dateTo: now,
                  updatedAt: now,
                  starred: true,
                  vectorClock: VectorClock({deviceName: index}),
                ),
                entryText: EntryText(
                  plainText: 'Test $deviceName #$index - $now',
                ),
              ),
              status: SyncEntryStatus.initial,
            ),
            myRoomId: roomId,
          );
        }

        const n = testSlowNetwork ? 10 : 100;

        debugPrint('\n--- AliceDevice sends $n message');
        for (var i = 0; i < n; i++) {
          await sendTestMessage(
            i,
            device: aliceDevice,
            deviceName: 'aliceDevice',
          );
        }

        debugPrint('\n--- BobDevice sends $n message');
        for (var i = 0; i < n; i++) {
          await sendTestMessage(
            i,
            device: bobDevice,
            deviceName: 'bobDevice',
          );
        }

        await waitUntilAsync(
          () async => await aliceDb.getJournalCount() == 2 * n,
        );
        debugPrint('\n--- AliceDevice finished receiving messages');
        final aliceEntriesCount = await aliceDb.getJournalCount();
        expect(aliceEntriesCount, 2 * n);
        debugPrint('AliceDevice persisted entries: $aliceEntriesCount');

        await waitUntilAsync(
          () async => await bobDb.getJournalCount() == 2 * n,
        );
        debugPrint('\n--- BobDevice finished receiving messages');
        final bobEntriesCount = await bobDb.getJournalCount();
        expect(bobEntriesCount, 2 * n);
        debugPrint('BobDevice persisted entries: $bobEntriesCount');

        debugPrint('\n--- Logging out AliceDevice and BobDevice');

        await aliceDevice.logout();
        await waitSeconds(defaultDelay * delayFactor);
        await bobDevice.logout();
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}

String extractEmojiString(Iterable<KeyVerificationEmoji>? emojis) {
  final buffer = StringBuffer();
  if (emojis != null) {
    for (final emoji in emojis) {
      buffer.write(' ${emoji.emoji}  ');
    }
  }
  return buffer.toString();
}
