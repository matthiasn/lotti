import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show ExploreConfig, Glados, any;
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_data.dart';
import 'task_list_detail_state_test_helpers.dart';

void main() {
  group('TaskListDetailState', () {
    test('selects the matching task when visible', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: '',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState(),
      );

      expect(state.selectedTask?.task.meta.id, 'payment-confirmation');
      expect(state.visibleSections.first.title, 'Today');
      expect(state.visibleSections.first.tasks.length, 3);
    });

    test('filters visible tasks by search query across title and project', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: 'device sync',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState(),
      );

      expect(
        state.visibleTasks.map((record) => record.task.meta.id),
        ['payment-confirmation'],
      );
    });

    test('filters visible tasks by selected priority', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: '',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState().copyWith(
          selectedPriorityIds: const {TaskPriorityFilterIds.p1},
        ),
      );

      expect(
        state.visibleTasks.every(
          (record) => record.task.data.priority.short == 'P1',
        ),
        isTrue,
      );
      expect(
        state.visibleTasks.map((record) => record.task.meta.id),
        containsAll([
          'payment-confirmation',
          'sprint-planning',
          'customer-onboarding',
          'marketing-campaign',
        ]),
      );
    });

    test('filters visible tasks by selected label', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: '',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState().copyWith(
          labelField: const DesignSystemTaskFilterFieldState(
            label: 'Labels',
            options: [
              DesignSystemTaskFilterOption(id: 'bug-fix', label: 'Bug fix'),
              DesignSystemTaskFilterOption(
                id: 'release-blocker',
                label: 'Release blocker',
              ),
            ],
            selectedIds: {'release-blocker'},
          ),
        ),
      );

      expect(
        state.visibleTasks.map((record) => record.task.meta.id),
        ['payment-confirmation'],
      );
    });

    test(
      'createdDateSort orders same-section tasks by createdAt descending',
      () {
        // Two records in the same section (same sectionDate) with distinct
        // createdAt. This forces the createdDateSort branch and its
        // `createdCompare != 0` guard to decide the order (newest first).
        final older = hRecord(
          id: 'older',
          title:
              'Zeta', // alphabetically last, to prove title is not the tie-breaker
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 8),
          status: hOpen(DateTime(2026, 4, 1, 8)),
        );
        final newer = hRecord(
          id: 'newer',
          title: 'Alpha',
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 12),
          status: hOpen(DateTime(2026, 4, 1, 12)),
        );

        final state = hStateWith(
          [older, newer],
          sortId: TaskSortIds.createdDateSort,
        );

        expect(
          state.visibleTasks.map((record) => record.task.meta.id),
          ['newer', 'older'],
        );
      },
    );

    test(
      'createdDateSort falls through to title when createdAt is equal',
      () {
        // Same section, identical createdAt -> createdCompare == 0, so the
        // comparator must fall through to the title tie-breaker.
        final createdAt = DateTime(2026, 4, 1, 9);
        final bravo = hRecord(
          id: 'bravo',
          title: 'Bravo',
          sectionDate: DateTime(2026, 4),
          createdAt: createdAt,
          status: hOpen(createdAt),
        );
        final alpha = hRecord(
          id: 'alpha',
          title: 'Alpha',
          sectionDate: DateTime(2026, 4),
          createdAt: createdAt,
          status: hOpen(createdAt),
        );

        final state = hStateWith(
          [bravo, alpha],
          sortId: TaskSortIds.createdDateSort,
        );

        expect(
          state.visibleTasks.map((record) => record.task.meta.id),
          ['alpha', 'bravo'],
        );
      },
    );

    test('dueDateSort places a null due after a non-null due', () {
      // Same section, exactly one record has a null due. The due-date sort
      // branch must order the record with a due before the one without.
      final withDue = hRecord(
        id: 'with-due',
        title: 'Zeta', // last alphabetically, to prove due drives the order
        sectionDate: DateTime(2026, 4),
        createdAt: DateTime(2026, 4, 1, 8),
        status: hOpen(DateTime(2026, 4, 1, 8)),
        due: DateTime(2026, 4, 5),
      );
      final withoutDue = hRecord(
        id: 'without-due',
        title: 'Alpha',
        sectionDate: DateTime(2026, 4),
        createdAt: DateTime(2026, 4, 1, 9),
        status: hOpen(DateTime(2026, 4, 1, 9)),
      );

      final state = hStateWith(
        [withoutDue, withDue],
        sortId: TaskSortIds.dueDateSort,
      );

      expect(
        state.visibleTasks.map((record) => record.task.meta.id),
        ['with-due', 'without-due'],
      );
    });

    test(
      'dueDateSort orders two non-null due dates ascending, ignoring title',
      () {
        // Same section, both records have a non-null due. This forces the
        // `leftDue != null && rightDue != null` arm and its `dueCompare != 0`
        // guard (the branch the Glados generator only hits opportunistically)
        // to decide the order: the earlier due date sorts first. Titles are
        // chosen so the title tie-breaker would invert the order if it ran.
        final earlierDue = hRecord(
          id: 'earlier-due',
          title: 'Zeta', // alphabetically last, must NOT win
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 8),
          status: hOpen(DateTime(2026, 4, 1, 8)),
          due: DateTime(2026, 4, 3),
        );
        final laterDue = hRecord(
          id: 'later-due',
          title: 'Alpha', // alphabetically first, must NOT win
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 9),
          status: hOpen(DateTime(2026, 4, 1, 9)),
          due: DateTime(2026, 4, 9),
        );

        final state = hStateWith(
          [laterDue, earlierDue],
          sortId: TaskSortIds.dueDateSort,
        );

        expect(
          state.visibleTasks.map((record) => record.task.meta.id),
          ['earlier-due', 'later-due'],
        );
      },
    );

    test(
      'dueDateSort falls through to title when both due dates are equal',
      () {
        // Same section, identical non-null due -> dueCompare == 0, so the
        // comparator must fall through to the title tie-breaker even though the
        // due-date arm was entered.
        final due = DateTime(2026, 4, 5);
        final bravo = hRecord(
          id: 'bravo',
          title: 'Bravo',
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 8),
          status: hOpen(DateTime(2026, 4, 1, 8)),
          due: due,
        );
        final alpha = hRecord(
          id: 'alpha',
          title: 'Alpha',
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 9),
          status: hOpen(DateTime(2026, 4, 1, 9)),
          due: due,
        );

        final state = hStateWith(
          [bravo, alpha],
          sortId: TaskSortIds.dueDateSort,
        );

        expect(
          state.visibleTasks.map((record) => record.task.meta.id),
          ['alpha', 'bravo'],
        );
      },
    );

    test(
      'status filter matches done and rejected tasks via hStatusFilterId',
      () {
        // Exercises the TaskDone and TaskRejected arms of hStatusFilterId,
        // which the showcase mock data never produces.
        final done = hRecord(
          id: 'done-task',
          title: 'Done',
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 8),
          status: TaskStatus.done(
            id: 'done-status',
            createdAt: DateTime(2026, 4, 1, 8),
            utcOffset: 0,
          ),
        );
        final rejected = hRecord(
          id: 'rejected-task',
          title: 'Rejected',
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 9),
          status: TaskStatus.rejected(
            id: 'rejected-status',
            createdAt: DateTime(2026, 4, 1, 9),
            utcOffset: 0,
          ),
        );
        final open = hRecord(
          id: 'open-task',
          title: 'Open',
          sectionDate: DateTime(2026, 4),
          createdAt: DateTime(2026, 4, 1, 10),
          status: hOpen(DateTime(2026, 4, 1, 10)),
        );

        final tasks = [done, rejected, open];

        final doneOnly = TaskListDetailState(
          data: hDataWith(tasks),
          searchQuery: '',
          selectedTaskId: '',
          filterState: buildTaskShowcaseFilterState().copyWith(
            statusField: buildTaskShowcaseFilterState().statusField?.copyWith(
              selectedIds: const {TaskStatusFilterIds.done},
            ),
          ),
        );
        expect(
          doneOnly.visibleTasks.map((record) => record.task.meta.id),
          ['done-task'],
        );

        final rejectedOnly = TaskListDetailState(
          data: hDataWith(tasks),
          searchQuery: '',
          selectedTaskId: '',
          filterState: buildTaskShowcaseFilterState().copyWith(
            statusField: buildTaskShowcaseFilterState().statusField?.copyWith(
              selectedIds: const {TaskStatusFilterIds.rejected},
            ),
          ),
        );
        expect(
          rejectedOnly.visibleTasks.map((record) => record.task.meta.id),
          ['rejected-task'],
        );
      },
    );

    Glados(any.taskListScenario, ExploreConfig(numRuns: 180)).test(
      'matches the generated task filtering and sorting model',
      (scenario) {
        final data = buildTaskListDetailMockData();
        final state = TaskListDetailState(
          data: data,
          searchQuery: scenario.query,
          selectedTaskId: scenario.selectedTaskId(data),
          filterState: hFilterStateFor(scenario),
        );
        final expected = hExpectedVisibleTasks(data, scenario);

        expect(
          state.visibleTasks.map((record) => record.task.meta.id),
          expected.map((record) => record.task.meta.id),
          reason: 'visibleTasks should match the model for $scenario',
        );

        expect(
          state.visibleSections.expand((section) => section.tasks),
          state.visibleTasks,
          reason: 'visibleSections should flatten back to visibleTasks',
        );

        for (var i = 0; i < state.visibleSections.length - 1; i++) {
          expect(
            state.visibleSections[i].sectionDate.compareTo(
              state.visibleSections[i + 1].sectionDate,
            ),
            greaterThanOrEqualTo(0),
          );
        }

        final selectedTaskId = scenario.selectedTaskId(data);
        final expectedSelected =
            expected
                .where((record) => record.task.meta.id == selectedTaskId)
                .firstOrNull ??
            expected.firstOrNull;
        expect(state.selectedTask, expectedSelected);
      },
      tags: 'glados',
    );
  });
}
