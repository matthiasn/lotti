import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
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
import 'package:lotti/features/sync/state/outbox_state_controller.dart'
    show OutboxStatus;
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import 'sync_db_test_utils.dart';
import 'test_utils.dart' show clearAllTables;

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
    registerFallbackValue(FakeMetadata());
  });

  group('Maintenance', () {
    late Directory tempDir;
    late JournalDb journalDb;
    late Fts5Db initialFts5;
    late Maintenance maintenance;
    late MockDomainLogger mockDomainLogger;
    late MockPersistenceLogic persistenceLogic;
    late MockEntitiesCacheService entitiesCacheService;
    late List<dynamic> loggedExceptions;
    late PathProviderPlatform originalPathProvider;
    late MockPathProviderPlatform mockPathProvider;

    // The journal DB's migration ladder runs once for the group; each test
    // re-registers the same instance and starts clean via clearAllTables. The
    // Fts5 DB stays per-test because the maintenance ops under test rebuild it.
    setUpAll(() async {
      journalDb = JournalDb(inMemoryDatabase: true);
    });

    setUp(() async {
      await getIt.reset();

      tempDir = Directory.systemTemp.createTempSync('maintenance_test_');
      getIt.registerSingleton<Directory>(tempDir);

      await clearAllTables(journalDb);
      getIt.registerSingleton<JournalDb>(journalDb);

      mockDomainLogger = MockDomainLogger();
      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      persistenceLogic = MockPersistenceLogic();
      getIt.registerSingleton<PersistenceLogic>(persistenceLogic);

      entitiesCacheService = MockEntitiesCacheService();
      when(() => entitiesCacheService.getDataTypeById(any())).thenReturn(null);
      getIt.registerSingleton<EntitiesCacheService>(entitiesCacheService);

      initialFts5 = Fts5Db(inMemoryDatabase: true);
      getIt.registerSingleton<Fts5Db>(initialFts5);

      mockPathProvider = MockPathProviderPlatform();
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

      loggedExceptions = [];
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
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
          message: any<String?>(named: 'message'),
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
      await getIt.reset();
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    tearDownAll(() async {
      await journalDb.close();
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
