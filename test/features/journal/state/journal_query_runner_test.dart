// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

final _testDate = DateTime(2024, 3, 15);

Task _makeTask({
  required String id,
  required DateTime createdAt,
  DateTime? due,
  String? categoryId,
}) {
  return Task(
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-$id',
        createdAt: createdAt,
        utcOffset: 0,
      ),
      title: 'Task $id',
      statusHistory: const [],
      dateFrom: createdAt,
      dateTo: createdAt,
      due: due,
    ),
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
      updatedAt: createdAt,
      categoryId: categoryId,
    ),
  );
}

JournalEntry _makeEntry({
  required String id,
  required DateTime createdAt,
}) {
  return JournalEntry(
    entryText: EntryText(plainText: 'Entry $id', markdown: 'Entry $id'),
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
      updatedAt: createdAt,
    ),
  );
}

JournalQueryParams _defaultParams({
  bool showTasks = false,
  Set<String> selectedEntryTypes = const {},
  Set<String> selectedCategoryIds = const {},
  Set<String> selectedProjectIds = const {},
  Set<String> selectedLabelIds = const {},
  Set<String> selectedPriorities = const {},
  Set<String> selectedTaskStatuses = const {'OPEN', 'GROOMED', 'IN PROGRESS'},
  TaskSortOption sortOption = TaskSortOption.byPriority,
  AgentAssignmentFilter agentAssignmentFilter = AgentAssignmentFilter.all,
  Set<DisplayFilter> filters = const {},
  String query = '',
  bool enableVectorSearch = false,
  SearchMode searchMode = SearchMode.fullText,
  bool enableEvents = true,
  bool enableHabits = true,
  bool enableDashboards = true,
}) {
  return JournalQueryParams(
    showTasks: showTasks,
    selectedEntryTypes: selectedEntryTypes,
    selectedCategoryIds: selectedCategoryIds,
    selectedProjectIds: selectedProjectIds,
    selectedLabelIds: selectedLabelIds,
    selectedPriorities: selectedPriorities,
    selectedTaskStatuses: selectedTaskStatuses,
    sortOption: sortOption,
    agentAssignmentFilter: agentAssignmentFilter,
    filters: filters,
    query: query,
    enableVectorSearch: enableVectorSearch,
    searchMode: searchMode,
    enableEvents: enableEvents,
    enableHabits: enableHabits,
    enableDashboards: enableDashboards,
  );
}

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
      final withDue = _makeTask(
        id: 'with-due',
        createdAt: DateTime(2024, 1, 1),
        due: DateTime(2024, 6, 15),
      );
      final withoutDue = _makeTask(
        id: 'without-due',
        createdAt: DateTime(2024, 1, 2),
      );

      final sorted = JournalQueryRunner.sortByDueDate([withoutDue, withDue]);

      expect(sorted.first.meta.id, equals('with-due'));
      expect(sorted.last.meta.id, equals('without-due'));
    });

    test('sorts tasks by due date ascending (soonest first)', () {
      final sooner = _makeTask(
        id: 'sooner',
        createdAt: DateTime(2024, 1, 1),
        due: DateTime(2024, 3, 1),
      );
      final later = _makeTask(
        id: 'later',
        createdAt: DateTime(2024, 1, 2),
        due: DateTime(2024, 9, 1),
      );

      final sorted = JournalQueryRunner.sortByDueDate([later, sooner]);

      expect(sorted.first.meta.id, equals('sooner'));
      expect(sorted.last.meta.id, equals('later'));
    });

    test('preserves creation date order for same due date', () {
      final newer = _makeTask(
        id: 'newer',
        createdAt: DateTime(2024, 2, 1),
        due: DateTime(2024, 6, 15),
      );
      final older = _makeTask(
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
      final dueSoon = _makeTask(
        id: 'due-soon',
        createdAt: DateTime(2024, 1, 1),
        due: DateTime(2024, 3, 1),
      );
      final dueLate = _makeTask(
        id: 'due-late',
        createdAt: DateTime(2024, 1, 2),
        due: DateTime(2024, 12, 1),
      );
      final noDue1 = _makeTask(
        id: 'no-due-newer',
        createdAt: DateTime(2024, 3, 1),
      );
      final noDue2 = _makeTask(
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
        final newest = _makeTask(
          id: 'newest',
          createdAt: DateTime(2024, 6, 1),
        );
        final middle = _makeTask(
          id: 'middle',
          createdAt: DateTime(2024, 3, 1),
        );
        final oldest = _makeTask(
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
  });

  group('runQuery - journal entries', () {
    test('calls getJournalEntities for showTasks=false', () {
      fakeAsync((async) {
        final entry = _makeEntry(id: 'e-1', createdAt: _testDate);

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

        final params = _defaultParams();

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
        final params = _defaultParams(
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
        final params = _defaultParams(
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
        final task = _makeTask(id: 'task-1', createdAt: _testDate);

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

        final params = _defaultParams(
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

    test('applies sortByDueDate when sortOption is byDueDate', () {
      fakeAsync((async) {
        final taskNoDue = _makeTask(
          id: 'no-due',
          createdAt: DateTime(2024, 1, 1),
        );
        final taskWithDue = _makeTask(
          id: 'with-due',
          createdAt: DateTime(2024, 1, 2),
          due: DateTime(2024, 6, 1),
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
        ).thenAnswer((_) async => [taskNoDue, taskWithDue]);

        final params = _defaultParams(
          showTasks: true,
          sortOption: TaskSortOption.byDueDate,
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        // with-due should come before no-due after sort
        expect(result.first.meta.id, equals('with-due'));
        expect(result.last.meta.id, equals('no-due'));
      });
    });
  });

  group('runQuery - tasks with post-filter', () {
    test('post-filters by project IDs', () {
      fakeAsync((async) {
        final taskInProject = _makeTask(
          id: 'in-project',
          createdAt: _testDate,
        );
        final taskNotInProject = _makeTask(
          id: 'not-in-project',
          createdAt: _testDate,
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

        final params = _defaultParams(
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

        final agentTask = _makeTask(
          id: 'agent-task',
          createdAt: _testDate,
        );
        final noAgentTask = _makeTask(
          id: 'no-agent-task',
          createdAt: _testDate,
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

        final params = _defaultParams(
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

        final agentTask = _makeTask(
          id: 'agent-task',
          createdAt: _testDate,
        );
        final noAgentTask = _makeTask(
          id: 'no-agent-task',
          createdAt: _testDate,
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

        final params = _defaultParams(
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

    test('calls setPostFilterNextRawOffset with correct offset', () {
      fakeAsync((async) {
        final tasks = List.generate(
          3,
          (i) => _makeTask(id: 'task-$i', createdAt: _testDate),
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

        final params = _defaultParams(
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
          final params = _defaultParams(
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

        final task = _makeTask(id: 'vec-task', createdAt: _testDate);
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

        final params = _defaultParams(
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

        final entry = _makeEntry(id: 'vec-entry', createdAt: _testDate);
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

        final params = _defaultParams(
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

        final params = _defaultParams(
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

        final params = _defaultParams(
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
