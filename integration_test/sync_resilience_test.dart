import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../test/mocks/mocks.dart';
import 'helpers/sync_test_helpers.dart';
import 'helpers/toxiproxy_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(minutes: 2);

  group('Sync Resilience Tests', () {
    final secureStorageMock = MockSecureStorage();

    // Each test gets its own user pair to avoid device accumulation
    // All env vars must be compile-time constants
    const testUser1 = String.fromEnvironment('TEST_USER1');
    const testUser2 = String.fromEnvironment('TEST_USER2');
    const testUser3 = String.fromEnvironment('TEST_USER3');
    const testUser4 = String.fromEnvironment('TEST_USER4');
    const testUser5 = String.fromEnvironment('TEST_USER5');
    const testUser6 = String.fromEnvironment('TEST_USER6');
    const testUser7 = String.fromEnvironment('TEST_USER7');
    const testUser8 = String.fromEnvironment('TEST_USER8');

    // create separate databases for each simulated device & suppress warning
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final mockUpdateNotifications = MockUpdateNotifications();
    late LoggingService sharedLoggingService;
    late UserActivityService sharedUserActivityService;
    late Directory sharedDocumentsDirectory;
    late AiConfigRepository sharedAiConfigRepository;
    late ToxiproxyController toxiproxy;

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

    late JournalDb aliceDb;
    late JournalDb bobDb;
    late AiConfigDb aiConfigDb;

    // Alice uses direct homeserver, Bob uses proxy so we can control his network
    const aliceHomeServer = 'http://localhost:8008';
    const bobHomeServer = 'http://localhost:18008';
    const testPassword = '?Secret123@';

    // Check if first user pair is present
    final missingEnv = <String>[
      if (!const bool.hasEnvironment('TEST_USER1')) 'TEST_USER1',
      if (!const bool.hasEnvironment('TEST_USER2')) 'TEST_USER2',
    ];
    final skipReason = missingEnv.isEmpty
        ? null
        : 'Missing: ${missingEnv.join(', ')}. Run via run_resilience_tests.sh';

    /// Get user credentials for a specific test index
    (String alice, String bob) getUserPair(int testIndex) {
      switch (testIndex) {
        case 0:
          return (
            testUser1.isNotEmpty ? testUser1 : '@test_alice:localhost',
            testUser2.isNotEmpty ? testUser2 : '@test_bob:localhost',
          );
        case 1:
          return (
            testUser3.isNotEmpty ? testUser3 : '@test_alice:localhost',
            testUser4.isNotEmpty ? testUser4 : '@test_bob:localhost',
          );
        case 2:
          return (
            testUser5.isNotEmpty ? testUser5 : '@test_alice:localhost',
            testUser6.isNotEmpty ? testUser6 : '@test_bob:localhost',
          );
        case 3:
          return (
            testUser7.isNotEmpty ? testUser7 : '@test_alice:localhost',
            testUser8.isNotEmpty ? testUser8 : '@test_bob:localhost',
          );
        default:
          throw ArgumentError('Invalid test index: $testIndex');
      }
    }

    /// Get configs for a specific test index
    (MatrixConfig alice, MatrixConfig bob) getConfigs(int testIndex) {
      final users = getUserPair(testIndex);
      return (
        MatrixConfig(
          homeServer: aliceHomeServer,
          user: users.$1,
          password: testPassword,
        ),
        MatrixConfig(
          homeServer: bobHomeServer,
          user: users.$2,
          password: testPassword,
        ),
      );
    }

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

      // Setup Toxiproxy
      toxiproxy = ToxiproxyController();
      await toxiproxy.setup();
      debugPrint('Toxiproxy setup complete');

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

      // Give time for any async initializations to complete
      await Future<void>.delayed(const Duration(seconds: 2));
    });

    setUp(() {
      // Create fresh databases for each test
      aliceDb = JournalDb(
        overriddenFilename: 'alice_resilience_${uuid.v1()}.sqlite',
        inMemoryDatabase: true,
      );
      bobDb = JournalDb(
        overriddenFilename: 'bob_resilience_${uuid.v1()}.sqlite',
        inMemoryDatabase: true,
      );
    });

    tearDownAll(() async {
      try {
        await aiConfigDb.close();
        toxiproxy.close();
      } catch (e) {
        debugPrint('Error during cleanup: $e');
      }
    });

    tearDown(() async {
      // Reset toxiproxy to clean state
      await toxiproxy.reset(ToxiproxyController.dendriteProxy);

      try {
        await aliceDb.close();
        await bobDb.close();
      } catch (e) {
        debugPrint('Error during database cleanup: $e');
      }
    });

    Future<({MatrixService alice, MatrixService bob, String roomId})>
        setupAliceAndBob({required int testIndex}) async {
      // Ensure proxy is enabled at the start
      await toxiproxy.reset(ToxiproxyController.dendriteProxy);

      final configs = getConfigs(testIndex);
      final aliceConfig = configs.$1;
      final bobConfig = configs.$2;
      final userPair = getUserPair(testIndex);

      debugPrint('\n--- Setting up Alice (direct connection)');
      debugPrint('Alice user: ${userPair.$1}');
      final aliceClient = await createMatrixClient(
        documentsDirectory: sharedDocumentsDirectory,
        dbName: 'AliceResilience_${uuid.v1()}',
      );
      final aliceRegistry = SentEventRegistry();
      final aliceGateway = MatrixSdkGateway(
        client: aliceClient,
        sentEventRegistry: aliceRegistry,
      );
      final aliceSettingsDb = SettingsDb(inMemoryDatabase: true);
      final alice = createMatrixService(
        config: aliceConfig,
        gateway: aliceGateway,
        loggingService: sharedLoggingService,
        journalDb: aliceDb,
        settingsDb: aliceSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'AliceResilience',
        activityService: sharedUserActivityService,
        documentsDirectory: sharedDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
        sentEventRegistry: aliceRegistry,
      );

      await alice.init();
      await alice.login();
      debugPrint('Alice - deviceId: ${alice.client.deviceID}');

      final roomId = await alice.createRoom();
      debugPrint('Alice - room created: $roomId');

      await alice.joinRoom(roomId);
      debugPrint('Alice - room joined');

      debugPrint('\n--- Setting up Bob (via proxy)');
      debugPrint('Bob user: ${userPair.$2}');
      final bobClient = await createMatrixClient(
        documentsDirectory: sharedDocumentsDirectory,
        dbName: 'BobResilience_${uuid.v1()}',
      );
      final bobRegistry = SentEventRegistry();
      final bobGateway = MatrixSdkGateway(
        client: bobClient,
        sentEventRegistry: bobRegistry,
      );
      final bobSettingsDb = SettingsDb(inMemoryDatabase: true);
      final bob = createMatrixService(
        config: bobConfig,
        gateway: bobGateway,
        loggingService: sharedLoggingService,
        journalDb: bobDb,
        settingsDb: bobSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'BobResilience',
        activityService: sharedUserActivityService,
        documentsDirectory: sharedDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
        sentEventRegistry: bobRegistry,
      );

      await bob.init();
      await bob.login();
      debugPrint('Bob - deviceId: ${bob.client.deviceID}');

      debugPrint('\n--- Alice invites Bob');
      await alice.inviteToSyncRoom(userId: userPair.$2);
      await waitSeconds(defaultDelay);

      await bob.joinRoom(roomId);
      debugPrint('Bob - room joined');
      await waitSeconds(defaultDelay);

      // Verify devices and wait for unverified devices
      debugPrint('\n--- Waiting for unverified devices');
      await waitUntil(
        () => alice.getUnverifiedDevices().isNotEmpty,
        timeout: timeout,
      );
      await waitUntil(
        () => bob.getUnverifiedDevices().isNotEmpty,
        timeout: timeout,
      );

      // Get the current device IDs so we can verify them specifically
      final aliceDeviceId = alice.client.deviceID;
      final bobDeviceId = bob.client.deviceID;
      debugPrint('Alice deviceId: $aliceDeviceId, Bob deviceId: $bobDeviceId');

      // Get all unverified devices
      var unverifiedAlice = alice.getUnverifiedDevices();
      debugPrint('Alice - unverified: ${unverifiedAlice.length} devices');

      // If there are no unverified devices, we're good to go
      if (unverifiedAlice.isEmpty) {
        debugPrint('No unverified devices found, skipping verification');
        return (alice: alice, bob: bob, roomId: roomId);
      }

      final outgoingKeyVerificationStream = alice.keyVerificationStream;
      final incomingKeyVerificationRunnerStream =
          bob.incomingKeyVerificationRunnerStream;

      var emojisFromBob = '';
      var emojisFromAlice = '';
      var verificationComplete = false;

      final incomingSubscription = incomingKeyVerificationRunnerStream.listen(
        (runner) async {
          debugPrint('Bob - incoming verification step: ${runner.lastStep}');
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
          if (runner.lastStep == 'm.key.verification.done') {
            verificationComplete = true;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('incomingKeyVerificationRunnerStream error: $error');
        },
      );

      final outgoingSubscription = outgoingKeyVerificationStream.listen(
        (runner) async {
          debugPrint('Alice - outgoing verification step: ${runner.lastStep}');
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromBob = extractEmojiString(runner.emojis);
            debugPrint('Alice received emojis: $emojisFromBob');

            await waitUntil(
              () =>
                  emojisFromAlice == emojisFromBob && emojisFromBob.isNotEmpty,
              timeout: timeout,
            );

            await runner.acceptEmojiVerification();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('keyVerificationStream error: $error');
        },
      );

      // Verify all unverified devices one by one
      for (final device in unverifiedAlice) {
        final deviceId = device.deviceId;
        debugPrint('\n--- Alice verifies device: $deviceId');

        emojisFromBob = '';
        emojisFromAlice = '';
        verificationComplete = false;

        await alice.verifyDevice(device);

        try {
          await waitUntil(() => emojisFromAlice.isNotEmpty, timeout: timeout);
          await waitUntil(() => emojisFromBob.isNotEmpty, timeout: timeout);
          expect(emojisFromAlice, emojisFromBob);
          await waitUntil(() => verificationComplete, timeout: timeout);
          debugPrint('Device $deviceId verified successfully');
        } catch (e) {
          debugPrint('Failed to verify device $deviceId: $e');
          // Continue with other devices even if one fails
        }

        await waitSeconds(2);
      }

      await incomingSubscription.cancel();
      await outgoingSubscription.cancel();

      // Wait a bit for verification to propagate
      await waitSeconds(defaultDelay);

      // Check if there are still unverified devices
      unverifiedAlice = alice.getUnverifiedDevices();
      debugPrint('Remaining unverified devices: ${unverifiedAlice.length}');

      debugPrint('\n--- Setup complete, devices verified');
      await waitSeconds(defaultDelay);

      return (alice: alice, bob: bob, roomId: roomId);
    }

    test(
      'Network interruption during sync - messages eventually sync',
      () async {
        final setup = await setupAliceAndBob(testIndex: 0);
        final alice = setup.alice;
        final bob = setup.bob;
        final roomId = setup.roomId;

        addTearDown(() async {
          try {
            await alice.dispose();
          } catch (_) {}
          try {
            await bob.dispose();
          } catch (_) {}
        });

        const totalMessages = 20;
        const interruptAfter = 8;

        debugPrint('\n--- Alice sends $totalMessages messages');
        debugPrint('    Network will be cut after $interruptAfter messages');

        // Send first batch
        for (var i = 0; i < interruptAfter; i++) {
          await sendTestMessage(
            matrixService: alice,
            deviceName: 'aliceResilience',
            index: i,
            roomId: roomId,
          );
          debugPrint('Alice sent message $i');
        }

        // Give Bob time to start receiving
        await waitSeconds(3);

        // Cut network to Bob
        debugPrint('\n--- Cutting network to Bob');
        await toxiproxy.disconnect(ToxiproxyController.dendriteProxy);

        // Send remaining messages while Bob is offline
        for (var i = interruptAfter; i < totalMessages; i++) {
          // Use direct homeserver for Alice (not via proxy)
          await sendTestMessage(
            matrixService: alice,
            deviceName: 'aliceResilience',
            index: i,
            roomId: roomId,
          );
          debugPrint('Alice sent message $i (Bob offline)');
        }

        // Wait a bit with network cut
        await waitSeconds(5);

        // Restore network
        debugPrint('\n--- Restoring network to Bob');
        await toxiproxy.reconnect(ToxiproxyController.dendriteProxy);

        // Force Bob to catch up
        debugPrint('\n--- Forcing Bob to rescan');
        await bob.forceRescan();

        // Wait for Bob to receive all messages
        var lastBobCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              debugPrint('Bob journal count: $currentCount');
              lastBobCount = currentCount;
            }
            if (currentCount < totalMessages) {
              await bob.forceRescan();
              await bob.retryNow();
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
            return currentCount >= totalMessages;
          },
          timeout: timeout,
        );

        final bobEntriesCount = await bobDb.getJournalCount();
        debugPrint('Bob final count: $bobEntriesCount');
        expect(bobEntriesCount, totalMessages);

        // Check metrics
        final metrics = await bob.getSyncMetrics();
        debugPrint('Bob metrics: $metrics');
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'High latency - messages still sync correctly',
      () async {
        final setup = await setupAliceAndBob(testIndex: 1);
        final alice = setup.alice;
        final bob = setup.bob;
        final roomId = setup.roomId;

        addTearDown(() async {
          try {
            await alice.dispose();
          } catch (_) {}
          try {
            await bob.dispose();
          } catch (_) {}
        });

        // Add significant latency
        debugPrint('\n--- Adding 2000ms latency');
        await toxiproxy.addLatency(
          ToxiproxyController.dendriteProxy,
          latencyMs: 2000,
        );

        const totalMessages = 10;

        debugPrint(
            '\n--- Alice sends $totalMessages messages with high latency');
        for (var i = 0; i < totalMessages; i++) {
          await sendTestMessage(
            matrixService: alice,
            deviceName: 'aliceLatency',
            index: i,
            roomId: roomId,
          );
          debugPrint('Alice sent message $i');
        }

        // Wait for Bob to receive with longer timeout due to latency
        var lastBobCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              debugPrint('Bob journal count: $currentCount');
              lastBobCount = currentCount;
            }
            if (currentCount < totalMessages) {
              await bob.forceRescan();
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
            return currentCount >= totalMessages;
          },
          timeout: const Duration(minutes: 3),
        );

        final bobEntriesCount = await bobDb.getJournalCount();
        debugPrint('Bob final count: $bobEntriesCount');
        expect(bobEntriesCount, totalMessages);
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'Bandwidth throttling - messages sync without data loss',
      () async {
        final setup = await setupAliceAndBob(testIndex: 2);
        final alice = setup.alice;
        final bob = setup.bob;
        final roomId = setup.roomId;

        addTearDown(() async {
          try {
            await alice.dispose();
          } catch (_) {}
          try {
            await bob.dispose();
          } catch (_) {}
        });

        // Severely limit bandwidth
        debugPrint('\n--- Limiting bandwidth to 50 KB/s');
        await toxiproxy.limitBandwidth(
          ToxiproxyController.dendriteProxy,
          bytesPerSecond: 50000,
        );

        const totalMessages = 15;

        debugPrint(
            '\n--- Alice sends $totalMessages messages with limited bandwidth');
        for (var i = 0; i < totalMessages; i++) {
          await sendTestMessage(
            matrixService: alice,
            deviceName: 'aliceBandwidth',
            index: i,
            roomId: roomId,
          );
          debugPrint('Alice sent message $i');
        }

        // Wait for Bob to receive
        var lastBobCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              debugPrint('Bob journal count: $currentCount');
              lastBobCount = currentCount;
            }
            if (currentCount < totalMessages) {
              await bob.forceRescan();
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
            return currentCount >= totalMessages;
          },
          timeout: const Duration(minutes: 3),
        );

        final bobEntriesCount = await bobDb.getJournalCount();
        debugPrint('Bob final count: $bobEntriesCount');
        expect(bobEntriesCount, totalMessages);
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'Multiple network interruptions - eventual consistency',
      () async {
        final setup = await setupAliceAndBob(testIndex: 3);
        final alice = setup.alice;
        final bob = setup.bob;
        final roomId = setup.roomId;

        addTearDown(() async {
          try {
            await alice.dispose();
          } catch (_) {}
          try {
            await bob.dispose();
          } catch (_) {}
        });

        const totalMessages = 30;
        const messagesPerBatch = 10;

        debugPrint('\n--- Sending messages with intermittent disconnections');

        for (var batch = 0; batch < 3; batch++) {
          final start = batch * messagesPerBatch;
          final end = start + messagesPerBatch;

          debugPrint('\n--- Batch $batch: Sending messages $start-${end - 1}');

          for (var i = start; i < end; i++) {
            await sendTestMessage(
              matrixService: alice,
              deviceName: 'aliceIntermittent',
              index: i,
              roomId: roomId,
            );
          }

          if (batch < 2) {
            // Disconnect briefly between batches
            debugPrint('--- Disconnecting...');
            await toxiproxy.disconnect(ToxiproxyController.dendriteProxy);
            await waitSeconds(3);
            debugPrint('--- Reconnecting...');
            await toxiproxy.reconnect(ToxiproxyController.dendriteProxy);
            // Give Bob time to sync after reconnection
            await waitSeconds(5);
            debugPrint('--- Forcing rescan after reconnect');
            await bob.forceRescan();
            await waitSeconds(3);
          }
        }

        // Force catch-up
        debugPrint('\n--- Final catch-up');
        await bob.forceRescan();

        // Wait for Bob to receive all messages - use longer timeout for this test
        const extendedTimeout = Duration(minutes: 4);
        var lastBobCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              debugPrint('Bob journal count: $currentCount');
              lastBobCount = currentCount;
            }
            if (currentCount < totalMessages) {
              await bob.forceRescan();
              await bob.retryNow();
              await Future<void>.delayed(const Duration(seconds: 1));
            }
            return currentCount >= totalMessages;
          },
          timeout: extendedTimeout,
        );

        final bobEntriesCount = await bobDb.getJournalCount();
        debugPrint('Bob final count: $bobEntriesCount');
        expect(bobEntriesCount, totalMessages);
      },
      timeout: const Timeout(Duration(minutes: 8)),
      skip: skipReason ?? false,
    );
  });
}
