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
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/send_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
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

    final mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(
      () => mockUpdateNotifications.notify(any()),
    ).thenAnswer((_) {});

    final aliceDb = JournalDb(
      overriddenFilename: 'alice_db.sqlite',
      inMemoryDatabase: true,
    );
    final bobDb = JournalDb(
      overriddenFilename: 'bob_db.sqlite',
      inMemoryDatabase: true,
    );

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
    const delayFactor = testSlowNetwork ? 3 : 1;

    setUpAll(() async {
      final tmpDir = await getTemporaryDirectory();
      final docDir = Directory('${tmpDir.path}/${uuid.v1()}')
        ..createSync(recursive: true);
      debugPrint('Created temporary docDir ${docDir.path}');

      getIt
        ..registerSingleton<Directory>(docDir)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true))
        ..registerSingleton<SecureStorage>(secureStorageMock);

      await Future<void>.delayed(const Duration(seconds: 5));
    });

    setUp(() {});

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() async {});

    test(
      'Create room & join',
      () async {
        debugPrint('\n--- Alice goes live');
        final alice = MatrixService(
          matrixConfig: config1,
          dbName: 'Alice',
          deviceDisplayName: 'Alice',
          overriddenJournalDb: aliceDb,
          overriddenSettingsDb: SettingsDb(inMemoryDatabase: true),
        );

        await alice.login();
        await alice.startKeyVerificationListener();
        debugPrint('Alice - deviceId: ${alice.client.deviceID}');

        final roomId = await alice.createRoom();

        debugPrint('Alice - room created: $roomId');

        expect(roomId, isNotEmpty);

        final joinRes = await alice.joinRoom(roomId);
        debugPrint('Alice - room joined: $joinRes');
        debugPrint(
          'Alice - room encrypted: ${alice.syncRoom?.encrypted}',
        );
        await alice.listenToTimeline();

        debugPrint('\n--- Bob goes live');
        final bob = MatrixService(
          matrixConfig: config2,
          dbName: 'Bob',
          deviceDisplayName: 'Bob',
          overriddenJournalDb: bobDb,
          overriddenSettingsDb: SettingsDb(inMemoryDatabase: true),
        );

        await bob.login();
        await bob.startKeyVerificationListener();
        debugPrint('Bob - deviceId: ${bob.client.deviceID}');

        debugPrint('\n--- Alice invites Bob into room $roomId');
        await alice.inviteToSyncRoom(userId: bobUserName);
        await waitSeconds(defaultDelay * delayFactor);

        final joinRes2 = await bob.joinRoom(roomId);
        debugPrint('Bob - room joined: $joinRes2');
        await bob.listenToTimeline();
        await waitSeconds(defaultDelay * delayFactor);

        await waitUntil(() => alice.getUnverifiedDevices().isNotEmpty);
        await waitUntil(() => bob.getUnverifiedDevices().isNotEmpty);

        final unverifiedAlice = alice.getUnverifiedDevices();
        final unverifiedBob = bob.getUnverifiedDevices();

        debugPrint('\nAlice - unverified: $unverifiedAlice');
        debugPrint('\nBob - unverified: $unverifiedBob');

        expect(unverifiedAlice, isNotNull);
        expect(unverifiedBob, isNotNull);

        final outgoingKeyVerificationStream = alice.keyVerificationStream;
        final incomingKeyVerificationRunnerStream =
            bob.incomingKeyVerificationRunnerStream;

        await waitSeconds(defaultDelay * 2 * delayFactor);

        var emojisFromBob = '';
        var emojisFromAlice = '';

        unawaited(
          incomingKeyVerificationRunnerStream.forEach((runner) async {
            debugPrint(
              'Bob - incoming verification runner step: ${runner.lastStep}',
            );
            if (runner.lastStep == 'm.key.verification.request') {
              await runner.acceptVerification();
            }
            if (runner.lastStep == 'm.key.verification.key') {
              emojisFromAlice = extractEmojiString(runner.emojis);
              debugPrint('Bob received emojis: $emojisFromAlice');

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
              'Alice - outgoing verification step: ${runner.lastStep}',
            );
            if (runner.lastStep == 'm.key.verification.key') {
              emojisFromBob = extractEmojiString(runner.emojis);
              debugPrint('Alice received emojis: $emojisFromBob');

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

        debugPrint('\n--- Alice verifies Bob');
        await alice.verifyDevice(unverifiedAlice.first);

        await waitUntil(() => emojisFromAlice.isNotEmpty);
        await waitUntil(() => emojisFromBob.isNotEmpty);

        expect(emojisFromAlice, isNotEmpty);
        expect(emojisFromBob, isNotEmpty);
        expect(emojisFromAlice, emojisFromAlice);

        debugPrint(
          '\n--- Alice and Bob both have no unverified devices',
        );

        await waitUntil(() => alice.getUnverifiedDevices().isEmpty);
        await waitUntil(() => bob.getUnverifiedDevices().isEmpty);

        expect(alice.getUnverifiedDevices(), isEmpty);
        expect(bob.getUnverifiedDevices(), isEmpty);

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

        debugPrint('\n--- Alice sends $n message');
        for (var i = 0; i < n; i++) {
          await sendTestMessage(
            i,
            device: alice,
            deviceName: 'aliceDevice',
          );
        }

        debugPrint('\n--- Bob sends $n message');
        for (var i = 0; i < n; i++) {
          await sendTestMessage(
            i,
            device: bob,
            deviceName: 'bobDevice',
          );
        }

        await waitUntilAsync(
          () async {
            final currentCount = await aliceDb.getJournalCount();
            return currentCount == n;
          },
        );
        debugPrint('\n--- Alice finished receiving messages');
        final aliceEntriesCount = await aliceDb.getJournalCount();
        expect(aliceEntriesCount, n);
        debugPrint('Alice persisted $aliceEntriesCount entries');

        await waitUntilAsync(
          () async => await bobDb.getJournalCount() == n,
        );
        debugPrint('\n--- Bob finished receiving messages');
        final bobEntriesCount = await bobDb.getJournalCount();
        expect(bobEntriesCount, n);
        debugPrint('Bob persisted $bobEntriesCount entries');

        await Future<void>.delayed(const Duration(seconds: 15));
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
