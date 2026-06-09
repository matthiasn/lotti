import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show ExploreConfig, Glados, Glados2, Glados3, any;
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

  int compareByTimeSpentThenPriorityModel(
    TaskDayProgress a,
    TaskDayProgress b,
  ) {
    final aHasTime = a.timeSpentOnDay > Duration.zero;
    final bHasTime = b.timeSpentOnDay > Duration.zero;

    if (aHasTime && bHasTime) {
      final timeCompare = b.timeSpentOnDay.compareTo(a.timeSpentOnDay);
      if (timeCompare != 0) return timeCompare;
      return compareByPriorityUrgencyTitleModel(a, b);
    }

    if (aHasTime) return -1;
    if (bHasTime) return 1;

    return compareByPriorityUrgencyTitleModel(a, b);
  }

  List<String> sortedIds(
    List<TaskDayProgress> items,
    int Function(TaskDayProgress a, TaskDayProgress b) compare,
  ) {
    return (items.toList()..sort(compare)).map((item) => item.task.id).toList();
  }

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

    Glados(any.taskProgressSpecs, ExploreConfig(numRuns: 180)).test(
      'matches the generated time-spent ordering model',
      (specs) {
        final items = createGeneratedProgress(specs);

        expect(
          sortedIds(items, TaskSortComparators.byTimeSpentThenPriority),
          sortedIds(items, compareByTimeSpentThenPriorityModel),
          reason:
              'Generated specs should match the documented time-spent '
              'model: $specs',
        );
      },
      tags: 'glados',
    );
  });

  group('TaskSortComparators — comparator properties', () {
    // Transitivity: if compare(a,b)<0 and compare(b,c)<0 then compare(a,c)<0.
    Glados3(
      any.taskProgressSpec,
      any.taskProgressSpec,
      any.taskProgressSpec,
      ExploreConfig(numRuns: 120),
    ).test(
      'byPriorityUrgencyTitle is transitive',
      (specA, specB, specC) {
        final a = createProgress(
          id: 'ta',
          title: specA.titleFor(0),
          priority: specA.priority,
          urgency: specA.urgency,
        );
        final b = createProgress(
          id: 'tb',
          title: specB.titleFor(1),
          priority: specB.priority,
          urgency: specB.urgency,
        );
        final c = createProgress(
          id: 'tc',
          title: specC.titleFor(2),
          priority: specC.priority,
          urgency: specC.urgency,
        );
        final ab = TaskSortComparators.byPriorityUrgencyTitle(a, b);
        final bc = TaskSortComparators.byPriorityUrgencyTitle(b, c);
        final ac = TaskSortComparators.byPriorityUrgencyTitle(a, c);
        if (ab < 0 && bc < 0) {
          expect(
            ac,
            lessThan(0),
            reason: 'transitivity: a<b and b<c implies a<c',
          );
        }
      },
      tags: 'glados',
    );

    // Antisymmetry: sign(compare(a,b)) == -sign(compare(b,a)) unless zero.
    Glados2(
      any.taskProgressSpec,
      any.taskProgressSpec,
      ExploreConfig(numRuns: 120),
    ).test(
      'byPriorityUrgencyTitle is antisymmetric',
      (specA, specB) {
        final a = createProgress(
          id: 'ta',
          title: specA.titleFor(0),
          priority: specA.priority,
          urgency: specA.urgency,
        );
        final b = createProgress(
          id: 'tb',
          title: specB.titleFor(1),
          priority: specB.priority,
          urgency: specB.urgency,
        );
        final ab = TaskSortComparators.byPriorityUrgencyTitle(a, b);
        final ba = TaskSortComparators.byPriorityUrgencyTitle(b, a);
        if (ab != 0) {
          expect(
            ab.sign,
            equals(-ba.sign),
            reason: 'antisymmetry: sign(a,b) == -sign(b,a) when non-zero',
          );
        } else {
          expect(ba, isZero, reason: 'both must be zero or both non-zero');
        }
      },
      tags: 'glados',
    );

    // Transitivity for byTimeSpentThenPriority.
    Glados3(
      any.taskProgressSpec,
      any.taskProgressSpec,
      any.taskProgressSpec,
      ExploreConfig(numRuns: 120),
    ).test(
      'byTimeSpentThenPriority is transitive',
      (specA, specB, specC) {
        final a = createProgress(
          id: 'ta',
          title: specA.titleFor(0),
          priority: specA.priority,
          urgency: specA.urgency,
          timeSpent: Duration(minutes: specA.timeSpentMinutes),
        );
        final b = createProgress(
          id: 'tb',
          title: specB.titleFor(1),
          priority: specB.priority,
          urgency: specB.urgency,
          timeSpent: Duration(minutes: specB.timeSpentMinutes),
        );
        final c = createProgress(
          id: 'tc',
          title: specC.titleFor(2),
          priority: specC.priority,
          urgency: specC.urgency,
          timeSpent: Duration(minutes: specC.timeSpentMinutes),
        );
        final ab = TaskSortComparators.byTimeSpentThenPriority(a, b);
        final bc = TaskSortComparators.byTimeSpentThenPriority(b, c);
        final ac = TaskSortComparators.byTimeSpentThenPriority(a, c);
        if (ab < 0 && bc < 0) {
          expect(
            ac,
            lessThan(0),
            reason: 'transitivity: a<b and b<c implies a<c',
          );
        }
      },
      tags: 'glados',
    );

    // Antisymmetry for byTimeSpentThenPriority.
    Glados2(
      any.taskProgressSpec,
      any.taskProgressSpec,
      ExploreConfig(numRuns: 120),
    ).test(
      'byTimeSpentThenPriority is antisymmetric',
      (specA, specB) {
        final a = createProgress(
          id: 'ta',
          title: specA.titleFor(0),
          priority: specA.priority,
          urgency: specA.urgency,
          timeSpent: Duration(minutes: specA.timeSpentMinutes),
        );
        final b = createProgress(
          id: 'tb',
          title: specB.titleFor(1),
          priority: specB.priority,
          urgency: specB.urgency,
          timeSpent: Duration(minutes: specB.timeSpentMinutes),
        );
        final ab = TaskSortComparators.byTimeSpentThenPriority(a, b);
        final ba = TaskSortComparators.byTimeSpentThenPriority(b, a);
        if (ab != 0) {
          expect(
            ab.sign,
            equals(-ba.sign),
            reason: 'antisymmetry: sign(a,b) == -sign(b,a) when non-zero',
          );
        } else {
          expect(ba, isZero, reason: 'both must be zero or both non-zero');
        }
      },
      tags: 'glados',
    );
  });
}
