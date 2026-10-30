import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/notifications/preferences/notification_preference_effects.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/embedding_vectors/embedding_vectors_sync.dart';
import 'package:lotti/features/sync/maintenance_keys.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/saved_task_filters_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';

void main() {
  setUpAll(() {
    // Register fallback values for complex types used with any()
    registerFallbackValue(
      const Stream<List<({String id, Map<String, int>? vectorClock})>>.empty(),
    );
    registerFallbackValue(() async => 0);
    registerFallbackValue(FakeCategoryDefinition());
    registerFallbackValue(SyncSequencePayloadType.journalEntity);
  });
  setUp(() async {
    // Use a dedicated scope per test to avoid cross-file contamination
    getIt.pushNewScope();
  });

  tearDown(() async {
    await getIt.resetScope();
    await getIt.popScope();
  });

  group('resendBurnedOwnCountersOnceForTesting', () {
    late MockDomainLogger logger;
    late MockSettingsDb settingsDb;
    late MockBackfillResponseHandler handler;

    setUp(() {
      logger = MockDomainLogger();
      settingsDb = MockSettingsDb();
      handler = MockBackfillResponseHandler();
      when(
        () => logger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      getIt
        ..registerSingleton<DomainLogger>(logger)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<BackfillResponseHandler>(handler);
    });

    test('runs once, records it, and logs how many it resent', () async {
      when(
        () => settingsDb.itemByKey(burnedOwnCountersResentSettingsKey),
      ).thenAnswer((_) async => null);
      when(handler.resendBurnedOwnCountersCarried).thenAnswer((_) async => 2);

      await resendBurnedOwnCountersOnceForTesting();

      verify(
        () => settingsDb.saveSettingsItem(
          burnedOwnCountersResentSettingsKey,
          'true',
        ),
      ).called(1);
      verify(
        () => logger.log(
          any<LogDomain>(),
          any<String>(that: contains('Resent 2')),
          subDomain: 'burnedOwnCounters',
        ),
      ).called(1);
    });

    test('is skipped once recorded', () async {
      when(
        () => settingsDb.itemByKey(burnedOwnCountersResentSettingsKey),
      ).thenAnswer((_) async => 'true');

      await resendBurnedOwnCountersOnceForTesting();

      verifyNever(handler.resendBurnedOwnCountersCarried);
    });

    test('a failure is logged and retried at the next start', () async {
      when(
        () => settingsDb.itemByKey(burnedOwnCountersResentSettingsKey),
      ).thenAnswer((_) async => null);
      when(
        handler.resendBurnedOwnCountersCarried,
      ).thenThrow(StateError('closed'));

      await resendBurnedOwnCountersOnceForTesting();

      verifyNever(
        () => settingsDb.saveSettingsItem(
          burnedOwnCountersResentSettingsKey,
          any(),
        ),
      );
      verify(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'burnedOwnCounters',
        ),
      ).called(1);
    });
  });

  group('resendOwnCounterZeroOnceForTesting', () {
    late MockDomainLogger logger;
    late MockSettingsDb settingsDb;
    late MockBackfillResponseHandler handler;

    setUp(() {
      logger = MockDomainLogger();
      settingsDb = MockSettingsDb();
      handler = MockBackfillResponseHandler();
      when(
        () => logger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      getIt
        ..registerSingleton<DomainLogger>(logger)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<BackfillResponseHandler>(handler);
    });

    test(
      'runs once: resends, records it, and logs only when it sent',
      () async {
        when(
          () => settingsDb.itemByKey(counterZeroResentSettingsKey),
        ).thenAnswer((_) async => null);
        when(handler.resendOwnCounterZero).thenAnswer((_) async => true);

        await resendOwnCounterZeroOnceForTesting();

        verify(
          () =>
              settingsDb.saveSettingsItem(counterZeroResentSettingsKey, 'true'),
        ).called(1);
        verify(
          () => logger.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: 'counterZeroResend',
          ),
        ).called(1);
      },
    );

    test('is skipped once recorded', () async {
      when(
        () => settingsDb.itemByKey(counterZeroResentSettingsKey),
      ).thenAnswer((_) async => 'true');

      await resendOwnCounterZeroOnceForTesting();

      verifyNever(handler.resendOwnCounterZero);
    });

    test('a failure is logged and retried at the next start', () async {
      when(
        () => settingsDb.itemByKey(counterZeroResentSettingsKey),
      ).thenAnswer((_) async => null);
      when(handler.resendOwnCounterZero).thenThrow(StateError('closed'));

      await resendOwnCounterZeroOnceForTesting();

      verifyNever(
        () => settingsDb.saveSettingsItem(counterZeroResentSettingsKey, any()),
      );
      verify(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'counterZeroResend',
        ),
      ).called(1);
    });
  });

  group('repairClocklessRowsOnceForTesting', () {
    late MockDomainLogger logger;
    late MockSettingsDb settingsDb;
    late MockJournalDb journalDb;
    late MockVectorClockService vectorClock;

    setUp(() {
      logger = MockDomainLogger();
      settingsDb = MockSettingsDb();
      journalDb = MockJournalDb();
      vectorClock = MockVectorClockService();
      when(
        () => logger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      when(() => vectorClock.initialized).thenAnswer((_) async {});
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(journalDb.clocklessDefinitions).thenAnswer((_) async => []);
      when(journalDb.entryLinksWithNullVectorClock).thenAnswer((_) async => []);
      getIt
        ..registerSingleton<DomainLogger>(logger)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<VectorClockService>(vectorClock)
        ..registerSingleton<OutboxService>(MockOutboxService())
        ..registerSingleton<AiConfigRepository>(MockAiConfigRepository())
        ..registerSingleton<SavedTaskFiltersRepository>(
          MockSavedTaskFiltersRepository(),
        )
        ..registerSingleton<AgentDatabase>(MockAgentDatabase());
      when(
        () => settingsDb.saveSettingsItemIfUnchanged(
          any(),
          expected: any(named: 'expected'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async => true);
    });

    test('does nothing once a device has run it', () async {
      when(
        () => settingsDb.itemByKey(clocklessRepairSettingsKey),
      ).thenAnswer((_) async => clocklessRepairDone);

      await repairClocklessRowsOnceForTesting();

      verifyNever(journalDb.clocklessDefinitions);
      verifyNever(journalDb.entryLinksWithNullVectorClock);
    });

    test(
      'repairs definitions and entry links, then records that it ran',
      () async {
        when(
          () => settingsDb.itemByKey(clocklessRepairSettingsKey),
        ).thenAnswer((_) async => null);

        await repairClocklessRowsOnceForTesting();

        verify(journalDb.clocklessDefinitions).called(1);
        verify(journalDb.entryLinksWithNullVectorClock).called(1);
        verify(
          () => settingsDb.saveSettingsItemIfUnchanged(
            clocklessRepairSettingsKey,
            expected: null,
            value: clocklessRepairDone,
          ),
        ).called(1);
      },
    );

    test(
      'a clockless row stored during the sweep keeps the repair pending: '
      'completion is recorded only over the token read before sweeping',
      () async {
        when(
          () => settingsDb.itemByKey(clocklessRepairSettingsKey),
        ).thenAnswer((_) async => 'pending:first');
        when(
          () => settingsDb.saveSettingsItemIfUnchanged(
            clocklessRepairSettingsKey,
            expected: 'pending:first',
            value: clocklessRepairDone,
          ),
        ).thenAnswer((_) async => false);

        await repairClocklessRowsOnceForTesting();

        verify(journalDb.entryLinksWithNullVectorClock).called(1);
        verify(
          () => logger.log(
            any<LogDomain>(),
            any<String>(that: contains('next start sweeps again')),
            subDomain: 'clocklessRepair',
          ),
        ).called(1);
      },
    );

    test(
      'a failed repair is logged and left to run again at the next start',
      () async {
        when(
          () => settingsDb.itemByKey(clocklessRepairSettingsKey),
        ).thenAnswer((_) async => null);
        when(
          journalDb.entryLinksWithNullVectorClock,
        ).thenThrow(StateError('database closed'));

        await repairClocklessRowsOnceForTesting();

        verifyNever(
          () => settingsDb.saveSettingsItemIfUnchanged(
            clocklessRepairSettingsKey,
            expected: any(named: 'expected'),
            value: any(named: 'value'),
          ),
        );
        verify(
          () => logger.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'clocklessRepair',
          ),
        ).called(1);
      },
    );
  });

  group('checkAndPopulateSequenceLogForTesting', () {
    late MockDomainLogger mockDomainLogger;
    late MockSettingsDb settingsDb;
    late MockSyncDatabase syncDatabase;
    late MockJournalDb journalDb;
    late MockAgentDatabase agentDb;
    late MockNotificationsDb notificationsDb;
    late MockConsumptionDatabase consumptionDb;
    late MockAiConfigDb aiConfigDb;
    late MockSyncSequenceLogService sequenceLogService;

    const settingsKey = 'maintenance_sequenceLogPopulatedV2';
    const noRecords =
        Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();

    setUp(() {
      mockDomainLogger = MockDomainLogger();
      settingsDb = MockSettingsDb();
      syncDatabase = MockSyncDatabase();
      journalDb = MockJournalDb();
      agentDb = MockAgentDatabase();
      notificationsDb = MockNotificationsDb();
      consumptionDb = MockConsumptionDatabase();
      aiConfigDb = MockAiConfigDb();
      final aiConfigRepository = MockAiConfigRepository();
      when(() => aiConfigRepository.configDb).thenReturn(aiConfigDb);
      sequenceLogService = MockSyncSequenceLogService();

      // The other sequence-tracked stores hold nothing unless a test says so.
      when(notificationsDb.countAllNotifications).thenAnswer((_) async => 0);
      when(
        notificationsDb.streamNotificationsWithVectorClock,
      ).thenAnswer((_) => noRecords);
      when(consumptionDb.countAllEvents).thenAnswer((_) async => 0);
      when(
        consumptionDb.streamEventsWithVectorClock,
      ).thenAnswer((_) => noRecords);
      when(journalDb.countAllDefinitions).thenAnswer((_) async => 0);
      when(
        journalDb.streamDefinitionsWithVectorClock,
      ).thenAnswer((_) => noRecords);
      when(aiConfigDb.countAllVersions).thenAnswer((_) async => 0);
      when(
        aiConfigDb.streamVersionsWithVectorClock,
      ).thenAnswer((_) => noRecords);
      getIt.registerSingleton<AiConfigRepository>(aiConfigRepository);
      when(
        () => sequenceLogService.populateFromRecords(
          payloadType: any(named: 'payloadType'),
          records: any(named: 'records'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
      ).thenAnswer((_) async => 0);

      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      getIt
        ..registerSingleton<DomainLogger>(mockDomainLogger)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<SyncDatabase>(syncDatabase)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<AgentDatabase>(agentDb)
        ..registerSingleton<NotificationsDb>(notificationsDb)
        ..registerSingleton<ConsumptionDatabase>(consumptionDb)
        ..registerSingleton<SyncSequenceLogService>(sequenceLogService);
    });

    /// Every store the population reads, empty, and the settings it writes.
    void stubEmptyPopulation() {
      when(() => syncDatabase.getSequenceLogCount()).thenAnswer((_) async => 0);
      when(() => journalDb.countAllJournalEntries()).thenAnswer((_) async => 0);
      when(() => journalDb.countAllEntryLinks()).thenAnswer((_) async => 0);
      when(() => agentDb.countAllAgentEntities()).thenAnswer((_) async => 0);
      when(() => agentDb.countAllAgentLinks()).thenAnswer((_) async => 0);
      for (final populate in [
        () => sequenceLogService.populateFromJournal(
          entryStream: any(named: 'entryStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
        () => sequenceLogService.populateFromEntryLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
        () => sequenceLogService.populateFromAgentEntities(
          entityStream: any(named: 'entityStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
        () => sequenceLogService.populateFromAgentLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
      ]) {
        when(populate).thenAnswer((_) async => 0);
      }
      when(
        journalDb.streamEntriesWithVectorClock,
      ).thenAnswer((_) => noRecords);
      when(
        journalDb.streamEntryLinksWithVectorClock,
      ).thenAnswer((_) => noRecords);
      when(
        agentDb.streamAgentEntitiesWithVectorClock,
      ).thenAnswer((_) => noRecords);
      when(
        agentDb.streamAgentLinksWithVectorClock,
      ).thenAnswer((_) => noRecords);
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
    }

    test(
      'populates the vectors registers the store holds, after restore '
      '(ADR 0149)',
      () async {
        when(
          () => settingsDb.itemByKey(settingsKey),
        ).thenAnswer((_) async => null);
        stubEmptyPopulation();
        final vectors = MockEmbeddingVectorsSync();
        when(vectors.sharedRegisters).thenAnswer(
          (_) async => [
            const EmbeddingRegister(
              entityId: 'e1',
              modelId: 'm',
              entityType: 'task',
              contentHash: 'h',
              vectorClock: VectorClock({'host': 4}),
              originatingHostId: 'host',
            ),
          ],
        );
        getIt.registerSingleton<EmbeddingVectorsSync>(vectors);
        addTearDown(() => getIt.unregister<EmbeddingVectorsSync>());

        await checkAndPopulateSequenceLogForTesting();

        final call = verify(
          () => sequenceLogService.populateFromRecords(
            payloadType: SyncSequencePayloadType.embeddingVectors,
            records: captureAny(named: 'records'),
            getTotalCount: captureAny(named: 'getTotalCount'),
          ),
        )..called(1);
        final records =
            call.captured[0]
                as Stream<List<({String id, Map<String, int>? vectorClock})>>;
        final count = call.captured[1] as Future<int> Function();
        final record = (await records.toList()).single.single;
        expect(record.id, 'e1|m');
        expect(record.vectorClock, {'host': 4});
        expect(await count(), 1);
      },
    );

    test('skips when flag already set', () async {
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenAnswer((_) async => 'true');

      await checkAndPopulateSequenceLogForTesting();

      verifyNever(() => syncDatabase.getSequenceLogCount());
      verifyNever(() => journalDb.countAllJournalEntries());
    });

    test('runs once more after the sync database was restored from a '
        'backup, and only once per restore', () async {
      final documents = Directory.systemTemp.createTempSync('restored_');
      addTearDown(() => documents.deleteSync(recursive: true));
      File(
        '${documents.path}/sync.sqlite.restored',
      ).writeAsStringSync('2026-10-11T10:00:00.000');
      getIt.registerSingleton<Directory>(documents);
      addTearDown(() => getIt.unregister<Directory>());
      const restoreKey = 'maintenance_sequenceLogRestoreRepopulated';
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenAnswer((_) async => 'true');
      String? handled;
      when(
        () => settingsDb.itemByKey(restoreKey),
      ).thenAnswer((_) async => handled);
      when(() => settingsDb.saveSettingsItem(any(), any())).thenAnswer((
        invocation,
      ) async {
        if (invocation.positionalArguments.first == restoreKey) {
          handled = invocation.positionalArguments[1] as String;
        }
        return 1;
      });
      when(
        () => syncDatabase.getSequenceLogCount(),
      ).thenAnswer((_) async => 10);
      when(() => journalDb.countAllJournalEntries()).thenAnswer((_) async => 0);
      when(() => journalDb.countAllEntryLinks()).thenAnswer((_) async => 0);
      when(() => agentDb.countAllAgentEntities()).thenAnswer((_) async => 0);
      when(() => agentDb.countAllAgentLinks()).thenAnswer((_) async => 0);

      await checkAndPopulateSequenceLogForTesting();
      await checkAndPopulateSequenceLogForTesting();

      verify(() => journalDb.countAllJournalEntries()).called(1);
      expect(handled, '2026-10-11T10:00:00.000');
    });

    test(
      'marks done and skips when all data sources are empty',
      () async {
        when(
          () => settingsDb.itemByKey(settingsKey),
        ).thenAnswer((_) async => null);
        when(
          () => syncDatabase.getSequenceLogCount(),
        ).thenAnswer((_) async => 150);
        when(
          () => journalDb.countAllJournalEntries(),
        ).thenAnswer((_) async => 0);
        when(
          () => journalDb.countAllEntryLinks(),
        ).thenAnswer((_) async => 0);
        when(
          () => agentDb.countAllAgentEntities(),
        ).thenAnswer((_) async => 0);
        when(
          () => agentDb.countAllAgentLinks(),
        ).thenAnswer((_) async => 0);
        when(
          () => settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);

        await checkAndPopulateSequenceLogForTesting();

        verify(
          () => settingsDb.saveSettingsItem(
            settingsKey,
            'true',
          ),
        ).called(1);
      },
    );

    test('populates notifications, consumption events and definitions, '
        'even when they are all a restored device holds', () async {
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenAnswer((_) async => null);
      stubEmptyPopulation();
      when(notificationsDb.countAllNotifications).thenAnswer((_) async => 3);

      await checkAndPopulateSequenceLogForTesting();

      final populated = verify(
        () => sequenceLogService.populateFromRecords(
          payloadType: captureAny(named: 'payloadType'),
          records: any(named: 'records'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
      ).captured;
      expect(populated, [
        SyncSequencePayloadType.notification,
        SyncSequencePayloadType.consumptionEvent,
        SyncSequencePayloadType.entityDefinition,
        SyncSequencePayloadType.aiConfig,
      ]);
      verify(() => settingsDb.saveSettingsItem(settingsKey, 'true')).called(1);
    });

    test('logs exception when population fails', () async {
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenAnswer((_) async => null);
      when(
        () => syncDatabase.getSequenceLogCount(),
      ).thenThrow(Exception('db error'));

      await checkAndPopulateSequenceLogForTesting();

      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });

    test('populates from all data sources when needed', () async {
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenAnswer((_) async => null);
      when(() => syncDatabase.getSequenceLogCount()).thenAnswer((_) async => 0);
      when(
        () => journalDb.countAllJournalEntries(),
      ).thenAnswer((_) async => 100);
      when(() => journalDb.countAllEntryLinks()).thenAnswer((_) async => 50);
      when(() => agentDb.countAllAgentEntities()).thenAnswer((_) async => 10);
      when(() => agentDb.countAllAgentLinks()).thenAnswer((_) async => 5);
      const entriesStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();
      const entryLinksStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();
      const agentEntitiesStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();
      const agentLinksStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();
      when(
        () => journalDb.streamEntriesWithVectorClock(),
      ).thenAnswer((_) => entriesStream);
      when(
        () => journalDb.streamEntryLinksWithVectorClock(),
      ).thenAnswer((_) => entryLinksStream);
      when(
        () => agentDb.streamAgentEntitiesWithVectorClock(),
      ).thenAnswer((_) => agentEntitiesStream);
      when(
        () => agentDb.streamAgentLinksWithVectorClock(),
      ).thenAnswer((_) => agentLinksStream);
      // Use specific callback matching instead of any() for complex types
      when(
        () => sequenceLogService.populateFromJournal(
          entryStream:
              any<Stream<List<({String id, Map<String, int>? vectorClock})>>>(
                named: 'entryStream',
              ),
          getTotalCount: any<Future<int> Function()>(named: 'getTotalCount'),
        ),
      ).thenAnswer((_) async => 100);
      when(
        () => sequenceLogService.populateFromEntryLinks(
          linkStream:
              any<Stream<List<({String id, Map<String, int>? vectorClock})>>>(
                named: 'linkStream',
              ),
          getTotalCount: any<Future<int> Function()>(named: 'getTotalCount'),
        ),
      ).thenAnswer((_) async => 50);
      when(
        () => sequenceLogService.populateFromAgentEntities(
          entityStream:
              any<Stream<List<({String id, Map<String, int>? vectorClock})>>>(
                named: 'entityStream',
              ),
          getTotalCount: any<Future<int> Function()>(named: 'getTotalCount'),
        ),
      ).thenAnswer((_) async => 10);
      when(
        () => sequenceLogService.populateFromAgentLinks(
          linkStream:
              any<Stream<List<({String id, Map<String, int>? vectorClock})>>>(
                named: 'linkStream',
              ),
          getTotalCount: any<Future<int> Function()>(named: 'getTotalCount'),
        ),
      ).thenAnswer((_) async => 5);
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      await checkAndPopulateSequenceLogForTesting();

      // Verify settings saved (which means population completed)
      verify(
        () => settingsDb.saveSettingsItem(
          settingsKey,
          'true',
        ),
      ).called(1);
      // Verify all populate methods were called
      verify(
        () => sequenceLogService.populateFromJournal(
          entryStream: any(named: 'entryStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
      ).called(1);
      verify(
        () => sequenceLogService.populateFromEntryLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
      ).called(1);
      verify(
        () => sequenceLogService.populateFromAgentEntities(
          entityStream: any(named: 'entityStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
      ).called(1);
      verify(
        () => sequenceLogService.populateFromAgentLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
        ),
      ).called(1);
      // Verify logging events
      verify(
        () => mockDomainLogger.log(
          LogDomain.database,
          any<String>(that: contains('Starting automatic sequence log')),
          subDomain: 'sequenceLogPopulation',
        ),
      ).called(1);
      verify(
        () => mockDomainLogger.log(
          LogDomain.database,
          any<String>(that: contains('(V2) completed')),
          subDomain: 'sequenceLogPopulation',
        ),
      ).called(1);
    });
  });

  group('migrateSpeechDictionaryForTesting', () {
    test(
      "migrates the categories' lists through the registered services",
      () async {
        final journalDb = MockJournalDb();
        final persistence = MockPersistenceLogic();
        final logger = MockDomainLogger();
        when(
          journalDb.getSpeechDictionaryEntriesIncludingDeleted,
        ).thenAnswer((_) async => []);
        when(journalDb.getAllCategoriesIncludingPrivate).thenAnswer(
          (_) async => [
            CategoryDefinition(
              id: 'work',
              name: 'Work',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
              private: false,
              active: true,
              speechDictionary: const ['Kubernetes'],
            ),
          ],
        );
        when(
          () => persistence.seedEntityDefinition(any()),
        ).thenAnswer((_) async => 1);
        getIt
          ..registerSingleton<JournalDb>(journalDb)
          ..registerSingleton<PersistenceLogic>(persistence)
          ..registerSingleton<DomainLogger>(logger);

        await migrateSpeechDictionaryForTesting();

        final seeded =
            verify(
                  () => persistence.seedEntityDefinition(captureAny()),
                ).captured.single
                as SpeechDictionaryEntry;
        expect(seeded.term, 'Kubernetes');
        expect(seeded.categoryIds, ['work']);
      },
    );
  });

  group('composition-root builders for the layer seams', () {
    setUp(() {
      getIt
        ..registerSingleton<JournalDb>(MockJournalDb())
        ..registerSingleton<AgentDatabase>(MockAgentDatabase())
        ..registerSingleton<DomainLogger>(MockDomainLogger());
    });

    test('buildConfigFlagEffects is the notification preference effects', () {
      expect(buildConfigFlagEffects(), isA<NotificationPreferenceEffects>());
    });

    test('buildRelationshipCascade is the relationship repository', () {
      expect(
        buildRelationshipCascade(
          buildJournalRepository(),
          MockPersistenceLogic(),
        ),
        isA<RelationshipRepository>(),
      );
    });
  });

  group('GetItLiveWorldServices', () {
    test('is empty-handed in a generation that registered nothing', () {
      const world = GetItLiveWorldServices();

      expect(world.profileContext, isNull);
      expect(world.fts, isNull);
      expect(world.domainLogger, isNull);
    });

    test('answers with the services the live generation registered', () {
      final journalDb = MockJournalDb();
      final aiConfigs = MockAiConfigRepository();
      final root = Directory.systemTemp;
      final persistence = MockPersistenceLogic();
      final fts = MockFts5Db();
      final logger = MockDomainLogger();
      final context = ProfileContext.forProfile(
        profile: Profile.realDefault(),
        root: Directory.systemTemp,
      );
      getIt
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<AiConfigRepository>(aiConfigs)
        ..registerSingleton<Directory>(root)
        ..registerSingleton<PersistenceLogic>(persistence)
        ..registerSingleton<Fts5Db>(fts)
        ..registerSingleton<DomainLogger>(logger)
        ..registerSingleton<ProfileContext>(context);

      const world = GetItLiveWorldServices();

      expect(world.journalDb, same(journalDb));
      expect(world.aiConfigs, same(aiConfigs));
      expect(world.root, same(root));
      expect(world.persistence, same(persistence));
      expect(world.fts, same(fts));
      expect(world.domainLogger, same(logger));
      expect(world.profileContext, same(context));
    });
  });
}
