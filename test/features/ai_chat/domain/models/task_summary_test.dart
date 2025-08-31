import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/domain/models/task_summary.dart';

void main() {
  group('TaskSummary', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    group('basic properties', () {
      test('creates TaskSummary with required fields', () {
        final summary = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(summary.taskId, equals('task1'));
        expect(summary.taskName, equals('Test Task'));
        expect(summary.createdAt, equals(testDate));
        expect(summary.completedAt, isNull);
        expect(summary.categoryId, isNull);
        expect(summary.categoryName, isNull);
        expect(summary.tags, isNull);
        expect(summary.aiSummary, isNull);
        expect(summary.timeLogged, isNull);
        expect(summary.status, isNull);
        expect(summary.metadata, isNull);
      });

      test('creates TaskSummary with all fields', () {
        final completedAt = testDate.add(const Duration(hours: 2));
        const timeLogged = Duration(hours: 1, minutes: 30);
        final tags = ['urgent', 'development'];
        final metadata = {'priority': 'high', 'project': 'ai-chat'};

        final summary = TaskSummary(
          taskId: 'task1',
          taskName: 'Complete Feature',
          createdAt: testDate,
          completedAt: completedAt,
          categoryId: 'cat1',
          categoryName: 'Development',
          tags: tags,
          aiSummary: 'AI generated summary of task completion',
          timeLogged: timeLogged,
          status: TaskStatus.completed,
          metadata: metadata,
        );

        expect(summary.taskId, equals('task1'));
        expect(summary.taskName, equals('Complete Feature'));
        expect(summary.createdAt, equals(testDate));
        expect(summary.completedAt, equals(completedAt));
        expect(summary.categoryId, equals('cat1'));
        expect(summary.categoryName, equals('Development'));
        expect(summary.tags, equals(tags));
        expect(summary.aiSummary,
            equals('AI generated summary of task completion'));
        expect(summary.timeLogged, equals(timeLogged));
        expect(summary.status, equals(TaskStatus.completed));
        expect(summary.metadata, equals(metadata));
      });
    });

    group('extension methods', () {
      test('isCompleted returns true when completedAt is set', () {
        final completed = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          completedAt: testDate.add(const Duration(hours: 1)),
        );

        final incomplete = TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(completed.isCompleted, isTrue);
        expect(incomplete.isCompleted, isFalse);
      });

      test('hasAiSummary returns true when summary exists and is not empty',
          () {
        final withSummary = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          aiSummary: 'This is a summary',
        );

        final withEmptySummary = TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
          aiSummary: '',
        );

        final withoutSummary = TaskSummary(
          taskId: 'task3',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(withSummary.hasAiSummary, isTrue);
        expect(withEmptySummary.hasAiSummary, isFalse);
        expect(withoutSummary.hasAiSummary, isFalse);
      });

      test('hasTimeLogged returns true when time logged is greater than zero',
          () {
        final withTime = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          timeLogged: const Duration(minutes: 30),
        );

        final withZeroTime = TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
          timeLogged: Duration.zero,
        );

        final withoutTime = TaskSummary(
          taskId: 'task3',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(withTime.hasTimeLogged, isTrue);
        expect(withZeroTime.hasTimeLogged, isFalse);
        expect(withoutTime.hasTimeLogged, isFalse);
      });

      test('hasTags returns true when tags exist and are not empty', () {
        final withTags = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          tags: ['tag1', 'tag2'],
        );

        final withEmptyTags = TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
          tags: [],
        );

        final withoutTags = TaskSummary(
          taskId: 'task3',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(withTags.hasTags, isTrue);
        expect(withEmptyTags.hasTags, isFalse);
        expect(withoutTags.hasTags, isFalse);
      });

      test('displayName returns task name or default for empty name', () {
        final withName = TaskSummary(
          taskId: 'task1',
          taskName: 'My Task',
          createdAt: testDate,
        );

        final withEmptyName = TaskSummary(
          taskId: 'task2',
          taskName: '',
          createdAt: testDate,
        );

        expect(withName.displayName, equals('My Task'));
        expect(withEmptyName.displayName, equals('Untitled Task'));
      });

      test('statusText returns correct text for each status', () {
        final completed = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          status: TaskStatus.completed,
        );

        final inProgress = TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
          status: TaskStatus.inProgress,
        );

        final planned = TaskSummary(
          taskId: 'task3',
          taskName: 'Test Task',
          createdAt: testDate,
          status: TaskStatus.planned,
        );

        final cancelled = TaskSummary(
          taskId: 'task4',
          taskName: 'Test Task',
          createdAt: testDate,
          status: TaskStatus.cancelled,
        );

        final unknown = TaskSummary(
          taskId: 'task5',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(completed.statusText, equals('Completed'));
        expect(inProgress.statusText, equals('In Progress'));
        expect(planned.statusText, equals('Planned'));
        expect(cancelled.statusText, equals('Cancelled'));
        expect(unknown.statusText, equals('Unknown'));
      });

      test('loggedTimeOrZero returns time logged or zero', () {
        final withTime = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          timeLogged: const Duration(hours: 2, minutes: 30),
        );

        final withoutTime = TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(withTime.loggedTimeOrZero,
            equals(const Duration(hours: 2, minutes: 30)));
        expect(withoutTime.loggedTimeOrZero, equals(Duration.zero));
      });

      test('formattedTimeLogged formats time correctly', () {
        final hoursAndMinutes = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          timeLogged: const Duration(hours: 2, minutes: 30),
        );

        final minutesOnly = TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
          timeLogged: const Duration(minutes: 45),
        );

        final secondsOnly = TaskSummary(
          taskId: 'task3',
          taskName: 'Test Task',
          createdAt: testDate,
          timeLogged: const Duration(seconds: 30),
        );

        final noTime = TaskSummary(
          taskId: 'task4',
          taskName: 'Test Task',
          createdAt: testDate,
        );

        expect(hoursAndMinutes.formattedTimeLogged, equals('2h 30m'));
        expect(minutesOnly.formattedTimeLogged, equals('45m'));
        expect(secondsOnly.formattedTimeLogged, equals('30s'));
        expect(noTime.formattedTimeLogged, equals('0s'));
      });
    });

    group('JSON serialization', () {
      test('toJson and fromJson work correctly', () {
        final original = TaskSummary(
          taskId: 'task1',
          taskName: 'Test Task',
          createdAt: testDate,
          completedAt: testDate.add(const Duration(hours: 2)),
          categoryId: 'cat1',
          categoryName: 'Development',
          tags: ['urgent', 'development'],
          aiSummary: 'AI generated summary',
          timeLogged: const Duration(hours: 1, minutes: 30),
          status: TaskStatus.completed,
          metadata: {'priority': 'high'},
        );

        final json = original.toJson();
        final deserialized = TaskSummary.fromJson(json);

        expect(deserialized.taskId, equals(original.taskId));
        expect(deserialized.taskName, equals(original.taskName));
        expect(deserialized.createdAt, equals(original.createdAt));
        expect(deserialized.completedAt, equals(original.completedAt));
        expect(deserialized.categoryId, equals(original.categoryId));
        expect(deserialized.categoryName, equals(original.categoryName));
        expect(deserialized.tags, equals(original.tags));
        expect(deserialized.aiSummary, equals(original.aiSummary));
        expect(deserialized.timeLogged, equals(original.timeLogged));
        expect(deserialized.status, equals(original.status));
        expect(deserialized.metadata, equals(original.metadata));
      });
    });
  });

  group('TaskSummaryResult', () {
    final testDate = DateTime(2024, 1, 15);

    test('creates empty result correctly', () {
      final startDate = DateTime(2024);
      final endDate = DateTime(2024, 1, 31);

      final result = TaskSummaryResult.empty(startDate, endDate);

      expect(result.tasks, isEmpty);
      expect(result.queryStartDate, equals(startDate));
      expect(result.queryEndDate, equals(endDate));
      expect(result.totalCount, equals(0));
      expect(result.isEmpty, isTrue);
      expect(result.hasResults, isFalse);
    });

    test('calculates aggregated values correctly', () {
      final tasks = [
        TaskSummary(
          taskId: 'task1',
          taskName: 'Completed Task',
          createdAt: testDate,
          completedAt: testDate.add(const Duration(hours: 2)),
          timeLogged: const Duration(hours: 1),
          aiSummary: 'Summary 1',
          status: TaskStatus.completed,
          categoryName: 'Development',
        ),
        TaskSummary(
          taskId: 'task2',
          taskName: 'In Progress Task',
          createdAt: testDate,
          timeLogged: const Duration(minutes: 30),
          status: TaskStatus.inProgress,
          categoryName: 'Development',
        ),
        TaskSummary(
          taskId: 'task3',
          taskName: 'Another Completed Task',
          createdAt: testDate,
          completedAt: testDate.add(const Duration(hours: 3)),
          timeLogged: const Duration(hours: 2, minutes: 30),
          aiSummary: 'Summary 2',
          status: TaskStatus.completed,
          categoryName: 'Testing',
        ),
      ];

      final result = TaskSummaryResult(
        tasks: tasks,
        queryStartDate: DateTime(2024),
        queryEndDate: DateTime(2024, 1, 31),
        totalCount: tasks.length,
      );

      expect(result.totalTimeLogged, equals(const Duration(hours: 4)));
      expect(result.completedTasksCount, equals(2));
      expect(result.tasksWithAiSummaryCount, equals(2));
      expect(result.completedTasks.length, equals(2));
      expect(result.incompleteTasks.length, equals(1));
      expect(result.tasksWithTimeLogged.length, equals(3));
    });

    test('groups tasks by category correctly', () {
      final tasks = [
        TaskSummary(
          taskId: 'task1',
          taskName: 'Dev Task',
          createdAt: testDate,
          categoryName: 'Development',
        ),
        TaskSummary(
          taskId: 'task2',
          taskName: 'Test Task',
          createdAt: testDate,
          categoryName: 'Testing',
        ),
        TaskSummary(
          taskId: 'task3',
          taskName: 'Another Dev Task',
          createdAt: testDate,
          categoryName: 'Development',
        ),
        TaskSummary(
          taskId: 'task4',
          taskName: 'Uncategorized Task',
          createdAt: testDate,
        ),
      ];

      final result = TaskSummaryResult(
        tasks: tasks,
        queryStartDate: DateTime(2024),
        queryEndDate: DateTime(2024, 1, 31),
        totalCount: tasks.length,
      );

      final byCategory = result.tasksByCategory;

      expect(byCategory.keys, contains('Development'));
      expect(byCategory.keys, contains('Testing'));
      expect(byCategory.keys, contains('Uncategorized'));
      expect(byCategory['Development']?.length, equals(2));
      expect(byCategory['Testing']?.length, equals(1));
      expect(byCategory['Uncategorized']?.length, equals(1));
    });

    test('formats date range correctly', () {
      final result = TaskSummaryResult(
        tasks: [],
        queryStartDate: DateTime(2024, 1, 15),
        queryEndDate: DateTime(2024, 2, 28),
        totalCount: 0,
      );

      expect(result.formattedDateRange, equals('15/1/2024 - 28/2/2024'));
    });
  });

  group('TaskStatus', () {
    test('enum values are correct', () {
      expect(TaskStatus.values, contains(TaskStatus.planned));
      expect(TaskStatus.values, contains(TaskStatus.inProgress));
      expect(TaskStatus.values, contains(TaskStatus.completed));
      expect(TaskStatus.values, contains(TaskStatus.cancelled));
    });
  });
}
