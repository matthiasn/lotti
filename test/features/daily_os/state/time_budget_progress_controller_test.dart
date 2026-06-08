import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'time_budget_progress_controller_test_helpers.dart';

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
      for (final (planned, recorded, expected, label)
          in progressFractionCases) {
        test('$label → $expected', () {
          final progress = makeProgress(planned: planned, recorded: recorded);
          expect(progress.progressFraction, expected);
        });
      }
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
}
