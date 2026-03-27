import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';

void main() {
  final fixedDate = DateTime(2024, 3, 15);

  final testMeta = Metadata(
    id: 'test-task-id',
    createdAt: fixedDate,
    updatedAt: fixedDate,
    dateFrom: fixedDate,
    dateTo: fixedDate,
  );

  final testTaskData = TaskData(
    status: TaskStatus.open(
      id: 'status-id',
      createdAt: fixedDate,
      utcOffset: 60,
    ),
    title: 'Test task',
    statusHistory: [],
    dateFrom: fixedDate,
    dateTo: fixedDate,
  );

  final testTaskEntity = Task(meta: testMeta, data: testTaskData);

  final testCategory = CategoryDefinition(
    id: 'cat-1',
    createdAt: fixedDate,
    updatedAt: fixedDate,
    name: 'Test Category',
    vectorClock: null,
    private: false,
    active: true,
  );

  final testBlock = PlannedBlock(
    id: 'block-1',
    categoryId: 'cat-1',
    startTime: DateTime(2024, 3, 15, 9),
    endTime: DateTime(2024, 3, 15, 11),
  );

  group('BudgetProgressStatus', () {
    test('enum has all expected values', () {
      expect(BudgetProgressStatus.values, hasLength(4));
      expect(
        BudgetProgressStatus.values,
        containsAll([
          BudgetProgressStatus.underBudget,
          BudgetProgressStatus.nearLimit,
          BudgetProgressStatus.exhausted,
          BudgetProgressStatus.overBudget,
        ]),
      );
    });
  });

  group('TaskDayProgress', () {
    test('stores task, timeSpentOnDay, and wasCompletedOnDay', () {
      final progress = TaskDayProgress(
        task: testTaskEntity,
        timeSpentOnDay: const Duration(minutes: 30),
        wasCompletedOnDay: true,
      );

      expect(progress.task, testTaskEntity);
      expect(progress.timeSpentOnDay, const Duration(minutes: 30));
      expect(progress.wasCompletedOnDay, isTrue);
    });

    test('dueDateStatus defaults to DueDateStatus.none()', () {
      final progress = TaskDayProgress(
        task: testTaskEntity,
        timeSpentOnDay: Duration.zero,
        wasCompletedOnDay: false,
      );

      expect(progress.dueDateStatus.urgency, DueDateUrgency.normal);
      expect(progress.dueDateStatus.daysUntilDue, isNull);
    });

    group('isDueOrOverdue', () {
      test('returns false when dueDateStatus is none (no due date)', () {
        final progress = TaskDayProgress(
          task: testTaskEntity,
          timeSpentOnDay: Duration.zero,
          wasCompletedOnDay: false,
        );

        expect(progress.isDueOrOverdue, isFalse);
      });

      test('returns false when due date is in the future', () {
        final progress = TaskDayProgress(
          task: testTaskEntity,
          timeSpentOnDay: Duration.zero,
          wasCompletedOnDay: false,
          dueDateStatus: const DueDateStatus(
            urgency: DueDateUrgency.normal,
            daysUntilDue: 5,
          ),
        );

        expect(progress.isDueOrOverdue, isFalse);
      });

      test('returns true when due date is today', () {
        final progress = TaskDayProgress(
          task: testTaskEntity,
          timeSpentOnDay: Duration.zero,
          wasCompletedOnDay: false,
          dueDateStatus: const DueDateStatus(
            urgency: DueDateUrgency.dueToday,
            daysUntilDue: 0,
          ),
        );

        expect(progress.isDueOrOverdue, isTrue);
      });

      test('returns true when due date is overdue', () {
        final progress = TaskDayProgress(
          task: testTaskEntity,
          timeSpentOnDay: Duration.zero,
          wasCompletedOnDay: false,
          dueDateStatus: const DueDateStatus(
            urgency: DueDateUrgency.overdue,
            daysUntilDue: -3,
          ),
        );

        expect(progress.isDueOrOverdue, isTrue);
      });
    });
  });

  group('TimeBudgetProgress', () {
    TimeBudgetProgress makeProgress({
      required Duration planned,
      required Duration recorded,
      BudgetProgressStatus status = BudgetProgressStatus.underBudget,
      bool hasNoBudgetWarning = false,
    }) {
      return TimeBudgetProgress(
        categoryId: 'cat-1',
        category: testCategory,
        plannedDuration: planned,
        recordedDuration: recorded,
        status: status,
        contributingEntries: const [],
        taskProgressItems: const [],
        blocks: [testBlock],
        hasNoBudgetWarning: hasNoBudgetWarning,
      );
    }

    group('progressFraction', () {
      test('returns correct fraction for normal values', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 1),
        );

        // 60 / 120 = 0.5
        expect(progress.progressFraction, 0.5);
      });

      test('returns 0 when planned duration is zero', () {
        final progress = makeProgress(
          planned: Duration.zero,
          recorded: const Duration(hours: 1),
        );

        expect(progress.progressFraction, 0.0);
      });

      test('returns 0 when both planned and recorded are zero', () {
        final progress = makeProgress(
          planned: Duration.zero,
          recorded: Duration.zero,
        );

        expect(progress.progressFraction, 0.0);
      });

      test('returns 0 when recorded is zero', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: Duration.zero,
        );

        expect(progress.progressFraction, 0.0);
      });

      test('returns 1.0 when recorded equals planned', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 2),
        );

        expect(progress.progressFraction, 1.0);
      });

      test('returns value > 1.0 when over budget', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 3),
        );

        // 180 / 120 = 1.5
        expect(progress.progressFraction, 1.5);
      });

      test('uses integer minutes for calculation', () {
        // 90 minutes planned, 45 minutes recorded => 0.5
        final progress = makeProgress(
          planned: const Duration(minutes: 90),
          recorded: const Duration(minutes: 45),
        );

        expect(progress.progressFraction, 0.5);
      });

      test('returns 0 when planned is less than 1 minute', () {
        // 30 seconds => 0 inMinutes
        final progress = makeProgress(
          planned: const Duration(seconds: 30),
          recorded: const Duration(seconds: 15),
        );

        expect(progress.progressFraction, 0.0);
      });
    });

    group('remainingDuration', () {
      test('returns positive duration when under budget', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 1),
        );

        expect(progress.remainingDuration, const Duration(hours: 1));
      });

      test('returns zero when exactly at budget', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 2),
        );

        expect(progress.remainingDuration, Duration.zero);
      });

      test('returns negative duration when over budget', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 3),
        );

        expect(progress.remainingDuration, const Duration(hours: -1));
        expect(progress.remainingDuration.isNegative, isTrue);
      });

      test('returns full planned duration when nothing recorded', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: Duration.zero,
        );

        expect(progress.remainingDuration, const Duration(hours: 2));
      });
    });

    group('isOverBudget', () {
      test('returns false when recorded is less than planned', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 1),
        );

        expect(progress.isOverBudget, isFalse);
      });

      test('returns false when recorded equals planned', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 2),
        );

        expect(progress.isOverBudget, isFalse);
      });

      test('returns true when recorded exceeds planned', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 3),
        );

        expect(progress.isOverBudget, isTrue);
      });

      test('returns true when over by just one microsecond', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 2, microseconds: 1),
        );

        expect(progress.isOverBudget, isTrue);
      });

      test('returns false when both are zero', () {
        final progress = makeProgress(
          planned: Duration.zero,
          recorded: Duration.zero,
        );

        expect(progress.isOverBudget, isFalse);
      });
    });

    group('hasNoBudgetWarning', () {
      test('defaults to false', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 1),
        );

        expect(progress.hasNoBudgetWarning, isFalse);
      });

      test('can be set to true', () {
        final progress = makeProgress(
          planned: const Duration(hours: 2),
          recorded: const Duration(hours: 1),
          hasNoBudgetWarning: true,
        );

        expect(progress.hasNoBudgetWarning, isTrue);
      });
    });

    test('stores all required fields correctly', () {
      final entries = [
        JournalEntity.journalEntry(meta: testMeta),
      ];
      final taskProgressItems = [
        TaskDayProgress(
          task: testTaskEntity,
          timeSpentOnDay: const Duration(minutes: 30),
          wasCompletedOnDay: false,
        ),
      ];

      final progress = TimeBudgetProgress(
        categoryId: 'cat-1',
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: entries,
        taskProgressItems: taskProgressItems,
        blocks: [testBlock],
      );

      expect(progress.categoryId, 'cat-1');
      expect(progress.category, testCategory);
      expect(progress.plannedDuration, const Duration(hours: 2));
      expect(progress.recordedDuration, const Duration(hours: 1));
      expect(progress.status, BudgetProgressStatus.underBudget);
      expect(progress.contributingEntries, entries);
      expect(progress.taskProgressItems, taskProgressItems);
      expect(progress.blocks, [testBlock]);
    });

    test('category can be null', () {
      const progress = TimeBudgetProgress(
        categoryId: 'cat-1',
        category: null,
        plannedDuration: Duration(hours: 1),
        recordedDuration: Duration.zero,
        status: BudgetProgressStatus.underBudget,
        contributingEntries: [],
        taskProgressItems: [],
        blocks: [],
      );

      expect(progress.category, isNull);
    });
  });

  group('DayBudgetStats', () {
    group('totalRemaining', () {
      test('returns positive duration when under budget', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 5),
          budgetCount: 3,
          overBudgetCount: 0,
        );

        expect(stats.totalRemaining, const Duration(hours: 3));
      });

      test('returns zero when exactly at budget', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 8),
          budgetCount: 3,
          overBudgetCount: 0,
        );

        expect(stats.totalRemaining, Duration.zero);
      });

      test('returns negative duration when over budget', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 10),
          budgetCount: 3,
          overBudgetCount: 1,
        );

        expect(stats.totalRemaining, const Duration(hours: -2));
        expect(stats.totalRemaining.isNegative, isTrue);
      });

      test('returns zero when both are zero', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );

        expect(stats.totalRemaining, Duration.zero);
      });
    });

    group('isOverBudget', () {
      test('returns false when recorded is less than planned', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 5),
          budgetCount: 3,
          overBudgetCount: 0,
        );

        expect(stats.isOverBudget, isFalse);
      });

      test('returns false when recorded equals planned', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 8),
          budgetCount: 3,
          overBudgetCount: 0,
        );

        expect(stats.isOverBudget, isFalse);
      });

      test('returns true when recorded exceeds planned', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 10),
          budgetCount: 3,
          overBudgetCount: 1,
        );

        expect(stats.isOverBudget, isTrue);
      });

      test('returns false when both are zero', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );

        expect(stats.isOverBudget, isFalse);
      });

      test('returns true when over by one microsecond', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 8, microseconds: 1),
          budgetCount: 3,
          overBudgetCount: 0,
        );

        expect(stats.isOverBudget, isTrue);
      });
    });

    group('progressFraction', () {
      test('returns correct fraction for normal values', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 4),
          budgetCount: 3,
          overBudgetCount: 0,
        );

        // 240 / 480 = 0.5
        expect(stats.progressFraction, 0.5);
      });

      test('returns 0 when planned is zero', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration(hours: 2),
          budgetCount: 0,
          overBudgetCount: 0,
        );

        expect(stats.progressFraction, 0.0);
      });

      test('returns 0 when both are zero', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );

        expect(stats.progressFraction, 0.0);
      });

      test('returns 0 when recorded is zero', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration.zero,
          budgetCount: 3,
          overBudgetCount: 0,
        );

        expect(stats.progressFraction, 0.0);
      });

      test('returns 1.0 when recorded equals planned', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 8),
          totalRecorded: Duration(hours: 8),
          budgetCount: 3,
          overBudgetCount: 0,
        );

        expect(stats.progressFraction, 1.0);
      });

      test('returns value > 1.0 when over budget', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(hours: 4),
          totalRecorded: Duration(hours: 6),
          budgetCount: 2,
          overBudgetCount: 1,
        );

        // 360 / 240 = 1.5
        expect(stats.progressFraction, 1.5);
      });

      test('uses integer minutes for calculation', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(minutes: 90),
          totalRecorded: Duration(minutes: 45),
          budgetCount: 1,
          overBudgetCount: 0,
        );

        expect(stats.progressFraction, 0.5);
      });

      test('returns 0 when planned is less than 1 minute', () {
        const stats = DayBudgetStats(
          totalPlanned: Duration(seconds: 30),
          totalRecorded: Duration(seconds: 15),
          budgetCount: 1,
          overBudgetCount: 0,
        );

        expect(stats.progressFraction, 0.0);
      });
    });

    test('stores all required fields correctly', () {
      const stats = DayBudgetStats(
        totalPlanned: Duration(hours: 8),
        totalRecorded: Duration(hours: 5),
        budgetCount: 4,
        overBudgetCount: 1,
      );

      expect(stats.totalPlanned, const Duration(hours: 8));
      expect(stats.totalRecorded, const Duration(hours: 5));
      expect(stats.budgetCount, 4);
      expect(stats.overBudgetCount, 1);
    });
  });
}
