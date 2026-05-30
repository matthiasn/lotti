import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as agent_model;
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart'
    show OutboxStatus;
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

class _MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

JournalEntry _buildJournalEntry({
  required String id,
  required DateTime timestamp,
  required String text,
}) {
  return testTextEntry.copyWith(
    meta: testTextEntry.meta.copyWith(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
    ),
    entryText: EntryText(plainText: text),
  );
}

QuantitativeEntry _buildQuantitativeEntry({
  required String id,
  required DateTime timestamp,
  num value = 99,
}) {
  return testWeightEntry.copyWith(
    meta: testWeightEntry.meta.copyWith(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
    ),
    data: testWeightEntry.data.map(
      cumulativeQuantityData: (data) => data.copyWith(
        value: value,
        dateFrom: timestamp,
        dateTo: timestamp,
      ),
      discreteQuantityData: (data) => data.copyWith(
        value: value,
        dateFrom: timestamp,
        dateTo: timestamp,
      ),
    ),
  );
}

EntryLink _buildEntryLink({
  required String id,
  required String fromId,
  required String toId,
  required DateTime timestamp,
}) {
  return EntryLink.basic(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: timestamp,
    updatedAt: timestamp,
    vectorClock: const VectorClock({'node': 1}),
  );
}

Future<void> _insertEntries(JournalDb db, List<JournalEntity> entries) async {
  if (entries.isEmpty) {
    return;
  }

  await db.batch((batch) {
    batch.insertAll(
      db.journal,
      entries.map(toDbEntity).toList(),
      mode: InsertMode.insertOrReplace,
    );
  });
}

class _ThrowingMaintenance extends Maintenance {
  @override
  Future<void> deleteFts5Db() {
    throw const FileSystemException('Simulated delete failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(fallbackSyncMessage);
    registerFallbackValue(FakeMetadata());
  });

  group('Maintenance', () {
    late Directory tempDir;
    late JournalDb journalDb;
    late Fts5Db initialFts5;
    late Maintenance maintenance;
    late MockOutboxService outboxService;
    late MockDomainLogger mockDomainLogger;
    late MockPersistenceLogic persistenceLogic;
    late MockEntitiesCacheService entitiesCacheService;
    late MockVectorClockService vectorClockService;
    late List<SyncMessage> sentMessages;
    late List<String> loggedEvents;
    late List<dynamic> loggedExceptions;
    late PathProviderPlatform originalPathProvider;
    late _MockPathProviderPlatform mockPathProvider;

    setUp(() async {
      await getIt.reset();

      tempDir = Directory.systemTemp.createTempSync('maintenance_test_');
      getIt.registerSingleton<Directory>(tempDir);

      journalDb = JournalDb(inMemoryDatabase: true);
      getIt.registerSingleton<JournalDb>(journalDb);

      outboxService = MockOutboxService();
      getIt.registerSingleton<OutboxService>(outboxService);

      mockDomainLogger = MockDomainLogger();
      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      persistenceLogic = MockPersistenceLogic();
      getIt.registerSingleton<PersistenceLogic>(persistenceLogic);

      entitiesCacheService = MockEntitiesCacheService();
      when(() => entitiesCacheService.getDataTypeById(any())).thenReturn(null);
      getIt.registerSingleton<EntitiesCacheService>(entitiesCacheService);

      vectorClockService = MockVectorClockService();
      when(
        () => vectorClockService.getHost(),
      ).thenAnswer((_) async => 'test-host-id');
      getIt.registerSingleton<VectorClockService>(vectorClockService);

      initialFts5 = Fts5Db(inMemoryDatabase: true);
      getIt.registerSingleton<Fts5Db>(initialFts5);

      mockPathProvider = _MockPathProviderPlatform();
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = mockPathProvider;
      when(
        mockPathProvider.getApplicationDocumentsPath,
      ).thenAnswer((_) async => tempDir.path);
      when(
        mockPathProvider.getApplicationSupportPath,
      ).thenAnswer((_) async => tempDir.path);
      when(
        mockPathProvider.getTemporaryPath,
      ).thenAnswer((_) async => tempDir.path);

      sentMessages = [];
      loggedEvents = [];
      loggedExceptions = [];
      when(() => outboxService.enqueueMessage(any())).thenAnswer((
        invocation,
      ) async {
        sentMessages.add(invocation.positionalArguments.first as SyncMessage);
      });

      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((invocation) {
        loggedEvents.add(invocation.positionalArguments.first.toString());
        return;
      });

      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((invocation) {
        // error(LogDomain, Object error, ...): the error object is the
        // second positional argument.
        loggedExceptions.add(invocation.positionalArguments[1]);
        return;
      });

      maintenance = Maintenance();
    });

    tearDown(() async {
      if (getIt.isRegistered<Fts5Db>()) {
        await getIt<Fts5Db>().close();
      }
      await journalDb.close();
      await getIt.reset();
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('reSyncInterval', () {
      late MockAgentRepository mockAgentRepo;

      setUp(() {
        mockAgentRepo = MockAgentRepository();
        when(
          () => mockAgentRepo.countEntitiesInInterval(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer((_) async => 0);
        when(
          () => mockAgentRepo.countLinksInInterval(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer((_) async => 0);
      });

      test('enqueues all journal entities inside interval', () async {
        final baseDate = DateTime(2024);
        final entries = List.generate(
          5,
          (index) => _buildJournalEntry(
            id: 'entry-$index',
            timestamp: baseDate.add(Duration(days: index)),
            text: 'Entry $index',
          ),
        );
        await _insertEntries(journalDb, entries);

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 5)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();
        expect(journalMessages, hasLength(entries.length));
        expect(
          journalMessages.map((m) => m.id),
          containsAll(entries.map((e) => e.meta.id)),
        );
      });

      test('handles pagination beyond the default page size', () async {
        final baseDate = DateTime(2024, 2);
        final entries = List.generate(
          350,
          (index) => _buildJournalEntry(
            id: 'paginated-$index',
            timestamp: baseDate.add(Duration(minutes: index)),
            text: 'Paginated entry $index',
          ),
        );
        await _insertEntries(journalDb, entries);

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 2)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();
        expect(journalMessages, hasLength(entries.length));
      });

      test('enqueues linked entry messages for linked entities', () async {
        final baseDate = DateTime(2024, 3);
        final entryA = _buildJournalEntry(
          id: 'linked-A',
          timestamp: baseDate,
          text: 'Linked entry A',
        );
        final entryB = _buildJournalEntry(
          id: 'linked-B',
          timestamp: baseDate.add(const Duration(minutes: 5)),
          text: 'Linked entry B',
        );
        await _insertEntries(journalDb, [entryA, entryB]);

        final link = _buildEntryLink(
          id: 'link-1',
          fromId: entryA.meta.id,
          toId: entryB.meta.id,
          timestamp: baseDate,
        );
        await journalDb.upsertEntryLink(link);

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(hours: 1)),
          end: baseDate.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();
        final linkMessages = sentMessages.whereType<SyncEntryLink>().toList();

        expect(journalMessages, hasLength(2));
        expect(linkMessages, hasLength(1));
        expect(linkMessages.first.entryLink.id, equals(link.id));
      });

      test('filters journal entities by provided date range', () async {
        final baseDate = DateTime(2024, 4);
        final beforeEntry = _buildJournalEntry(
          id: 'before',
          timestamp: baseDate.subtract(const Duration(days: 2)),
          text: 'Outside before',
        );
        final insideEntry = _buildJournalEntry(
          id: 'inside',
          timestamp: baseDate,
          text: 'Inside range',
        );
        final afterEntry = _buildJournalEntry(
          id: 'after',
          timestamp: baseDate.add(const Duration(days: 2)),
          text: 'Outside after',
        );
        await _insertEntries(journalDb, [beforeEntry, insideEntry, afterEntry]);

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();

        expect(journalMessages, hasLength(1));
        expect(journalMessages.first.id, equals(insideEntry.meta.id));
      });

      test(
        'completes without enqueuing messages for empty intervals',
        () async {
          await maintenance.reSyncInterval(
            start: DateTime(2024, 5),
            end: DateTime(2024, 5, 2),
            agentRepository: mockAgentRepo,
          );

          expect(sentMessages, isEmpty);
        },
      );

      test('includes relative entity path in enqueued messages', () async {
        final timestamp = DateTime(2024, 6, 15, 10, 30);
        final entry = _buildJournalEntry(
          id: 'path-test',
          timestamp: timestamp,
          text: 'Check path',
        );
        await _insertEntries(journalDb, [entry]);

        await maintenance.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
        );

        final journalMessage = sentMessages
            .whereType<SyncJournalEntity>()
            .single;

        expect(
          journalMessage.jsonPath,
          equals('/text_entries/2024-06-15/path-test.text.json'),
        );
      });
    });

    group('reSyncInterval – agent entities and links', () {
      late AgentDatabase agentDb;
      late AgentRepository agentRepo;

      setUp(() {
        agentDb = AgentDatabase(inMemoryDatabase: true);
        agentRepo = AgentRepository(agentDb);
      });

      tearDown(() async {
        await agentDb.close();
      });

      /// Populates the in-memory agent DB with the given entities/links.
      Future<void> populateAgentDb({
        List<AgentDomainEntity> entities = const [],
        List<agent_model.AgentLink> links = const [],
      }) async {
        for (final entity in entities) {
          await agentRepo.upsertEntity(entity);
        }
        for (final link in links) {
          await agentRepo.upsertLink(link);
        }
      }

      test('enqueues agent entities updated within interval', () async {
        final baseDate = DateTime(2024, 10);
        final insideDate = baseDate.add(const Duration(hours: 12));

        final agentEntity = AgentDomainEntity.agent(
          id: 'agent-entity-1',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Test Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(entities: [agentEntity]);

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final agentMessages = sentMessages
            .whereType<SyncAgentEntity>()
            .toList();
        expect(agentMessages, hasLength(1));
        expect(
          agentMessages.first.agentEntity?.id,
          equals('agent-entity-1'),
        );
      });

      test('enqueues agent links updated within interval', () async {
        final baseDate = DateTime(2024, 11);
        final insideDate = baseDate.add(const Duration(hours: 6));

        // Need an entity so the link's fromId/toId are valid.
        final entity = AgentDomainEntity.agent(
          id: 'agent-link-entity',
          agentId: 'agent-link-agent',
          kind: 'task_agent',
          displayName: 'Link Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        final link = agent_model.AgentLink.basic(
          id: 'agent-link-1',
          fromId: 'agent-link-agent',
          toId: 'agent-link-entity',
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(entities: [entity], links: [link]);

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final linkMessages = sentMessages.whereType<SyncAgentLink>().toList();
        expect(linkMessages, hasLength(1));
        expect(linkMessages.first.agentLink?.id, equals('agent-link-1'));
      });

      test('does not enqueue agent entities outside interval', () async {
        final baseDate = DateTime(2024, 12);
        final outsideDate = baseDate.subtract(const Duration(days: 10));

        final agentEntity = AgentDomainEntity.agent(
          id: 'agent-outside',
          agentId: 'agent-outside-id',
          kind: 'task_agent',
          displayName: 'Outside Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: outsideDate,
          updatedAt: outsideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(entities: [agentEntity]);

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final agentMessages = sentMessages
            .whereType<SyncAgentEntity>()
            .toList();
        expect(agentMessages, isEmpty);
      });

      test('enqueues both agent entities and links together', () async {
        final baseDate = DateTime(2025);
        final insideDate = baseDate.add(const Duration(hours: 3));

        final entity1 = AgentDomainEntity.agent(
          id: 'combo-entity-1',
          agentId: 'combo-agent-1',
          kind: 'task_agent',
          displayName: 'Combo Agent 1',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        final entity2 = AgentDomainEntity.agentState(
          id: 'combo-state-1',
          agentId: 'combo-agent-1',
          revision: 1,
          slots: const AgentSlots(activeTaskId: 'task-1'),
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        final link = agent_model.AgentLink.agentState(
          id: 'combo-link-1',
          fromId: 'combo-agent-1',
          toId: 'combo-state-1',
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(
          entities: [entity1, entity2],
          links: [link],
        );

        await maintenance.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final agentMessages = sentMessages
            .whereType<SyncAgentEntity>()
            .toList();
        final linkMessages = sentMessages.whereType<SyncAgentLink>().toList();

        expect(agentMessages, hasLength(2));
        expect(linkMessages, hasLength(1));
        expect(
          agentMessages.map((m) => m.agentEntity?.id),
          containsAll(['combo-entity-1', 'combo-state-1']),
        );
        expect(linkMessages.first.agentLink?.id, equals('combo-link-1'));
      });

      test(
        'reSyncInterval skips agent sweep when includeAgentEntities=false',
        () async {
          final baseDate = DateTime(2024, 6);
          final insideDate = baseDate;

          // Seed both a journal entry and an agent entity inside the
          // window. With includeAgentEntities=false the journal entry must
          // still be enqueued but no agent messages should appear.
          final journal = _buildJournalEntry(
            id: 'journal-only-1',
            timestamp: insideDate,
            text: 'inside',
          );
          await _insertEntries(journalDb, [journal]);

          final agentEntity = AgentDomainEntity.agent(
            id: 'agent-skip-1',
            agentId: 'agent-skip-1',
            kind: 'task_agent',
            displayName: 'Skip Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: insideDate,
            updatedAt: insideDate,
            vectorClock: const VectorClock({'node': 1}),
          );
          final agentLink = agent_model.AgentLink.basic(
            id: 'agent-skip-link',
            fromId: 'agent-skip-1',
            toId: 'state-1',
            createdAt: insideDate,
            updatedAt: insideDate,
            vectorClock: const VectorClock({'node': 1}),
          );
          await populateAgentDb(
            entities: [agentEntity],
            links: [agentLink],
          );

          await maintenance.reSyncInterval(
            start: baseDate.subtract(const Duration(days: 1)),
            end: baseDate.add(const Duration(days: 1)),
            agentRepository: agentRepo,
            includeAgentEntities: false,
          );

          // Journal sweep ran.
          expect(
            sentMessages.whereType<SyncJournalEntity>().toList(),
            isNotEmpty,
          );
          // Agent sweep did NOT run.
          expect(
            sentMessages.whereType<SyncAgentEntity>().toList(),
            isEmpty,
          );
          expect(
            sentMessages.whereType<SyncAgentLink>().toList(),
            isEmpty,
          );
        },
      );

      test(
        'reSyncInterval skips journal sweep when includeJournalEntities=false',
        () async {
          final baseDate = DateTime(2024, 7);
          final insideDate = baseDate;

          final journal = _buildJournalEntry(
            id: 'journal-skip-1',
            timestamp: insideDate,
            text: 'inside',
          );
          await _insertEntries(journalDb, [journal]);

          final agentEntity = AgentDomainEntity.agent(
            id: 'agent-only-1',
            agentId: 'agent-only-1',
            kind: 'task_agent',
            displayName: 'Only Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: insideDate,
            updatedAt: insideDate,
            vectorClock: const VectorClock({'node': 1}),
          );
          await populateAgentDb(entities: [agentEntity], links: []);

          await maintenance.reSyncInterval(
            start: baseDate.subtract(const Duration(days: 1)),
            end: baseDate.add(const Duration(days: 1)),
            agentRepository: agentRepo,
            includeJournalEntities: false,
          );

          // No journal messages enqueued.
          expect(
            sentMessages.whereType<SyncJournalEntity>().toList(),
            isEmpty,
          );
          // Agent message present.
          expect(
            sentMessages.whereType<SyncAgentEntity>().toList(),
            hasLength(1),
          );
        },
      );

      test(
        'reSyncInterval is a no-op and logs when both filters are off',
        () async {
          final baseDate = DateTime(2024, 8);
          await maintenance.reSyncInterval(
            start: baseDate.subtract(const Duration(days: 1)),
            end: baseDate.add(const Duration(days: 1)),
            agentRepository: agentRepo,
            includeJournalEntities: false,
            includeAgentEntities: false,
          );

          expect(sentMessages, isEmpty);
          verify(
            () => mockDomainLogger.log(
              LogDomain.database,
              'reSyncInterval skipped — both entity-type filters disabled',
              subDomain: 'reSyncInterval',
            ),
          ).called(1);
        },
      );
    });

    group('database deletion helpers', () {
      test('deleteEditorDb removes existing database file', () async {
        final dbFile = await getDatabaseFile(editorDbFileName);
        await dbFile.create(recursive: true);
        expect(dbFile.existsSync(), isTrue);

        await maintenance.deleteEditorDb();

        expect(dbFile.existsSync(), isFalse);
      });

      test('deleteSyncDb removes existing database file', () async {
        final dbFile = await getDatabaseFile(syncDbFileName);
        await dbFile.create(recursive: true);
        expect(dbFile.existsSync(), isTrue);

        await maintenance.deleteSyncDb();

        expect(dbFile.existsSync(), isFalse);
      });

      test('deleteFts5Db removes file and logs deletion event', () async {
        final dbFile = await getDatabaseFile(fts5DbFileName);
        await dbFile.create(recursive: true);
        expect(dbFile.existsSync(), isTrue);

        await maintenance.deleteFts5Db();

        expect(dbFile.existsSync(), isFalse);

        verify(
          () => mockDomainLogger.log(
            LogDomain.database,
            'FTS5 database DELETED',
            subDomain: 'recreateFts5',
          ),
        ).called(1);
      });

      test(
        'database deletion is idempotent when file does not exist',
        () async {
          final dbFile = await getDatabaseFile(editorDbFileName);
          if (dbFile.existsSync()) {
            await dbFile.delete();
          }

          await maintenance.deleteEditorDb();

          expect(dbFile.existsSync(), isFalse);
        },
      );

      test('deleteAgentDb removes database and WAL companion files', () async {
        final dbFile = await getDatabaseFile(agentDbFileName);
        await dbFile.create(recursive: true);
        final shmFile = File('${dbFile.path}-shm');
        final walFile = File('${dbFile.path}-wal');
        await shmFile.create();
        await walFile.create();
        expect(dbFile.existsSync(), isTrue);
        expect(shmFile.existsSync(), isTrue);
        expect(walFile.existsSync(), isTrue);

        await maintenance.deleteAgentDb();

        expect(dbFile.existsSync(), isFalse);
        expect(shmFile.existsSync(), isFalse);
        expect(walFile.existsSync(), isFalse);
      });

      test('deleteAgentDb creates backup before deletion', () async {
        final dbFile = await getDatabaseFile(agentDbFileName);
        await dbFile.create(recursive: true);
        await dbFile.writeAsString('test-data');

        await maintenance.deleteAgentDb();

        expect(dbFile.existsSync(), isFalse);

        final backupDir = Directory('${tempDir.path}/backup');
        expect(backupDir.existsSync(), isTrue);
        final backupFiles = backupDir.listSync();
        expect(backupFiles, isNotEmpty);
      });

      test('deleteAgentDb is idempotent when file does not exist', () async {
        final dbFile = await getDatabaseFile(agentDbFileName);
        if (dbFile.existsSync()) {
          await dbFile.delete();
        }

        await maintenance.deleteAgentDb();

        expect(dbFile.existsSync(), isFalse);
        verify(
          () => mockDomainLogger.log(
            LogDomain.database,
            'Database file $agentDbFileName does not exist',
            subDomain: 'deleteAgentDb',
          ),
        ).called(1);
      });
    });

    group('recreateFts5', () {
      test('deletes existing index file and reindexes all entries', () async {
        when(
          () => entitiesCacheService.getDataTypeById(measurableChocolate.id),
        ).thenReturn(measurableChocolate);

        final now = DateTime(2024, 7);
        final entries = [
          _buildJournalEntry(
            id: 'fts-text',
            timestamp: now,
            text: 'FTS text entry',
          ),
          buildMeasurementEntry(
            id: 'fts-measurement',
            timestamp: now.add(const Duration(minutes: 5)),
            value: 123,
          ),
          _buildQuantitativeEntry(
            id: 'fts-quant',
            timestamp: now.add(const Duration(minutes: 10)),
            value: 88,
          ),
        ];
        await _insertEntries(journalDb, entries);

        final ftsFile = await getDatabaseFile(fts5DbFileName);
        await ftsFile.create(recursive: true);
        expect(ftsFile.existsSync(), isTrue);

        final progress = <double>[];
        await maintenance.recreateFts5(onProgress: progress.add);

        final newFtsDb = getIt<Fts5Db>();
        expect(newFtsDb, isNot(same(initialFts5)));
        expect(ftsFile.existsSync(), isTrue);
        expect(progress, isNotEmpty);
        expect(progress.last, closeTo(1.0, 1e-6));

        final textMatches = await newFtsDb
            .watchFullTextMatches('FTS text entry')
            .first;
        final measurementMatches = await newFtsDb
            .watchFullTextMatches('"Chocolate 123 g"')
            .first;
        final quantMatches = await newFtsDb
            .watchFullTextMatches('Weight')
            .first;

        expect(textMatches, contains('fts-text'));
        expect(measurementMatches, contains('fts-measurement'));
        expect(quantMatches, contains('fts-quant'));
      });

      test('reindexes all pages when entry count exceeds page size', () async {
        final start = DateTime(2024, 8);
        final entries = List.generate(
          520,
          (index) => _buildJournalEntry(
            id: 'bulk-$index',
            timestamp: start.add(Duration(minutes: index)),
            text: 'Bulk entry $index',
          ),
        );
        await _insertEntries(journalDb, entries);

        final ftsFile = await getDatabaseFile(fts5DbFileName);
        await ftsFile.create(recursive: true);

        await maintenance.recreateFts5();

        final newFtsDb = getIt<Fts5Db>();
        final sampleMatches = await newFtsDb
            .watchFullTextMatches('Bulk entry 519')
            .first;

        expect(sampleMatches, contains('bulk-519'));
      });

      test('handles deletion errors gracefully and logs exception', () async {
        final entries = [
          _buildJournalEntry(
            id: 'fts-error',
            timestamp: DateTime(2024, 9),
            text: 'Should index despite deletion error',
          ),
        ];
        await _insertEntries(journalDb, entries);

        loggedEvents.clear();
        loggedExceptions.clear();

        final throwingMaintenance = _ThrowingMaintenance();
        await throwingMaintenance.recreateFts5();

        expect(loggedExceptions, isNotEmpty);
        expect(loggedExceptions.last, isA<FileSystemException>());

        final newFtsDb = getIt<Fts5Db>();
        final matches = await newFtsDb
            .watchFullTextMatches('Should index')
            .first;
        expect(matches, contains('fts-error'));
      });
    });

    group('purgeSentOutboxItems', () {
      late SyncDatabase syncDb;

      setUp(() {
        syncDb = SyncDatabase(inMemoryDatabase: true);
        getIt.registerSingleton<SyncDatabase>(syncDb);
      });

      tearDown(() async {
        await syncDb.close();
      });

      OutboxCompanion buildSent({
        required DateTime updatedAt,
      }) {
        return OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s'),
          message: const Value('{}'),
          createdAt: Value(updatedAt),
          updatedAt: Value(updatedAt),
          retries: const Value(0),
        );
      }

      test(
        'deletes only sent rows older than retention and reports the count via '
        'onProgress + log event',
        () async {
          final now = DateTime(2026, 5, 9, 12);
          // 12 sent rows older than retention → with chunkSize=5 the
          // chunked path must run 3 passes (5 + 5 + 2). The progress
          // callback receives the running total after each pass, so the
          // sequence is the assertion that the chunked loop did its job.
          for (var i = 0; i < 12; i++) {
            await syncDb.addOutboxItem(
              buildSent(updatedAt: now.subtract(const Duration(days: 30))),
            );
          }
          // Fresh sent row — retention keeps it.
          await syncDb.addOutboxItem(buildSent(updatedAt: now));
          // Pending row — never pruned.
          await syncDb.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.pending.index),
              subject: const Value('p'),
              message: const Value('{}'),
              createdAt: Value(now),
              updatedAt: Value(now),
              retries: const Value(0),
            ),
          );

          final progress = <int>[];
          final deleted = await maintenance.purgeSentOutboxItems(
            chunkSize: 5,
            onProgress: progress.add,
            // Pin the cutoff so the assertion below is not a time bomb:
            // without this, `purgeSentOutboxItems` falls back to
            // `DateTime.now()` and the "fresh" sent row becomes
            // prunable once wall-clock crosses ~`now + 7d`, deleting
            // 13 rows instead of 12.
            now: now,
          );

          expect(deleted, 12);
          expect(progress, [5, 10, 12]);
          // Live state survived.
          expect(await syncDb.allOutboxItems, hasLength(2));

          verify(
            () => mockDomainLogger.log(
              LogDomain.database,
              'purgeSentOutbox removed=12 retentionDays=7 chunkSize=5',
              subDomain: 'purgeSentOutbox',
            ),
          ).called(1);
        },
      );

      test(
        'returns 0 and still logs a single event when there is nothing to '
        'purge',
        () async {
          final deleted = await maintenance.purgeSentOutboxItems(
            chunkSize: 5,
          );

          expect(deleted, 0);
          verify(
            () => mockDomainLogger.log(
              LogDomain.database,
              'purgeSentOutbox removed=0 retentionDays=7 chunkSize=5',
              subDomain: 'purgeSentOutbox',
            ),
          ).called(1);
        },
      );
    });
  });
}
