// ignore_for_file: avoid_redundant_argument_values

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
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

  group('runQuery - due-date smart views', () {
    final now = DateTime(2024, 7, 3, 15);

    List<String>? capturedTaskIds({required bool byDueDate}) {
      final captured = byDueDate
          ? verify(
              () => mockJournalDb.getTasksSortedByDueDate(
                ids: captureAny(named: 'ids'),
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              ),
            ).captured
          : verify(
              () => mockJournalDb.getTasks(
                ids: captureAny(named: 'ids'),
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
                sortByDate: any(named: 'sortByDate'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              ),
            ).captured;
      return captured.single as List<String>?;
    }

    for (final byDueDate in [false, true]) {
      test("restricts the task query to the view's ids "
          '(${byDueDate ? 'due-date' : 'priority'} sort)', () async {
        when(
          () => mockJournalDb.getOpenTaskIdsForDueFilter(
            TaskDueFilter.overdue,
            now: now,
          ),
        ).thenAnswer((_) async => {'late-1', 'late-2'});

        await withClock(
          Clock.fixed(now),
          () => runner.runQuery(
            hDefaultParams(
              showTasks: true,
              dueFilter: TaskDueFilter.overdue,
              sortOption: byDueDate
                  ? TaskSortOption.byDueDate
                  : TaskSortOption.byPriority,
            ),
            0,
            fullTextMatches: {},
          ),
        );

        expect(
          capturedTaskIds(byDueDate: byDueDate),
          unorderedEquals(['late-1', 'late-2']),
        );
      });
    }

    test('intersects the view with an active search', () async {
      when(
        () => mockJournalDb.getOpenTaskIdsForDueFilter(
          TaskDueFilter.dueToday,
          now: now,
        ),
      ).thenAnswer((_) async => {'today-1', 'today-2'});

      await withClock(
        Clock.fixed(now),
        () => runner.runQuery(
          hDefaultParams(
            showTasks: true,
            dueFilter: TaskDueFilter.dueToday,
            query: 'habitat',
          ),
          0,
          fullTextMatches: {'today-2', 'undated'},
        ),
      );

      expect(capturedTaskIds(byDueDate: false), ['today-2']);
    });

    test('an empty view returns no rows without querying tasks', () async {
      when(
        () => mockJournalDb.getOpenTaskIdsForDueFilter(
          TaskDueFilter.overdue,
          now: now,
        ),
      ).thenAnswer((_) async => <String>{});
      var offsetReported = false;
      int? reportedOffset = -1;

      final result = await withClock(
        Clock.fixed(now),
        () => runner.runQuery(
          hDefaultParams(
            showTasks: true,
            dueFilter: TaskDueFilter.overdue,
            selectedProjectIds: {'proj-1'},
          ),
          0,
          fullTextMatches: {},
          setPostFilterNextRawOffset: (offset) {
            offsetReported = true;
            reportedOffset = offset;
          },
        ),
      );

      expect(result, isEmpty);
      // The pagination cursor is cleared, as on the un-post-filtered path.
      expect(offsetReported, isTrue);
      expect(reportedOffset, isNull);
      verifyNever(
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
      );
      verifyNever(() => mockJournalDb.getTaskIdsForProjects(any()));
    });

    test(
      'semantic results are narrowed to the view, distances kept whole',
      () async {
        final repo = MockVectorSearchRepository();
        getIt.registerSingleton<VectorSearchRepository>(repo);
        final late = hMakeTask(id: 'late', createdAt: hTestDate);
        final undated = hMakeTask(id: 'undated', createdAt: hTestDate);
        when(
          () => repo.searchRelatedTasks(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer(
          (_) async => VectorSearchResult(
            entities: [late, undated],
            elapsed: const Duration(milliseconds: 5),
            distances: const {'late': 0.1, 'undated': 0.2},
          ),
        );
        when(
          () => mockJournalDb.getOpenTaskIdsForDueFilter(
            TaskDueFilter.overdue,
            now: now,
          ),
        ).thenAnswer((_) async => {'late'});

        final result = await withClock(
          Clock.fixed(now),
          () => runner.runVectorSearch(
            hDefaultParams(
              showTasks: true,
              dueFilter: TaskDueFilter.overdue,
              query: 'fish',
              enableVectorSearch: true,
              searchMode: SearchMode.vector,
            ),
          ),
        );

        expect(result.entities.map((e) => e.meta.id), ['late']);
        // The search's own result set, which the smart-view counts read.
        expect(result.distances.keys, unorderedEquals(['late', 'undated']));
      },
    );

    test('no view leaves the search restriction untouched', () async {
      await runner.runQuery(
        hDefaultParams(showTasks: true),
        0,
        fullTextMatches: {},
      );

      expect(capturedTaskIds(byDueDate: false), isNull);
      verifyNever(
        () => mockJournalDb.getOpenTaskIdsForDueFilter(
          TaskDueFilter.overdue,
          now: now,
        ),
      );
    });
  });

  group('runQuery - best match while searching', () {
    final first = hMakeTask(id: 'first', createdAt: hTestDate);
    final second = hMakeTask(id: 'second', createdAt: hTestDate);
    final third = hMakeTask(id: 'third', createdAt: hTestDate);

    void taskQueryAnswers(List<JournalEntity> rows) =>
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
        ).thenAnswer(
          // Like the database: rows from the offset on, none past the end.
          (invocation) async =>
              rows.skip(invocation.namedArguments[#offset] as int).toList(),
        );

    test('the matches come back in the order the search ranked them, from '
        'one task query with room for all of them', () async {
      // The task query answers in its own (priority) order.
      taskQueryAnswers([third, first, second]);

      final page = await runner.runQuery(
        hDefaultParams(showTasks: true, query: 'krill'),
        0,
        fullTextMatches: {'first', 'second', 'third'},
      );

      expect(page.map((t) => t.meta.id), ['first', 'second', 'third']);
      final asked = verify(
        () => mockJournalDb.getTasks(
          ids: captureAny(named: 'ids'),
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          labelIds: any(named: 'labelIds'),
          priorities: any(named: 'priorities'),
          sortByDate: any(named: 'sortByDate'),
          limit: captureAny(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).captured;
      expect(asked, hasLength(2));
      expect(asked, contains(3));
      expect(
        asked,
        contains(equals(['first', 'second', 'third'])),
        reason: 'the matches, in their order',
      );
    });

    test('the results are one page: the next asks for nothing', () async {
      taskQueryAnswers([first]);

      final next = await runner.runQuery(
        hDefaultParams(showTasks: true, query: 'krill'),
        50,
        fullTextMatches: {'first'},
      );

      expect(next, isEmpty);
      verifyNever(
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
      );
    });

    test(
      'a project filter still applies, and the ranking survives it',
      () async {
        taskQueryAnswers([third, first, second]);
        when(
          () => mockJournalDb.getTaskIdsForProjects(any()),
        ).thenAnswer((_) async => {'first', 'third'});

        final page = await runner.runQuery(
          hDefaultParams(
            showTasks: true,
            query: 'krill',
            selectedProjectIds: const {'project-1'},
          ),
          0,
          fullTextMatches: {'third', 'second', 'first'},
        );

        expect(page.map((t) => t.meta.id), ['third', 'first']);
      },
    );
  });

  group('runPullRequestSearch', () {
    const link = 'https://github.com/MatthiasN/Lotti/pull/42/files';
    const key = 'matthiasn/lotti#42';
    final tasks = {
      for (final task in [
        hMakeTask(id: 'feed', createdAt: hTestDate, categoryId: 'colony'),
        hMakeTask(id: 'count', createdAt: hTestDate, categoryId: 'survey'),
        hMakeTask(id: 'loose', createdAt: hTestDate),
      ])
        task.meta.id: task,
    };

    void linkedTo(Set<String> taskIds) {
      when(
        () => mockJournalDb.taskIdsHoldingPullRequest(key),
      ).thenAnswer((_) async => taskIds);
      when(() => mockJournalDb.getJournalEntitiesForIds(any())).thenAnswer(
        (invocation) async => [
          for (final id in invocation.positionalArguments.single as Set<String>)
            ?tasks[id],
        ],
      );
    }

    Future<List<String>?> search(JournalQueryParams params) async =>
        (await runner.runPullRequestSearch(
          params,
        ))?.map((task) => task.meta.id).toList();

    test('anything but a pasted link on the tasks page is no lookup', () async {
      for (final params in [
        hDefaultParams(showTasks: true),
        hDefaultParams(showTasks: true, query: 'penguin census'),
        hDefaultParams(showTasks: true, query: 'matthiasn/lotti#42'),
        hDefaultParams(
          showTasks: true,
          query: 'https://gitlab.com/matthiasn/lotti/-/merge_requests/42',
        ),
        hDefaultParams(query: link),
      ]) {
        expect(await search(params), isNull, reason: params.query);
      }
      verifyNever(() => mockJournalDb.taskIdsHoldingPullRequest(any()));
    });

    test('a pull request linked to one task finds that task', () async {
      linkedTo({'feed'});

      expect(await search(hDefaultParams(showTasks: true, query: link)), [
        'feed',
      ]);
    });

    test(
      'a pull request linked to several tasks finds them all, whatever the '
      'status selection',
      () async {
        linkedTo({'feed', 'count', 'loose'});

        expect(
          await search(
            hDefaultParams(
              showTasks: true,
              query: link,
              selectedTaskStatuses: const {'IN PROGRESS'},
            ),
          ),
          unorderedEquals(['feed', 'count', 'loose']),
        );
        verifyNever(
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
        );
      },
    );

    test('the category selection still scopes what is shown, the empty id '
        'standing for uncategorised', () async {
      linkedTo({'feed', 'count', 'loose'});

      expect(
        await search(
          hDefaultParams(
            showTasks: true,
            query: link,
            selectedCategoryIds: const {'colony', ''},
          ),
        ),
        unorderedEquals(['feed', 'loose']),
      );
    });

    test('a due view narrows the linked tasks before they are read', () async {
      final now = DateTime(2024, 7, 3, 15);
      linkedTo({'feed', 'count'});
      when(
        () => mockJournalDb.getOpenTaskIdsForDueFilter(
          TaskDueFilter.overdue,
          now: now,
        ),
      ).thenAnswer((_) async => {'count', 'elsewhere'});

      final found = await withClock(
        Clock.fixed(now),
        () => search(
          hDefaultParams(
            showTasks: true,
            query: link,
            dueFilter: TaskDueFilter.overdue,
          ),
        ),
      );

      expect(found, ['count']);
      verify(() => mockJournalDb.getJournalEntitiesForIds({'count'})).called(1);
    });

    test('a pull request no task holds finds nothing rather than falling back '
        'to text search', () async {
      linkedTo({});

      expect(
        await search(hDefaultParams(showTasks: true, query: link)),
        isEmpty,
      );
      verifyNever(() => anyMatchIds(mockFts5Db));
      verifyNever(() => anyMatchHits(mockFts5Db));
    });
  });

  group('runQuery - tasks with post-filter', () {
    test('post-filters by project IDs', () {
      fakeAsync((async) {
        final taskInProject = hMakeTask(
          id: 'in-project',
          createdAt: hTestDate,
        );
        final taskNotInProject = hMakeTask(
          id: 'not-in-project',
          createdAt: hTestDate,
        );

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
        ).thenAnswer(
          (_) async => [taskInProject, taskNotInProject],
        );

        when(
          () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
        ).thenAnswer((_) async => {'in-project'});

        final params = hDefaultParams(
          showTasks: true,
          selectedProjectIds: {'proj-1'},
        );

        int? capturedOffset;
        late List<JournalEntity> result;
        runner
            .runQuery(
              params,
              0,
              fullTextMatches: {},
              setPostFilterNextRawOffset: (offset) {
                capturedOffset = offset;
              },
            )
            .then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        expect(result.first.meta.id, equals('in-project'));
        expect(capturedOffset, isNotNull);
      });
    });

    test('post-filters by agent assignment (hasAgent)', () {
      fakeAsync((async) {
        final mockAgentDb = MockAgentDatabase();
        getIt.registerSingleton<AgentDatabase>(mockAgentDb);

        when(
          mockAgentDb.getAgentTaskLinkToIds,
        ).thenReturn(MockSelectable<String>(['agent-task']));

        final agentTask = hMakeTask(
          id: 'agent-task',
          createdAt: hTestDate,
        );
        final noAgentTask = hMakeTask(
          id: 'no-agent-task',
          createdAt: hTestDate,
        );

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
        ).thenAnswer((_) async => [agentTask, noAgentTask]);

        final params = hDefaultParams(
          showTasks: true,
          agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        expect(result.first.meta.id, equals('agent-task'));
      });
    });

    test('post-filters by agent assignment (noAgent)', () {
      fakeAsync((async) {
        final mockAgentDb = MockAgentDatabase();
        getIt.registerSingleton<AgentDatabase>(mockAgentDb);

        when(
          mockAgentDb.getAgentTaskLinkToIds,
        ).thenReturn(MockSelectable<String>(['agent-task']));

        final agentTask = hMakeTask(
          id: 'agent-task',
          createdAt: hTestDate,
        );
        final noAgentTask = hMakeTask(
          id: 'no-agent-task',
          createdAt: hTestDate,
        );

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
        ).thenAnswer((_) async => [agentTask, noAgentTask]);

        final params = hDefaultParams(
          showTasks: true,
          agentAssignmentFilter: AgentAssignmentFilter.noAgent,
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        expect(result.first.meta.id, equals('no-agent-task'));
      });
    });

    test(
      'fetches a second chunk when the first is fully filtered out, applies '
      'both filters simultaneously, and stops on a partial chunk',
      () {
        fakeAsync((async) {
          const chunk = JournalQueryRunner.pageSize;
          final mockAgentDb = MockAgentDatabase();
          getIt.registerSingleton<AgentDatabase>(mockAgentDb);

          // Agent links: both-match and agent-only carry an agent link.
          when(
            mockAgentDb.getAgentTaskLinkToIds,
          ).thenReturn(MockSelectable<String>(['both-match', 'agent-only']));

          // Project membership: only both-match belongs to proj-1.
          when(
            () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
          ).thenAnswer((_) async => {'both-match'});

          // Chunk 1 (offset 0): a full page of tasks, none of which match
          // the project filter -> the loop must fetch a second chunk.
          final chunk1 = List.generate(
            chunk,
            (i) => hMakeTask(id: 'c1-$i', createdAt: hTestDate),
          );
          // Chunk 2 (offset = chunk): partial (2 < pageSize) -> loop exits
          // after consuming it. agent-only fails the project filter; only
          // both-match survives both filters.
          final chunk2 = [
            hMakeTask(id: 'both-match', createdAt: hTestDate),
            hMakeTask(id: 'agent-only', createdAt: hTestDate),
          ];
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
          ).thenAnswer((invocation) async {
            final offset = invocation.namedArguments[#offset] as int?;
            return offset == 0 ? chunk1 : chunk2;
          });

          final params = hDefaultParams(
            showTasks: true,
            selectedProjectIds: {'proj-1'},
            agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
          );

          int? capturedOffset;
          late List<JournalEntity> result;
          runner
              .runQuery(
                params,
                0,
                fullTextMatches: {},
                setPostFilterNextRawOffset: (offset) => capturedOffset = offset,
              )
              .then((r) => result = r);
          async.flushMicrotasks();

          expect(result, hasLength(1));
          expect(result.single.meta.id, 'both-match');
          // Both chunks were consumed: full chunk + 2 partial rows.
          expect(capturedOffset, chunk + 2);
        });
      },
    );

    test('calls setPostFilterNextRawOffset with correct offset', () {
      fakeAsync((async) {
        final tasks = List.generate(
          3,
          (i) => hMakeTask(id: 'task-$i', createdAt: hTestDate),
        );

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
        ).thenAnswer((_) async => tasks);

        // Only task-0 is in the project
        when(
          () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
        ).thenAnswer((_) async => {'task-0'});

        final params = hDefaultParams(
          showTasks: true,
          selectedProjectIds: {'proj-1'},
        );

        int? capturedOffset;
        late List<JournalEntity> result;
        runner
            .runQuery(
              params,
              0,
              fullTextMatches: {},
              setPostFilterNextRawOffset: (offset) {
                capturedOffset = offset;
              },
            )
            .then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        // Consumed all 3 rows (< fetchChunk of 50), so offset = 0 + 3
        expect(capturedOffset, equals(3));
      });
    });
  });

  group('getAgentLinkedTaskIds', () {
    test('caches result across multiple calls', () {
      fakeAsync((async) {
        final mockAgentDb = MockAgentDatabase();
        getIt.registerSingleton<AgentDatabase>(mockAgentDb);

        when(
          mockAgentDb.getAgentTaskLinkToIds,
        ).thenReturn(MockSelectable<String>(['linked-1', 'linked-2']));

        late Set<String> result1;
        late Set<String> result2;

        runner.getAgentLinkedTaskIds().then((r) => result1 = r);
        async.flushMicrotasks();

        runner.getAgentLinkedTaskIds().then((r) => result2 = r);
        async.flushMicrotasks();

        expect(result1, equals({'linked-1', 'linked-2'}));
        expect(result2, equals({'linked-1', 'linked-2'}));

        // Database should only be queried once due to caching
        verify(mockAgentDb.getAgentTaskLinkToIds).called(1);
      });
    });

    test('clearCache resets the cache', () {
      fakeAsync((async) {
        final mockAgentDb = MockAgentDatabase();
        getIt.registerSingleton<AgentDatabase>(mockAgentDb);

        when(
          mockAgentDb.getAgentTaskLinkToIds,
        ).thenReturn(MockSelectable<String>(['linked-1']));

        late Set<String> result1;
        runner.getAgentLinkedTaskIds().then((r) => result1 = r);
        async.flushMicrotasks();

        expect(result1, equals({'linked-1'}));

        // Clear cache and call again
        runner.clearCache();

        when(
          mockAgentDb.getAgentTaskLinkToIds,
        ).thenReturn(MockSelectable<String>(['linked-1', 'linked-3']));

        late Set<String> result2;
        runner.getAgentLinkedTaskIds().then((r) => result2 = r);
        async.flushMicrotasks();

        expect(result2, equals({'linked-1', 'linked-3'}));

        // Database queried twice: once before clear, once after
        verify(mockAgentDb.getAgentTaskLinkToIds).called(2);
      });
    });
  });

  group('runVectorSearch', () {
    test(
      'returns empty result when VectorSearchRepository is not registered',
      () {
        fakeAsync((async) {
          final params = hDefaultParams(
            query: 'test query',
            enableVectorSearch: true,
          );

          late JournalVectorSearchResult result;
          runner.runVectorSearch(params).then((r) => result = r);
          async.flushMicrotasks();

          expect(result.entities, isEmpty);
          expect(result.elapsed, equals(Duration.zero));
          expect(result.distances, isEmpty);
          verify(
            () => mockDomainLogger.log(
              LogDomain.persistence,
              any(that: contains('VectorSearchRepository not registered')),
              subDomain: 'JournalQueryRunner',
              level: InsightLevel.warn,
            ),
          ).called(1);
        });
      },
    );

    test('returns results with telemetry from repository', () {
      fakeAsync((async) {
        final mockVectorRepo = MockVectorSearchRepository();
        getIt.registerSingleton<VectorSearchRepository>(mockVectorRepo);

        final task = hMakeTask(id: 'vec-task', createdAt: hTestDate);
        final vectorResult = VectorSearchResult(
          entities: [task],
          elapsed: const Duration(milliseconds: 150),
          distances: {'vec-task': 0.42},
        );

        when(
          () => mockVectorRepo.searchRelatedTasks(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async => vectorResult);

        final params = hDefaultParams(
          showTasks: true,
          query: 'semantic search',
          enableVectorSearch: true,
        );

        late JournalVectorSearchResult result;
        runner.runVectorSearch(params).then((r) => result = r);
        async.flushMicrotasks();

        expect(result.entities, hasLength(1));
        expect(result.entities.first.meta.id, equals('vec-task'));
        expect(result.elapsed, equals(const Duration(milliseconds: 150)));
        expect(result.distances, equals({'vec-task': 0.42}));
      });
    });

    test('calls searchRelatedEntries when showTasks is false', () {
      fakeAsync((async) {
        final mockVectorRepo = MockVectorSearchRepository();
        getIt.registerSingleton<VectorSearchRepository>(mockVectorRepo);

        final entry = hMakeEntry(id: 'vec-entry', createdAt: hTestDate);
        final vectorResult = VectorSearchResult(
          entities: [entry],
          elapsed: const Duration(milliseconds: 80),
          distances: {'vec-entry': 0.3},
        );

        when(
          () => mockVectorRepo.searchRelatedEntries(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async => vectorResult);

        final params = hDefaultParams(
          showTasks: false,
          query: 'semantic search',
          enableVectorSearch: true,
        );

        late JournalVectorSearchResult result;
        runner.runVectorSearch(params).then((r) => result = r);
        async.flushMicrotasks();

        expect(result.entities, hasLength(1));
        expect(result.entities.first.meta.id, equals('vec-entry'));

        verify(
          () => mockVectorRepo.searchRelatedEntries(
            query: 'semantic search',
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
        verifyNever(
          () => mockVectorRepo.searchRelatedTasks(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        );
      });
    });

    test('passes null categoryIds when selectedCategoryIds is empty', () {
      fakeAsync((async) {
        final mockVectorRepo = MockVectorSearchRepository();
        getIt.registerSingleton<VectorSearchRepository>(mockVectorRepo);

        final vectorResult = VectorSearchResult(
          entities: <JournalEntity>[],
          elapsed: const Duration(milliseconds: 10),
        );

        when(
          () => mockVectorRepo.searchRelatedEntries(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async => vectorResult);

        final params = hDefaultParams(
          query: 'test query',
          enableVectorSearch: true,
          // selectedCategoryIds defaults to empty set
        );

        late JournalVectorSearchResult result;
        runner.runVectorSearch(params).then((r) => result = r);
        async.flushMicrotasks();

        expect(result.entities, isEmpty);

        // Verify categoryIds was passed as null (not an empty set).
        verify(
          () => mockVectorRepo.searchRelatedEntries(
            query: 'test query',
            categoryIds: null,
          ),
        ).called(1);
      });
    });

    test('returns empty result when repository throws', () {
      fakeAsync((async) {
        final mockVectorRepo = MockVectorSearchRepository();
        getIt.registerSingleton<VectorSearchRepository>(mockVectorRepo);

        when(
          () => mockVectorRepo.searchRelatedTasks(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenThrow(Exception('embedding service unavailable'));

        final params = hDefaultParams(
          showTasks: true,
          query: 'broken search',
          enableVectorSearch: true,
        );

        late JournalVectorSearchResult result;
        runner.runVectorSearch(params).then((r) => result = r);
        async.flushMicrotasks();

        expect(result.entities, isEmpty);
        expect(result.elapsed, equals(Duration.zero));
        expect(result.distances, isEmpty);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(that: isA<Exception>()),
            stackTrace: any(named: 'stackTrace', that: isNotNull),
            subDomain: 'JournalQueryRunner',
            message: 'Vector search failed',
          ),
        ).called(1);
      });
    });
  });
}
