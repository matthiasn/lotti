import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart' hide uuid;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/mocks/mocks.dart';
import '../test/widget_test_utils.dart';
import 'helpers/sync_test_helpers.dart';
import 'helpers/toxiproxy_controller.dart';
import 'matrix_test_room.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(minutes: 2);

  group('Sync Resilience Tests', () {
    final secureStorageMock = MockSecureStorage();

    // Each test gets its own user pair to avoid device accumulation
    // Scripts use Dart defines; MCP/IDE runners can supply process environment.
    final testUser1 = const String.fromEnvironment('TEST_USER1').isNotEmpty
        ? const String.fromEnvironment('TEST_USER1')
        : Platform.environment['TEST_USER1'] ?? '';
    final testUser2 = const String.fromEnvironment('TEST_USER2').isNotEmpty
        ? const String.fromEnvironment('TEST_USER2')
        : Platform.environment['TEST_USER2'] ?? '';
    final testUser3 = const String.fromEnvironment('TEST_USER3').isNotEmpty
        ? const String.fromEnvironment('TEST_USER3')
        : Platform.environment['TEST_USER3'] ?? '';
    final testUser4 = const String.fromEnvironment('TEST_USER4').isNotEmpty
        ? const String.fromEnvironment('TEST_USER4')
        : Platform.environment['TEST_USER4'] ?? '';
    final testUser5 = const String.fromEnvironment('TEST_USER5').isNotEmpty
        ? const String.fromEnvironment('TEST_USER5')
        : Platform.environment['TEST_USER5'] ?? '';
    final testUser6 = const String.fromEnvironment('TEST_USER6').isNotEmpty
        ? const String.fromEnvironment('TEST_USER6')
        : Platform.environment['TEST_USER6'] ?? '';
    final testUser7 = const String.fromEnvironment('TEST_USER7').isNotEmpty
        ? const String.fromEnvironment('TEST_USER7')
        : Platform.environment['TEST_USER7'] ?? '';
    final testUser8 = const String.fromEnvironment('TEST_USER8').isNotEmpty
        ? const String.fromEnvironment('TEST_USER8')
        : Platform.environment['TEST_USER8'] ?? '';

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
    when(
      () => secureStorageMock.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => secureStorageMock.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => secureStorageMock.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});

    late JournalDb aliceDb;
    late JournalDb bobDb;
    late Directory aliceDocumentsDirectory;
    late Directory bobDocumentsDirectory;
    final expectedEntries = <JournalEntry>[];
    late AiConfigDb aiConfigDb;

    // Alice uses direct homeserver, Bob uses proxy so we can control his network
    const aliceHomeServer = 'http://localhost:8008';
    const bobHomeServer = 'http://localhost:18008';
    const testPassword = '?Secret123@';

    final testUsers = [
      testUser1,
      testUser2,
      testUser3,
      testUser4,
      testUser5,
      testUser6,
      testUser7,
      testUser8,
    ];
    final missingEnv = <String>[
      for (var i = 0; i < testUsers.length; i++)
        if (testUsers[i].isEmpty) 'TEST_USER${i + 1}',
    ];
    final skipReason = missingEnv.isEmpty
        ? null
        : 'Missing: ${missingEnv.join(', ')}. Run via run_resilience_tests.sh';

    (String alice, String bob) getUserPair(int testIndex) =>
        (testUsers[testIndex * 2], testUsers[testIndex * 2 + 1]);

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
      SharedPreferences.setMockInitialValues({});
      await vod.init();
      final docDir = await Directory.systemTemp.createTemp('lotti-resilience-');
      debugPrint('Created temporary docDir ${docDir.path}');
      sharedDocumentsDirectory = docDir;

      aiConfigDb = AiConfigDb(inMemoryDatabase: true);
      sharedAiConfigRepository = AiConfigRepository(aiConfigDb);
      sharedUserActivityService = UserActivityService();

      // Setup Toxiproxy
      toxiproxy = ToxiproxyController();
      await toxiproxy.setup();
      debugPrint('Toxiproxy setup complete');

      final harness = await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<Directory>(sharedDocumentsDirectory)
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
            ..registerSingleton<UserActivityService>(sharedUserActivityService)
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true))
            ..registerSingleton<SecureStorage>(secureStorageMock)
            ..registerSingleton<AiConfigDb>(aiConfigDb)
            ..registerSingleton<AiConfigRepository>(sharedAiConfigRepository);
        },
      );
      sharedLoggingService = harness.loggingService;
    });

    setUp(() async {
      expectedEntries.clear();
      aliceDocumentsDirectory = await Directory(
        '${sharedDocumentsDirectory.path}/alice-${uuid.v1()}',
      ).create();
      bobDocumentsDirectory = await Directory(
        '${sharedDocumentsDirectory.path}/bob-${uuid.v1()}',
      ).create();
      expect(aliceDocumentsDirectory.path, isNot(bobDocumentsDirectory.path));
      // Create fresh databases for each test
      aliceDb = JournalDb(
        overriddenFilename: 'alice_resilience_${uuid.v1()}.sqlite',
        documentsDirectory: aliceDocumentsDirectory,
        inMemoryDatabase: true,
      );
      bobDb = JournalDb(
        overriddenFilename: 'bob_resilience_${uuid.v1()}.sqlite',
        documentsDirectory: bobDocumentsDirectory,
        inMemoryDatabase: true,
      );
    });

    tearDownAll(() async {
      await getIt<JournalDb>().close();
      await getIt<SettingsDb>().close();
      await aiConfigDb.close();
      await sharedUserActivityService.dispose();
      await sharedLoggingService.flush();
      await sharedLoggingService.dispose();
      toxiproxy.close();
      await tearDownTestGetIt();
      await sharedDocumentsDirectory.delete(recursive: true);
    });

    tearDown(() async {
      await toxiproxy.reset(ToxiproxyController.dendriteProxy);
      await aliceDb.close();
      await bobDb.close();
    });

    // Polls only database state. No manual retry or rescan can make this pass.
    Future<void> expectAutomaticDelivery({
      Duration deliveryTimeout = timeout,
    }) async {
      await waitUntilAsync(
        () async => await bobDb.getJournalCount() >= expectedEntries.length,
        timeout: deliveryTimeout,
        message: 'Bob did not recover automatically',
      );
      expect(await bobDb.getJournalCount(), expectedEntries.length);
      for (final expected in expectedEntries) {
        expect(
          await bobDb.journalEntityById(expected.meta.id),
          expected,
          reason:
              'Receiver must preserve ID, text, timestamps and vector clock',
        );
        final relativePath = relativeEntityPath(expected);
        final bobFile = resolveJsonCandidateFileInDirectory(
          relativePath,
          bobDocumentsDirectory,
        );
        final aliceFile = resolveJsonCandidateFileInDirectory(
          relativePath,
          aliceDocumentsDirectory,
        );
        expect(
          await bobFile.readAsBytes(),
          await aliceFile.readAsBytes(),
          reason:
              'Receiver must download the sender attachment into its own sandbox',
        );
        expect(
          jsonDecode(await bobFile.readAsString()),
          jsonDecode(jsonEncode(expected)),
        );
        expect(
          resolveJsonCandidateFileInDirectory(
            relativePath,
            sharedDocumentsDirectory,
          ).existsSync(),
          isFalse,
          reason: 'Neither simulated device may use the global documents root',
        );
      }
    }

    Future<({SyncTestDevice alice, SyncTestDevice bob})> setupAliceAndBob({
      required int testIndex,
    }) async {
      // Ensure proxy is enabled at the start
      await toxiproxy.reset(ToxiproxyController.dendriteProxy);

      final configs = getConfigs(testIndex);
      final aliceConfig = configs.$1;
      final bobConfig = configs.$2;
      final userPair = getUserPair(testIndex);

      debugPrint('\n--- Setting up Alice (direct connection)');
      debugPrint('Alice user: ${userPair.$1}');
      final aliceClient = await createMatrixClient(
        documentsDirectory: aliceDocumentsDirectory,
        dbName: 'AliceResilience_${uuid.v1()}',
      );
      addTearDown(aliceClient.dispose);
      final aliceRegistry = SentEventRegistry();
      final aliceGateway = MatrixSdkGateway(
        client: aliceClient,
        sentEventRegistry: aliceRegistry,
      );
      final aliceSettingsDb = SettingsDb(inMemoryDatabase: true);
      addTearDown(aliceSettingsDb.close);
      final aliceSyncDb = SyncDatabase(inMemoryDatabase: true);
      addTearDown(aliceSyncDb.close);
      final aliceClock = MockVectorClockService();
      when(() => aliceClock.initialized).thenAnswer((_) async {});
      when(aliceClock.getHost).thenAnswer((_) async => 'alice-resilience');
      when(
        aliceClock.getHostHash,
      ).thenAnswer((_) async => 'alice-resilience-hash');
      final aliceDevice = await createSyncTestDevice(
        config: aliceConfig,
        gateway: aliceGateway,
        loggingService: getIt<DomainLogger>(),
        journalDb: aliceDb,
        settingsDb: aliceSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'AliceResilience',
        activityService: sharedUserActivityService,
        documentsDirectory: aliceDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
        sentEventRegistry: aliceRegistry,
        syncDb: aliceSyncDb,
        vectorClockService: aliceClock,
      );

      addTearDown(aliceDevice.dispose);
      final alice = aliceDevice.matrixService;
      await alice.init();
      await alice.login();
      debugPrint('Alice - deviceId: ${alice.client.deviceID}');

      final roomId = await createTestSyncRoom(aliceGateway);
      debugPrint('Alice - room created: $roomId');

      await alice.joinRoom(roomId);
      debugPrint('Alice - room joined');

      debugPrint('\n--- Setting up Bob (via proxy)');
      debugPrint('Bob user: ${userPair.$2}');
      final bobClient = await createMatrixClient(
        documentsDirectory: bobDocumentsDirectory,
        dbName: 'BobResilience_${uuid.v1()}',
      );
      addTearDown(bobClient.dispose);
      final bobRegistry = SentEventRegistry();
      final bobGateway = MatrixSdkGateway(
        client: bobClient,
        sentEventRegistry: bobRegistry,
      );
      final bobSettingsDb = SettingsDb(inMemoryDatabase: true);
      addTearDown(bobSettingsDb.close);
      final bobSyncDb = SyncDatabase(inMemoryDatabase: true);
      addTearDown(bobSyncDb.close);
      final bobClock = MockVectorClockService();
      when(() => bobClock.initialized).thenAnswer((_) async {});
      when(bobClock.getHost).thenAnswer((_) async => 'bob-resilience');
      when(bobClock.getHostHash).thenAnswer((_) async => 'bob-resilience-hash');
      final bobDevice = await createSyncTestDevice(
        config: bobConfig,
        gateway: bobGateway,
        loggingService: getIt<DomainLogger>(),
        journalDb: bobDb,
        settingsDb: bobSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'BobResilience',
        activityService: sharedUserActivityService,
        documentsDirectory: bobDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
        sentEventRegistry: bobRegistry,
        syncDb: bobSyncDb,
        vectorClockService: bobClock,
      );

      addTearDown(bobDevice.dispose);
      final bob = bobDevice.matrixService;
      await bob.init();
      await bob.login();
      debugPrint('Bob - deviceId: ${bob.client.deviceID}');

      debugPrint('\n--- Alice invites Bob');
      await inviteToTestSyncRoom(alice, userId: userPair.$2);
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
        return (alice: aliceDevice, bob: bobDevice);
      }

      final outgoingKeyVerificationStream = alice.keyVerificationStream;
      final incomingKeyVerificationRunnerStream =
          bob.incomingKeyVerificationRunnerStream;

      var emojisFromBob = '';
      var emojisFromAlice = '';
      var aliceAccepted = false;
      var bobAccepted = false;

      final incomingSubscription = incomingKeyVerificationRunnerStream.listen(
        (runner) async {
          debugPrint('Bob - incoming verification step: ${runner.lastStep}');
          if (runner.lastStep == 'm.key.verification.request') {
            await runner.acceptVerification();
          }
          if (runner.lastStep == 'm.key.verification.key' && !bobAccepted) {
            bobAccepted = true;
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
          debugPrint('Alice - outgoing verification step: ${runner.lastStep}');
          if (runner.lastStep == 'm.key.verification.key' && !aliceAccepted) {
            aliceAccepted = true;
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
          fail('keyVerificationStream error: $error\n$stackTrace');
        },
      );

      addTearDown(outgoingSubscription.cancel);

      // Verify all unverified devices one by one
      for (final device in unverifiedAlice) {
        final deviceId = device.deviceId;
        debugPrint('\n--- Alice verifies device: $deviceId');

        emojisFromBob = '';
        emojisFromAlice = '';
        aliceAccepted = false;
        bobAccepted = false;

        await alice.verifyDevice(device);

        await waitUntil(() => emojisFromAlice.isNotEmpty, timeout: timeout);
        await waitUntil(() => emojisFromBob.isNotEmpty, timeout: timeout);
        expect(emojisFromAlice, emojisFromBob);
        // The SDK can dispose the runner without emitting a final step.
        // Device trust is the durable outcome of the SAS exchange.
        await waitUntil(
          () =>
              alice.getUnverifiedDevices().isEmpty &&
              bob.getUnverifiedDevices().isEmpty,
          timeout: timeout,
        );
        debugPrint('Device $deviceId verified successfully');

        await waitSeconds(2);
      }

      await incomingSubscription.cancel();
      await outgoingSubscription.cancel();

      // Wait a bit for verification to propagate
      await waitSeconds(defaultDelay);

      // Check if there are still unverified devices
      unverifiedAlice = alice.getUnverifiedDevices();
      expect(unverifiedAlice, isEmpty);
      expect(bob.getUnverifiedDevices(), isEmpty);

      debugPrint('\n--- Setup complete, devices verified');
      await waitSeconds(defaultDelay);

      return (alice: aliceDevice, bob: bobDevice);
    }

    test(
      'Network interruption during sync - messages eventually sync',
      () async {
        final setup = await setupAliceAndBob(testIndex: 0);
        final alice = setup.alice;

        const totalMessages = 20;
        const interruptAfter = 8;

        debugPrint('\n--- Alice sends $totalMessages messages');
        debugPrint('    Network will be cut after $interruptAfter messages');

        // Send first batch
        for (var i = 0; i < interruptAfter; i++) {
          expectedEntries.add(
            await sendTestMessage(
              device: alice,
              index: i,
            ),
          );
          debugPrint('Alice sent message $i');
        }

        // Give Bob time to start receiving
        await waitSeconds(3);

        // Cut network to Bob
        debugPrint('\n--- Cutting network to Bob');
        await toxiproxy.disconnect(ToxiproxyController.dendriteProxy);
        final proxies = await toxiproxy.getProxies();
        expect(
          (proxies[ToxiproxyController.dendriteProxy]
              as Map<String, dynamic>)['enabled'],
          isFalse,
        );

        // Send remaining messages while Bob is offline
        for (var i = interruptAfter; i < totalMessages; i++) {
          // Use direct homeserver for Alice (not via proxy)
          expectedEntries.add(
            await sendTestMessage(
              device: alice,
              index: i,
            ),
          );
          debugPrint('Alice sent message $i (Bob offline)');
        }

        // Wait a bit with network cut
        await waitSeconds(5);

        final offlineEntry = expectedEntries.last;
        expect(
          await bobDb.journalEntityById(offlineEntry.meta.id),
          isNull,
          reason: 'Bob must actually miss entries during the outage',
        );
        expect(
          resolveJsonCandidateFileInDirectory(
            relativeEntityPath(offlineEntry),
            bobDocumentsDirectory,
          ).existsSync(),
          isFalse,
        );

        // Restore network
        debugPrint('\n--- Restoring network to Bob');
        await toxiproxy.reconnect(ToxiproxyController.dendriteProxy);

        // Wait for Bob to receive all messages
        expect(expectedEntries, hasLength(totalMessages));
        await expectAutomaticDelivery(
          deliveryTimeout: const Duration(minutes: 3),
        );

        // Check metrics
        final metrics = await setup.bob.matrixService.getSyncMetrics();
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

        // Add significant latency
        debugPrint('\n--- Adding 2000ms latency');
        await toxiproxy.addLatency(
          ToxiproxyController.dendriteProxy,
          latencyMs: 2000,
        );

        const totalMessages = 10;

        debugPrint(
          '\n--- Alice sends $totalMessages messages with high latency',
        );
        for (var i = 0; i < totalMessages; i++) {
          expectedEntries.add(
            await sendTestMessage(
              device: alice,
              index: i,
            ),
          );
          debugPrint('Alice sent message $i');
        }

        // Wait for Bob to receive with longer timeout due to latency
        expect(expectedEntries, hasLength(totalMessages));
        await expectAutomaticDelivery(
          deliveryTimeout: const Duration(minutes: 3),
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'Bandwidth throttling - messages sync without data loss',
      () async {
        final setup = await setupAliceAndBob(testIndex: 2);
        final alice = setup.alice;

        // Severely limit bandwidth
        debugPrint('\n--- Limiting bandwidth to 50 KB/s');
        await toxiproxy.limitBandwidth(
          ToxiproxyController.dendriteProxy,
          bytesPerSecond: 50000,
        );

        const totalMessages = 15;
        // Repeated text compresses almost to nothing. Seeded random bytes keep
        // each JSON attachment large enough to exercise the bandwidth limit.
        final random = Random(42);
        final payload = base64Encode(
          List<int>.generate(
            96 * 1024,
            (_) => random.nextInt(256),
          ),
        );

        debugPrint(
          '\n--- Alice sends $totalMessages messages with limited bandwidth',
        );
        for (var i = 0; i < totalMessages; i++) {
          expectedEntries.add(
            await sendTestMessage(
              device: alice,
              text: 'Bandwidth fixture #$i: $payload',
              index: i,
            ),
          );
          debugPrint('Alice sent message $i');
        }

        // Wait for Bob to receive
        expect(expectedEntries, hasLength(totalMessages));
        await expectAutomaticDelivery(
          deliveryTimeout: const Duration(minutes: 3),
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'Multiple network interruptions - eventual consistency',
      () async {
        final setup = await setupAliceAndBob(testIndex: 3);
        final alice = setup.alice;

        const totalMessages = 30;
        const messagesPerBatch = 10;

        debugPrint('\n--- Sending messages with intermittent disconnections');

        for (var batch = 0; batch < 3; batch++) {
          final start = batch * messagesPerBatch;
          final end = start + messagesPerBatch;

          debugPrint('\n--- Batch $batch: Sending messages $start-${end - 1}');

          for (var i = start; i < end; i++) {
            expectedEntries.add(
              await sendTestMessage(
                device: alice,
                index: i,
              ),
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
          }
        }

        // Wait for Bob to receive all messages - use longer timeout for this test
        expect(expectedEntries, hasLength(totalMessages));
        await expectAutomaticDelivery(
          deliveryTimeout: const Duration(minutes: 3),
        );
      },
      timeout: const Timeout(Duration(minutes: 8)),
      skip: skipReason ?? false,
    );
  });
}
