import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  late MockJournalDb db;
  late MockEntitiesCacheService cache;
  late MockAgentRepository agentRepo;
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
    agentRepo = MockAgentRepository();

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

  test(
    'zero known categories still queries with the empty-string sentinel',
    () async {
      // The expansion branch always appends '' — even with an empty cache
      // the query runs against [''] rather than short-circuiting to 0.
      when(() => cache.sortedCategories).thenReturn(const []);
      when(
        () => db.getFilteredTasksCount(
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          labelIds: any(named: 'labelIds'),
          priorities: any(named: 'priorities'),
        ),
      ).thenAnswer((_) async => 3);

      final c = await sut.count(
        const TasksFilter(selectedTaskStatuses: {'OPEN'}),
      );

      expect(c, 3);
      final captured =
          verify(
                () => db.getFilteredTasksCount(
                  taskStatuses: any(named: 'taskStatuses'),
                  categoryIds: captureAny(named: 'categoryIds'),
                  labelIds: any(named: 'labelIds'),
                  priorities: any(named: 'priorities'),
                ),
              ).captured.single
              as List<String>;
      expect(captured, ['']);
    },
  );

  test('an explicit category selection queries only those categories, '
      'without the uncategorised sentinel', () async {
    await sut.count(
      const TasksFilter(
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {'cat-2'},
      ),
    );

    final captured =
        verify(
              () => db.getFilteredTasksCount(
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: captureAny(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
              ),
            ).captured.single
            as List<String>;
    expect(captured, ['cat-2']);
    verifyNever(() => cache.sortedCategories);
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

  group('due-date clause', () {
    // 15:00 on 3 Jul 2024, fixed for both the repository and the stubs.
    final now = DateTime(2024, 7, 3, 15);
    const open = TasksFilter(selectedTaskStatuses: {'OPEN', 'IN PROGRESS'});

    void stubDue({
      Set<String> overdue = const {},
      Set<String> dueToday = const {},
    }) {
      when(
        () => db.getOpenTaskIdsForDueFilter(TaskDueFilter.overdue, now: now),
      ).thenAnswer((_) async => overdue);
      when(
        () => db.getOpenTaskIdsForDueFilter(TaskDueFilter.dueToday, now: now),
      ).thenAnswer((_) async => dueToday);
      when(
        () => db.getOpenTaskIdsByDueWindow(now: now),
      ).thenAnswer((_) async => (overdue: overdue, dueToday: dueToday));
    }

    void verifyIdListFetches(int times) {
      Future<List<String>> idList() => db.getFilteredTaskIds(
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
      );
      if (times == 0) {
        verifyNever(idList);
      } else {
        verify(idList).called(times);
      }
    }

    void stubMatchingIds(List<String> ids) {
      when(
        () => db.getFilteredTaskIds(
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          labelIds: any(named: 'labelIds'),
          priorities: any(named: 'priorities'),
        ),
      ).thenAnswer((_) async => ids);
    }

    Future<T> atNow<T>(Future<T> Function() body) =>
        withClock(Clock.fixed(now), body);

    test('a due clause intersects the matching ids with the due set — '
        'Due today never counts an overdue task', () async {
      stubDue(overdue: {'late'}, dueToday: {'today-a', 'today-b'});
      // 'today-b' is due today but outside the filter's other clauses.
      stubMatchingIds(const ['late', 'today-a', 'later']);

      final dueToday = await atNow(
        () => sut.count(open.copyWith(dueFilter: TaskDueFilter.dueToday)),
      );
      final overdue = await atNow(
        () => sut.count(open.copyWith(dueFilter: TaskDueFilter.overdue)),
      );

      expect(dueToday, 1);
      expect(overdue, 1);
      // The SQL COUNT path cannot see the due set, so it is bypassed.
      verifyNever(
        () => db.getFilteredTasksCount(
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          labelIds: any(named: 'labelIds'),
          priorities: any(named: 'priorities'),
        ),
      );
    });

    test(
      'an empty due window short-circuits to 0 without an id fetch',
      () async {
        stubDue();

        final c = await atNow(
          () => sut.count(open.copyWith(dueFilter: TaskDueFilter.overdue)),
        );

        expect(c, 0);
        verifyNever(
          () => db.getFilteredTaskIds(
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
          ),
        );
      },
    );

    test('the due clause composes with the project post-filter', () async {
      stubDue(overdue: {'t1', 't2'});
      stubMatchingIds(const ['t1', 't2', 't3']);
      when(
        () => db.getTaskIdsForProjects({'proj-1'}),
      ).thenAnswer((_) async => {'t2', 't3'});

      final c = await atNow(
        () => sut.count(
          open.copyWith(
            dueFilter: TaskDueFilter.overdue,
            selectedProjectIds: {'proj-1'},
          ),
        ),
      );

      expect(c, 1);
    });

    test('a search restriction narrows the due count to its matches', () async {
      stubDue(overdue: {'late-a', 'late-b'});
      stubMatchingIds(const ['late-a', 'late-b']);

      final c = await atNow(
        () => sut.count(
          open.copyWith(dueFilter: TaskDueFilter.overdue),
          restrictToIds: {'late-b', 'unrelated'},
        ),
      );

      expect(c, 1);
    });

    test('a search restriction alone moves off the COUNT path', () async {
      stubMatchingIds(const ['a', 'b', 'c']);

      expect(await sut.count(open, restrictToIds: {'b', 'c', 'x'}), 2);
      expect(await sut.count(open, restrictToIds: const {}), 0);
      verifyNever(
        () => db.getFilteredTasksCount(
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          labelIds: any(named: 'labelIds'),
          priorities: any(named: 'priorities'),
        ),
      );
    });

    group('dueUrgencies', () {
      Future<List<DueDateUrgency>> urgencies(List<TasksFilter> filters) =>
          atNow(() => sut.dueUrgencies(filters));

      test('overdue outranks due today', () async {
        stubDue(overdue: {'late'}, dueToday: {'today'});
        stubMatchingIds(const ['late', 'today']);

        expect(await urgencies([open]), [DueDateUrgency.overdue]);
      });

      test('reads due today when nothing it matches is overdue', () async {
        // Something is overdue, but not inside this filter.
        stubDue(overdue: {'elsewhere'}, dueToday: {'today'});
        stubMatchingIds(const ['today']);

        expect(await urgencies([open]), [DueDateUrgency.dueToday]);
      });

      test('reads normal when nothing it matches is due', () async {
        stubDue(overdue: {'elsewhere'}, dueToday: {'elsewhere-too'});
        stubMatchingIds(const ['undated']);

        expect(await urgencies([open]), [DueDateUrgency.normal]);
      });

      test("honours each filter's own due clause", () async {
        stubDue(overdue: {'late'}, dueToday: {'today'});
        stubMatchingIds(const ['late', 'today']);

        expect(
          await urgencies([
            // A saved Due today view cannot contain an overdue task.
            open.copyWith(dueFilter: TaskDueFilter.dueToday),
            open.copyWith(dueFilter: TaskDueFilter.overdue),
          ]),
          [DueDateUrgency.dueToday, DueDateUrgency.overdue],
        );
      });

      test('a saved Overdue view never falls back to due today', () async {
        stubDue(dueToday: {'today'});
        stubMatchingIds(const ['today']);

        expect(
          await urgencies([open.copyWith(dueFilter: TaskDueFilter.overdue)]),
          [DueDateUrgency.normal],
        );
        // Its only window is empty: no id list is worth fetching.
        verifyIdListFetches(0);
      });

      test('N filters cost one window read and one id list each', () async {
        stubDue(overdue: {'late'}, dueToday: {'today'});
        stubMatchingIds(const ['today', 'undated']);

        final result = await urgencies([open, open, open]);

        expect(result, List.filled(3, DueDateUrgency.dueToday));
        verify(() => db.getOpenTaskIdsByDueWindow(now: now)).called(1);
        // Not 2 per filter: both windows are checked against one list.
        verifyIdListFetches(3);
        for (final window in [TaskDueFilter.overdue, TaskDueFilter.dueToday]) {
          verifyNever(
            () => db.getOpenTaskIdsForDueFilter(window, now: any(named: 'now')),
          );
        }
      });

      test('nothing due by tonight costs one read and no id lists', () async {
        stubDue();

        expect(
          await urgencies([open, open]),
          List.filled(2, DueDateUrgency.normal),
        );
        verifyIdListFetches(0);
      });

      test('the agent-link set is read once for the whole batch', () async {
        stubDue(overdue: {'t1'});
        stubMatchingIds(const ['t1', 't2']);
        when(
          () => agentRepo.getTaskIdsWithAgentLink(),
        ).thenAnswer((_) async => {'t1'});
        const withAgent = TasksFilter(
          selectedTaskStatuses: {'OPEN'},
          agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
        );
        const withoutAgent = TasksFilter(
          selectedTaskStatuses: {'OPEN'},
          agentAssignmentFilter: AgentAssignmentFilter.noAgent,
        );

        expect(await urgencies([withAgent, withoutAgent, withAgent]), [
          DueDateUrgency.overdue,
          DueDateUrgency.normal,
          DueDateUrgency.overdue,
        ]);
        verify(() => agentRepo.getTaskIdsWithAgentLink()).called(1);
      });

      test('a filter with no statuses matches nothing', () async {
        stubDue(overdue: {'late'});
        stubMatchingIds(const ['late']);

        expect(await urgencies([const TasksFilter()]), [
          DueDateUrgency.normal,
        ]);
        verifyIdListFetches(0);
      });

      test('no filters, no reads', () async {
        expect(await urgencies(const []), isEmpty);
        verifyNever(() => db.getOpenTaskIdsByDueWindow(now: any(named: 'now')));
      });
    });

    group('dueViewCounts', () {
      test('counts both views from one window read and one id list', () async {
        stubDue(overdue: {'late-a', 'late-b'}, dueToday: {'today'});
        stubMatchingIds(const ['late-a', 'today', 'undated']);

        final counts = await atNow(() => sut.dueViewCounts(open));

        expect((counts.overdue, counts.dueToday), (1, 1));
        verify(() => db.getOpenTaskIdsByDueWindow(now: now)).called(1);
        verifyIdListFetches(1);
      });

      test("ignores the filter's own due clause", () async {
        stubDue(overdue: {'late'}, dueToday: {'today'});
        stubMatchingIds(const ['late', 'today']);

        final counts = await atNow(
          () => sut.dueViewCounts(
            open.copyWith(dueFilter: TaskDueFilter.overdue),
          ),
        );

        expect((counts.overdue, counts.dueToday), (1, 1));
      });

      test('a search restriction narrows both views', () async {
        stubDue(overdue: {'late-a', 'late-b'}, dueToday: {'today'});
        stubMatchingIds(const ['late-a', 'late-b', 'today']);

        final counts = await atNow(
          () => sut.dueViewCounts(open, restrictToIds: {'late-b'}),
        );

        expect((counts.overdue, counts.dueToday), (1, 0));
      });

      test('short-circuits to zero without an id list', () async {
        stubDue();
        expect((await atNow(() => sut.dueViewCounts(open))).overdue, 0);
        expect(
          (await atNow(
            () => sut.dueViewCounts(open, restrictToIds: const {}),
          )).dueToday,
          0,
        );
        expect(
          (await atNow(() => sut.dueViewCounts(const TasksFilter()))).overdue,
          0,
        );
        verifyIdListFetches(0);
      });
    });
  });
}
