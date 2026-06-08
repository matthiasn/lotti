import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';

import '../test_data/test_data.dart';
import 'coalescing_test_utils.dart';

/// Subclass of [JournalDb] whose `runCalendarEntriesFetch` throws so the
/// coalescer's error-propagation branch can be exercised deterministically.
class _FailingCalendarJournalDb extends JournalDb {
  _FailingCalendarJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  Object failure = StateError('not set');
  int attempts = 0;

  @override
  Future<List<JournalEntity>> runCalendarEntriesFetch({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    attempts += 1;
    return Future<List<JournalEntity>>.error(failure);
  }
}

/// Subclass of [JournalDb] that counts the date-range calendar query
/// emitted by `sortedCalenderEntriesInRange`. The coalescer flushes the
/// whole wave through that one statement, so the counter equals the
/// number of DB round-trips for calendar fetches.
class _CountingJournalDb extends JournalDb {
  _CountingJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  int calendarQueryCount = 0;

  @override
  drift.Selectable<drift.QueryRow> customSelect(
    String query, {
    List<drift.Variable<Object>> variables = const [],
    Set<drift.ResultSetImplementation<dynamic, dynamic>> readsFrom = const {},
  }) {
    if (query.contains("type IN ('JournalEntry', 'WorkoutEntry')") &&
        query.contains('date_from >= ?1 AND date_to <= ?2')) {
      calendarQueryCount += 1;
    }
    return super.customSelect(
      query,
      variables: variables,
      readsFrom: readsFrom,
    );
  }
}

JournalEntry _buildEntry({
  required String id,
  required DateTime dateFrom,
  required DateTime dateTo,
  String text = 'entry',
}) {
  return testTextEntry.copyWith(
    meta: testTextEntry.meta.copyWith(
      id: id,
      createdAt: dateFrom,
      updatedAt: dateFrom,
      dateFrom: dateFrom,
      dateTo: dateTo,
    ),
    entryText: EntryText(plainText: text),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingJournalDb db;
  late CoalescingDbBench<_CountingJournalDb> bench;

  setUp(() async {
    bench = await CoalescingDbBench.create(_CountingJournalDb.new);
    db = bench.db;
  });

  tearDown(() => bench.tearDown());

  Future<void> insertEntry(JournalEntry entry) async {
    await db.upsertJournalDbEntity(toDbEntity(entry));
  }

  group('calendar-entries microtask coalescing', () {
    test(
      'three concurrent sortedCalendarEntries calls share one DB query '
      'and each returns only its own date range',
      () async {
        final mon = _buildEntry(
          id: 'mon',
          dateFrom: DateTime(2026, 4, 13, 9),
          dateTo: DateTime(2026, 4, 13, 10),
        );
        final wed = _buildEntry(
          id: 'wed',
          dateFrom: DateTime(2026, 4, 15, 9),
          dateTo: DateTime(2026, 4, 15, 10),
        );
        final fri = _buildEntry(
          id: 'fri',
          dateFrom: DateTime(2026, 4, 17, 9),
          dateTo: DateTime(2026, 4, 17, 10),
        );
        await insertEntry(mon);
        await insertEntry(wed);
        await insertEntry(fri);
        db.calendarQueryCount = 0;

        final futures = [
          db.sortedCalendarEntries(
            rangeStart: DateTime(2026, 4, 13),
            rangeEnd: DateTime(2026, 4, 14),
          ),
          db.sortedCalendarEntries(
            rangeStart: DateTime(2026, 4, 15),
            rangeEnd: DateTime(2026, 4, 16),
          ),
          db.sortedCalendarEntries(
            rangeStart: DateTime(2026, 4, 17),
            rangeEnd: DateTime(2026, 4, 18),
          ),
        ];
        final results = await Future.wait(futures);

        expect(results[0].map((e) => e.meta.id), ['mon']);
        expect(results[1].map((e) => e.meta.id), ['wed']);
        expect(results[2].map((e) => e.meta.id), ['fri']);
        expect(db.calendarQueryCount, 1);
      },
    );

    test(
      'wave merges expanding ranges so a later joiner with a wider window '
      'still gets the entries the wave fetched',
      () async {
        final early = _buildEntry(
          id: 'early',
          dateFrom: DateTime(2026, 4, 10, 9),
          dateTo: DateTime(2026, 4, 10, 10),
        );
        final late = _buildEntry(
          id: 'late',
          dateFrom: DateTime(2026, 4, 20, 9),
          dateTo: DateTime(2026, 4, 20, 10),
        );
        await insertEntry(early);
        await insertEntry(late);
        db.calendarQueryCount = 0;

        // First caller asks about a narrow early window; second caller
        // joins the same wave with a window that extends the upper
        // bound. Both must see their own day's entry.
        final narrowEarly = db.sortedCalendarEntries(
          rangeStart: DateTime(2026, 4, 10),
          rangeEnd: DateTime(2026, 4, 11),
        );
        final narrowLate = db.sortedCalendarEntries(
          rangeStart: DateTime(2026, 4, 20),
          rangeEnd: DateTime(2026, 4, 21),
        );

        expect((await narrowEarly).map((e) => e.meta.id), ['early']);
        expect((await narrowLate).map((e) => e.meta.id), ['late']);
        expect(db.calendarQueryCount, 1);
      },
    );

    test('distinct microtask waves issue separate queries', () async {
      final entry = _buildEntry(
        id: 'only',
        dateFrom: DateTime(2026, 4, 10, 9),
        dateTo: DateTime(2026, 4, 10, 10),
      );
      await insertEntry(entry);
      db.calendarQueryCount = 0;

      final first = await db.sortedCalendarEntries(
        rangeStart: DateTime(2026, 4, 10),
        rangeEnd: DateTime(2026, 4, 11),
      );
      final second = await db.sortedCalendarEntries(
        rangeStart: DateTime(2026, 4, 10),
        rangeEnd: DateTime(2026, 4, 11),
      );

      expect(first.map((e) => e.meta.id), ['only']);
      expect(second.map((e) => e.meta.id), ['only']);
      expect(db.calendarQueryCount, 2);
    });

    test(
      'entries outside the caller window are filtered out even when they '
      'appear in the merged wave result',
      () async {
        final inside = _buildEntry(
          id: 'inside',
          dateFrom: DateTime(2026, 4, 13, 9),
          dateTo: DateTime(2026, 4, 13, 10),
        );
        final outside = _buildEntry(
          id: 'outside',
          dateFrom: DateTime(2026, 4, 17, 9),
          dateTo: DateTime(2026, 4, 17, 10),
        );
        await insertEntry(inside);
        await insertEntry(outside);
        db.calendarQueryCount = 0;

        // Two concurrent callers — narrow caller must NOT see `outside`
        // even though the wide caller pulls it into the wave result.
        final narrow = db.sortedCalendarEntries(
          rangeStart: DateTime(2026, 4, 13),
          rangeEnd: DateTime(2026, 4, 14),
        );
        final wide = db.sortedCalendarEntries(
          rangeStart: DateTime(2026, 4, 13),
          rangeEnd: DateTime(2026, 4, 18),
        );

        expect((await narrow).map((e) => e.meta.id), ['inside']);
        expect((await wide).map((e) => e.meta.id).toSet(), {
          'inside',
          'outside',
        });
        expect(db.calendarQueryCount, 1);
      },
    );

    test(
      'query error propagates to every caller waiting on the wave',
      () async {
        await db.close();
        final failingDb = _FailingCalendarJournalDb()
          ..failure = StateError('simulated');
        await initConfigFlags(failingDb, inMemoryDatabase: true);
        addTearDown(failingDb.close);

        final futures = [
          failingDb.sortedCalendarEntries(
            rangeStart: DateTime(2026, 4, 10),
            rangeEnd: DateTime(2026, 4, 11),
          ),
          failingDb.sortedCalendarEntries(
            rangeStart: DateTime(2026, 4, 11),
            rangeEnd: DateTime(2026, 4, 12),
          ),
        ];

        await Future.wait([
          for (final f in futures)
            expectLater(f, throwsA(same(failingDb.failure))),
        ]);
        expect(failingDb.attempts, 1);
      },
    );
  });
}
