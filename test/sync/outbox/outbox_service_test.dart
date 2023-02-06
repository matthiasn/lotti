import 'dart:convert';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/outbox/outbox_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../test_data/sync_config_test_data.dart';
import '../../test_data/test_data.dart';
import '../../utils/wait.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutboxService Tests', () {
    final syncConfigMock = MockSyncConfigService();
    final mockVectorClockService = MockVectorClockService();
    final mockJournalDb = MockJournalDb();

    final mockConnectivityService = MockConnectivityService();
    when(() => mockConnectivityService.connectedStream).thenAnswer(
      (_) => Stream<bool>.fromIterable([true]),
    );
    when(mockConnectivityService.isConnected).thenAnswer((_) async => true);

    final mockFgBgService = MockFgBgService();
    when(() => mockFgBgService.fgBgStream).thenAnswer(
      (_) => Stream<bool>.fromIterable([true]),
    );

    setUpAll(() async {
      setFakeDocumentsPath();

      when(syncConfigMock.getSyncConfig)
          .thenAnswer((_) async => testSyncConfigConfigured);
      when(() => mockJournalDb.getConfigFlag(enableSyncFlag))
          .thenAnswer((_) async => true);

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<Future<DriftIsolate>>(
          createDriftIsolate(settingsDbFileName, inMemory: true),
          instanceName: settingsDbFileName,
        )
        ..registerSingleton<SettingsDb>(getSettingsDb())
        ..registerSingleton<Future<DriftIsolate>>(
          createDriftIsolate(syncDbFileName, inMemory: true),
          instanceName: syncDbFileName,
        )
        ..registerSingleton<SyncDatabase>(getSyncDatabase())
        ..registerSingleton<ConnectivityService>(mockConnectivityService)
        ..registerSingleton<FgBgService>(mockFgBgService)
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<Future<DriftIsolate>>(
          createDriftIsolate(loggingDbFileName, inMemory: true),
          instanceName: loggingDbFileName,
        )
        ..registerSingleton<LoggingDb>(getLoggingDb())
        ..registerSingleton<SyncConfigService>(syncConfigMock)
        ..registerSingleton<OutboxService>(OutboxService());
    });

    setUp(() {
      when(mockVectorClockService.getHostHash)
          .thenAnswer((_) async => 'some_host_hash');
      when(mockVectorClockService.getHost)
          .thenAnswer((_) async => 'some_host_id');

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => true);
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() async {
      await getIt<SyncDatabase>().deleteOutboxItems();
      reset(mockVectorClockService);
    });

    test('SyncMessage with JournalEntry is enqueued into database', () async {
      final outboxService = getIt<OutboxService>();
      await outboxService.init();

      final message = SyncMessage.journalEntity(
        journalEntity: testWeightEntry,
        status: SyncEntryStatus.initial,
      );

      await outboxService.enqueueMessage(message);
      final nextItems = await outboxService.getNextItems();
      expect(nextItems.first.message, jsonEncode(message));
    });

    test('SyncMessage with TagDefinition is enqueued into database', () async {
      final outboxService = getIt<OutboxService>();
      final message = SyncMessage.tagEntity(
        tagEntity: testStoryTag1,
        status: SyncEntryStatus.initial,
      );

      await outboxService.enqueueMessage(message);
      final nextItems = await outboxService.getNextItems();
      expect(nextItems.first.message, jsonEncode(message));
    });

    test('SyncMessage with Measurable is enqueued into database', () async {
      final outboxService = getIt<OutboxService>();
      final message = SyncMessage.entityDefinition(
        entityDefinition: measurableWater,
        status: SyncEntryStatus.initial,
      );

      await outboxService.enqueueMessage(message);
      final nextItems = await outboxService.getNextItems();
      expect(nextItems.first.message, jsonEncode(message));
    });

    test('SyncMessage with Link is enqueued into database', () async {
      final now = DateTime.now();
      final outboxService = getIt<OutboxService>();
      final message = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: uuid.v1(),
          fromId: uuid.v1(),
          toId: uuid.v1(),
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
        status: SyncEntryStatus.initial,
      );

      await outboxService.enqueueMessage(message);
      final nextItems = await outboxService.getNextItems();
      expect(nextItems.first.message, jsonEncode(message));
      await waitMilliseconds(100);
    });
  });
}
