// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/classes/task_search_hit.dart';
import 'package:lotti/database/search_hit.dart';
import 'package:lotti/database/task_search.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fts5_stubs.dart';
import '../../../mocks/mocks.dart';
import 'journal_query_runner_test_helpers.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockFts5Db mockFts5Db;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockDomainLogger mockDomainLogger;
  late JournalQueryRunner runner;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockFts5Db = MockFts5Db();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockDomainLogger = MockDomainLogger();

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
      fts5Db: () => mockFts5Db,
      entitiesCacheService: mockEntitiesCacheService,
      domainLogger: mockDomainLogger,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('fts5Search', () {
    late Invocation asked;

    void recordMatches() {
      when(() => anyMatchIds(mockFts5Db)).thenAnswer((invocation) async {
        asked = invocation;
        return const <String>[];
      });
      when(() => anyMatchHits(mockFts5Db)).thenAnswer((invocation) async {
        asked = invocation;
        return const <SearchHit>[];
      });
    }

    ({Set<String>? types, Set<String>? categoryIds, bool includePrivate})
    askedFilters() => (
      types: asked.namedArguments[#types] as Set<String>?,
      categoryIds: asked.namedArguments[#categoryIds] as Set<String>?,
      includePrivate: asked.namedArguments[#includePrivate] as bool,
    );

    void showsPrivate({required bool shows}) => when(
      () => mockJournalDb.getConfigFlag(privateFlag),
    ).thenAnswer((_) async => shows);

    test('a blank query asks the index nothing', () async {
      final matches = await runner.fts5Search(hDefaultParams(query: '  '));
      expect(matches.ids, isEmpty);
      expect(matches.taskHits, isEmpty);
      verifyNever(() => anyMatchIds(mockFts5Db));
      verifyNever(() => anyMatchHits(mockFts5Db));
    });

    test('tasks keep the index order, best match first, each with where it '
        'matched', () async {
      showsPrivate(shows: true);
      when(() => anyMatchHits(mockFts5Db, 'penguin')).thenAnswer(
        (_) async => [
          taskHit('best', snippet: 'the \uE000penguin\uE001 census'),
          taskHit('next'),
          taskHit('best', snippet: 'a weaker match'),
        ],
      );

      final matches = await runner.fts5Search(
        hDefaultParams(showTasks: true, query: 'penguin'),
      );

      expect(matches.ids.toList(), ['best', 'next']);
      expect(
        matches.taskHits['best'],
        const TaskSearchHit(
          taskId: 'best',
          snippet: 'the \uE000penguin\uE001 census',
          matchedType: 'Task',
        ),
      );
    });

    test(
      'the tasks page asks for tasks and what belongs to them, in its '
      'categories, private ones only while private mode shows them',
      () async {
        for (final shows in [true, false]) {
          showsPrivate(shows: shows);
          recordMatches();

          await runner.fts5Search(
            hDefaultParams(
              showTasks: true,
              query: 'penguin',
              selectedCategoryIds: const {'colony', ''},
            ),
          );

          final asked = askedFilters();
          expect(asked.types, taskSearchTypes);
          expect(asked.categoryIds, {'colony', ''});
          expect(asked.includePrivate, shows);
        }
      },
    );

    test('the logbook asks for the entry types it lists, in every category '
        'when none is selected', () async {
      showsPrivate(shows: true);
      recordMatches();

      final matches = await runner.fts5Search(
        hDefaultParams(
          query: 'penguin',
          selectedEntryTypes: const {'JournalEntry', 'JournalEvent'},
          enableEvents: false,
        ),
      );

      final asked = askedFilters();
      expect(asked.types, {'JournalEntry'}, reason: 'events are flagged off');
      expect(asked.categoryIds, isNull);
      expect(matches.taskHits, isEmpty);
    });
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

  // ADR 0139: a check-in is in the feed and a search result alike — the
  // exclusion ADR 0064 made is gone.
  group('runQuery - check-ins', () {
    for (final (query, expected) in [('', true), ('krill', true)]) {
      test("query '$query' ${expected ? 'keeps' : 'drops'} check-ins", () {
        fakeAsync((async) {
          runner.runQuery(
            hDefaultParams(
              selectedEntryTypes: {'JournalEntry', 'CheckIn'},
              query: query,
            ),
            0,
            fullTextMatches: {'entry-1'},
          );
          async.flushMicrotasks();

          final types =
              verify(
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
                  ).captured.single
                  as List<String>;
          expect(types, contains('JournalEntry'));
          expect(types.contains('CheckIn'), expected);
        });
      });
    }
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
