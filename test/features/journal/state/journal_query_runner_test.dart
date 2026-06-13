// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'journal_query_runner_test_helpers.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockFts5Db mockFts5Db;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late JournalQueryRunner runner;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockFts5Db = MockFts5Db();
    mockEntitiesCacheService = MockEntitiesCacheService();

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

    when(
      () => mockJournalDb.getJournalEntities(
        types: any(named: 'types'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        ids: any(named: 'ids'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTasks(
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTasksSortedByDueDate(
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTaskIdsForProjects(any()),
    ).thenAnswer((_) async => <String>{});

    runner = JournalQueryRunner(
      db: mockJournalDb,
      fts5Db: mockFts5Db,
      entitiesCacheService: mockEntitiesCacheService,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('fts5Search', () {
    test('returns empty set for empty query', () {
      fakeAsync((async) {
        late Set<String> result;
        runner.fts5Search('').then((r) => result = r);
        async.flushMicrotasks();

        expect(result, isEmpty);
        verifyNever(() => mockFts5Db.watchFullTextMatches(any()));
      });
    });

    test('returns matching IDs for non-empty query', () {
      fakeAsync((async) {
        when(
          () => mockFts5Db.watchFullTextMatches('flutter'),
        ).thenAnswer((_) => Stream.value(['id-1', 'id-2', 'id-1']));

        late Set<String> result;
        runner.fts5Search('flutter').then((r) => result = r);
        async.flushMicrotasks();

        expect(result, equals({'id-1', 'id-2'}));
        verify(() => mockFts5Db.watchFullTextMatches('flutter')).called(1);
      });
    });
  });

  group('sortByDueDate', () {
    test('sorts tasks with due dates before tasks without', () {
      final withDue = hMakeTask(
        id: 'with-due',
        createdAt: DateTime(2024, 1, 1),
        due: DateTime(2024, 6, 15),
      );
      final withoutDue = hMakeTask(
        id: 'without-due',
        createdAt: DateTime(2024, 1, 2),
      );

      final sorted = JournalQueryRunner.sortByDueDate([withoutDue, withDue]);

      expect(sorted.first.meta.id, equals('with-due'));
      expect(sorted.last.meta.id, equals('without-due'));
    });

    test('sorts tasks by due date ascending (soonest first)', () {
      final sooner = hMakeTask(
        id: 'sooner',
        createdAt: DateTime(2024, 1, 1),
        due: DateTime(2024, 3, 1),
      );
      final later = hMakeTask(
        id: 'later',
        createdAt: DateTime(2024, 1, 2),
        due: DateTime(2024, 9, 1),
      );

      final sorted = JournalQueryRunner.sortByDueDate([later, sooner]);

      expect(sorted.first.meta.id, equals('sooner'));
      expect(sorted.last.meta.id, equals('later'));
    });

    test('preserves creation date order for same due date', () {
      final newer = hMakeTask(
        id: 'newer',
        createdAt: DateTime(2024, 2, 1),
        due: DateTime(2024, 6, 15),
      );
      final older = hMakeTask(
        id: 'older',
        createdAt: DateTime(2024, 1, 1),
        due: DateTime(2024, 6, 15),
      );

      final sorted = JournalQueryRunner.sortByDueDate([older, newer]);

      // Same due date -> sorted by dateFrom descending (newer first)
      expect(sorted.first.meta.id, equals('newer'));
      expect(sorted.last.meta.id, equals('older'));
    });

    test('handles mixed tasks with and without due dates', () {
      final dueSoon = hMakeTask(
        id: 'due-soon',
        createdAt: DateTime(2024, 1, 1),
        due: DateTime(2024, 3, 1),
      );
      final dueLate = hMakeTask(
        id: 'due-late',
        createdAt: DateTime(2024, 1, 2),
        due: DateTime(2024, 12, 1),
      );
      final noDue1 = hMakeTask(
        id: 'no-due-newer',
        createdAt: DateTime(2024, 3, 1),
      );
      final noDue2 = hMakeTask(
        id: 'no-due-older',
        createdAt: DateTime(2024, 1, 1),
      );

      final sorted = JournalQueryRunner.sortByDueDate(
        [noDue2, dueLate, noDue1, dueSoon],
      );

      // Due tasks first sorted by due date, then no-due by dateFrom desc
      expect(sorted[0].meta.id, equals('due-soon'));
      expect(sorted[1].meta.id, equals('due-late'));
      expect(sorted[2].meta.id, equals('no-due-newer'));
      expect(sorted[3].meta.id, equals('no-due-older'));
    });

    test(
      'handles all tasks without due dates (falls back to creation date)',
      () {
        final newest = hMakeTask(
          id: 'newest',
          createdAt: DateTime(2024, 6, 1),
        );
        final middle = hMakeTask(
          id: 'middle',
          createdAt: DateTime(2024, 3, 1),
        );
        final oldest = hMakeTask(
          id: 'oldest',
          createdAt: DateTime(2024, 1, 1),
        );

        final sorted = JournalQueryRunner.sortByDueDate([
          oldest,
          newest,
          middle,
        ]);

        // No due dates -> sorted by dateFrom descending (newest first)
        expect(sorted[0].meta.id, equals('newest'));
        expect(sorted[1].meta.id, equals('middle'));
        expect(sorted[2].meta.id, equals('oldest'));
      },
    );

    glados.Glados(
      glados.any.dueDateSortScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('generated task lists satisfy all sort invariants', (scenario) {
      final input = scenario.tasks;
      final sorted = JournalQueryRunner.sortByDueDate(input);

      // 1. Total order: the output is a permutation of the input.
      expect(
        sorted.map((e) => e.meta.id).toSet(),
        input.map((e) => e.meta.id).toSet(),
      );
      expect(sorted.length, input.length);

      final dues = sorted.map((e) => e is Task ? e.data.due : null).toList();

      // 2. Tasks with due dates always precede tasks without.
      final firstWithoutDue = dues.indexWhere((d) => d == null);
      if (firstWithoutDue != -1) {
        expect(
          dues.sublist(firstWithoutDue).every((d) => d == null),
          isTrue,
          reason: 'due-less task before a task with a due date: $dues',
        );
      }

      for (var i = 1; i < sorted.length; i++) {
        final prevDue = dues[i - 1];
        final currDue = dues[i];
        if (prevDue != null && currDue != null) {
          // 3. Due dates are non-decreasing.
          expect(prevDue.isAfter(currDue), isFalse);
          if (prevDue == currDue) {
            // 4. Same due date -> dateFrom non-increasing (newest first).
            expect(
              sorted[i - 1].meta.dateFrom.isBefore(sorted[i].meta.dateFrom),
              isFalse,
            );
          }
        } else if (prevDue == null && currDue == null) {
          // 5. Among due-less tasks, dateFrom non-increasing.
          expect(
            sorted[i - 1].meta.dateFrom.isBefore(sorted[i].meta.dateFrom),
            isFalse,
          );
        }
      }
    }, tags: 'glados');
  });

  group('runQuery - journal entries', () {
    test('calls getJournalEntities for showTasks=false', () {
      fakeAsync((async) {
        final entry = hMakeEntry(id: 'e-1', createdAt: hTestDate);

        when(
          () => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async => [entry]);

        final params = hDefaultParams();

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        expect(result.first.meta.id, equals('e-1'));
        verify(
          () => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: 50,
            offset: 0,
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
      });
    });

    test('passes categoryIds when selectedCategoryIds is non-empty', () {
      fakeAsync((async) {
        final params = hDefaultParams(
          selectedCategoryIds: {'cat-1', 'cat-2'},
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        final captured = verify(
          () => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: captureAny(named: 'categoryIds'),
          ),
        ).captured;

        final categoryIds = captured.first as Set<String>?;
        expect(categoryIds, isNotNull);
        expect(categoryIds, equals({'cat-1', 'cat-2'}));
        expect(result, isEmpty);
      });
    });

    test('passes correct types filtered by feature flags', () {
      fakeAsync((async) {
        final params = hDefaultParams(
          selectedEntryTypes: {'JournalEntry', 'JournalEvent', 'Task'},
          enableEvents: false,
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        final captured = verify(
          () => mockJournalDb.getJournalEntities(
            types: captureAny(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).captured;

        final types = captured.first as List<String>;
        expect(types, contains('JournalEntry'));
        expect(types, isNot(contains('JournalEvent')));
        expect(result, isEmpty);
      });
    });
  });

  group('runQuery - tasks without post-filter', () {
    test('calls getTasks with correct params', () {
      fakeAsync((async) {
        final task = hMakeTask(id: 'task-1', createdAt: hTestDate);

        when(
          () => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            sortByDate: any(named: 'sortByDate'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [task]);

        final params = hDefaultParams(
          showTasks: true,
          selectedTaskStatuses: {'OPEN'},
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        expect(result.first.meta.id, equals('task-1'));
        verify(
          () => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            sortByDate: any(named: 'sortByDate'),
            limit: 50,
            offset: 0,
          ),
        ).called(1);
      });
    });

    test('uses getTasksSortedByDueDate when sortOption is byDueDate', () {
      fakeAsync((async) {
        final taskWithDue = hMakeTask(
          id: 'with-due',
          createdAt: DateTime(2024, 1, 2),
          due: DateTime(2024, 6, 1),
        );
        final taskNoDue = hMakeTask(
          id: 'no-due',
          createdAt: DateTime(2024, 1, 1),
        );

        // DB returns already-sorted results
        when(
          () => mockJournalDb.getTasksSortedByDueDate(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [taskWithDue, taskNoDue]);

        final params = hDefaultParams(
          showTasks: true,
          sortOption: TaskSortOption.byDueDate,
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result.first.meta.id, equals('with-due'));
        expect(result.last.meta.id, equals('no-due'));

        verify(
          () => mockJournalDb.getTasksSortedByDueDate(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).called(1);
      });
    });
  });
}
