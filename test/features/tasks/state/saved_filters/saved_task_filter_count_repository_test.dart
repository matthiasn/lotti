import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:mocktail/mocktail.dart';

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
      () => db.getFilteredTasksCount(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => db.getFilteredTaskIds(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    ).thenAnswer((_) async => const <String>[]);

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
      () => db.getFilteredTasksCount(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    );
  });

  test('uses the SQL COUNT path when no post-filters are active', () async {
    when(
      () => db.getFilteredTasksCount(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    ).thenAnswer((_) async => 7);

    final c = await sut.count(
      const TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
    );

    expect(c, 7);
    verifyNever(
      () => db.getFilteredTaskIds(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    );
  });

  test(
    'expands empty category selection to all known categories + ""',
    () async {
      final captured = <List<String>>[];
      when(
        () => db.getFilteredTasksCount(
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: captureAny(named: 'categoryIds'),
          labelIds: any(named: 'labelIds'),
          priorities: any(named: 'priorities'),
        ),
      ).thenAnswer((invocation) async {
        captured.add(
          invocation.namedArguments[#categoryIds] as List<String>,
        );
        return 0;
      });

      await sut.count(
        const TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
      );

      expect(captured.single.toSet(), {'cat-1', 'cat-2', ''});
    },
  );

  test('intersects with project ids when project filter is active', () async {
    when(
      () => db.getFilteredTaskIds(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    ).thenAnswer((_) async => const ['t1', 't2', 't3']);
    when(
      () => db.getTaskIdsForProjects({'proj-1'}),
    ).thenAnswer((_) async => {'t1', 't3'});

    final c = await sut.count(
      const TasksFilter(
        selectedTaskStatuses: {'IN_PROGRESS'},
        selectedProjectIds: {'proj-1'},
      ),
    );

    expect(c, 2);
    // The COUNT path is bypassed when post-filters are active.
    verifyNever(
      () => db.getFilteredTasksCount(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    );
  });

  test('applies hasAgent and noAgent post-filters', () async {
    when(
      () => db.getFilteredTaskIds(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    ).thenAnswer((_) async => const ['t1', 't2']);
    when(
      () => agentRepo.getTaskIdsWithAgentLink(),
    ).thenAnswer((_) async => {'t1'});

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
      () => db.getFilteredTaskIds(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      ),
    ).thenAnswer((_) async => const ['t1', 't2', 't3']);
    when(
      () => db.getTaskIdsForProjects({'proj-1'}),
    ).thenAnswer((_) async => {'t1', 't2'});
    when(
      () => agentRepo.getTaskIdsWithAgentLink(),
    ).thenAnswer((_) async => {'t2', 't3'});

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
