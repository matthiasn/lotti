import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_task_groups.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';

import '../../test_utils.dart';

void main() {
  final now = DateTime(2026, 9, 5, 12);

  TaskStatus status(String kind, DateTime at) => switch (kind) {
    'open' => TaskStatus.open(id: 's', createdAt: at, utcOffset: 0),
    'inProgress' => TaskStatus.inProgress(id: 's', createdAt: at, utcOffset: 0),
    'groomed' => TaskStatus.groomed(id: 's', createdAt: at, utcOffset: 0),
    'blocked' => TaskStatus.blocked(
      id: 's',
      createdAt: at,
      utcOffset: 0,
      reason: 'waiting',
    ),
    'onHold' => TaskStatus.onHold(
      id: 's',
      createdAt: at,
      utcOffset: 0,
      reason: 'later',
    ),
    'done' => TaskStatus.done(id: 's', createdAt: at, utcOffset: 0),
    'rejected' => TaskStatus.rejected(id: 's', createdAt: at, utcOffset: 0),
    _ => throw ArgumentError(kind),
  };

  TaskSummary summary(
    String id,
    String title, {
    DateTime? createdAt,
    DateTime? updatedAt,
    String state = 'open',
    DateTime? due,
    TaskPriority priority = TaskPriority.p2Medium,
    Duration estimate = Duration.zero,
  }) {
    final created = createdAt ?? now;
    final task = makeTestTask(id: id, title: title, createdAt: created);
    return TaskSummary(
      task: task.copyWith(
        meta: task.meta.copyWith(updatedAt: updatedAt ?? created),
        data: task.data.copyWith(
          status: status(state, created),
          due: due,
          priority: priority,
          estimate: estimate == Duration.zero ? null : estimate,
        ),
      ),
      estimatedDuration: estimate,
    );
  }

  List<String> titles(ProjectTaskGroup group) =>
      group.tasks.map((s) => s.task.data.title).toList();

  group('groupProjectTasks', () {
    test('groups by creation month, newest first, and folds done tasks', () {
      final groups = groupProjectTasks(
        [
          summary('a', 'August open', createdAt: DateTime(2026, 8, 3)),
          summary(
            'b',
            'September blocked',
            createdAt: DateTime(2026, 9, 2),
            state: 'blocked',
          ),
          summary('c', 'September open', createdAt: DateTime(2026, 9)),
          summary(
            'd',
            'August done',
            createdAt: DateTime(2026, 8, 20),
            state: 'done',
          ),
        ],
        options: ProjectTaskListOptions.defaults,
        now: now,
      );

      expect(groups.map((g) => g.key.id), [
        'month:2026-9',
        'month:2026-8',
        'done',
      ]);
      expect(
        titles(groups[0]),
        ['September blocked', 'September open'],
        reason: 'Actionability puts the blocked task first.',
      );
      expect(titles(groups[1]), ['August open']);
      expect(groups[2].key, const ProjectTaskDoneKey());
      expect(titles(groups[2]), ['August done']);
      expect(groups.every((g) => g.hasHeader), isTrue);
    });

    test('rejected tasks fold with done ones, in every grouping', () {
      for (final groupBy in ProjectTaskGroupBy.values) {
        final groups = groupProjectTasks(
          [
            summary('a', 'Open'),
            summary('b', 'Rejected', state: 'rejected'),
            summary('c', 'Done', state: 'done'),
          ],
          options: ProjectTaskListOptions(groupBy: groupBy),
          now: now,
        );
        expect(groups.last.key, const ProjectTaskDoneKey(), reason: '$groupBy');
        expect(titles(groups.last), ['Done', 'Rejected'], reason: '$groupBy');
        expect(
          groups.sublist(0, groups.length - 1).expand(titles),
          ['Open'],
          reason: '$groupBy',
        );
      }
    });

    test('keepDoneInGroups keeps done tasks in their groups', () {
      final groups = groupProjectTasks(
        [
          summary('a', 'Open', createdAt: DateTime(2026, 8, 3)),
          summary(
            'b',
            'Done',
            createdAt: DateTime(2026, 8, 20),
            state: 'done',
          ),
        ],
        options: const ProjectTaskListOptions(keepDoneInGroups: true),
        now: now,
      );

      expect(groups, hasLength(1));
      expect(titles(groups.single), ['Open', 'Done']);
    });

    test('groups by status in actionability order', () {
      final groups = groupProjectTasks(
        [
          summary('a', 'Open'),
          summary('b', 'In progress', state: 'inProgress'),
          summary('c', 'Blocked', state: 'blocked'),
          summary('d', 'On hold', state: 'onHold'),
          summary('e', 'Groomed', state: 'groomed'),
        ],
        options: const ProjectTaskListOptions(
          groupBy: ProjectTaskGroupBy.status,
        ),
        now: now,
      );

      expect(groups.map((g) => titles(g).single), [
        'Blocked',
        'On hold',
        'In progress',
        'Open',
        'Groomed',
      ]);
      expect(groups.first.key, isA<ProjectTaskStatusKey>());
    });

    test('groups by priority, highest first', () {
      final groups = groupProjectTasks(
        [
          summary('a', 'Low', priority: TaskPriority.p3Low),
          summary('b', 'Urgent', priority: TaskPriority.p0Urgent),
          summary('c', 'Medium'),
          summary('d', 'High', priority: TaskPriority.p1High),
        ],
        options: const ProjectTaskListOptions(
          groupBy: ProjectTaskGroupBy.priority,
        ),
        now: now,
      );

      expect(groups.map((g) => (g.key as ProjectTaskPriorityKey).priority), [
        TaskPriority.p0Urgent,
        TaskPriority.p1High,
        TaskPriority.p2Medium,
        TaskPriority.p3Low,
      ]);
    });

    test('groups by due window relative to today', () {
      final groups = groupProjectTasks(
        [
          summary('a', 'Undated'),
          summary('b', 'Next month', due: DateTime(2026, 10)),
          summary('c', 'Yesterday', due: DateTime(2026, 9, 4, 23)),
          summary('d', 'Today', due: DateTime(2026, 9, 5, 8)),
          summary('e', 'In six days', due: DateTime(2026, 9, 11)),
          summary('f', 'In seven days', due: DateTime(2026, 9, 12)),
        ],
        options: const ProjectTaskListOptions(
          groupBy: ProjectTaskGroupBy.dueWindow,
        ),
        now: now,
      );

      expect(groups.map((g) => (g.key as ProjectTaskDueWindowKey).window), [
        ProjectDueWindow.overdue,
        ProjectDueWindow.thisWeek,
        ProjectDueWindow.later,
        ProjectDueWindow.none,
      ]);
      expect(titles(groups[0]), ['Yesterday']);
      expect(titles(groups[1]), ['Today', 'In six days']);
      expect(titles(groups[2]), ['In seven days', 'Next month']);
      expect(titles(groups[3]), ['Undated']);
    });

    test('grouping by nothing yields one header-less group', () {
      final groups = groupProjectTasks(
        [summary('a', 'One'), summary('b', 'Two')],
        options: const ProjectTaskListOptions(groupBy: ProjectTaskGroupBy.none),
        now: now,
      );

      expect(groups, hasLength(1));
      expect(groups.single.hasHeader, isFalse);
      expect(groups.single.key, const ProjectTaskAllKey());
    });

    test('an empty list yields no groups', () {
      expect(
        groupProjectTasks(
          const [],
          options: ProjectTaskListOptions.defaults,
          now: now,
        ),
        isEmpty,
      );
    });

    test('a group totals the estimates of its tasks', () {
      final group = groupProjectTasks(
        [
          summary('a', 'One', estimate: const Duration(minutes: 30)),
          summary('b', 'Two', estimate: const Duration(hours: 1)),
        ],
        options: const ProjectTaskListOptions(groupBy: ProjectTaskGroupBy.none),
        now: now,
      ).single;

      expect(group.totalDuration, const Duration(hours: 1, minutes: 30));
    });
  });

  group('compareProjectTaskSummaries', () {
    final older = summary(
      'older',
      'Beta',
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 9, 4),
      due: DateTime(2026, 9, 20),
      priority: TaskPriority.p3Low,
      estimate: const Duration(hours: 2),
    );
    final newer = summary(
      'newer',
      'Alpha',
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9, 2),
      due: DateTime(2026, 9, 10),
      priority: TaskPriority.p1High,
      estimate: const Duration(minutes: 30),
    );
    final undated = summary(
      'undated',
      'Gamma',
      createdAt: DateTime(2026, 7),
    );

    List<String> sorted(ProjectTaskSortBy sortBy) =>
        ([older, newer, undated]
              ..sort((a, b) => compareProjectTaskSummaries(a, b, sortBy)))
            .map((s) => s.task.data.title)
            .toList();

    test('each sort key orders the way its label promises', () {
      expect(sorted(ProjectTaskSortBy.created), ['Alpha', 'Beta', 'Gamma']);
      expect(sorted(ProjectTaskSortBy.dueDate), ['Alpha', 'Beta', 'Gamma']);
      expect(sorted(ProjectTaskSortBy.estimate), ['Beta', 'Alpha', 'Gamma']);
      expect(sorted(ProjectTaskSortBy.priority), ['Alpha', 'Gamma', 'Beta']);
      expect(sorted(ProjectTaskSortBy.recentlyUpdated), [
        'Beta',
        'Alpha',
        'Gamma',
      ]);
      expect(sorted(ProjectTaskSortBy.title), ['Alpha', 'Beta', 'Gamma']);
      expect(
        sorted(ProjectTaskSortBy.actionability),
        ['Alpha', 'Beta', 'Gamma'],
        reason: 'Same status: sooner due date first, undated last.',
      );
    });

    test('actionability ranks status before anything else', () {
      final blocked = summary('b', 'Zulu', state: 'blocked');
      final open = summary('o', 'Alpha', due: DateTime(2026, 9, 6));
      expect(compareTasksByActionability(blocked.task, open.task), lessThan(0));
      expect(taskStatusRank(blocked.task.data.status), 0);
      expect(taskStatusRank(open.task.data.status), 3);
    });

    test('ties break on title, then id, never on input order', () {
      final a = summary('a', 'Same');
      final b = summary('b', 'Same');
      expect(
        compareProjectTaskSummaries(a, b, ProjectTaskSortBy.title),
        lessThan(0),
      );
      expect(
        compareProjectTaskSummaries(b, a, ProjectTaskSortBy.title),
        greaterThan(0),
      );
    });
  });

  group('projectDueWindow', () {
    test('buckets relative to the start of today', () {
      expect(projectDueWindow(null, now), ProjectDueWindow.none);
      expect(
        projectDueWindow(DateTime(2026, 9, 4, 23, 59), now),
        ProjectDueWindow.overdue,
      );
      expect(
        projectDueWindow(DateTime(2026, 9, 5), now),
        ProjectDueWindow.thisWeek,
      );
      expect(
        projectDueWindow(DateTime(2026, 9, 11, 23), now),
        ProjectDueWindow.thisWeek,
      );
      expect(
        projectDueWindow(DateTime(2026, 9, 12), now),
        ProjectDueWindow.later,
      );
    });
  });

  group('properties', () {
    final anyKind = glados.any.choose([
      'open',
      'inProgress',
      'groomed',
      'blocked',
      'onHold',
      'done',
      'rejected',
    ]);
    final anyTask = glados.any.combine3(
      glados.any.int,
      anyKind,
      glados.any.int,
      (int seed, String kind, int day) => summary(
        'id-${seed.abs()}',
        'Task ${seed.abs() % 7}',
        createdAt: DateTime(2026, 1 + day.abs() % 12, 1 + day.abs() % 28),
        state: kind,
        due: seed.isEven ? null : DateTime(2026, 9, 1 + seed.abs() % 30),
        priority: TaskPriority.values[seed.abs() % 4],
        estimate: Duration(minutes: seed.abs() % 240),
      ),
    );
    final anyOptions = glados.any.combine3(
      glados.any.choose(ProjectTaskGroupBy.values),
      glados.any.choose(ProjectTaskSortBy.values),
      glados.any.bool,
      (ProjectTaskGroupBy g, ProjectTaskSortBy s, bool d) =>
          ProjectTaskListOptions(groupBy: g, sortBy: s, keepDoneInGroups: d),
    );

    /// The generator may repeat an id; the list a project holds never does.
    List<TaskSummary> uniqueIds(List<TaskSummary> tasks) => [
      for (final (index, summary) in tasks.indexed)
        TaskSummary(
          task: summary.task.copyWith(
            meta: summary.task.meta.copyWith(id: 'task-$index'),
          ),
          estimatedDuration: summary.estimatedDuration,
        ),
    ];

    glados.Glados2(glados.any.list(anyTask), anyOptions).test(
      'grouping keeps every task exactly once, sorted within its group, and '
      'folds done tasks only when asked',
      (generated, options) {
        final tasks = uniqueIds(generated);
        final groups = groupProjectTasks(tasks, options: options, now: now);

        final seen = groups.expand((g) => g.tasks).toList();
        expect(seen.length, tasks.length);
        expect(seen.toSet(), tasks.toSet());
        for (final group in groups) {
          for (var i = 1; i < group.tasks.length; i++) {
            expect(
              compareProjectTaskSummaries(
                group.tasks[i - 1],
                group.tasks[i],
                options.sortBy,
              ),
              lessThanOrEqualTo(0),
            );
          }
          bool closed(TaskSummary s) =>
              s.task.data.status is TaskDone ||
              s.task.data.status is TaskRejected;
          if (group.key is ProjectTaskDoneKey) {
            expect(options.keepDoneInGroups, isFalse);
            expect(group.tasks.every(closed), isTrue);
            expect(group, same(groups.last));
          } else if (!options.keepDoneInGroups) {
            expect(group.tasks.any(closed), isFalse);
          }
        }
        expect(groups.where((g) => g.tasks.isEmpty), isEmpty);
        if (options.groupBy == ProjectTaskGroupBy.none) {
          expect(
            groups.where((g) => g.hasHeader && g.key is! ProjectTaskDoneKey),
            isEmpty,
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2(glados.any.list(anyTask), anyOptions).test(
      'grouping is independent of input order',
      (generated, options) {
        final tasks = uniqueIds(generated);
        final forward = groupProjectTasks(tasks, options: options, now: now);
        final backward = groupProjectTasks(
          tasks.reversed.toList(),
          options: options,
          now: now,
        );
        String shape(List<ProjectTaskGroup> groups) => groups
            .map(
              (g) =>
                  '${g.key.id}:${g.tasks.map((s) => s.task.meta.id).join(',')}',
            )
            .join('|');
        expect(shape(backward), shape(forward));
      },
      tags: 'glados',
    );
  });
}
