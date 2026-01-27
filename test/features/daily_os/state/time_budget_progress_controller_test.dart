import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  JournalEntity createTestEntry({required String id}) {
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(hours: 1)),
      ),
    );
  }

  Task createTestTask({required String id, required String title}) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(hours: 1)),
      ),
      data: TaskData(
        title: title,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(hours: 1)),
        statusHistory: const [],
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    );
  }

  TimeBudgetProgress createProgress({
    List<JournalEntity> contributingEntries = const [],
    List<Task> pinnedTasks = const [],
  }) {
    return TimeBudgetProgress(
      categoryId: 'cat-1',
      category: null,
      plannedDuration: const Duration(hours: 2),
      recordedDuration: const Duration(hours: 1),
      status: BudgetProgressStatus.underBudget,
      contributingEntries: contributingEntries,
      pinnedTasks: pinnedTasks,
      blocks: [
        PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-1',
          startTime: testDate.add(const Duration(hours: 9)),
          endTime: testDate.add(const Duration(hours: 11)),
        ),
      ],
    );
  }

  group('TimeBudgetProgress', () {
    group('contributingTasks getter', () {
      test('returns empty list when contributingEntries is empty', () {
        final progress = createProgress(contributingEntries: []);

        expect(progress.contributingTasks, isEmpty);
      });

      test('returns empty list when contributingEntries has no Tasks', () {
        final progress = createProgress(
          contributingEntries: [
            createTestEntry(id: 'entry-1'),
            createTestEntry(id: 'entry-2'),
            createTestEntry(id: 'entry-3'),
          ],
        );

        expect(progress.contributingTasks, isEmpty);
      });

      test('returns only Task entries when mixed with JournalEntry', () {
        final task1 = createTestTask(id: 'task-1', title: 'Task One');
        final task2 = createTestTask(id: 'task-2', title: 'Task Two');

        final progress = createProgress(
          contributingEntries: [
            createTestEntry(id: 'entry-1'),
            task1,
            createTestEntry(id: 'entry-2'),
            task2,
            createTestEntry(id: 'entry-3'),
          ],
        );

        final tasks = progress.contributingTasks;
        expect(tasks.length, equals(2));
        expect(tasks[0].meta.id, equals('task-1'));
        expect(tasks[1].meta.id, equals('task-2'));
      });

      test('returns all Tasks when all entries are Tasks', () {
        final task1 = createTestTask(id: 'task-1', title: 'Task One');
        final task2 = createTestTask(id: 'task-2', title: 'Task Two');
        final task3 = createTestTask(id: 'task-3', title: 'Task Three');

        final progress = createProgress(
          contributingEntries: [task1, task2, task3],
        );

        final tasks = progress.contributingTasks;
        expect(tasks.length, equals(3));
        expect(tasks.map((t) => t.meta.id), containsAll(['task-1', 'task-2', 'task-3']));
      });

      test('preserves order of Tasks from contributingEntries', () {
        final task1 = createTestTask(id: 'task-1', title: 'First');
        final task2 = createTestTask(id: 'task-2', title: 'Second');
        final task3 = createTestTask(id: 'task-3', title: 'Third');

        final progress = createProgress(
          contributingEntries: [
            createTestEntry(id: 'entry-1'),
            task2,
            task1,
            createTestEntry(id: 'entry-2'),
            task3,
          ],
        );

        final tasks = progress.contributingTasks;
        expect(tasks[0].meta.id, equals('task-2'));
        expect(tasks[1].meta.id, equals('task-1'));
        expect(tasks[2].meta.id, equals('task-3'));
      });
    });

    group('computed properties', () {
      test('remainingDuration returns planned minus recorded', () {
        final progress = TimeBudgetProgress(
          categoryId: 'cat-1',
          category: null,
          plannedDuration: const Duration(hours: 3),
          recordedDuration: const Duration(hours: 1, minutes: 30),
          status: BudgetProgressStatus.underBudget,
          contributingEntries: const [],
          pinnedTasks: const [],
          blocks: const [],
        );

        expect(
          progress.remainingDuration,
          equals(const Duration(hours: 1, minutes: 30)),
        );
      });

      test('progressFraction returns 0 when planned is zero', () {
        final progress = TimeBudgetProgress(
          categoryId: 'cat-1',
          category: null,
          plannedDuration: Duration.zero,
          recordedDuration: const Duration(hours: 1),
          status: BudgetProgressStatus.overBudget,
          contributingEntries: const [],
          pinnedTasks: const [],
          blocks: const [],
        );

        expect(progress.progressFraction, equals(0.0));
      });

      test('progressFraction returns correct ratio', () {
        final progress = TimeBudgetProgress(
          categoryId: 'cat-1',
          category: null,
          plannedDuration: const Duration(hours: 2),
          recordedDuration: const Duration(hours: 1),
          status: BudgetProgressStatus.underBudget,
          contributingEntries: const [],
          pinnedTasks: const [],
          blocks: const [],
        );

        expect(progress.progressFraction, equals(0.5));
      });

      test('isOverBudget returns true when recorded exceeds planned', () {
        final progress = TimeBudgetProgress(
          categoryId: 'cat-1',
          category: null,
          plannedDuration: const Duration(hours: 1),
          recordedDuration: const Duration(hours: 2),
          status: BudgetProgressStatus.overBudget,
          contributingEntries: const [],
          pinnedTasks: const [],
          blocks: const [],
        );

        expect(progress.isOverBudget, isTrue);
      });

      test('isOverBudget returns false when recorded is less than planned', () {
        final progress = TimeBudgetProgress(
          categoryId: 'cat-1',
          category: null,
          plannedDuration: const Duration(hours: 2),
          recordedDuration: const Duration(hours: 1),
          status: BudgetProgressStatus.underBudget,
          contributingEntries: const [],
          pinnedTasks: const [],
          blocks: const [],
        );

        expect(progress.isOverBudget, isFalse);
      });
    });
  });

  group('DayBudgetStats', () {
    test('totalRemaining returns planned minus recorded', () {
      const stats = DayBudgetStats(
        totalPlanned: Duration(hours: 8),
        totalRecorded: Duration(hours: 5),
        budgetCount: 3,
        overBudgetCount: 1,
      );

      expect(stats.totalRemaining, equals(const Duration(hours: 3)));
    });

    test('isOverBudget returns true when recorded exceeds planned', () {
      const stats = DayBudgetStats(
        totalPlanned: Duration(hours: 4),
        totalRecorded: Duration(hours: 5),
        budgetCount: 2,
        overBudgetCount: 1,
      );

      expect(stats.isOverBudget, isTrue);
    });

    test('isOverBudget returns false when recorded is under planned', () {
      const stats = DayBudgetStats(
        totalPlanned: Duration(hours: 8),
        totalRecorded: Duration(hours: 5),
        budgetCount: 3,
        overBudgetCount: 0,
      );

      expect(stats.isOverBudget, isFalse);
    });

    test('progressFraction returns 0 when planned is zero', () {
      const stats = DayBudgetStats(
        totalPlanned: Duration.zero,
        totalRecorded: Duration(hours: 1),
        budgetCount: 0,
        overBudgetCount: 0,
      );

      expect(stats.progressFraction, equals(0.0));
    });

    test('progressFraction returns correct ratio', () {
      const stats = DayBudgetStats(
        totalPlanned: Duration(hours: 8),
        totalRecorded: Duration(hours: 4),
        budgetCount: 2,
        overBudgetCount: 0,
      );

      expect(stats.progressFraction, equals(0.5));
    });
  });
}
