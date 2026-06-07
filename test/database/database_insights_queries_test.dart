import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';

void main() {
  late JournalDb db;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    } else {
      previousDirectory = null;
    }
    getIt.registerSingleton<Directory>(Directory.systemTemp);
    db = JournalDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
  });

  JournalEntity buildTimeEntry({
    required String id,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? categoryId,
    bool deleted = false,
    bool private = false,
  }) {
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        updatedAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
        deletedAt: deleted ? dateTo : null,
        private: private,
      ),
      entryText: const EntryText(plainText: 'work'),
    );
  }

  Future<void> setPrivateFlag({required bool status}) {
    return db.customStatement(
      'INSERT INTO config_flags (name, description, status) '
      "VALUES ('private', 'show private entries', ?) "
      'ON CONFLICT(name) DO UPDATE SET status = excluded.status',
      [if (status) 1 else 0],
    );
  }

  JournalEntity buildTask({
    required String id,
    required DateTime at,
    String? categoryId,
  }) {
    return JournalEntity.task(
      meta: Metadata(
        id: id,
        createdAt: at,
        updatedAt: at,
        dateFrom: at,
        dateTo: at,
        categoryId: categoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-$id',
          createdAt: at,
          utcOffset: at.timeZoneOffset.inMinutes,
        ),
        dateFrom: at,
        dateTo: at,
        statusHistory: const [],
        title: 'Task $id',
      ),
    );
  }

  Future<void> link({
    required String fromId,
    required String toId,
    bool hidden = false,
  }) {
    final at = DateTime(2024, 3);
    return db.upsertEntryLink(
      EntryLink.basic(
        id: '$fromId-$toId',
        fromId: fromId,
        toId: toId,
        createdAt: at,
        updatedAt: at,
        vectorClock: const VectorClock(<String, int>{}),
        hidden: hidden,
      ),
    );
  }

  group('insightsTimeRows', () {
    test(
      'returns spans with entry-own category for unlinked entries',
      () async {
        await db.updateJournalEntity(
          buildTimeEntry(
            id: 'entry-1',
            dateFrom: DateTime(2024, 3, 1, 9),
            dateTo: DateTime(2024, 3, 1, 10, 30),
            categoryId: 'cat-own',
          ),
        );

        final rows = await db.insightsTimeRows(
          start: DateTime(2024, 3),
          end: DateTime(2024, 4),
        );

        expect(rows, hasLength(1));
        expect(rows.single.dateFrom, DateTime(2024, 3, 1, 9));
        expect(rows.single.dateTo, DateTime(2024, 3, 1, 10, 30));
        expect(rows.single.categoryId, 'cat-own');
      },
    );

    test('uncategorized entries resolve to null, not empty string', () async {
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-1',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 10),
        ),
      );

      final rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows.single.categoryId, isNull);
    });

    test(
      'linked task category takes precedence over entry-own category',
      () async {
        await db.updateJournalEntity(
          buildTask(
            id: 'task-1',
            at: DateTime(2024, 3),
            categoryId: 'cat-task',
          ),
        );
        await db.updateJournalEntity(
          buildTimeEntry(
            id: 'entry-1',
            dateFrom: DateTime(2024, 3, 1, 9),
            dateTo: DateTime(2024, 3, 1, 10),
            categoryId: 'cat-own',
          ),
        );
        await link(fromId: 'task-1', toId: 'entry-1');

        final rows = await db.insightsTimeRows(
          start: DateTime(2024, 3),
          end: DateTime(2024, 4),
        );
        expect(rows.single.categoryId, 'cat-task');
      },
    );

    test('multiple incoming links yield exactly ONE row — no fan-out '
        'double-counting', () async {
      await db.updateJournalEntity(
        buildTask(id: 'task-a', at: DateTime(2024, 3), categoryId: 'cat-a'),
      );
      await db.updateJournalEntity(
        buildTask(
          id: 'task-b',
          at: DateTime(2024, 3, 2),
          categoryId: 'cat-b',
        ),
      );
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-1',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 10),
        ),
      );
      await link(fromId: 'task-a', toId: 'entry-1');
      await link(fromId: 'task-b', toId: 'entry-1');

      final rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );

      // One hour of work stays one hour, attributed deterministically to
      // the most recent linked task.
      expect(rows, hasLength(1));
      expect(rows.single.categoryId, 'cat-b');
    });

    test('hidden links and deleted tasks do not steal attribution', () async {
      await db.updateJournalEntity(
        buildTask(
          id: 'task-hidden',
          at: DateTime(2024, 3, 5),
          categoryId: 'cat-hidden',
        ),
      );
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-1',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 10),
          categoryId: 'cat-own',
        ),
      );
      await link(fromId: 'task-hidden', toId: 'entry-1', hidden: true);

      final rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows.single.categoryId, 'cat-own');
    });

    test(
      'uncategorized linked task falls back to entry-own category',
      () async {
        await db.updateJournalEntity(
          buildTask(id: 'task-1', at: DateTime(2024, 3)),
        );
        await db.updateJournalEntity(
          buildTimeEntry(
            id: 'entry-1',
            dateFrom: DateTime(2024, 3, 1, 9),
            dateTo: DateTime(2024, 3, 1, 10),
            categoryId: 'cat-own',
          ),
        );
        await link(fromId: 'task-1', toId: 'entry-1');

        final rows = await db.insightsTimeRows(
          start: DateTime(2024, 3),
          end: DateTime(2024, 4),
        );
        expect(rows.single.categoryId, 'cat-own');
      },
    );

    test(
      'window-edge entries overlap in, fully-outside entries stay out',
      () async {
        // Crosses the window start boundary — must be returned.
        await db.updateJournalEntity(
          buildTimeEntry(
            id: 'entry-edge',
            dateFrom: DateTime(2024, 2, 29, 23),
            dateTo: DateTime(2024, 3, 1, 1),
            categoryId: 'cat',
          ),
        );
        // Entirely before the window — must not be returned.
        await db.updateJournalEntity(
          buildTimeEntry(
            id: 'entry-before',
            dateFrom: DateTime(2024, 2, 28, 9),
            dateTo: DateTime(2024, 2, 28, 10),
            categoryId: 'cat',
          ),
        );
        // Ends exactly at the window start (half-open) — must not be
        // returned.
        await db.updateJournalEntity(
          buildTimeEntry(
            id: 'entry-touching',
            dateFrom: DateTime(2024, 2, 29, 22),
            dateTo: DateTime(2024, 3),
            categoryId: 'cat',
          ),
        );

        final rows = await db.insightsTimeRows(
          start: DateTime(2024, 3),
          end: DateTime(2024, 4),
        );
        expect(rows, hasLength(1));
        expect(rows.single.dateFrom, DateTime(2024, 2, 29, 23));
      },
    );

    test('deleted and zero-duration entries are excluded; tasks and other '
        'types never appear', () async {
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-deleted',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 10),
          categoryId: 'cat',
          deleted: true,
        ),
      );
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-zero',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 9),
          categoryId: 'cat',
        ),
      );
      // A task spanning the whole month must not count as tracked time.
      await db.updateJournalEntity(
        buildTask(id: 'task-1', at: DateTime(2024, 3, 1, 9), categoryId: 'c'),
      );

      final rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows, isEmpty);
    });

    test('short entries are included — no 15-second floor', () async {
      // The legacy workEntriesInDateRange floor was a JournalEntry noise
      // heuristic; a totals dashboard must count everything > 0s.
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-short',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 9, 0, 5),
          categoryId: 'cat',
        ),
      );
      final rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows, hasLength(1));
    });

    test('private entries are hidden unless the private flag is on', () async {
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-private',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 10),
          categoryId: 'cat-secret',
          private: true,
        ),
      );
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'entry-public',
          dateFrom: DateTime(2024, 3, 1, 11),
          dateTo: DateTime(2024, 3, 1, 12),
          categoryId: 'cat-public',
        ),
      );

      // No flag row at all → private hidden by default.
      var rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows.map((r) => r.categoryId), ['cat-public']);

      // Flag explicitly off → still hidden.
      await setPrivateFlag(status: false);
      rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows.map((r) => r.categoryId), ['cat-public']);

      // Flag on → private durations included.
      await setPrivateFlag(status: true);
      rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows.map((r) => r.categoryId), [
        'cat-secret',
        'cat-public',
      ]);
    });

    test(
      'a hidden private task cannot leak its category into attribution',
      () async {
        await db.updateJournalEntity(
          JournalEntity.task(
            meta: Metadata(
              id: 'task-private',
              createdAt: DateTime(2024, 3),
              updatedAt: DateTime(2024, 3),
              dateFrom: DateTime(2024, 3),
              dateTo: DateTime(2024, 3),
              categoryId: 'cat-secret-task',
              private: true,
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-task-private',
                createdAt: DateTime(2024, 3),
                utcOffset: 0,
              ),
              dateFrom: DateTime(2024, 3),
              dateTo: DateTime(2024, 3),
              statusHistory: const [],
              title: 'Private task',
            ),
          ),
        );
        await db.updateJournalEntity(
          buildTimeEntry(
            id: 'entry-1',
            dateFrom: DateTime(2024, 3, 1, 9),
            dateTo: DateTime(2024, 3, 1, 10),
            categoryId: 'cat-own',
          ),
        );
        await link(fromId: 'task-private', toId: 'entry-1');

        // Private hidden: the public entry still counts, but attribution
        // falls back to its own category instead of the private task's.
        final rows = await db.insightsTimeRows(
          start: DateTime(2024, 3),
          end: DateTime(2024, 4),
        );
        expect(rows.single.categoryId, 'cat-own');

        // Private visible: the task's category wins again.
        await setPrivateFlag(status: true);
        final visibleRows = await db.insightsTimeRows(
          start: DateTime(2024, 3),
          end: DateTime(2024, 4),
        );
        expect(visibleRows.single.categoryId, 'cat-secret-task');
      },
    );

    test('rows are ordered by date_from ascending', () async {
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'later',
          dateFrom: DateTime(2024, 3, 2, 9),
          dateTo: DateTime(2024, 3, 2, 10),
        ),
      );
      await db.updateJournalEntity(
        buildTimeEntry(
          id: 'earlier',
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 10),
        ),
      );
      final rows = await db.insightsTimeRows(
        start: DateTime(2024, 3),
        end: DateTime(2024, 4),
      );
      expect(rows.first.dateFrom, DateTime(2024, 3, 1, 9));
      expect(rows.last.dateFrom, DateTime(2024, 3, 2, 9));
    });
  });
}
