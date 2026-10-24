import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/service/open_task_corpus.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

final _day = DateTime(2026, 5, 25, 14, 30);

Task _task({
  required String id,
  required String title,
  bool done = false,
  String? categoryId = 'work',
}) {
  final status = done
      ? TaskStatus.done(
          id: 'status-$id',
          createdAt: DateTime(2026, 5, 20),
          utcOffset: 120,
        )
      : TaskStatus.open(
          id: 'status-$id',
          createdAt: DateTime(2026, 5, 20),
          utcOffset: 120,
        );
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: DateTime(2026, 5, 20),
          updatedAt: DateTime(2026, 5, 20),
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          categoryId: categoryId,
        ),
        data: TaskData(
          status: status,
          statusHistory: [status],
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          title: title,
        ),
      )
      as Task;
}

void main() {
  late MockJournalDb journalDb;
  late MockFts5Db fts5Db;

  setUp(() {
    journalDb = MockJournalDb();
    fts5Db = MockFts5Db();
  });

  group('readOpenTaskCorpus', () {
    test('due and overdue tasks come first, then open ones, each once, '
        'closed and disallowed dropped', () async {
      when(
        () => journalDb.getTasksDueOnOrBefore(any()),
      ).thenAnswer(
        (_) async => [
          _task(id: 'due-done', title: 'Done', done: true),
          _task(id: 'due', title: 'Due'),
          _task(id: 'both', title: 'Due and open'),
        ],
      );
      when(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          _task(id: 'both', title: 'Due and open'),
          _task(id: 'open', title: 'Open'),
          _task(id: 'other', title: 'Elsewhere', categoryId: 'life'),
        ],
      );

      final corpus = await readOpenTaskCorpus(
        journalDb: journalDb,
        allowedCategoryIds: {'work'},
        day: _day,
        limit: 10,
      );

      expect(corpus.map((t) => t.id), ['due', 'both', 'open']);
      // The due read is keyed on the local calendar day, not the instant.
      final captured =
          verify(
                () => journalDb.getTasksDueOnOrBefore(captureAny()),
              ).captured.single
              as DateTime;
      expect(captured, DateTime(2026, 5, 25));
      verify(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: {'work'},
          limit: 10,
        ),
      ).called(1);
    });

    test('stops at the limit, due work first', () async {
      when(
        () => journalDb.getTasksDueOnOrBefore(any()),
      ).thenAnswer((_) async => [_task(id: 'due', title: 'Due')]);
      when(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          _task(id: 'o1', title: 'One'),
          _task(id: 'o2', title: 'Two'),
        ],
      );

      final corpus = await readOpenTaskCorpus(
        journalDb: journalDb,
        allowedCategoryIds: const {},
        day: _day,
        limit: 2,
      );
      expect(corpus.map((t) => t.id), ['due', 'o1']);
    });
  });

  group('matchOpenTasksByPhrase', () {
    test('returns open tasks in FTS order with their original rank', () async {
      when(
        () => fts5Db.watchFullTextMatches('hose'),
      ).thenAnswer(
        (_) => Stream.value(['note-1', 'closed', 'open-a', 'open-b']),
      );
      when(
        () => journalDb.getJournalEntitiesForIdsUnordered(any()),
      ).thenAnswer(
        (_) async => [
          _task(id: 'open-b', title: 'B'),
          _task(id: 'closed', title: 'Closed', done: true),
          _task(id: 'open-a', title: 'A'),
        ],
      );

      final matches = await matchOpenTasksByPhrase(
        fts5Db: fts5Db,
        journalDb: journalDb,
        phrase: 'hose',
        categoryFilter: null,
        limit: 8,
      );

      // The note and the closed task still occupy ranks 0 and 1.
      expect(matches.map((m) => (m.rank, m.task.id)), [
        (2, 'open-a'),
        (3, 'open-b'),
      ]);
    });

    test('applies the category filter and the limit', () async {
      when(
        () => fts5Db.watchFullTextMatches(any()),
      ).thenAnswer((_) => Stream.value(['t1', 't2', 't3']));
      when(
        () => journalDb.getJournalEntitiesForIdsUnordered(any()),
      ).thenAnswer(
        (_) async => [
          _task(id: 't1', title: '1', categoryId: 'life'),
          _task(id: 't2', title: '2'),
          _task(id: 't3', title: '3'),
        ],
      );

      final matches = await matchOpenTasksByPhrase(
        fts5Db: fts5Db,
        journalDb: journalDb,
        phrase: 'x',
        categoryFilter: {'work'},
        limit: 1,
      );
      expect(matches.map((m) => m.task.id), ['t2']);
    });

    test('an empty FTS result reads nothing from the journal', () async {
      when(
        () => fts5Db.watchFullTextMatches(any()),
      ).thenAnswer((_) => Stream.value(const []));

      final matches = await matchOpenTasksByPhrase(
        fts5Db: fts5Db,
        journalDb: journalDb,
        phrase: 'nothing',
        categoryFilter: null,
        limit: 8,
      );
      expect(matches, isEmpty);
      verifyNever(() => journalDb.getJournalEntitiesForIdsUnordered(any()));
    });
  });
}
