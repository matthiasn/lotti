import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
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

MatrixService _createMatrixService({
  required MatrixConfig config,
  required MatrixSyncGateway gateway,
  required LoggingService loggingService,
  required JournalDb journalDb,
  required SettingsDb settingsDb,
  required SecureStorage secureStorage,
  required String deviceName,
  required UserActivityService activityService,
  required Directory documentsDirectory,
  required UpdateNotifications updateNotifications,
  required AiConfigRepository aiConfigRepository,
  required SentEventRegistry sentEventRegistry,
}) {
  final activityGate = UserActivityGate(
    activityService: activityService,
  );
  final messageSender = MatrixMessageSender(
    loggingService: loggingService,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
    sentEventRegistry: sentEventRegistry,
  );
  final readMarkerService = SyncReadMarkerService(
    settingsDb: settingsDb,
    loggingService: loggingService,
  );
  final eventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    updateNotifications: updateNotifications,
    aiConfigRepository: aiConfigRepository,
    settingsDb: settingsDb,
  );

  return MatrixService(
    matrixConfig: config,
    gateway: gateway,
    loggingService: loggingService,
    activityGate: activityGate,
    messageSender: messageSender,
    journalDb: journalDb,
    settingsDb: settingsDb,
    readMarkerService: readMarkerService,
    eventProcessor: eventProcessor,
    secureStorage: secureStorage,
    deviceDisplayName: deviceName,
    ownsActivityGate: true,
    attachmentIndex: AttachmentIndex(logging: loggingService),
    sentEventRegistry: sentEventRegistry,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(minutes: 1);

  // description and how to run in https://github.com/matthiasn/lotti/pull/1695
  group('MatrixService V2 Tests', () {
    final secureStorageMock = MockSecureStorage();
    const testUserEnv1 = 'TEST_USER1';
    const testUserEnv2 = 'TEST_USER2';
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    // create separate databases for each simulated device & suppress warning
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final mockUpdateNotifications = MockUpdateNotifications();
    late LoggingService sharedLoggingService;
    late UserActivityService sharedUserActivityService;
    late Directory sharedDocumentsDirectory;
    late AiConfigRepository sharedAiConfigRepository;

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(
      () => mockUpdateNotifications.notify(any()),
    ).thenAnswer((_) {});
    when(() => secureStorageMock.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(
      () => secureStorageMock.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => secureStorageMock.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    final aliceDb = JournalDb(
      overriddenFilename: 'alice_db.sqlite',
      inMemoryDatabase: true,
    );
    final bobDb = JournalDb(
      overriddenFilename: 'bob_db.sqlite',
      inMemoryDatabase: true,
    );
    late AiConfigDb aiConfigDb;

    const testSlowNetwork = bool.fromEnvironment(testSlowNetworkEnv);

    if (testSlowNetwork) {
      debugPrint('Testing with degraded network.');
    }

    final missingEnv = <String>[
      if (!const bool.hasEnvironment(testUserEnv1)) testUserEnv1,
      if (!const bool.hasEnvironment(testUserEnv2)) testUserEnv2,
    ];
    final skipReason = missingEnv.isEmpty
        ? null
        : 'Missing: ${missingEnv.join(', ')}. Run via run_matrix_tests.sh';

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

    const defaultDelay = 5;

    setUpAll(() async {
      await vod.init();
      final tmpDir = await getTemporaryDirectory();
      final docDir = Directory('${tmpDir.path}/${uuid.v1()}')
        ..createSync(recursive: true);
      debugPrint('Created temporary docDir ${docDir.path}');
      sharedDocumentsDirectory = docDir;

      aiConfigDb = AiConfigDb(inMemoryDatabase: true);
      sharedAiConfigRepository = AiConfigRepository(aiConfigDb);
      sharedLoggingService = LoggingService();
      sharedUserActivityService = UserActivityService();

      // Register essential dependencies
      getIt
        ..registerSingleton<Directory>(sharedDocumentsDirectory)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingService>(sharedLoggingService)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<UserActivityService>(sharedUserActivityService)
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true))
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<AiConfigDb>(aiConfigDb)
        ..registerSingleton<AiConfigRepository>(sharedAiConfigRepository);

      // Ensure all GetIt instances are properly initialized
      // Give time for any async initializations to complete
      await Future<void>.delayed(const Duration(seconds: 2));
    });

    setUp(() {});

    tearDownAll(() async {
      // Ensure proper cleanup before resetting GetIt
      try {
        await aliceDb.close();
        await bobDb.close();
        await aiConfigDb.close();
      } catch (e) {
        debugPrint('Error during database cleanup: $e');
      }
    });

    tearDown(() async {
      // Perform any per-test cleanup here
    });

    test(
      'Create room & join (sync v2)',
      () async {
        debugPrint('\n--- Alice goes live');

        // Make sure the GetIt dependencies are ready before creating MatrixService
        await Future<void>.delayed(const Duration(seconds: 1));

        final aliceClient = await createMatrixClient(
          documentsDirectory: sharedDocumentsDirectory,
          dbName: 'AliceV2',
        );
        final aliceRegistry = SentEventRegistry();
        final aliceGateway = MatrixSdkGateway(
          client: aliceClient,
          sentEventRegistry: aliceRegistry,
        );
        final loggingService = sharedLoggingService;
        final aliceSettingsDb = SettingsDb(inMemoryDatabase: true);
        final alice = _createMatrixService(
          config: config1,
          gateway: aliceGateway,
          loggingService: loggingService,
          journalDb: aliceDb,
          settingsDb: aliceSettingsDb,
          secureStorage: secureStorageMock,
          deviceName: 'AliceV2',
          activityService: sharedUserActivityService,
          documentsDirectory: sharedDocumentsDirectory,
          updateNotifications: mockUpdateNotifications,
          aiConfigRepository: sharedAiConfigRepository,
          sentEventRegistry: aliceRegistry,
        );
        addTearDown(() async {
          try {
            await alice.dispose();
          } catch (_) {}
        });

        await alice.init();
        expect(alice.debugPipeline, isNotNull);

        // Allow time for constructor initialization to complete
        await Future<void>.delayed(const Duration(seconds: 1));

        await alice.login();
        debugPrint('Alice - deviceId: ${alice.client.deviceID}');

        final roomId = await alice.createRoom();

        debugPrint('Alice - room created: $roomId');

        expect(roomId, isNotEmpty);

        final joinRes = await alice.joinRoom(roomId);
        debugPrint('Alice - room joined: $joinRes');
        debugPrint(
          'Alice - room encrypted: ${alice.syncRoom?.encrypted}',
        );

        debugPrint('\n--- Bob goes live');
        final bobClient = await createMatrixClient(
          documentsDirectory: sharedDocumentsDirectory,
          dbName: 'BobV2',
        );
        final bobRegistry = SentEventRegistry();
        final bobGateway = MatrixSdkGateway(
          client: bobClient,
          sentEventRegistry: bobRegistry,
        );
        final bobSettingsDb = SettingsDb(inMemoryDatabase: true);
        final bob = _createMatrixService(
          config: config2,
          gateway: bobGateway,
          loggingService: sharedLoggingService,
          journalDb: bobDb,
          settingsDb: bobSettingsDb,
          secureStorage: secureStorageMock,
          deviceName: 'BobV2',
          activityService: sharedUserActivityService,
          documentsDirectory: sharedDocumentsDirectory,
          updateNotifications: mockUpdateNotifications,
          aiConfigRepository: sharedAiConfigRepository,
          sentEventRegistry: bobRegistry,
        );
        addTearDown(() async {
          try {
            await bob.dispose();
          } catch (_) {}
        });

        await bob.init();
        expect(bob.debugPipeline, isNotNull);

        // Allow time for constructor initialization to complete
        await Future<void>.delayed(const Duration(seconds: 1));

        await bob.login();
        debugPrint('Bob - deviceId: ${bob.client.deviceID}');

        debugPrint('\n--- Alice invites Bob into room $roomId');
        await alice.inviteToSyncRoom(userId: bobUserName);
        // Allow invite to propagate to Bob's homeserver before joining
        await waitSeconds(defaultDelay);

        final joinRes2 = await bob.joinRoom(roomId);
        debugPrint('Bob - room joined: $joinRes2');

        // Wait for devices to discover each other (event-driven)
        await waitUntil(
          () => alice.getUnverifiedDevices().isNotEmpty,
          timeout: timeout,
        );
        await waitUntil(
          () => bob.getUnverifiedDevices().isNotEmpty,
          timeout: timeout,
        );

        final unverifiedAlice = alice.getUnverifiedDevices();
        final unverifiedBob = bob.getUnverifiedDevices();

        debugPrint('\nAlice - unverified: $unverifiedAlice');
        debugPrint('\nBob - unverified: $unverifiedBob');

        expect(unverifiedAlice, isNotNull);
        expect(unverifiedBob, isNotNull);

        final outgoingKeyVerificationStream = alice.keyVerificationStream;
        final incomingKeyVerificationRunnerStream =
            bob.incomingKeyVerificationRunnerStream;

        var emojisFromBob = '';
        var emojisFromAlice = '';

        final incomingSubscription = incomingKeyVerificationRunnerStream.listen(
          (runner) async {
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
                timeout: timeout,
              );

              await runner.acceptEmojiVerification();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            fail(
              'incomingKeyVerificationRunnerStream error: $error\n$stackTrace',
            );
          },
        );
        addTearDown(incomingSubscription.cancel);

        final outgoingSubscription = outgoingKeyVerificationStream.listen(
          (runner) async {
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
                timeout: timeout,
              );

              await runner.acceptEmojiVerification();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            fail(
              'keyVerificationStream error: $error\n$stackTrace',
            );
          },
        );
        addTearDown(outgoingSubscription.cancel);

        // Allow stream subscriptions to be fully established before initiating verification
        await waitSeconds(defaultDelay);

        debugPrint('\n--- Alice verifies Bob');
        await alice.verifyDevice(unverifiedAlice.first);

        await waitUntil(() => emojisFromAlice.isNotEmpty, timeout: timeout);
        await waitUntil(
          () => emojisFromBob.isNotEmpty,
          timeout: timeout,
        );

        expect(emojisFromAlice, isNotEmpty);
        expect(emojisFromBob, isNotEmpty);
        expect(emojisFromAlice, emojisFromBob);

        debugPrint(
          '\n--- Alice and Bob both have no unverified devices',
        );

        await waitUntil(
          () => alice.getUnverifiedDevices().isEmpty,
          timeout: timeout,
        );
        await waitUntil(
          () => bob.getUnverifiedDevices().isEmpty,
          timeout: timeout,
        );

        expect(alice.getUnverifiedDevices(), isEmpty);
        expect(bob.getUnverifiedDevices(), isEmpty);

        Future<void> sendTestMessage(
          int index, {
          required MatrixService device,
          required String deviceName,
        }) async {
          final id = const Uuid().v1();
          final now = DateTime.now();

          final entity = JournalEntry(
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
          );

          final jsonPath = relativeEntityPath(entity);

          await saveJournalEntityJson(entity);

          await device.sendMatrixMsg(
            SyncMessage.journalEntity(
              id: id,
              status: SyncEntryStatus.initial,
              vectorClock: VectorClock({deviceName: index}),
              jsonPath: jsonPath,
            ),
            myRoomId: roomId,
          );
        }

        const n = testSlowNetwork ? 10 : 100;
        // With signal-driven consumer and self-event suppression, each device
        // applies only the other device's messages. Expect n entries per DB.
        const expectedEntriesPerDb = n;

        debugPrint('\n--- Alice sends $n message');
        for (var i = 0; i < n; i++) {
          await sendTestMessage(
            i,
            device: alice,
            deviceName: 'aliceDeviceV2',
          );
        }

        debugPrint('\n--- Bob sends $n message');
        for (var i = 0; i < n; i++) {
          await sendTestMessage(
            i,
            device: bob,
            deviceName: 'bobDeviceV2',
          );
        }

        await alice.forceRescan();
        debugPrint(
          'Alice V2 metrics after rescan: '
          '${alice.debugPipeline?.metricsSnapshot()}',
        );
        await bob.forceRescan();
        debugPrint(
          'Bob V2 metrics after rescan: '
          '${bob.debugPipeline?.metricsSnapshot()}',
        );

        var lastAliceCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await aliceDb.getJournalCount();
            if (currentCount != lastAliceCount) {
              debugPrint('Alice journal count: $currentCount');
              lastAliceCount = currentCount;
            }
            if (currentCount < expectedEntriesPerDb) {
              // Under degraded network, proactively drive catch-up and retries
              // while we wait to avoid long hangs on CI.
              await alice.forceRescan();
              await alice.retryNow();
              // Allow the homeserver to settle before the next fetch.
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
            return currentCount >= expectedEntriesPerDb;
          },
          timeout: timeout,
        );
        debugPrint('\n--- Alice finished receiving messages');
        final aliceEntriesCount = await aliceDb.getJournalCount();
        expect(aliceEntriesCount, expectedEntriesPerDb);
        debugPrint('Alice persisted $aliceEntriesCount entries');

        var lastBobCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              debugPrint('Bob journal count: $currentCount');
              lastBobCount = currentCount;
            }
            if (currentCount < expectedEntriesPerDb) {
              await bob.forceRescan();
              await bob.retryNow();
              // Allow the homeserver to settle before the next fetch.
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
            return currentCount >= expectedEntriesPerDb;
          },
          timeout: timeout,
        );
        debugPrint('\n--- Bob finished receiving messages');
        final bobEntriesCount = await bobDb.getJournalCount();
        expect(bobEntriesCount, expectedEntriesPerDb);
        debugPrint('Bob persisted $bobEntriesCount entries');
      },
      timeout: const Timeout(Duration(minutes: 15)),
      skip: skipReason ?? false,
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
