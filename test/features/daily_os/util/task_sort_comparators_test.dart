import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/util/task_sort_comparators.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';

void main() {
  final testDate = DateTime(2026, 1, 15, 12);

  Task createTask({
    required String id,
    required String title,
    TaskPriority priority = TaskPriority.p2Medium,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: TaskData(
        title: title,
        dateFrom: testDate,
        dateTo: testDate,
        priority: priority,
        statusHistory: [],
        status: TaskStatus.inProgress(
          id: 'status-$id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    );
  }

  TaskDayProgress createProgress({
    required String id,
    required String title,
    TaskPriority priority = TaskPriority.p2Medium,
    Duration timeSpent = Duration.zero,
    DueDateUrgency urgency = DueDateUrgency.normal,
  }) {
    return TaskDayProgress(
      task: createTask(id: id, title: title, priority: priority),
      timeSpentOnDay: timeSpent,
      wasCompletedOnDay: false,
      dueDateStatus: DueDateStatus(
        urgency: urgency,
        daysUntilDue: urgency == DueDateUrgency.overdue
            ? -1
            : urgency == DueDateUrgency.dueToday
                ? 0
                : 5,
      ),
    );
  }

  group('TaskSortComparators.byPriorityUrgencyTitle', () {
    group('priority ordering', () {
      test('P0 comes before P1', () {
        final p0 = createProgress(
            id: '1', title: 'A', priority: TaskPriority.p0Urgent);
        final p1 =
            createProgress(id: '2', title: 'A', priority: TaskPriority.p1High);

        expect(TaskSortComparators.byPriorityUrgencyTitle(p0, p1), lessThan(0));
        expect(
            TaskSortComparators.byPriorityUrgencyTitle(p1, p0), greaterThan(0));
      });

      test('P1 comes before P2', () {
        final p1 =
            createProgress(id: '1', title: 'A', priority: TaskPriority.p1High);
        final p2 = createProgress(id: '2', title: 'A');

        expect(TaskSortComparators.byPriorityUrgencyTitle(p1, p2), lessThan(0));
      });

      test('P2 comes before P3', () {
        final p2 = createProgress(id: '1', title: 'A');
        final p3 =
            createProgress(id: '2', title: 'A', priority: TaskPriority.p3Low);

        expect(TaskSortComparators.byPriorityUrgencyTitle(p2, p3), lessThan(0));
      });

      test('sorts list by priority correctly', () {
        final items = [
          createProgress(id: '1', title: 'Low', priority: TaskPriority.p3Low),
          createProgress(
              id: '2', title: 'Urgent', priority: TaskPriority.p0Urgent),
          createProgress(id: '3', title: 'Medium'),
          createProgress(id: '4', title: 'High', priority: TaskPriority.p1High),
        ];

        expect(
          (items..sort(TaskSortComparators.byPriorityUrgencyTitle))
              .map((e) => e.task.data.title)
              .toList(),
          ['Urgent', 'High', 'Medium', 'Low'], // P0, P1, P2, P3
        );
      });
    });

    group('urgency ordering (same priority)', () {
      test('overdue comes before dueToday', () {
        final overdue = createProgress(
          id: '1',
          title: 'A',
          urgency: DueDateUrgency.overdue,
        );
        final dueToday = createProgress(
          id: '2',
          title: 'A',
          urgency: DueDateUrgency.dueToday,
        );

        expect(
          TaskSortComparators.byPriorityUrgencyTitle(overdue, dueToday),
          lessThan(0),
        );
      });

      test('dueToday comes before none', () {
        final dueToday = createProgress(
          id: '1',
          title: 'A',
          urgency: DueDateUrgency.dueToday,
        );
        final none = createProgress(
          id: '2',
          title: 'A',
        );

        expect(
          TaskSortComparators.byPriorityUrgencyTitle(dueToday, none),
          lessThan(0),
        );
      });

      test('sorts list by urgency when priority is equal', () {
        final items = [
          createProgress(id: '1', title: 'None'),
          createProgress(
              id: '2', title: 'Overdue', urgency: DueDateUrgency.overdue),
          createProgress(
              id: '3', title: 'DueToday', urgency: DueDateUrgency.dueToday),
        ];

        expect(
          (items..sort(TaskSortComparators.byPriorityUrgencyTitle))
              .map((e) => e.task.data.title)
              .toList(),
          ['Overdue', 'DueToday', 'None'],
        );
      });
    });

    group('alphabetical ordering (same priority and urgency)', () {
      test('A comes before B', () {
        final a = createProgress(id: '1', title: 'Apple');
        final b = createProgress(id: '2', title: 'Banana');

        expect(TaskSortComparators.byPriorityUrgencyTitle(a, b), lessThan(0));
        expect(
            TaskSortComparators.byPriorityUrgencyTitle(b, a), greaterThan(0));
      });

      test('equal titles return 0', () {
        final a = createProgress(id: '1', title: 'Same');
        final b = createProgress(id: '2', title: 'Same');

        expect(TaskSortComparators.byPriorityUrgencyTitle(a, b), equals(0));
      });

      test('sorts list alphabetically when priority and urgency are equal', () {
        final items = [
          createProgress(id: '1', title: 'Zebra'),
          createProgress(id: '2', title: 'Apple'),
          createProgress(id: '3', title: 'Mango'),
        ];

        expect(
          (items..sort(TaskSortComparators.byPriorityUrgencyTitle))
              .map((e) => e.task.data.title)
              .toList(),
          ['Apple', 'Mango', 'Zebra'],
        );
      });
    });

    group('combined ordering', () {
      test('priority takes precedence over urgency', () {
        final p0None = createProgress(
          id: '1',
          title: 'A',
          priority: TaskPriority.p0Urgent,
        );
        final p1Overdue = createProgress(
          id: '2',
          title: 'A',
          priority: TaskPriority.p1High,
          urgency: DueDateUrgency.overdue,
        );

        // P0 should come first even though P1 is overdue
        expect(
          TaskSortComparators.byPriorityUrgencyTitle(p0None, p1Overdue),
          lessThan(0),
        );
      });

      test('urgency takes precedence over title', () {
        final overdueZ = createProgress(
          id: '1',
          title: 'Zebra',
          urgency: DueDateUrgency.overdue,
        );
        final noneA = createProgress(
          id: '2',
          title: 'Apple',
        );

        // Overdue should come first even though 'Apple' < 'Zebra'
        expect(
          TaskSortComparators.byPriorityUrgencyTitle(overdueZ, noneA),
          lessThan(0),
        );
      });

      test('complex sort with all factors', () {
        final items = [
          createProgress(
            id: '1',
            title: 'P2 None Z',
          ),
          createProgress(
            id: '2',
            title: 'P0 None A',
            priority: TaskPriority.p0Urgent,
          ),
          createProgress(
            id: '3',
            title: 'P1 Overdue B',
            priority: TaskPriority.p1High,
            urgency: DueDateUrgency.overdue,
          ),
          createProgress(
            id: '4',
            title: 'P1 DueToday A',
            priority: TaskPriority.p1High,
            urgency: DueDateUrgency.dueToday,
          ),
          createProgress(
            id: '5',
            title: 'P1 DueToday C',
            priority: TaskPriority.p1High,
            urgency: DueDateUrgency.dueToday,
          ),
        ];

        expect(
          (items..sort(TaskSortComparators.byPriorityUrgencyTitle))
              .map((e) => e.task.data.title)
              .toList(),
          [
            'P0 None A', // P0 first (highest priority)
            'P1 Overdue B', // P1, overdue (most urgent within P1)
            'P1 DueToday A', // P1, dueToday, alphabetically first
            'P1 DueToday C', // P1, dueToday, alphabetically second
            'P2 None Z', // P2 last (lowest priority of those present)
          ],
        );
      });
    });
  });

  group('TaskSortComparators.byTimeSpentThenPriority', () {
    group('time-based ordering', () {
      test('more time comes before less time', () {
        final moreTime = createProgress(
          id: '1',
          title: 'A',
          timeSpent: const Duration(hours: 2),
        );
        final lessTime = createProgress(
          id: '2',
          title: 'A',
          timeSpent: const Duration(hours: 1),
        );

        expect(
          TaskSortComparators.byTimeSpentThenPriority(moreTime, lessTime),
          lessThan(0),
        );
      });

      test('task with time comes before task without time', () {
        final withTime = createProgress(
          id: '1',
          title: 'Z', // Later alphabetically
          priority: TaskPriority.p3Low, // Lower priority
          timeSpent: const Duration(minutes: 1),
        );
        final noTime = createProgress(
          id: '2',
          title: 'A', // Earlier alphabetically
          priority: TaskPriority.p0Urgent, // Higher priority
        );

        // With time comes first, regardless of priority or title
        expect(
          TaskSortComparators.byTimeSpentThenPriority(withTime, noTime),
          lessThan(0),
        );
      });

      test('equal time falls back to priority ordering', () {
        final p0 = createProgress(
          id: '1',
          title: 'A',
          priority: TaskPriority.p0Urgent,
          timeSpent: const Duration(hours: 1),
        );
        final p3 = createProgress(
          id: '2',
          title: 'A',
          priority: TaskPriority.p3Low,
          timeSpent: const Duration(hours: 1),
        );

        expect(
          TaskSortComparators.byTimeSpentThenPriority(p0, p3),
          lessThan(0),
        );
      });

      test('zero time tasks fall back to priority ordering', () {
        final p0 = createProgress(
          id: '1',
          title: 'A',
          priority: TaskPriority.p0Urgent,
        );
        final p3 = createProgress(
          id: '2',
          title: 'A',
          priority: TaskPriority.p3Low,
        );

        expect(
          TaskSortComparators.byTimeSpentThenPriority(p0, p3),
          lessThan(0),
        );
      });
    });

    group('comprehensive sorting', () {
      test('sorts list with mixed time and priorities', () {
        final items = [
          createProgress(
            id: '1',
            title: 'No time P3',
            priority: TaskPriority.p3Low,
          ),
          createProgress(
            id: '2',
            title: '1h P0',
            priority: TaskPriority.p0Urgent,
            timeSpent: const Duration(hours: 1),
          ),
          createProgress(
            id: '3',
            title: 'No time P0',
            priority: TaskPriority.p0Urgent,
          ),
          createProgress(
            id: '4',
            title: '2h P3',
            priority: TaskPriority.p3Low,
            timeSpent: const Duration(hours: 2),
          ),
          createProgress(
            id: '5',
            title: '30m P1',
            priority: TaskPriority.p1High,
            timeSpent: const Duration(minutes: 30),
          ),
        ];

        expect(
          (items..sort(TaskSortComparators.byTimeSpentThenPriority))
              .map((e) => e.task.data.title)
              .toList(),
          [
            '2h P3', // Most time (2h)
            '1h P0', // Second most time (1h)
            '30m P1', // Third most time (30m)
            'No time P0', // Zero time, P0 (highest priority among zero-time)
            'No time P3', // Zero time, P3 (lowest priority among zero-time)
          ],
        );
      });

      test('zero time tasks sorted by urgency after priority', () {
        final items = [
          createProgress(
            id: '1',
            title: 'P1 None',
            priority: TaskPriority.p1High,
          ),
          createProgress(
            id: '2',
            title: 'P1 Overdue',
            priority: TaskPriority.p1High,
            urgency: DueDateUrgency.overdue,
          ),
          createProgress(
            id: '3',
            title: 'P1 DueToday',
            priority: TaskPriority.p1High,
            urgency: DueDateUrgency.dueToday,
          ),
        ];

        expect(
          (items..sort(TaskSortComparators.byTimeSpentThenPriority))
              .map((e) => e.task.data.title)
              .toList(),
          ['P1 Overdue', 'P1 DueToday', 'P1 None'],
        );
      });
    });
  });
}
