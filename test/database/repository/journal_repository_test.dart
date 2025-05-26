import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/repository/journal_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  late JournalDb db;
  late IJournalRepository repository;

  setUp(() async {
    db = JournalDb(inMemoryDatabase: true);
    repository = JournalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('JournalRepository Tests', () {
    test('getById returns null for non-existent entry', () async {
      final result = await repository.getById('non-existent-id');
      expect(result, isNull);
    });

    test('upsert and getById work correctly', () async {
      final now = DateTime.now();
      final entry = JournalEntry(
        meta: Metadata(
          id: 'test-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          vectorClock: const VectorClock({'device1': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Upsert the entry
      final result = await repository.upsert(entry);
      expect(result, greaterThan(0));

      // Retrieve the entry
      final retrieved = await repository.getById('test-id');
      expect(retrieved, isNotNull);
      expect(retrieved!.meta.id, equals('test-id'));
      expect(retrieved.entryText.plainText, equals('Test entry'));
    });

    test('query returns entries matching criteria', () async {
      final now = DateTime.now();

      // Create test entries
      final entry1 = JournalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          starred: true,
          private: false,
          vectorClock: const VectorClock({'device1': 1}),
        ),
        entryText: const EntryText(plainText: 'Starred entry'),
      );

      final entry2 = JournalEntry(
        meta: Metadata(
          id: 'entry-2',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          starred: false,
          private: true,
          vectorClock: const VectorClock({'device1': 2}),
        ),
        entryText: const EntryText(plainText: 'Private entry'),
      );

      // Insert entries
      await repository.upsert(entry1);
      await repository.upsert(entry2);

      // Query for starred entries
      final starredEntries = await repository.query(
        types: ['JournalEntry'],
        starredStatuses: [true],
        privateStatuses: [true, false],
        flaggedStatuses: [0, 1, 2],
        limit: 10,
      );

      expect(starredEntries.length, equals(1));
      expect(starredEntries.first.meta.id, equals('entry-1'));

      // Query for private entries
      final privateEntries = await repository.query(
        types: ['JournalEntry'],
        starredStatuses: [true, false],
        privateStatuses: [true],
        flaggedStatuses: [0, 1, 2],
        limit: 10,
      );

      expect(privateEntries.length, equals(1));
      expect(privateEntries.first.meta.id, equals('entry-2'));
    });

    test('count returns correct number of entries', () async {
      final now = DateTime.now();

      // Initially should be 0
      expect(await repository.count(), equals(0));

      // Add an entry
      final entry = JournalEntry(
        meta: Metadata(
          id: 'count-test',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          vectorClock: const VectorClock({'device1': 1}),
        ),
        entryText: const EntryText(plainText: 'Count test'),
      );

      await repository.upsert(entry);
      expect(await repository.count(), equals(1));
    });

    test('watchById streams entity changes', () async {
      final now = DateTime.now();
      final entry = JournalEntry(
        meta: Metadata(
          id: 'watch-test',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          vectorClock: const VectorClock({'device1': 1}),
        ),
        entryText: const EntryText(plainText: 'Watch test'),
      );

      // Start watching before inserting
      final stream = repository.watchById('watch-test');

      // Insert the entry
      await repository.upsert(entry);

      // Verify the stream emits the entry
      final result = await stream.first;
      expect(result, isNotNull);
      expect(result!.meta.id, equals('watch-test'));
    });
  });
}
