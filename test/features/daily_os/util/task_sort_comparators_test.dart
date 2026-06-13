import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show ExploreConfig, Glados, any;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/util/task_sort_comparators.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'task_sort_comparators_test_helpers.dart';

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

  List<TaskDayProgress> createGeneratedProgress(
    List<GeneratedTaskProgressSpec> specs,
  ) {
    return [
      for (var index = 0; index < specs.length; index++)
        createProgress(
          id: 'generated-$index',
          title: specs[index].titleFor(index),
          priority: specs[index].priority,
          timeSpent: Duration(minutes: specs[index].timeSpentMinutes),
          urgency: specs[index].urgency,
        ),
    ];
  }

  int compareByPriorityUrgencyTitleModel(
    TaskDayProgress a,
    TaskDayProgress b,
  ) {
    final priorityCompare = a.task.data.priority.rank.compareTo(
      b.task.data.priority.rank,
    );
    if (priorityCompare != 0) return priorityCompare;

    final urgencyCompare = b.dueDateStatus.urgency.index.compareTo(
      a.dueDateStatus.urgency.index,
    );
    if (urgencyCompare != 0) return urgencyCompare;

    return a.task.data.title.compareTo(b.task.data.title);
  }

  List<String> sortedIds(
    List<TaskDayProgress> items,
    int Function(TaskDayProgress a, TaskDayProgress b) compare,
  ) {
    return (items.toList()..sort(compare)).map((item) => item.task.id).toList();
  }

  group('TaskSortComparators.byPriorityUrgencyTitle', () {
    group('priority ordering', () {
      test('P0 comes before P1', () {
        final p0 = createProgress(
          id: '1',
          title: 'A',
          priority: TaskPriority.p0Urgent,
        );
        final p1 = createProgress(
          id: '2',
          title: 'A',
          priority: TaskPriority.p1High,
        );

        expect(TaskSortComparators.byPriorityUrgencyTitle(p0, p1), lessThan(0));
        expect(
          TaskSortComparators.byPriorityUrgencyTitle(p1, p0),
          greaterThan(0),
        );
      });

      test('P1 comes before P2', () {
        final p1 = createProgress(
          id: '1',
          title: 'A',
          priority: TaskPriority.p1High,
        );
        final p2 = createProgress(id: '2', title: 'A');

        expect(TaskSortComparators.byPriorityUrgencyTitle(p1, p2), lessThan(0));
      });

      test('P2 comes before P3', () {
        final p2 = createProgress(id: '1', title: 'A');
        final p3 = createProgress(
          id: '2',
          title: 'A',
          priority: TaskPriority.p3Low,
        );

        expect(TaskSortComparators.byPriorityUrgencyTitle(p2, p3), lessThan(0));
      });

      test('sorts list by priority correctly', () {
        final items = [
          createProgress(id: '1', title: 'Low', priority: TaskPriority.p3Low),
          createProgress(
            id: '2',
            title: 'Urgent',
            priority: TaskPriority.p0Urgent,
          ),
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
            id: '2',
            title: 'Overdue',
            urgency: DueDateUrgency.overdue,
          ),
          createProgress(
            id: '3',
            title: 'DueToday',
            urgency: DueDateUrgency.dueToday,
          ),
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
          TaskSortComparators.byPriorityUrgencyTitle(b, a),
          greaterThan(0),
        );
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

    Glados(any.taskProgressSpecs, ExploreConfig(numRuns: 180)).test(
      'matches the generated priority, urgency, and title ordering model',
      (specs) {
        final items = createGeneratedProgress(specs);

        expect(
          sortedIds(items, TaskSortComparators.byPriorityUrgencyTitle),
          sortedIds(items, compareByPriorityUrgencyTitleModel),
          reason:
              'Generated specs should match the documented comparator '
              'model: $specs',
        );
      },
      tags: 'glados',
    );
  });
}
