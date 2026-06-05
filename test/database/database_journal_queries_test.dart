// ignore_for_file: avoid_redundant_argument_values
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

/// Forces the bulk fetch inside the `journalEntityById` coalescer to fail so
/// the wave's error path (`completer.completeError`) is exercised.
class _EntitiesByIdsFetchThrowsJournalDb extends JournalDb {
  _EntitiesByIdsFetchThrowsJournalDb() : super(inMemoryDatabase: true);

  @override
  Future<List<JournalDbEntity>> runEntitiesByIdsFetch(Set<String> ids) async {
    throw StateError('bulk fetch failed for $ids');
  }
}

class _DetectConflictThrowsJournalDb extends JournalDb {
  _DetectConflictThrowsJournalDb()
    : shouldThrowOnDetectConflict = false,
      super(inMemoryDatabase: true);

  bool shouldThrowOnDetectConflict;

  @override
  Future<VclockStatus> detectConflict(
    JournalEntity existing,
    JournalEntity updated,
  ) {
    if (shouldThrowOnDetectConflict) {
      throw StateError('detectConflict failed');
    }
    return super.detectConflict(existing, updated);
  }
}

Future<List<JournalEntity>> fetchJournalEntities(
  JournalDb db, {
  required List<String> types,
  required List<bool> starredStatuses,
  required List<bool> privateStatuses,
  required List<int> flaggedStatuses,
  Set<String>? categoryIds,
  List<String>? ids,
}) {
  return db.getJournalEntities(
    types: types,
    starredStatuses: starredStatuses,
    privateStatuses: privateStatuses,
    flaggedStatuses: flaggedStatuses,
    ids: ids,
    categoryIds: categoryIds,
  );
}

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb journal queries - ', () {
    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      await db?.close();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    group('Edge cases -', () {
      test(
        'journalEntityById returns new data after an initial cache miss',
        () async {
          final entry = buildJournalEntry(
            id: 'cache-miss-then-insert',
            timestamp: DateTime(2024, 4, 1, 10),
            text: 'Seeded after miss',
          );

          expect(await db!.journalEntityById(entry.meta.id), isNull);

          await db!.upsertJournalDbEntity(toDbEntity(entry));

          final retrieved = await db!.journalEntityById(entry.meta.id);
          expect(retrieved?.meta.id, entry.meta.id);
          expect(retrieved?.entryText?.plainText, 'Seeded after miss');
        },
      );

      test(
        'journalEntityById propagates a failure in the coalesced bulk fetch',
        () async {
          final throwingDb = _EntitiesByIdsFetchThrowsJournalDb();
          addTearDown(throwingDb.close);
          await initConfigFlags(throwingDb, inMemoryDatabase: true);

          // Issue two callers concurrently (without awaiting between them) so
          // they join the SAME coalescing wave; when the underlying bulk fetch
          // throws, the wave completes with the error and every joined caller
          // surfaces it.
          final a = throwingDb.journalEntityById('any-id');
          final b = throwingDb.journalEntityById('other-id');
          await expectLater(
            a,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('bulk fetch failed'),
              ),
            ),
          );
          await expectLater(b, throwsA(isA<StateError>()));

          // A third caller in a fresh wave still fails the same way, proving
          // the error path is reached per wave rather than a one-off.
          await expectLater(
            throwingDb.journalEntityById('third-id'),
            throwsA(isA<StateError>()),
          );
        },
      );

      test('handles null vector clock on incoming entity', () async {
        const existingClock = VectorClock(<String, int>{'device1': 1});
        final existing = createJournalEntryWithVclock(existingClock);
        await db!.updateJournalEntity(existing);

        final update = existing.copyWith(
          entryText: const EntryText(plainText: 'null vector clock update'),
          meta: existing.meta.copyWith(vectorClock: null),
        );

        final result = await db!.updateJournalEntity(update);

        expect(result.applied, isTrue);
        final stored = await db!.journalEntityById(existing.meta.id);
        expect(stored, isNotNull);
        expect(stored?.entryText?.plainText, 'null vector clock update');
        expect(stored?.meta.vectorClock, isNull);
      });

      test('returns skipReason when detectConflict throws', () async {
        final throwingDb = _DetectConflictThrowsJournalDb();
        await initConfigFlags(throwingDb, inMemoryDatabase: true);

        try {
          const existingClock = VectorClock(<String, int>{'device1': 1});
          const incomingClock = VectorClock(<String, int>{'device1': 2});
          final existing = createJournalEntryWithVclock(existingClock);
          await throwingDb.updateJournalEntity(existing);

          throwingDb.shouldThrowOnDetectConflict = true;
          final incoming = createJournalEntryWithVclock(
            incomingClock,
            id: existing.meta.id,
          );

          clearInteractions(mockLoggingService);
          final result = await throwingDb.updateJournalEntity(incoming);

          expect(result.applied, isFalse);
          expect(result.skipReason, JournalUpdateSkipReason.conflict);
          verify(
            () => mockLoggingService.error(
              LogDomain.database,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'detectConflict',
            ),
          ).called(1);
        } finally {
          await throwingDb.close();
        }
      });
    });

    group('Journal queries -', () {
      test('getJournalEntities filters by types', () async {
        final base = DateTime(2024);
        final textEntry = buildJournalEntry(
          id: 'journal-type-text',
          timestamp: base,
          text: 'Entry text',
        );
        final taskTimestamp = base.add(const Duration(minutes: 1));
        final taskEntry = buildTaskEntry(
          id: 'journal-type-task',
          timestamp: taskTimestamp,
          status: TaskStatus.open(
            id: 'type-task-status',
            createdAt: taskTimestamp,
            utcOffset: taskTimestamp.timeZoneOffset.inMinutes,
          ),
        );

        await db!.upsertJournalDbEntity(toDbEntity(textEntry));
        await db!.upsertJournalDbEntity(toDbEntity(taskEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['Task'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
        );

        expect(results.map((e) => e.meta.id), [taskEntry.meta.id]);
      });

      test('getJournalEntities filters by starred status', () async {
        final base = DateTime(2024, 2);
        final starredEntry = buildJournalEntry(
          id: 'starred',
          timestamp: base,
          text: 'starred',
          starred: true,
        );
        final regularEntry = buildJournalEntry(
          id: 'not-starred',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'not starred',
        );

        await db!.upsertJournalDbEntity(toDbEntity(starredEntry));
        await db!.upsertJournalDbEntity(toDbEntity(regularEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
        );

        expect(results.map((e) => e.meta.id), [starredEntry.meta.id]);
      });

      test('getJournalEntities filters by private status', () async {
        final base = DateTime(2024, 3);
        final privateEntry = buildJournalEntry(
          id: 'private',
          timestamp: base,
          text: 'private',
          privateFlag: true,
        );
        final publicEntry = buildJournalEntry(
          id: 'public',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'public',
        );

        await db!.upsertJournalDbEntity(toDbEntity(privateEntry));
        await db!.upsertJournalDbEntity(toDbEntity(publicEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
        );

        expect(results.map((e) => e.meta.id), [privateEntry.meta.id]);
      });

      test('getJournalEntities filters by flag', () async {
        final base = DateTime(2024, 4);
        final flaggedEntry = buildJournalEntry(
          id: 'flagged',
          timestamp: base,
          text: 'flagged',
          flag: EntryFlag.followUpNeeded,
        );
        final normalEntry = buildJournalEntry(
          id: 'normal',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'normal',
        );

        await db!.upsertJournalDbEntity(toDbEntity(flaggedEntry));
        await db!.upsertJournalDbEntity(toDbEntity(normalEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [EntryFlag.followUpNeeded.index],
        );

        expect(results.map((e) => e.meta.id), [flaggedEntry.meta.id]);
      });

      test('getJournalEntities filters by category ids', () async {
        final base = DateTime(2024, 5);
        final categoryEntry = buildJournalEntry(
          id: 'cat-entry',
          timestamp: base,
          text: 'cat-entry',
          categoryId: 'category-1',
        );
        final otherEntry = buildJournalEntry(
          id: 'other',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'other',
          categoryId: 'category-2',
        );

        await db!.upsertJournalDbEntity(toDbEntity(categoryEntry));
        await db!.upsertJournalDbEntity(toDbEntity(otherEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
          categoryIds: {'category-1'},
        );

        expect(results.map((e) => e.meta.id), [categoryEntry.meta.id]);
      });

      test('getJournalEntities filters by explicit ids', () async {
        final base = DateTime(2024, 6);
        final entryA = buildJournalEntry(
          id: 'id-A',
          timestamp: base,
          text: 'A',
        );
        final entryB = buildJournalEntry(
          id: 'id-B',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'B',
        );

        await db!.upsertJournalDbEntity(toDbEntity(entryA));
        await db!.upsertJournalDbEntity(toDbEntity(entryB));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
          ids: const ['id-B'],
        );

        expect(results.map((e) => e.meta.id), [entryB.meta.id]);
      });
    });

    group('Journal browse queries -', () {
      test(
        'journal browse queries use the browse-oriented journal index',
        () async {
          final plan = await db!.customSelect(
            '''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal
          WHERE type = 'JournalEntry'
          AND deleted = FALSE
          ORDER BY date_from DESC
          LIMIT 50 OFFSET 0
          ''',
          ).get();

          final details = plan
              .map((row) => row.read<String>('detail'))
              .join(' ');
          expect(details, contains('idx_journal_browse'));
        },
      );

      test(
        'getJournalEntities returns consistent results and reflects writes',
        () async {
          final base = DateTime(2024, 8, 6, 11);
          final firstEntry = buildJournalEntry(
            id: 'cached-journal-1',
            timestamp: base,
            text: 'First cached entry',
          );

          await db!.upsertJournalDbEntity(toDbEntity(firstEntry));

          final firstResults = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false, true],
            flaggedStatuses: const [0, 1],
          );
          final secondResults = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false, true],
            flaggedStatuses: const [0, 1],
          );

          expect(
            firstResults.map((e) => e.meta.id),
            secondResults.map((e) => e.meta.id),
          );

          final secondEntry = buildJournalEntry(
            id: 'cached-journal-2',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Second cached entry',
          );
          await db!.upsertJournalDbEntity(toDbEntity(secondEntry));

          final refreshedResults = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false, true],
            flaggedStatuses: const [0, 1],
          );

          expect(
            refreshedResults
                .where((entry) => entry.meta.id.startsWith('cached-journal-'))
                .map((entry) => entry.meta.id),
            ['cached-journal-2', 'cached-journal-1'],
          );
        },
      );
    });

    group('getCategoryIdsForEntryIds -', () {
      test(
        'returns empty map for empty input without hitting the db',
        () async {
          expect(
            await db!.getCategoryIdsForEntryIds(const <String>[]),
            isEmpty,
          );
        },
      );

      test(
        'returns denormalized category per id and maps empty column to null',
        () async {
          final base = DateTime(2026, 3, 1);
          final withCategory = buildJournalEntry(
            id: 'cat-id-entry-1',
            timestamp: base,
            text: 'has category',
            categoryId: 'cat-alpha',
          );
          final withoutCategory = buildJournalEntry(
            id: 'cat-id-entry-2',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'no category',
          );

          await db!.upsertJournalDbEntity(toDbEntity(withCategory));
          await db!.upsertJournalDbEntity(toDbEntity(withoutCategory));

          final result = await db!.getCategoryIdsForEntryIds([
            withCategory.meta.id,
            withoutCategory.meta.id,
            // Duplicate id is deduplicated via toSet() before the query.
            withCategory.meta.id,
            // Missing ids are simply absent from the returned map.
            'cat-id-missing',
          ]);

          expect(result, hasLength(2));
          expect(result[withCategory.meta.id], 'cat-alpha');
          // Empty column value is normalized to null so callers can treat
          // "no category" and "not present" uniformly.
          expect(result.containsKey(withoutCategory.meta.id), isTrue);
          expect(result[withoutCategory.meta.id], isNull);
          expect(result.containsKey('cat-id-missing'), isFalse);
        },
      );

      test(
        'filtered path drops private entries when privateFlag is off',
        () async {
          final base = DateTime(2026, 3, 2);
          final publicEntry = buildJournalEntry(
            id: 'cat-id-public',
            timestamp: base,
            text: 'public',
            categoryId: 'cat-public',
          );
          final privateEntry = buildJournalEntry(
            id: 'cat-id-private',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'private',
            privateFlag: true,
            categoryId: 'cat-private',
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicEntry));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));

          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          final filtered = await db!.getCategoryIdsForEntryIds([
            publicEntry.meta.id,
            privateEntry.meta.id,
          ]);
          expect(filtered, {publicEntry.meta.id: 'cat-public'});

          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: true,
            ),
          );

          final all = await db!.getCategoryIdsForEntryIds([
            publicEntry.meta.id,
            privateEntry.meta.id,
          ]);
          expect(all, {
            publicEntry.meta.id: 'cat-public',
            privateEntry.meta.id: 'cat-private',
          });
        },
      );
    });

    group('Aggregate queries -', () {
      test('getJournalCount returns total journal entries', () async {
        final entryA = buildJournalEntry(
          id: 'journal-count-a',
          timestamp: DateTime(2024, 11),
          text: 'Entry A',
        );
        final entryB = buildJournalEntry(
          id: 'journal-count-b',
          timestamp: DateTime(2024, 11, 2),
          text: 'Entry B',
        );

        await db!.upsertJournalDbEntity(toDbEntity(entryA));
        await db!.upsertJournalDbEntity(toDbEntity(entryB));

        expect(await db!.getJournalCount(), 2);
      });
    });

    group('Calendar entries -', () {
      test('sortedCalendarEntries filters and sorts correctly', () async {
        final janEarly = buildTextEntry(
          id: 'jan-05',
          timestamp: DateTime(2024, 1, 5, 8),
          text: 'Entry Jan 05',
        );
        final janLate = buildWorkoutEntry(
          id: 'jan-20-workout',
          start: DateTime(2024, 1, 20, 7),
          end: DateTime(2024, 1, 20, 8),
        );
        final febOutside = buildTextEntry(
          id: 'feb-01',
          timestamp: DateTime(2024, 2, 1, 9),
          text: 'Outside range',
        );

        await db!.updateJournalEntity(janEarly);
        await db!.updateJournalEntity(janLate);
        await db!.updateJournalEntity(febOutside);

        final rangeStart = DateTime(2024, 1, 1);
        final rangeEnd = DateTime(2024, 1, 31, 23, 59);
        final results = await db!.sortedCalendarEntries(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(
          results.map((e) => e.meta.id),
          equals(['jan-20-workout', 'jan-05']),
        );
      });
    });

    group('Vector clock streaming for sequence log population -', () {
      test(
        'streamEntriesWithVectorClock returns entries with vector clocks',
        () async {
          // Create entries with vector clocks
          const vc1 = VectorClock({'host1': 1, 'host2': 2});
          const vc2 = VectorClock({'host1': 3});
          final entry1 = createJournalEntryWithVclock(vc1);
          final entry2 = createJournalEntryWithVclock(vc2);

          await db!.updateJournalEntity(entry1);
          await db!.updateJournalEntity(entry2);

          // Stream and collect all batches
          final results = await db!
              .streamEntriesWithVectorClock()
              .expand((batch) => batch)
              .toList();

          // Verify we got the entries with their vector clocks
          expect(results.length, greaterThanOrEqualTo(2));

          final result1 = results.firstWhere((r) => r.id == entry1.meta.id);
          expect(result1.vectorClock, {'host1': 1, 'host2': 2});

          final result2 = results.firstWhere((r) => r.id == entry2.meta.id);
          expect(result2.vectorClock, {'host1': 3});
        },
      );

      test(
        'streamEntriesWithVectorClock handles entries without vector clock',
        () async {
          final entryNoVc = createJournalEntry('no vector clock');
          await db!.updateJournalEntity(entryNoVc);

          final results = await db!
              .streamEntriesWithVectorClock()
              .expand((batch) => batch)
              .toList();

          final found = results.firstWhere((r) => r.id == entryNoVc.meta.id);
          expect(found.vectorClock, isNull);
        },
      );

      test(
        'streamEntryLinksWithVectorClock returns links with vector clocks',
        () async {
          const vc = VectorClock({'host1': 5});
          final link = EntryLink.basic(
            id: 'link-with-vc',
            fromId: 'from-entry',
            toId: 'to-entry',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: vc,
          );

          await db!.upsertEntryLink(link);

          final results = await db!
              .streamEntryLinksWithVectorClock()
              .expand((batch) => batch)
              .toList();

          expect(results, isNotEmpty);
          final found = results.firstWhere((r) => r.id == 'link-with-vc');
          expect(found.vectorClock, {'host1': 5});
        },
      );

      test(
        'streamEntryLinksWithVectorClock handles links without vector clock',
        () async {
          final link = EntryLink.basic(
            id: 'link-no-vc',
            fromId: 'from-entry',
            toId: 'to-entry',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: null,
          );

          await db!.upsertEntryLink(link);

          final results = await db!
              .streamEntryLinksWithVectorClock()
              .expand((batch) => batch)
              .toList();

          final found = results.firstWhere((r) => r.id == 'link-no-vc');
          expect(found.vectorClock, isNull);
        },
      );

      test('countAllJournalEntries returns correct count', () async {
        final initialCount = await db!.countAllJournalEntries();

        await db!.updateJournalEntity(createJournalEntry('entry 1'));
        await db!.updateJournalEntity(createJournalEntry('entry 2'));

        final newCount = await db!.countAllJournalEntries();
        expect(newCount, initialCount + 2);
      });

      test('countAllEntryLinks returns correct count', () async {
        final initialCount = await db!.countAllEntryLinks();

        await db!.upsertEntryLink(
          EntryLink.basic(
            id: 'count-link-1',
            fromId: 'from',
            toId: 'to1',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: null,
          ),
        );
        await db!.upsertEntryLink(
          EntryLink.basic(
            id: 'count-link-2',
            fromId: 'from',
            toId: 'to2',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: null,
          ),
        );

        final newCount = await db!.countAllEntryLinks();
        expect(newCount, initialCount + 2);
      });

      test('streamEntriesWithVectorClock respects batch size', () async {
        // Create several entries
        for (var i = 0; i < 5; i++) {
          await db!.updateJournalEntity(createJournalEntry('batch test $i'));
        }

        // Stream with small batch size
        var batchCount = 0;
        await for (final batch in db!.streamEntriesWithVectorClock(
          batchSize: 2,
        )) {
          batchCount++;
          expect(batch.length, lessThanOrEqualTo(2));
        }

        // Should have multiple batches
        expect(batchCount, greaterThanOrEqualTo(1));
      });

      test(
        'streamEntriesWithVectorClock handles malformed serialized data',
        () async {
          // Create a valid entry first
          final validEntry = createJournalEntryWithVclock(
            const VectorClock({'host': 42}),
            id: 'valid-entry',
          );
          await db!.updateJournalEntity(validEntry);

          // Insert a malformed entry via raw SQL with non-numeric vectorClock
          // This bypasses normal serialization to test DB layer parsing
          final malformedSerialized = jsonEncode({
            'meta': {
              'id': 'malformed-entry',
              'createdAt': '2024-01-01T00:00:00.000',
              'updatedAt': '2024-01-01T00:00:00.000',
              'dateFrom': '2024-01-01T00:00:00.000',
              'dateTo': '2024-01-01T00:00:00.000',
              'starred': false,
              'private': false,
              'vectorClock': {'host': 'not-a-number'},
            },
            'entryText': {'plainText': 'malformed entry'},
          });

          final timestamp = DateTime(2024, 1, 1).millisecondsSinceEpoch;
          await db!.customStatement(
            'INSERT INTO journal '
            '(id, created_at, updated_at, date_from, date_to, deleted, starred, '
            'private, task, flag, type, serialized, schema_version, category) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'malformed-entry',
              timestamp,
              timestamp,
              timestamp,
              timestamp,
              0, // deleted
              0, // starred
              0, // private
              0, // task
              0, // flag
              'JournalEntry',
              malformedSerialized,
              0, // schema_version
              '', // category
            ],
          );

          // The streaming method should handle entries gracefully
          // even if vector clock extraction fails (returns null)
          final results = await db!
              .streamEntriesWithVectorClock()
              .expand((batch) => batch)
              .toList();

          expect(results.length, greaterThanOrEqualTo(2));

          // Valid entry should have its vectorClock intact
          final validFound = results.firstWhere((r) => r.id == 'valid-entry');
          expect(validFound.vectorClock, {'host': 42});

          // Malformed entry should have vectorClock == null (graceful handling)
          final malformedFound = results.firstWhere(
            (r) => r.id == 'malformed-entry',
          );
          expect(
            malformedFound.vectorClock,
            isNull,
            reason: 'Non-numeric vectorClock values should result in null',
          );
        },
      );

      test(
        'streamEntryLinksWithVectorClock handles links with non-numeric vectorClock values gracefully',
        () async {
          // Create a valid link first
          final validLink = EntryLink.basic(
            id: 'link-valid',
            fromId: 'from-valid',
            toId: 'to-valid',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: const VectorClock({'host': 1}),
          );
          await db!.upsertEntryLink(validLink);

          // Insert a malformed link via raw SQL with non-numeric vectorClock values
          // This bypasses normal serialization to test DB layer parsing
          final malformedSerialized = jsonEncode({
            'id': 'link-malformed',
            'fromId': 'from-malformed',
            'toId': 'to-malformed',
            'linkType': 'basic',
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
            'vectorClock': {'host': 'not-a-number', 'other': 'also-invalid'},
          });

          // Use Unix timestamp in milliseconds for created_at/updated_at
          final timestamp = DateTime(2024, 1, 1).millisecondsSinceEpoch;
          await db!.customStatement(
            'INSERT INTO linked_entries '
            '(id, from_id, to_id, type, serialized, hidden, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'link-malformed',
              'from-malformed',
              'to-malformed',
              'basic',
              malformedSerialized,
              0,
              timestamp,
              timestamp,
            ],
          );

          // Streaming should NOT throw and should handle both entries
          final results = await db!
              .streamEntryLinksWithVectorClock()
              .expand((batch) => batch)
              .toList();

          expect(results.length, greaterThanOrEqualTo(2));

          // Valid link should have its vectorClock intact
          final validFound = results.firstWhere((r) => r.id == 'link-valid');
          expect(validFound.vectorClock, {'host': 1});

          // Malformed link should have vectorClock == null (graceful handling)
          final malformedFound = results.firstWhere(
            (r) => r.id == 'link-malformed',
          );
          expect(
            malformedFound.vectorClock,
            isNull,
            reason: 'Non-numeric vectorClock values should result in null',
          );
        },
      );
    });

    group('getJournalEntitiesForIds sorted -', () {
      test(
        'sorts by dateFrom desc then id asc when dates are equal',
        () async {
          final base = DateTime(2024, 11, 11, 9);
          // Both entries share the same dateFrom but differ in id lexicography.
          final entryA = buildJournalEntry(
            id: 'sort-id-a',
            timestamp: base,
            text: 'Entry A',
          );
          final entryB = buildJournalEntry(
            id: 'sort-id-b',
            timestamp: base,
            text: 'Entry B',
          );
          await db!.upsertJournalDbEntity(toDbEntity(entryA));
          await db!.upsertJournalDbEntity(toDbEntity(entryB));

          final results = await db!.getJournalEntitiesForIds({
            'sort-id-a',
            'sort-id-b',
          });
          // Same date → sorted by id ascending.
          final ids = results.map((e) => e.meta.id).toList();
          expect(ids.indexOf('sort-id-a'), lessThan(ids.indexOf('sort-id-b')));
        },
      );
    });

    group('getJournalEntityIdsSortedByDateFromDesc -', () {
      test('returns empty list for empty input', () async {
        final result = await db!.getJournalEntityIdsSortedByDateFromDesc({});
        expect(result, isEmpty);
      });
    });

    group('getCountImportFlagEntries -', () {
      test('returns count of import-flagged entries', () async {
        final base = DateTime(2024, 11, 12, 9);
        // EntryFlag.import has index 1, which is what the query filters on.
        final flaggedEntry = buildJournalEntry(
          id: 'import-flag-entry',
          timestamp: base,
          text: 'Flagged',
          flag: EntryFlag.import,
        );
        await db!.upsertJournalDbEntity(toDbEntity(flaggedEntry));

        final count = await db!.getCountImportFlagEntries();
        expect(count, 1);
      });

      test('returns zero when no import-flagged entries exist', () async {
        expect(await db!.getCountImportFlagEntries(), 0);
      });
    });

    group('_extractEntryLinkVectorClock FormatException path -', () {
      test(
        'handles malformed JSON in streamEntryLinksWithVectorClock gracefully',
        () async {
          final timestamp = DateTime(2024, 11, 13).millisecondsSinceEpoch;
          // Insert a linked_entries row whose serialized value is not valid JSON.
          await db!.customStatement(
            'INSERT INTO linked_entries '
            '(id, from_id, to_id, type, serialized, hidden, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'link-bad-json',
              'from-bad-json',
              'to-bad-json',
              'basic',
              'NOT_VALID_JSON{{{',
              0,
              timestamp,
              timestamp,
            ],
          );

          final results = await db!
              .streamEntryLinksWithVectorClock()
              .expand((batch) => batch)
              .toList();

          final badEntry = results.firstWhere(
            (r) => r.id == 'link-bad-json',
            orElse: () => (id: 'link-bad-json', vectorClock: null),
          );
          expect(
            badEntry.vectorClock,
            isNull,
            reason: 'Malformed JSON should result in null vectorClock',
          );
        },
      );
    });

    group('getJournalEntities with categoryIds filter -', () {
      test(
        'filteredJournalByCategoriesFast paths (all-private, with filter)',
        () async {
          final base = DateTime(2024, 11, 14, 9);
          final catEntry = buildJournalEntry(
            id: 'cat-fast-entry',
            timestamp: base,
            text: 'Category entry',
            categoryId: 'filter-cat-fast',
          );
          final otherEntry = buildJournalEntry(
            id: 'cat-fast-other',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Other entry',
            categoryId: 'other-cat-fast',
          );
          await db!.upsertJournalDbEntity(toDbEntity(catEntry));
          await db!.upsertJournalDbEntity(toDbEntity(otherEntry));

          // All-private path (privateFlag true is the DB default in this test).
          final allPrivate = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [true, false],
            // [0, 1] is the matches-all-flag-states sentinel the dispatch in
            // _selectJournalEntities checks for (and what production callers
            // pass) — required to actually reach the fast paths under test.
            flaggedStatuses: [
              EntryFlag.none.index,
              EntryFlag.import.index,
            ],
            categoryIds: {'filter-cat-fast'},
          );
          expect(
            allPrivate.map((e) => e.meta.id),
            contains('cat-fast-entry'),
          );
          expect(
            allPrivate.map((e) => e.meta.id),
            isNot(contains('cat-fast-other')),
          );

          // Private-filtered path.
          final filtered = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false],
            // [0, 1] is the matches-all-flag-states sentinel the dispatch in
            // _selectJournalEntities checks for (and what production callers
            // pass) — required to actually reach the fast paths under test.
            flaggedStatuses: [
              EntryFlag.none.index,
              EntryFlag.import.index,
            ],
            categoryIds: {'filter-cat-fast'},
          );
          expect(
            filtered.map((e) => e.meta.id),
            contains('cat-fast-entry'),
          );
        },
      );
    });

    group('Private-filtered query branches -', () {
      // Helper: turn the `private` config flag off so query methods take the
      // `filtered:` SQL path instead of the all-private fast path.
      Future<void> disablePrivate() => db!.upsertConfigFlag(
        const ConfigFlag(
          name: privateFlag,
          description: 'Show private entries?',
          status: false,
        ),
      );

      test(
        'getJournalEntitiesForIds filtered path drops private entries and '
        'sorts by date desc',
        () async {
          final base = DateTime(2024, 10);
          final publicNewer = buildJournalEntry(
            id: 'gjefi-public-newer',
            timestamp: base.add(const Duration(days: 1)),
            text: 'public newer',
          );
          final publicOlder = buildJournalEntry(
            id: 'gjefi-public-older',
            timestamp: base,
            text: 'public older',
          );
          final privateEntry = buildJournalEntry(
            id: 'gjefi-private',
            timestamp: base.add(const Duration(days: 2)),
            text: 'private',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicNewer));
          await db!.upsertJournalDbEntity(toDbEntity(publicOlder));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));

          await disablePrivate();

          final ids = {
            'gjefi-public-newer',
            'gjefi-public-older',
            'gjefi-private',
          };
          final result = await db!.getJournalEntitiesForIds(ids);
          // Private excluded; remaining sorted by dateFrom desc.
          expect(
            result.map((e) => e.meta.id),
            ['gjefi-public-newer', 'gjefi-public-older'],
          );

          // Unordered variant returns the same (public-only) set.
          final unordered = await db!.getJournalEntitiesForIdsUnordered(ids);
          expect(
            unordered.map((e) => e.meta.id).toSet(),
            {'gjefi-public-newer', 'gjefi-public-older'},
          );
        },
      );

      test(
        'getJournalEntityIdsSortedByDateFromDesc filtered path drops private '
        'entries and orders by date desc',
        () async {
          final base = DateTime(2024, 10, 5);
          final newer = buildJournalEntry(
            id: 'gjeid-newer',
            timestamp: base.add(const Duration(days: 2)),
            text: 'newer',
          );
          final older = buildJournalEntry(
            id: 'gjeid-older',
            timestamp: base,
            text: 'older',
          );
          final privateEntry = buildJournalEntry(
            id: 'gjeid-private',
            timestamp: base.add(const Duration(days: 1)),
            text: 'private',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(newer));
          await db!.upsertJournalDbEntity(toDbEntity(older));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));

          await disablePrivate();

          final result = await db!.getJournalEntityIdsSortedByDateFromDesc({
            'gjeid-newer',
            'gjeid-older',
            'gjeid-private',
          });
          expect(result, ['gjeid-newer', 'gjeid-older']);
        },
      );

      test(
        'getJournalEntities filtered fast category path drops private entries',
        () async {
          final base = DateTime(2024, 10, 9);
          final publicEntry = buildJournalEntry(
            id: 'gje-cat-public',
            timestamp: base,
            text: 'public',
            categoryId: 'gje-cat',
          );
          final privateEntry = buildJournalEntry(
            id: 'gje-cat-private',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'private',
            categoryId: 'gje-cat',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicEntry));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));

          // privateStatuses=[false] (not all-private) + all-starred + all-flag
          // + category set -> filtered category fast path
          // (filteredJournalByCategoriesFast).
          final result = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false],
            // [0, 1] is the matches-all-flag-states sentinel the dispatch in
            // _selectJournalEntities checks for (and what production callers
            // pass) — required to actually reach the fast paths under test.
            flaggedStatuses: [
              EntryFlag.none.index,
              EntryFlag.import.index,
            ],
            categoryIds: {'gje-cat'},
          );
          expect(result.map((e) => e.meta.id), ['gje-cat-public']);
        },
      );

      test(
        'getJournalEntities filtered fast path (no category) drops private '
        'entries',
        () async {
          final base = DateTime(2024, 10, 11);
          final publicEntry = buildJournalEntry(
            id: 'gje-fast-public',
            timestamp: base,
            text: 'public',
          );
          final privateEntry = buildJournalEntry(
            id: 'gje-fast-private',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'private',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicEntry));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));

          // privateStatuses=[false] (not all-private) + all-starred + all-flag
          // + no category, no ids -> filteredJournalFast.
          final result = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false],
            // [0, 1] is the matches-all-flag-states sentinel the dispatch in
            // _selectJournalEntities checks for (and what production callers
            // pass) — required to actually reach the fast paths under test.
            flaggedStatuses: [
              EntryFlag.none.index,
              EntryFlag.import.index,
            ],
          );
          final ids = result.map((e) => e.meta.id).toSet();
          expect(ids, contains('gje-fast-public'));
          expect(ids, isNot(contains('gje-fast-private')));
        },
      );
    });

    group('calendar entries coalescing widening -', () {
      test(
        'second overlapping caller with earlier rangeStart widens the wave',
        () async {
          final inWindow = buildJournalEntry(
            id: 'cal-widen-in',
            timestamp: DateTime(2024, 5, 10, 12),
            text: 'in window',
          );
          await db!.upsertJournalDbEntity(toDbEntity(inWindow));

          // Two concurrent callers in the same microtask wave: the second
          // requests an EARLIER rangeStart, widening the shared wave.
          final firstFuture = db!.sortedCalendarEntries(
            rangeStart: DateTime(2024, 5, 10),
            rangeEnd: DateTime(2024, 5, 11),
          );
          final secondFuture = db!.sortedCalendarEntries(
            rangeStart: DateTime(2024, 5, 9),
            rangeEnd: DateTime(2024, 5, 12),
          );

          final results = await Future.wait([firstFuture, secondFuture]);
          // Both callers resolve from the single widened fetch and each sees
          // the entry inside its own window.
          expect(
            results[0].map((e) => e.meta.id),
            contains('cal-widen-in'),
          );
          expect(
            results[1].map((e) => e.meta.id),
            contains('cal-widen-in'),
          );
        },
      );
    });

    group('journalEntityMapForIds chunking -', () {
      test(
        'returns every entry when the id set spans multiple 500-id chunks',
        () async {
          final ids = <String>[];
          for (var i = 0; i < 501; i++) {
            final id = 'chunk-$i';
            ids.add(id);
            await db!.upsertJournalDbEntity(
              toDbEntity(
                buildJournalEntry(
                  id: id,
                  timestamp: DateTime(2024, 5).add(Duration(minutes: i)),
                  text: 'entry $i',
                ),
              ),
            );
          }

          // Duplicate ids must not produce duplicate work or wrong counts —
          // the implementation dedupes before chunking.
          final map = await db!.journalEntityMapForIds([...ids, ...ids]);

          expect(map, hasLength(501));
          expect(map.keys.toSet(), ids.toSet());
          // The row past the 500-id boundary is intact, proving the second
          // chunk was fetched and merged.
          expect(map['chunk-500']!.entryText?.plainText, 'entry 500');
        },
      );
    });
  });

  group('vector clock extraction (pure parsers) -', () {
    glados.Glados(glados.any.vectorClockMap).test(
      'journal-entity round-trip: meta.vectorClock survives extraction',
      (vclock) {
        final serialized = jsonEncode({
          'meta': {'vectorClock': vclock},
        });
        expect(extractVectorClockForTesting(serialized), vclock);
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.vectorClockMap).test(
      'entry-link round-trip: vectorClock survives extraction',
      (vclock) {
        final serialized = jsonEncode({'vectorClock': vclock});
        expect(extractEntryLinkVectorClockForTesting(serialized), vclock);
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.nonVectorClockJson).test(
      'malformed or non-object JSON never throws and yields null for both '
      'extractors',
      (garbage) {
        expect(extractVectorClockForTesting(garbage), isNull);
        expect(extractEntryLinkVectorClockForTesting(garbage), isNull);
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.vectorClockMap).test(
      'non-numeric clock values yield null for both extractors',
      (vclock) {
        final tainted = <String, dynamic>{...vclock, 'bad-host': 'NaN'};
        expect(
          extractVectorClockForTesting(
            jsonEncode({
              'meta': {'vectorClock': tainted},
            }),
          ),
          isNull,
        );
        expect(
          extractEntryLinkVectorClockForTesting(
            jsonEncode({'vectorClock': tainted}),
          ),
          isNull,
        );
      },
      tags: 'glados',
    );

    test('missing meta or vectorClock yields null', () {
      expect(extractVectorClockForTesting('{}'), isNull);
      expect(extractVectorClockForTesting('{"meta": {}}'), isNull);
      expect(extractVectorClockForTesting('{"meta": null}'), isNull);
      expect(extractEntryLinkVectorClockForTesting('{}'), isNull);
      expect(
        extractEntryLinkVectorClockForTesting('{"vectorClock": null}'),
        isNull,
      );
    });
  });
}

extension _AnyVectorClockJson on glados.Any {
  /// Arbitrary host-id → counter maps, the shape both extractors return.
  glados.Generator<Map<String, int>> get vectorClockMap =>
      glados.MapAnys(this).map(
        glados.StringAnys(this).nonEmptyLetterOrDigits,
        glados.IntAnys(this).intInRange(-1000000, 1000000),
      );

  /// Strings that either fail to parse as JSON at all or parse to a
  /// non-object top level (array, string, number). Both extractors must
  /// map every one of them to null without throwing.
  glados.Generator<String> get nonVectorClockJson =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 5),
        glados.StringAnys(this).letterOrDigits,
        (int shape, String s) => switch (shape) {
          0 => '{$s', // unbalanced object — never valid JSON
          1 => '[$s]', // array (or garbage) — wrong top-level shape
          2 => '"$s"', // JSON string — wrong top-level shape
          3 => s, // bare token: number or garbage
          _ => '$s}', // trailing garbage
        },
      );
}
