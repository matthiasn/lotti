import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/outbox_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/path_provider.dart';
import '../journal_test_data/test_data.dart';
import '../mocks/mocks.dart';
import '../mocks/sync_config_test_mocks.dart';
import '../test_data/sync_config_test_data.dart';
import '../utils/wait.dart';

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

    setUpAll(() async {
      setFakeDocumentsPath();

      when(syncConfigMock.getSyncConfig)
          .thenAnswer((_) async => testSyncConfigConfigured);
      when(() => mockJournalDb.getConfigFlag(enableSyncOutboxFlag))
          .thenAnswer((_) async => false);

      getIt
        ..registerSingleton<SyncDatabase>(
          SyncDatabase(inMemoryDatabase: true),
          dispose: (db) async => db.close(),
        )
        ..registerSingleton<ConnectivityService>(mockConnectivityService)
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<SyncConfigService>(syncConfigMock)
        ..registerSingleton<OutboxService>(OutboxService());
    });

    setUp(() {
      when(mockVectorClockService.getHostHash)
          .thenAnswer((_) async => 'some_host_hash');
      when(mockVectorClockService.getHost)
          .thenAnswer((_) async => 'some_host_id');
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
        tagEntity: testStoryTagReading,
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
