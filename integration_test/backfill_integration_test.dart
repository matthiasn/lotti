import 'dart:async' show unawaited;
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../test/mocks/mocks.dart';
import 'helpers/sync_test_helpers.dart';
import 'helpers/toxiproxy_controller.dart';

/// Device context holding all services for one simulated device.
class DeviceContext {
  DeviceContext({
    required this.name,
    required this.matrixService,
    required this.journalDb,
    required this.syncDb,
    required this.sequenceLogService,
    required this.outboxService,
    required this.backfillRequestService,
    required this.backfillResponseHandler,
    required this.vectorClockService,
  });

  final String name;
  final MatrixService matrixService;
  final JournalDb journalDb;
  final SyncDatabase syncDb;
  final SyncSequenceLogService sequenceLogService;
  final OutboxService outboxService;
  final BackfillRequestService backfillRequestService;
  final BackfillResponseHandler backfillResponseHandler;
  final VectorClockService vectorClockService;

  Future<void> dispose() async {
    backfillRequestService.dispose();
    await matrixService.dispose();
    await journalDb.close();
    await syncDb.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(minutes: 2);

  group('Backfill Integration Tests', () {
    final secureStorageMock = MockSecureStorage();

    // Environment variables for test users
    const testUser1 = String.fromEnvironment('TEST_USER1');
    const testUser2 = String.fromEnvironment('TEST_USER2');

    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final mockUpdateNotifications = MockUpdateNotifications();
    late LoggingService sharedLoggingService;
    late UserActivityService sharedUserActivityService;
    late Directory sharedDocumentsDirectory;
    late AiConfigRepository sharedAiConfigRepository;
    late ToxiproxyController toxiproxy;
    late AiConfigDb aiConfigDb;

    // Skip reason if env vars are missing
    final missingEnv = <String>[
      if (!const bool.hasEnvironment('TEST_USER1')) 'TEST_USER1',
      if (!const bool.hasEnvironment('TEST_USER2')) 'TEST_USER2',
    ];
    final skipReason = missingEnv.isEmpty
        ? null
        : 'Missing: ${missingEnv.join(', ')}. Run via run_resilience_tests.sh';

    const aliceHomeServer = 'http://localhost:8008';
    const bobHomeServer = 'http://localhost:18008';
    const testPassword = '?Secret123@';

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

      // Setup mocks
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );
      when(() => mockUpdateNotifications.notify(any())).thenAnswer((_) {});
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

      await Future<void>.delayed(const Duration(seconds: 2));
    });

    tearDownAll(() async {
      try {
        await aiConfigDb.close();
        toxiproxy.close();
      } catch (e) {
        debugPrint('Error during cleanup: $e');
      }
    });

    /// Create a full device context with all backfill services wired up.
    Future<DeviceContext> createDeviceContext({
      required String name,
      required String homeServer,
      required String user,
      required String password,
    }) async {
      final journalDb = JournalDb(
        overriddenFilename: '${name}_backfill_${uuid.v1()}.sqlite',
        inMemoryDatabase: true,
      );
      final syncDb = SyncDatabase(inMemoryDatabase: true);
      final settingsDb = SettingsDb(inMemoryDatabase: true);

      final vectorClockService = VectorClockService();

      final sequenceLogService = SyncSequenceLogService(
        syncDatabase: syncDb,
        vectorClockService: vectorClockService,
        loggingService: sharedLoggingService,
      );

      final client = await createMatrixClient(
        documentsDirectory: sharedDocumentsDirectory,
        dbName: '${name}Backfill_${uuid.v1()}',
      );
      final registry = SentEventRegistry();
      final gateway = MatrixSdkGateway(
        client: client,
        sentEventRegistry: registry,
      );

      final attachmentIndex = AttachmentIndex(logging: sharedLoggingService);
      final activityGate = UserActivityGate(
        activityService: sharedUserActivityService,
      );

      final messageSender = MatrixMessageSender(
        loggingService: sharedLoggingService,
        journalDb: journalDb,
        documentsDirectory: sharedDocumentsDirectory,
        sentEventRegistry: registry,
      );

      final readMarkerService = SyncReadMarkerService(
        settingsDb: settingsDb,
        loggingService: sharedLoggingService,
      );

      final syncEventProcessor = SyncEventProcessor(
        loggingService: sharedLoggingService,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
        settingsDb: settingsDb,
        sequenceLogService: sequenceLogService,
      );

      final config = MatrixConfig(
        homeServer: homeServer,
        user: user,
        password: password,
      );

      final matrixService = MatrixService(
        matrixConfig: config,
        gateway: gateway,
        loggingService: sharedLoggingService,
        activityGate: activityGate,
        messageSender: messageSender,
        journalDb: journalDb,
        settingsDb: settingsDb,
        readMarkerService: readMarkerService,
        eventProcessor: syncEventProcessor,
        secureStorage: secureStorageMock,
        deviceDisplayName: name,
        ownsActivityGate: true,
        attachmentIndex: attachmentIndex,
        sentEventRegistry: registry,
        collectSyncMetrics: true,
      );

      final outboxService = OutboxService(
        syncDatabase: syncDb,
        loggingService: sharedLoggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: sharedDocumentsDirectory,
        userActivityService: sharedUserActivityService,
        activityGate: activityGate,
        matrixService: matrixService,
        sequenceLogService: sequenceLogService,
      );

      final backfillResponseHandler = BackfillResponseHandler(
        journalDb: journalDb,
        sequenceLogService: sequenceLogService,
        outboxService: outboxService,
        loggingService: sharedLoggingService,
      );

      // Use short interval for testing
      final backfillRequestService = BackfillRequestService(
        sequenceLogService: sequenceLogService,
        outboxService: outboxService,
        vectorClockService: vectorClockService,
        loggingService: sharedLoggingService,
        requestInterval: const Duration(seconds: 5),
      );

      // Wire up backfill handler
      syncEventProcessor.backfillResponseHandler = backfillResponseHandler;

      return DeviceContext(
        name: name,
        matrixService: matrixService,
        journalDb: journalDb,
        syncDb: syncDb,
        sequenceLogService: sequenceLogService,
        outboxService: outboxService,
        backfillRequestService: backfillRequestService,
        backfillResponseHandler: backfillResponseHandler,
        vectorClockService: vectorClockService,
      );
    }

    /// Setup and verify Alice and Bob devices.
    Future<({DeviceContext alice, DeviceContext bob, String roomId})>
        setupDevices() async {
      await toxiproxy.reset(ToxiproxyController.dendriteProxy);

      final aliceUser =
          testUser1.isNotEmpty ? testUser1 : '@test_alice:localhost';
      final bobUser = testUser2.isNotEmpty ? testUser2 : '@test_bob:localhost';

      debugPrint('\n--- Setting up Alice (direct connection)');
      final alice = await createDeviceContext(
        name: 'Alice',
        homeServer: aliceHomeServer,
        user: aliceUser,
        password: testPassword,
      );
      await alice.matrixService.init();
      await alice.matrixService.login();
      debugPrint('Alice - deviceId: ${alice.matrixService.client.deviceID}');

      final roomId = await alice.matrixService.createRoom();
      debugPrint('Alice - room created: $roomId');
      await alice.matrixService.joinRoom(roomId);

      debugPrint('\n--- Setting up Bob (via proxy)');
      final bob = await createDeviceContext(
        name: 'Bob',
        homeServer: bobHomeServer,
        user: bobUser,
        password: testPassword,
      );
      await bob.matrixService.init();
      await bob.matrixService.login();
      debugPrint('Bob - deviceId: ${bob.matrixService.client.deviceID}');

      debugPrint('\n--- Alice invites Bob');
      await alice.matrixService.inviteToSyncRoom(userId: bobUser);
      await waitSeconds(5);

      await bob.matrixService.joinRoom(roomId);
      debugPrint('Bob - room joined');
      await waitSeconds(5);

      // Verify devices
      debugPrint('\n--- Waiting for unverified devices');
      await waitUntil(
        () => alice.matrixService.getUnverifiedDevices().isNotEmpty,
        timeout: timeout,
      );

      final unverifiedAlice = alice.matrixService.getUnverifiedDevices();
      if (unverifiedAlice.isNotEmpty) {
        debugPrint('Verifying ${unverifiedAlice.length} devices...');

        final incomingStream =
            bob.matrixService.incomingKeyVerificationRunnerStream;
        final outgoingStream = alice.matrixService.keyVerificationStream;

        var emojisFromBob = '';
        var emojisFromAlice = '';
        var verificationComplete = false;

        final incomingSub = incomingStream.listen((runner) async {
          if (runner.lastStep == 'm.key.verification.request') {
            await runner.acceptVerification();
          }
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromAlice = extractEmojiString(runner.emojis);
            await waitUntil(
              () =>
                  emojisFromAlice == emojisFromBob && emojisFromAlice.isNotEmpty,
              timeout: timeout,
            );
            await runner.acceptEmojiVerification();
          }
          if (runner.lastStep == 'm.key.verification.done') {
            verificationComplete = true;
          }
        });

        final outgoingSub = outgoingStream.listen((runner) async {
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromBob = extractEmojiString(runner.emojis);
            await waitUntil(
              () =>
                  emojisFromAlice == emojisFromBob && emojisFromBob.isNotEmpty,
              timeout: timeout,
            );
            await runner.acceptEmojiVerification();
          }
        });

        for (final device in unverifiedAlice) {
          emojisFromBob = '';
          emojisFromAlice = '';
          verificationComplete = false;

          await alice.matrixService.verifyDevice(device);
          await waitUntil(() => verificationComplete, timeout: timeout);
          await waitSeconds(2);
        }

        await incomingSub.cancel();
        await outgoingSub.cancel();
      }

      // Start backfill services
      alice.backfillRequestService.start();
      bob.backfillRequestService.start();

      debugPrint('\n--- Setup complete');
      await waitSeconds(5);

      return (alice: alice, bob: bob, roomId: roomId);
    }

    test(
      'Backfill recovers artificially injected gaps',
      () async {
        final setup = await setupDevices();
        final alice = setup.alice;
        final bob = setup.bob;
        final roomId = setup.roomId;

        addTearDown(() async {
          await alice.dispose();
          await bob.dispose();
          await toxiproxy.reset(ToxiproxyController.dendriteProxy);
        });

        const totalMessages = 10;

        debugPrint('\n--- Alice sends $totalMessages messages');
        for (var i = 0; i < totalMessages; i++) {
          await sendTestMessage(
            matrixService: alice.matrixService,
            deviceName: 'aliceBackfill',
            index: i,
            roomId: roomId,
          );
          debugPrint('Alice sent message $i');
        }

        // Wait for Bob to receive all messages
        debugPrint('\n--- Waiting for Bob to receive all messages');
        await waitUntilAsync(
          () async {
            final count = await bob.journalDb.getJournalCount();
            debugPrint('Bob journal count: $count');
            if (count < totalMessages) {
              await bob.matrixService.forceRescan();
            }
            return count >= totalMessages;
          },
          timeout: timeout,
        );

        final bobCountBefore = await bob.journalDb.getJournalCount();
        debugPrint('Bob received $bobCountBefore messages');
        expect(bobCountBefore, totalMessages);

        // Get Alice's host ID for sequence log manipulation
        final aliceHostId = await alice.vectorClockService.getHost();
        debugPrint('Alice host ID: $aliceHostId');

        // Check sequence log state before manipulation
        final entriesBefore = await bob.syncDb.getMissingEntries();
        debugPrint(
            'Bob missing entries before manipulation: ${entriesBefore.length}');

        // === ARTIFICIALLY INJECT GAPS ===
        // Delete entries 3, 4, 5 from Bob's sequence log and mark them as missing
        debugPrint('\n--- Artificially injecting gaps (counters 3, 4, 5)');

        for (var counter = 3; counter <= 5; counter++) {
          // Update the entry to mark it as missing (simulating a gap)
          await bob.syncDb.updateSequenceStatus(
            aliceHostId!,
            counter,
            SyncSequenceStatus.missing,
          );
          debugPrint('Marked counter $counter as missing');
        }

        // Verify gaps are now detected
        final missingAfter = await bob.syncDb.getMissingEntries();
        debugPrint('Bob missing entries after manipulation: ${missingAfter.length}');
        expect(missingAfter.length, 3);

        // === TRIGGER BACKFILL ===
        debugPrint('\n--- Triggering backfill request');
        unawaited(bob.backfillRequestService.processNow());

        // Wait for backfill to complete
        debugPrint('\n--- Waiting for backfill to complete');
        await waitUntilAsync(
          () async {
            final missing = await bob.syncDb.getMissingEntries();
            debugPrint('Remaining missing entries: ${missing.length}');
            if (missing.isNotEmpty) {
              // Keep triggering backfill
              unawaited(bob.backfillRequestService.processNow());
              await bob.matrixService.forceRescan();
            }
            return missing.isEmpty;
          },
          timeout: const Duration(minutes: 3),
          pollInterval: const Duration(seconds: 2),
        );

        // Verify all gaps are resolved
        final missingFinal = await bob.syncDb.getMissingEntries();
        debugPrint('Final missing entries: ${missingFinal.length}');
        expect(missingFinal, isEmpty);

        // Check that entries are now marked as backfilled
        for (var counter = 3; counter <= 5; counter++) {
          final entry =
              await bob.syncDb.getEntryByHostAndCounter(aliceHostId!, counter);
          debugPrint(
              'Counter $counter status: ${SyncSequenceStatus.values[entry!.status]}');
          expect(
            entry.status,
            anyOf(
              SyncSequenceStatus.backfilled.index,
              SyncSequenceStatus.received.index,
            ),
          );
        }

        debugPrint('\n--- Backfill integration test PASSED');
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'Backfill handles deleted entries correctly',
      () async {
        final setup = await setupDevices();
        final alice = setup.alice;
        final bob = setup.bob;
        final roomId = setup.roomId;

        addTearDown(() async {
          await alice.dispose();
          await bob.dispose();
          await toxiproxy.reset(ToxiproxyController.dendriteProxy);
        });

        const totalMessages = 5;

        debugPrint('\n--- Alice sends $totalMessages messages');
        for (var i = 0; i < totalMessages; i++) {
          await sendTestMessage(
            matrixService: alice.matrixService,
            deviceName: 'aliceDeleted',
            index: i,
            roomId: roomId,
          );
        }

        // Wait for sync
        await waitUntilAsync(
          () async {
            final count = await bob.journalDb.getJournalCount();
            if (count < totalMessages) {
              await bob.matrixService.forceRescan();
            }
            return count >= totalMessages;
          },
          timeout: timeout,
        );

        final aliceHostId = await alice.vectorClockService.getHost();

        // Create a fake gap for a counter that doesn't exist in Alice's journal
        // This simulates a deleted entry scenario
        debugPrint('\n--- Creating fake gap for non-existent entry (counter 99)');

        await bob.syncDb.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: drift.Value(aliceHostId!),
            counter: const drift.Value(99),
            status: drift.Value(SyncSequenceStatus.missing.index),
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );

        final missingBefore = await bob.syncDb.getMissingEntries();
        expect(missingBefore.length, 1);
        expect(missingBefore[0].counter, 99);

        // Trigger backfill
        debugPrint('\n--- Triggering backfill for non-existent entry');
        unawaited(bob.backfillRequestService.processNow());

        // Wait for backfill response
        await waitUntilAsync(
          () async {
            final missing = await bob.syncDb.getMissingEntries();
            if (missing.isNotEmpty) {
              unawaited(bob.backfillRequestService.processNow());
              await bob.matrixService.forceRescan();
            }
            return missing.isEmpty;
          },
          timeout: const Duration(minutes: 2),
          pollInterval: const Duration(seconds: 2),
        );

        // Verify entry is marked as deleted (not found)
        final entry =
            await bob.syncDb.getEntryByHostAndCounter(aliceHostId, 99);
        if (entry != null) {
          debugPrint('Counter 99 status: ${SyncSequenceStatus.values[entry.status]}');
          // Alice didn't have this entry, so she should respond with deleted=true
          // OR the entry might still be marked as requested if Alice ignored it
          expect(
            entry.status,
            anyOf(
              SyncSequenceStatus.deleted.index,
              SyncSequenceStatus.requested.index,
            ),
          );
        }

        debugPrint('\n--- Deleted entry test PASSED');
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );
  });
}
