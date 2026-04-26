import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';

class _MockAgentRepository extends Mock implements AgentRepository {}

void main() {
  late MockJournalDb db;
  late MockEntitiesCacheService cache;
  late _MockAgentRepository agentRepo;
  late SavedTaskFilterCountRepository sut;

  CategoryDefinition makeCategory(String id) => CategoryDefinition(
    id: id,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    name: 'Cat $id',
    vectorClock: null,
    private: false,
    active: true,
  );

  setUp(() {
    db = MockJournalDb();
    cache = MockEntitiesCacheService();
    agentRepo = _MockAgentRepository();

    when(() => cache.sortedCategories).thenReturn([
      makeCategory('cat-1'),
      makeCategory('cat-2'),
    ]);
    when(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const <JournalEntity>[]);

    sut = SavedTaskFilterCountRepository(
      db: db,
      cache: cache,
      agentRepository: agentRepo,
    );
  });

  test('returns 0 when no statuses are selected (fail-fast guard)', () async {
    final c = await sut.count(const TasksFilter());
    expect(c, 0);
    verifyNever(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    );
  });

  test('counts tasks returned by getTasks when no post-filters are active',
      () async {
    when(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => [
        TestTaskFactory.create(id: 't1', title: 'a', categoryId: 'cat-1'),
        TestTaskFactory.create(id: 't2', title: 'b', categoryId: 'cat-1'),
        TestTaskFactory.create(id: 't3', title: 'c', categoryId: 'cat-1'),
      ],
    );

    final c = await sut.count(
      const TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
    );
    expect(c, 3);
  });

  test('expands empty category selection to all known categories + ""',
      () async {
    final captured = <List<String>>[];
    when(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: captureAny(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      captured.add(
        invocation.namedArguments[#categoryIds] as List<String>,
      );
      return const <JournalEntity>[];
    });

    await sut.count(
      const TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
    );

    expect(captured.single.toSet(), {'cat-1', 'cat-2', ''});
  });

  test('applies project post-filter', () async {
    when(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => [
        TestTaskFactory.create(id: 't1', title: 'a', categoryId: 'cat-1'),
        TestTaskFactory.create(id: 't2', title: 'b', categoryId: 'cat-1'),
        TestTaskFactory.create(id: 't3', title: 'c', categoryId: 'cat-1'),
      ],
    );
    when(() => db.getTaskIdsForProjects({'proj-1'}))
        .thenAnswer((_) async => {'t1', 't3'});

    final c = await sut.count(
      const TasksFilter(
        selectedTaskStatuses: {'IN_PROGRESS'},
        selectedProjectIds: {'proj-1'},
      ),
    );
    expect(c, 2);
  });

  test('applies hasAgent agent post-filter', () async {
    when(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => [
        TestTaskFactory.create(id: 't1', title: 'a', categoryId: 'cat-1'),
        TestTaskFactory.create(id: 't2', title: 'b', categoryId: 'cat-1'),
      ],
    );
    when(() => agentRepo.getTaskIdsWithAgentLink())
        .thenAnswer((_) async => {'t1'});

    final hasAgent = await sut.count(
      const TasksFilter(
        selectedTaskStatuses: {'IN_PROGRESS'},
        agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
      ),
    );
    expect(hasAgent, 1);

    final noAgent = await sut.count(
      const TasksFilter(
        selectedTaskStatuses: {'IN_PROGRESS'},
        agentAssignmentFilter: AgentAssignmentFilter.noAgent,
      ),
    );
    expect(noAgent, 1);
  });

  test('combines project and agent post-filters (intersection)', () async {
    when(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => [
        TestTaskFactory.create(id: 't1', title: 'a', categoryId: 'cat-1'),
        TestTaskFactory.create(id: 't2', title: 'b', categoryId: 'cat-1'),
        TestTaskFactory.create(id: 't3', title: 'c', categoryId: 'cat-1'),
      ],
    );
    when(() => db.getTaskIdsForProjects({'proj-1'}))
        .thenAnswer((_) async => {'t1', 't2'});
    when(() => agentRepo.getTaskIdsWithAgentLink())
        .thenAnswer((_) async => {'t2', 't3'});

    final c = await sut.count(
      const TasksFilter(
        selectedTaskStatuses: {'IN_PROGRESS'},
        selectedProjectIds: {'proj-1'},
        agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
      ),
    );
    // t1: project ✓, agent ✗
    // t2: project ✓, agent ✓ → counted
    // t3: project ✗
    expect(c, 1);
  });
}
