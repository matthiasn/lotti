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
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
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
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../test/mocks/mocks.dart';
import '../test/utils/utils.dart';
import 'matrix_service_test.dart';

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
}) {
  final activityGate = UserActivityGate(
    activityService: activityService,
  );
  final messageSender = MatrixMessageSender(
    loggingService: loggingService,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
  );
  final readMarkerService = SyncReadMarkerService(
    settingsDb: settingsDb,
    loggingService: loggingService,
  );
  final eventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    updateNotifications: updateNotifications,
    aiConfigRepository: aiConfigRepository,
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
    documentsDirectory: documentsDirectory,
    deviceDisplayName: deviceName,
    ownsActivityGate: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixService V2 Tests', () {
    final secureStorageMock = MockSecureStorage();
    const testUserEnv1 = 'TEST_USER1';
    const testUserEnv2 = 'TEST_USER2';
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final mockUpdateNotifications = MockUpdateNotifications();
    late LoggingService sharedLoggingService;
    late UserActivityService sharedUserActivityService;
    late Directory sharedDocumentsDirectory;
    late AiConfigRepository sharedAiConfigRepository;

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(() => mockUpdateNotifications.notify(any())).thenAnswer((_) {});
    when(() => secureStorageMock.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => secureStorageMock.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
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

    if (!const bool.hasEnvironment(testUserEnv1) ||
        !const bool.hasEnvironment(testUserEnv2)) {
      debugPrint(
          'TEST_USER1/TEST_USER2 not defined!!! Run via run_matrix_tests.sh');
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
    const defaultDelay = 5;

    setUpAll(() async {
      await vod.init();
      final tmpDir = await getTemporaryDirectory();
      final docDir = Directory('${tmpDir.path}/${uuid.v1()}')
        ..createSync(recursive: true);
      sharedDocumentsDirectory = docDir;

      aiConfigDb = AiConfigDb(inMemoryDatabase: true);
      sharedAiConfigRepository = AiConfigRepository(aiConfigDb);
      sharedLoggingService = LoggingService();
      sharedUserActivityService = UserActivityService();
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

    test('Create room & join (sync v2)', () async {
      final aliceClient = await createMatrixClient(
        documentsDirectory: sharedDocumentsDirectory,
        dbName: 'AliceV2',
      );
      final aliceGateway = MatrixSdkGateway(client: aliceClient);
      final aliceSettingsDb = SettingsDb(inMemoryDatabase: true);
      final alice = _createMatrixService(
        config: config1,
        gateway: aliceGateway,
        loggingService: sharedLoggingService,
        journalDb: aliceDb,
        settingsDb: aliceSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'AliceV2',
        activityService: sharedUserActivityService,
        documentsDirectory: sharedDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await alice.login();
      await alice.startKeyVerificationListener();
      final roomId = await alice.createRoom();
      expect(roomId, isNotEmpty);
      await alice.joinRoom(roomId);

      final bobClient = await createMatrixClient(
        documentsDirectory: sharedDocumentsDirectory,
        dbName: 'BobV2',
      );
      final bobGateway = MatrixSdkGateway(client: bobClient);
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
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await bob.login();
      await bob.startKeyVerificationListener();
      await alice.inviteToSyncRoom(userId: bobUserName);
      await waitSeconds(defaultDelay);
      await bob.joinRoom(roomId);
      await waitSeconds(defaultDelay);

      // Device verification using SAS (auto-accept on both sides)
      await waitUntil(() => alice.getUnverifiedDevices().isNotEmpty);
      await waitUntil(() => bob.getUnverifiedDevices().isNotEmpty);

      final outgoingKeyVerificationStream = alice.keyVerificationStream;
      final incomingKeyVerificationRunnerStream =
          bob.incomingKeyVerificationRunnerStream;

      var emojisFromBob = '';
      var emojisFromAlice = '';

      unawaited(
        incomingKeyVerificationRunnerStream.forEach((runner) async {
          if (runner.lastStep == 'm.key.verification.request') {
            await runner.acceptVerification();
          }
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromAlice = extractEmojiString(runner.emojis);
            await runner.acceptEmojiVerification();
          }
        }),
      );

      unawaited(
        outgoingKeyVerificationStream.forEach((runner) async {
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromBob = extractEmojiString(runner.emojis);
            await waitUntil(
              () =>
                  emojisFromAlice == emojisFromBob && emojisFromBob.isNotEmpty,
            );
            await runner.acceptEmojiVerification();
          }
        }),
      );

      // Trigger verification from Alice to Bob
      final unverifiedAlice = alice.getUnverifiedDevices();
      await alice.verifyDevice(unverifiedAlice.first);

      await waitUntil(() => alice.getUnverifiedDevices().isEmpty);
      await waitUntil(() => bob.getUnverifiedDevices().isEmpty);

      Future<void> sendTestMessage(
          int index, MatrixService device, String name) async {
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
            vectorClock: VectorClock({name: index}),
          ),
          entryText: EntryText(plainText: 'Test from $name #$index - $now'),
        );
        final jsonPath = relativeEntityPath(entity);
        await saveJournalEntityJson(entity);
        await device.sendMatrixMsg(
          SyncMessage.journalEntity(
            id: id,
            status: SyncEntryStatus.initial,
            vectorClock: VectorClock({name: index}),
            jsonPath: jsonPath,
          ),
          myRoomId: roomId,
        );
      }

      const n = 20;
      for (var i = 0; i < n; i++) {
        await sendTestMessage(i, alice, 'aliceDeviceV2');
        await sendTestMessage(i, bob, 'bobDeviceV2');
      }
      await waitUntilAsync(() async => await aliceDb.getJournalCount() == n);
      await waitUntilAsync(() async => await bobDb.getJournalCount() == n);
      expect(await aliceDb.getJournalCount(), n);
      expect(await bobDb.getJournalCount(), n);
    });

    test('Reconnect resumes and processes remaining messages (sync v2)',
        () async {
      final aliceClient = await createMatrixClient(
        documentsDirectory: sharedDocumentsDirectory,
        dbName: 'AliceV2R',
      );
      final aliceGateway = MatrixSdkGateway(client: aliceClient);
      final aliceSettingsDb = SettingsDb(inMemoryDatabase: true);
      final alice = _createMatrixService(
        config: config1,
        gateway: aliceGateway,
        loggingService: sharedLoggingService,
        journalDb: aliceDb,
        settingsDb: aliceSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'AliceV2R',
        activityService: sharedUserActivityService,
        documentsDirectory: sharedDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await alice.login();
      final roomId = await alice.createRoom();
      await alice.joinRoom(roomId);

      final bobClient = await createMatrixClient(
        documentsDirectory: sharedDocumentsDirectory,
        dbName: 'BobV2R',
      );
      final bobGateway = MatrixSdkGateway(client: bobClient);
      final bobSettingsDb = SettingsDb(inMemoryDatabase: true);
      var bob = _createMatrixService(
        config: config2,
        gateway: bobGateway,
        loggingService: sharedLoggingService,
        journalDb: bobDb,
        settingsDb: bobSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'BobV2R',
        activityService: sharedUserActivityService,
        documentsDirectory: sharedDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await bob.login();
      await alice.inviteToSyncRoom(userId: bobUserName);
      await waitSeconds(5);
      await bob.joinRoom(roomId);
      await waitSeconds(5);

      // Device verification (same SAS flow as above)
      await waitUntil(() => alice.getUnverifiedDevices().isNotEmpty);
      await waitUntil(() => bob.getUnverifiedDevices().isNotEmpty);

      final outgoingKeyVerificationStream2 = alice.keyVerificationStream;
      final incomingKeyVerificationRunnerStream2 =
          bob.incomingKeyVerificationRunnerStream;
      var emojisFromBob2 = '';
      var emojisFromAlice2 = '';

      unawaited(
        incomingKeyVerificationRunnerStream2.forEach((runner) async {
          if (runner.lastStep == 'm.key.verification.request') {
            await runner.acceptVerification();
          }
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromAlice2 = extractEmojiString(runner.emojis);
            await runner.acceptEmojiVerification();
          }
        }),
      );
      unawaited(
        outgoingKeyVerificationStream2.forEach((runner) async {
          if (runner.lastStep == 'm.key.verification.key') {
            emojisFromBob2 = extractEmojiString(runner.emojis);
            await waitUntil(
              () =>
                  emojisFromAlice2 == emojisFromBob2 &&
                  emojisFromBob2.isNotEmpty,
            );
            await runner.acceptEmojiVerification();
          }
        }),
      );
      final unverifiedAlice2 = alice.getUnverifiedDevices();
      await alice.verifyDevice(unverifiedAlice2.first);
      await waitUntil(() => alice.getUnverifiedDevices().isEmpty);
      await waitUntil(() => bob.getUnverifiedDevices().isEmpty);

      Future<void> sendBatch(
          int count, MatrixService device, String name) async {
        for (var i = 0; i < count; i++) {
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
              vectorClock: VectorClock({name: i}),
            ),
            entryText: EntryText(plainText: 'R Test from $name #$i - $now'),
          );
          final jsonPath = relativeEntityPath(entity);
          await saveJournalEntityJson(entity);
          await device.sendMatrixMsg(
            SyncMessage.journalEntity(
              id: id,
              status: SyncEntryStatus.initial,
              vectorClock: VectorClock({name: i}),
              jsonPath: jsonPath,
            ),
            myRoomId: roomId,
          );
        }
      }

      const firstBatch = 10;
      const secondBatch = 15;
      await sendBatch(firstBatch, alice, 'aliceDeviceV2R');
      await waitUntilAsync(
          () async => await bobDb.getJournalCount() == firstBatch);

      await bob.disposeClient();
      bob = _createMatrixService(
        config: config2,
        gateway: MatrixSdkGateway(
          client: await createMatrixClient(
            documentsDirectory: sharedDocumentsDirectory,
            dbName: 'BobV2R',
          ),
        ),
        loggingService: sharedLoggingService,
        journalDb: bobDb,
        settingsDb: bobSettingsDb,
        secureStorage: secureStorageMock,
        deviceName: 'BobV2R-re',
        activityService: sharedUserActivityService,
        documentsDirectory: sharedDocumentsDirectory,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await bob.login();
      await bob.joinRoom(roomId);
      await waitSeconds(5);

      await sendBatch(secondBatch, alice, 'aliceDeviceV2R');
      await sendBatch(secondBatch, bob, 'bobDeviceV2R');

      await waitUntilAsync(
          () async => await aliceDb.getJournalCount() == secondBatch);
      await waitUntilAsync(
          () async => await bobDb.getJournalCount() == secondBatch);
      expect(await aliceDb.getJournalCount(), secondBatch);
      expect(await bobDb.getJournalCount(), secondBatch);
    });
  });
}
