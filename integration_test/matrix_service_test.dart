import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:mocktail/mocktail.dart';
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
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    // create separate databases for each simulated device & suppress warning
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final aliceDb = JournalDb(overriddenFilename: 'alice_db.sqlite');
    final bobDb = JournalDb(overriddenFilename: 'bob_db.sqlite');

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

    const aliceUserName = String.fromEnvironment(testUserEnv1);
    const bobUserName = String.fromEnvironment(testUserEnv2);

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
      user: aliceUserName,
      password: testPassword,
    );

    const config2 = MatrixConfig(
      homeServer: testHomeServer,
      user: bobUserName,
      password: testPassword,
    );

    const defaultDelay = 1;
    const delayFactor = testSlowNetwork ? 5 : 1;

    setUpAll(() async {
      final tmpDir = await getTemporaryDirectory();
      final docDir = Directory('${tmpDir.path}/${uuid.v1()}')
        ..createSync(recursive: true);
      debugPrint('Created temporary docDir ${docDir.path}');

      final mockSettingsDb = MockSettingsDb();

      getIt
        ..registerSingleton<Directory>(docDir)
        ..registerSingleton<LoggingDb>(LoggingDb())
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<SecureStorage>(secureStorageMock);

      when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 0);
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

        final roomId = await aliceDevice.createRoom(
            //invite: [bobUserName],
            );

        debugPrint('AliceDevice - room created: $roomId');

        expect(roomId, isNotEmpty);

        final joinRes = await aliceDevice.joinRoom(roomId);
        debugPrint('AliceDevice - room joined: $joinRes');
        debugPrint(
          'AliceDevice - room encrypted: ${aliceDevice.syncRoom?.encrypted}',
        );
        await aliceDevice.listenToTimeline();

        await aliceDevice.inviteToSyncRoom(userId: bobUserName);

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

        final aliceUserDeviceKeys = aliceDevice.client.userDeviceKeys;
        final bobUserDeviceKeys = bobDevice.client.userDeviceKeys;

        for (final deviceKey in aliceUserDeviceKeys.keys) {
          final value = aliceUserDeviceKeys[deviceKey];
          debugPrint(
            'aliceDevice $deviceKey ${value?.verified}',
          );
          value?.deviceKeys.values.forEach((element) {
            debugPrint(
              '>>> ${element.deviceId} ${element.deviceDisplayName} verified: ${element.verified} ',
            );
          });
        }

        for (final deviceKey in bobUserDeviceKeys.keys) {
          final value = bobUserDeviceKeys[deviceKey];
          debugPrint(
            'bobDevice $deviceKey ${value?.verified}',
          );
          value?.deviceKeys.values.forEach((element) {
            debugPrint(
              '>>> ${element.deviceId} ${element.deviceDisplayName} verified: ${element.verified} ',
            );
          });
        }

        await waitUntil(() => aliceDevice.findUnverified() != null);
        await waitUntil(() => bobDevice.findUnverified() != null);

        final unverifiedAlice = aliceDevice.findUnverified();
        final unverifiedBob = bobDevice.findUnverified();

        debugPrint('\nAliceDevice - unverified: $unverifiedAlice');
        debugPrint('\nBobDevice - unverified: $unverifiedBob');

        expect(unverifiedAlice, isNotNull);
        expect(unverifiedBob, isNotNull);

        final outgoingKeyVerificationStream = aliceDevice.keyVerificationStream;
        final incomingKeyVerificationRunnerStream =
            bobDevice.incomingKeyVerificationRunnerStream;

        await waitSeconds(defaultDelay * 2 * delayFactor);

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

        await waitSeconds(defaultDelay * delayFactor);

        debugPrint('\n--- AliceDevice verifies BobDevice');
        await aliceDevice.verifyDevice(unverifiedAlice!);

        await waitUntil(() => emojisFromAlice.isNotEmpty);
        await waitUntil(() => emojisFromBob.isNotEmpty);

        expect(emojisFromAlice, isNotEmpty);
        expect(emojisFromBob, isNotEmpty);
        expect(emojisFromAlice, emojisFromAlice);

        debugPrint(
          '\n--- AliceDevice and BobDevice both have no unverified devices',
        );

        await waitUntil(() => aliceDevice.findUnverified() == null);
        await waitUntil(() => bobDevice.findUnverified() == null);

        expect(aliceDevice.findUnverified(), isNull);
        expect(bobDevice.findUnverified(), isNull);

        await waitSeconds(defaultDelay * delayFactor);

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
                  plainText: 'Test from $deviceName #$index - $now',
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
          () async => await aliceDb.getJournalCount() == n,
        );
        debugPrint('\n--- AliceDevice finished receiving messages');
        final aliceEntriesCount = await aliceDb.getJournalCount();
        expect(aliceEntriesCount, n);
        debugPrint('AliceDevice persisted entries: $aliceEntriesCount');

        await waitUntilAsync(
          () async => await bobDb.getJournalCount() == n,
        );
        debugPrint('\n--- BobDevice finished receiving messages');
        final bobEntriesCount = await bobDb.getJournalCount();
        expect(bobEntriesCount, n);
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
