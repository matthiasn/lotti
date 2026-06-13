// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
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
      });
    });
  });
}
