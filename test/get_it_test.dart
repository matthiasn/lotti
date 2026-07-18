import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_backfill_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';

void main() {
  setUpAll(() {
    // Register fallback values for complex types used with any()
    registerFallbackValue(
      const Stream<List<({String id, Map<String, int>? vectorClock})>>.empty(),
    );
    registerFallbackValue(() async => 0);
    registerFallbackValue(<JournalEntity>[]);
    registerFallbackValue(<AgentDomainEntity>[]);
    registerFallbackValue(<AiConsumptionEvent>[]);
  });
  setUp(() async {
    // Use a dedicated scope per test to avoid cross-file contamination
    getIt.pushNewScope();
  });

  tearDown(() async {
    await getIt.resetScope();
    await getIt.popScope();
  });

  group('safeLog', () {
    test('delegates to logging service on success messages', () {
      final mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      safeLogForTesting('hello', isError: false);

      verify(
        () => mockDomainLogger.log(
          LogDomain.settings,
          'hello',
          subDomain: 'SERVICE_REGISTRATION',
        ),
      ).called(1);
    });

    test('delegates to logging service on error messages (success path)', () {
      final mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      DevLogger.clear();

      safeLogForTesting('registration failed', isError: true);

      // error() is logged under the 'error' subDomain (not 'SERVICE_REGISTRATION')
      // and, when it succeeds, the DevLogger fallback is not used.
      verify(
        () => mockDomainLogger.error(
          LogDomain.settings,
          'registration failed',
          subDomain: 'error',
        ),
      ).called(1);
      expect(DevLogger.capturedLogs, isEmpty);
    });

    test('falls back to DevLogger when logging service missing', () {
      DevLogger.clear();

      safeLogForTesting('fallback', isError: false);

      expect(DevLogger.capturedLogs, isNotEmpty);
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('SERVICE_REGISTRATION') && log.contains('fallback'),
        ),
        isTrue,
      );
    });

    test('uses DevLogger when logging service throws', () {
      final mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenThrow(Exception('fail'));

      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      DevLogger.clear();

      safeLogForTesting('failure', isError: true);

      expect(DevLogger.capturedLogs, isNotEmpty);
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('SERVICE_REGISTRATION') &&
              log.contains('failure') &&
              log.contains('logging failed'),
        ),
        isTrue,
      );
    });
  });

  group('registerLazyServiceForTesting', () {
    test('registers lazy singleton and logs lifecycle events', () {
      final mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      registerLazyServiceForTesting<String>(() => 'value', 'TestService');

      verify(
        () => mockDomainLogger.log(
          LogDomain.settings,
          'Successfully registered lazy TestService',
          subDomain: 'SERVICE_REGISTRATION',
        ),
      ).called(1);

      final resolved = getIt<String>();

      expect(resolved, 'value');
      verify(
        () => mockDomainLogger.log(
          LogDomain.settings,
          'Successfully created lazy instance of TestService',
          subDomain: 'SERVICE_REGISTRATION',
        ),
      ).called(1);
    });

    test('logs and rethrows when factory fails', () {
      final mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      registerLazyServiceForTesting<int>(
        () => throw StateError('broken'),
        'BrokenService',
      );

      // Suppress get_it package's internal debug printing during error
      runZoned(
        () => expect(getIt.call<int>, throwsA(isA<StateError>())),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, _) {}, // Suppress prints from get_it package
        ),
      );

      verify(
        () => mockDomainLogger.error(
          LogDomain.settings,
          any<Object>(
            that: contains('Failed to create lazy instance of BrokenService'),
          ),
          subDomain: 'error',
        ),
      ).called(1);
    });

    test('logs registration failure when duplicate service detected', () {
      final mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      registerLazyServiceForTesting<String>(() => 'first', 'DupService');

      registerLazyServiceForTesting<String>(() => 'second', 'DupService');

      final captured = verify(
        () => mockDomainLogger.error(
          LogDomain.settings,
          captureAny<Object>(),
          subDomain: 'error',
        ),
      ).captured;

      expect(
        captured.cast<String>().any(
          (message) => message.contains('Failed to register lazy DupService'),
        ),
        isTrue,
      );
    });
  });

  group('checkAndPopulateSequenceLogForTesting', () {
    late MockDomainLogger mockDomainLogger;
    late MockSettingsDb settingsDb;
    late MockSyncDatabase syncDatabase;
    late MockJournalDb journalDb;
    late MockAgentDatabase agentDb;
    late MockSyncSequenceLogService sequenceLogService;

    const settingsKey = 'maintenance_sequenceLogPopulatedV2';

    setUp(() {
      mockDomainLogger = MockDomainLogger();
      settingsDb = MockSettingsDb();
      syncDatabase = MockSyncDatabase();
      journalDb = MockJournalDb();
      agentDb = MockAgentDatabase();
      sequenceLogService = MockSyncSequenceLogService();

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
        ..registerSingleton<SyncSequenceLogService>(sequenceLogService);
    });

    test('skips when flag already set', () async {
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenAnswer((_) async => 'true');

      await checkAndPopulateSequenceLogForTesting();

      verifyNever(() => syncDatabase.getSequenceLogCount());
      verifyNever(() => journalDb.countAllJournalEntries());
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

  group('backfillAiAttributionForTesting', () {
    const settingsKey = 'maintenance_aiAttributionBackfillV1';
    late MockSettingsDb settingsDb;
    late MockDomainLogger logger;

    setUp(() {
      settingsDb = MockSettingsDb();
      logger = MockDomainLogger();
      when(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
      getIt
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<DomainLogger>(logger);
    });

    test('skips the already-completed migration', () async {
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenAnswer((_) async => 'true');

      await backfillAiAttributionForTesting();

      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });

    test(
      'backfills legacy carriers, agent rows, and consumption events',
      () async {
        final journalDb = MockJournalDb();
        final agentDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final repository = MockConsumptionRepository();
        final service = MockAiAttributionBackfillService();
        addTearDown(agentDb.close);
        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'legacy-entry',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
        );
        final event = AiConsumptionEvent(
          id: 'legacy-event',
          createdAt: DateTime(2024, 3, 15),
          providerType: InferenceProviderType.openAi,
          responseType: AiConsumptionResponseType.promptGeneration,
          vectorClock: null,
        );
        final page = [journalEntity];
        final events = [event];
        when(
          () => settingsDb.itemByKey(settingsKey),
        ).thenAnswer((_) async => null);
        when(
          () => journalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => page);
        when(
          () => repository.eventsWithoutAttribution(limit: 250),
        ).thenAnswer((_) async => events);
        when(
          () => service.backfill(
            journalEntities: any(named: 'journalEntities'),
            agentEntities: any(named: 'agentEntities'),
            consumptionEvents: any(named: 'consumptionEvents'),
          ),
        ).thenAnswer(
          (_) async => const AiAttributionBackfillResult(
            projectedCarriers: 0,
            createdLegacyAttributions: 0,
            migratedConsumptionEvents: 0,
          ),
        );
        when(
          () => settingsDb.saveSettingsItem(settingsKey, 'true'),
        ).thenAnswer((_) async => 1);
        getIt
          ..registerSingleton<JournalDb>(journalDb)
          ..registerSingleton<AgentDatabase>(agentDb)
          ..registerSingleton<ConsumptionRepository>(repository)
          ..registerSingleton<AiAttributionBackfillService>(service);

        await backfillAiAttributionForTesting();

        verify(
          () => service.backfill(journalEntities: page),
        ).called(1);
        verify(() => service.backfill(consumptionEvents: events)).called(1);
        verify(
          () => settingsDb.saveSettingsItem(settingsKey, 'true'),
        ).called(1);
      },
    );

    test('logs failures without marking the migration complete', () async {
      when(
        () => settingsDb.itemByKey(settingsKey),
      ).thenThrow(StateError('settings unavailable'));

      await backfillAiAttributionForTesting();

      verify(
        () => logger.error(
          LogDomain.ai,
          any<Object>(that: isA<StateError>()),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'aiAttributionBackfill',
        ),
      ).called(1);
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });
  });
}
