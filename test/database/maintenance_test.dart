import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/tags_service.dart';
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
  List<String>? tagIds,
}) {
  return testTextEntry.copyWith(
    meta: testTextEntry.meta.copyWith(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      tagIds: tagIds,
    ),
    entryText: EntryText(plainText: text),
  );
}

Task _buildTaskEntry({
  required String id,
  required DateTime timestamp,
  String title = 'Task title',
}) {
  return testTask.copyWith(
    meta: testTask.meta.copyWith(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp.add(const Duration(hours: 1)),
    ),
    data: testTask.data.copyWith(title: title),
  );
}

MeasurementEntry _buildMeasurementEntry({
  required String id,
  required DateTime timestamp,
  num value = 42,
}) {
  return testMeasurementChocolateEntry.copyWith(
    meta: testMeasurementChocolateEntry.meta.copyWith(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
    ),
    data: testMeasurementChocolateEntry.data.copyWith(value: value),
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
    data: () {
      final data = testWeightEntry.data;
      if (data is CumulativeQuantityData) {
        return data.copyWith(
          value: value,
          dateFrom: timestamp,
          dateTo: timestamp,
        );
      }
      final discrete = data as DiscreteQuantityData;
      return discrete.copyWith(
        value: value,
        dateFrom: timestamp,
        dateTo: timestamp,
      );
    }(),
  );
}

AiResponseEntry _buildAiResponseEntry({
  required String id,
  required DateTime timestamp,
  // ignore: deprecated_member_use_from_same_package
  AiResponseType type = AiResponseType.actionItemSuggestions,
}) {
  return AiResponseEntry(
    meta: testTextEntry.meta.copyWith(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
    ),
    data: AiResponseData(
      model: 'model',
      systemMessage: 'system',
      prompt: 'prompt',
      thoughts: 'thoughts',
      response: 'response',
      type: type,
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
  for (final entry in entries) {
    await db.upsertJournalDbEntity(toDbEntity(entry));
  }
}

Future<File> _ensureJournalDbFile() async {
  final file = await getDatabaseFile(journalDbFileName);
  if (!file.existsSync()) {
    await file.create(recursive: true);
    await file.writeAsString('journal-db');
  }
  return file;
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
    late MockLoggingService loggingService;
    late MockPersistenceLogic persistenceLogic;
    late MockTagsService tagsService;
    late MockEntitiesCacheService entitiesCacheService;
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

      loggingService = MockLoggingService();
      getIt.registerSingleton<LoggingService>(loggingService);

      persistenceLogic = MockPersistenceLogic();
      getIt.registerSingleton<PersistenceLogic>(persistenceLogic);

      tagsService = MockTagsService();
      when(() => tagsService.getTagById(any())).thenReturn(null);
      getIt.registerSingleton<TagsService>(tagsService);

      entitiesCacheService = MockEntitiesCacheService();
      when(() => entitiesCacheService.getDataTypeById(any())).thenReturn(null);
      getIt.registerSingleton<EntitiesCacheService>(entitiesCacheService);

      initialFts5 = Fts5Db(inMemoryDatabase: true);
      getIt.registerSingleton<Fts5Db>(initialFts5);

      mockPathProvider = _MockPathProviderPlatform();
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = mockPathProvider;
      when(mockPathProvider.getApplicationDocumentsPath)
          .thenAnswer((_) async => tempDir.path);
      when(mockPathProvider.getApplicationSupportPath)
          .thenAnswer((_) async => tempDir.path);
      when(mockPathProvider.getTemporaryPath)
          .thenAnswer((_) async => tempDir.path);

      sentMessages = [];
      loggedEvents = [];
      loggedExceptions = [];
      when(() => outboxService.enqueueMessage(any()))
          .thenAnswer((invocation) async {
        sentMessages.add(invocation.positionalArguments.first as SyncMessage);
      });

      when(
        () => loggingService.captureEvent(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((invocation) {
        loggedEvents.add(invocation.positionalArguments.first.toString());
        return;
      });

      when(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).thenAnswer((invocation) {
        loggedExceptions.add(invocation.positionalArguments.first);
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
        );

        final journalMessages =
            sentMessages.whereType<SyncJournalEntity>().toList();
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
        );

        final journalMessages =
            sentMessages.whereType<SyncJournalEntity>().toList();
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
        );

        final journalMessages =
            sentMessages.whereType<SyncJournalEntity>().toList();
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
        );

        final journalMessages =
            sentMessages.whereType<SyncJournalEntity>().toList();

        expect(journalMessages, hasLength(1));
        expect(journalMessages.first.id, equals(insideEntry.meta.id));
      });

      test('completes without enqueuing messages for empty intervals',
          () async {
        await maintenance.reSyncInterval(
          start: DateTime(2024, 5),
          end: DateTime(2024, 5, 2),
        );

        expect(sentMessages, isEmpty);
      });

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
        );

        final journalMessage =
            sentMessages.whereType<SyncJournalEntity>().single;

        expect(journalMessage.jsonPath,
            equals('/text_entries/2024-06-15/path-test.text.json'));
      });
    });

    group('database deletion helpers', () {
      test('deleteEditorDb removes existing database file', () async {
        final dbFile = await getDatabaseFile(editorDbFileName);
        await dbFile.create(recursive: true);
        expect(dbFile.existsSync(), isTrue);

        await maintenance.deleteEditorDb();

        expect(dbFile.existsSync(), isFalse);
      });

      test('deleteLoggingDb removes existing database file', () async {
        final dbFile = await getDatabaseFile(loggingDbFileName);
        await dbFile.create(recursive: true);
        expect(dbFile.existsSync(), isTrue);

        await maintenance.deleteLoggingDb();

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
          () => loggingService.captureEvent(
            'FTS5 database DELETED',
            domain: 'MAINTENANCE',
            subDomain: 'recreateFts5',
          ),
        ).called(1);
      });

      test('database deletion throws when file does not exist', () async {
        final dbFile = await getDatabaseFile(editorDbFileName);
        if (dbFile.existsSync()) {
          await dbFile.delete();
        }

        await expectLater(
          maintenance.deleteEditorDb(),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('recreateFts5', () {
      test('deletes existing index file and reindexes all entries', () async {
        when(() => entitiesCacheService.getDataTypeById(measurableChocolate.id))
            .thenReturn(measurableChocolate);

        final now = DateTime(2024, 7);
        final entries = [
          _buildJournalEntry(
            id: 'fts-text',
            timestamp: now,
            text: 'FTS text entry',
          ),
          _buildMeasurementEntry(
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

        final textMatches =
            await newFtsDb.watchFullTextMatches('FTS text entry').first;
        final measurementMatches =
            await newFtsDb.watchFullTextMatches('"Chocolate 123 g"').first;
        final quantMatches =
            await newFtsDb.watchFullTextMatches('Weight').first;

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
        final sampleMatches =
            await newFtsDb.watchFullTextMatches('Bulk entry 519').first;

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

        final staleFtsFile = await getDatabaseFile(fts5DbFileName);
        if (staleFtsFile.existsSync()) {
          await staleFtsFile.delete();
        }

        await maintenance.recreateFts5();

        verify(
          () => loggingService.captureException(
            any<dynamic>(),
            domain: 'MAINTENANCE',
            subDomain: 'deleteFts5Db',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);

        final newFtsDb = getIt<Fts5Db>();
        final matches =
            await newFtsDb.watchFullTextMatches('Should index').first;
        expect(matches, contains('fts-error'));
      });
    });

    group('removeActionItemSuggestions', () {
      setUp(() {
        when(
          () => persistenceLogic.updateMetadata(
            any<Metadata>(),
            deletedAt: any<DateTime?>(named: 'deletedAt'),
          ),
        ).thenAnswer((invocation) async {
          final metadata = invocation.positionalArguments.first as Metadata;
          final deletedAt = invocation.namedArguments[#deletedAt] as DateTime?;
          return metadata.copyWith(deletedAt: deletedAt);
        });

        when(() => persistenceLogic.updateDbEntity(any<JournalEntity>()))
            .thenAnswer((_) async => true);
      });

      test('creates backup before deletion and logs event', () async {
        await _ensureJournalDbFile();

        final now = DateTime(2024, 10);
        final entries = [
          _buildAiResponseEntry(
            id: 'ai-deprecated',
            timestamp: now,
          ),
          _buildJournalEntry(
            id: 'regular-entry',
            timestamp: now.add(const Duration(minutes: 5)),
            text: 'Regular entry',
          ),
        ];
        await _insertEntries(journalDb, entries);

        final progress = <double>[];
        await maintenance.removeActionItemSuggestions(
          triggeredAtAppStart: false,
          onProgress: progress.add,
        );

        final backupDir = Directory('${tempDir.path}/backup');
        expect(backupDir.existsSync(), isTrue);
        expect(backupDir.listSync(), isNotEmpty);
        expect(
          loggedEvents,
          contains(
            'Database backup created before removeActionItemSuggestions',
          ),
        );
        expect(progress, isNotEmpty);
      });

      test('rethrows when backup fails and leaves entries untouched', () async {
        final now = DateTime(2024, 11);
        final entries = [
          _buildAiResponseEntry(
            id: 'ai-backup-fail',
            timestamp: now,
          ),
        ];
        await _insertEntries(journalDb, entries);

        final journalFile = await getDatabaseFile(journalDbFileName);
        if (journalFile.existsSync()) {
          await journalFile.delete();
        }

        await expectLater(
          maintenance.removeActionItemSuggestions(
            triggeredAtAppStart: false,
          ),
          throwsA(isA<FileSystemException>()),
        );

        verifyNever(
          () => persistenceLogic.updateDbEntity(any<JournalEntity>()),
        );
      });

      test('marks deprecated entries as deleted and logs summary', () async {
        await _ensureJournalDbFile();

        final base = DateTime(2024, 12);
        final deprecatedEntries = [
          _buildAiResponseEntry(
            id: 'deprecated-1',
            timestamp: base,
          ),
          _buildAiResponseEntry(
            id: 'deprecated-2',
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        ];
        final otherEntries = [
          _buildAiResponseEntry(
            id: 'other-type',
            timestamp: base.add(const Duration(minutes: 2)),
            type: AiResponseType.taskSummary,
          ),
          _buildTaskEntry(
            id: 'task-entry',
            timestamp: base.add(const Duration(minutes: 3)),
          ),
        ];
        await _insertEntries(
          journalDb,
          [
            ...deprecatedEntries,
            ...otherEntries,
          ],
        );

        final updatedIds = <String>[];
        when(() => persistenceLogic.updateDbEntity(any<JournalEntity>()))
            .thenAnswer((invocation) async {
          final entity = invocation.positionalArguments.first as JournalEntity;
          updatedIds.add(entity.meta.id);
          return true;
        });

        final progress = <double>[];
        await maintenance.removeActionItemSuggestions(
          triggeredAtAppStart: false,
          onProgress: progress.add,
        );

        expect(updatedIds, containsAll(['deprecated-1', 'deprecated-2']));
        expect(updatedIds, hasLength(2));

        expect(
          loggedEvents,
          contains(
            'Removed 2 actionItemSuggestions entries out of 4 total entries',
          ),
        );
        expect(progress, isNotEmpty);
        expect(progress.last, closeTo(1.0, 1e-6));
      });
    });
  });
}
