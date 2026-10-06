import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/notifications/preferences/notification_preference_effects.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
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
    registerFallbackValue(FakeCategoryDefinition());
  });
  setUp(() async {
    // Use a dedicated scope per test to avoid cross-file contamination
    getIt.pushNewScope();
  });

  tearDown(() async {
    await getIt.resetScope();
    await getIt.popScope();
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
