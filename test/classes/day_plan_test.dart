import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';

void main() {
  group('Day plan tests', () {
    group('dayPlanId', () {
      test('generates correct ID format', () {
        final date = DateTime(2026, 1, 14);
        expect(dayPlanId(date), equals('dayplan-2026-01-14'));
      });

      test('handles single digit months and days', () {
        final date = DateTime(2026, 3, 5);
        expect(dayPlanId(date), equals('dayplan-2026-03-05'));
      });

      test('ignores time component', () {
        final date = DateTime(2026, 1, 14, 15, 30, 45);
        expect(dayPlanId(date), equals('dayplan-2026-01-14'));
      });
    });

    group('DayPlanStatus', () {
      test('draft can be serialized and deserialized', () {
        const status = DayPlanStatus.draft();

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(fromJson, isA<DayPlanStatusDraft>());
      });

      test('agreed can be serialized and deserialized', () {
        final status = DayPlanStatus.agreed(
          agreedAt: DateTime(2026, 1, 14, 10, 30),
        );

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(fromJson, isA<DayPlanStatusAgreed>());
        expect(
          (fromJson as DayPlanStatusAgreed).agreedAt,
          equals(DateTime(2026, 1, 14, 10, 30)),
        );
      });

      test('needsReview can be serialized and deserialized', () {
        final status = DayPlanStatus.needsReview(
          triggeredAt: DateTime(2026, 1, 14, 14),
          reason: DayPlanReviewReason.newDueTask,
          previouslyAgreedAt: DateTime(2026, 1, 14, 10, 30),
        );

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(fromJson, isA<DayPlanStatusNeedsReview>());
        final needsReview = fromJson as DayPlanStatusNeedsReview;
        expect(needsReview.reason, equals(DayPlanReviewReason.newDueTask));
        expect(
          needsReview.previouslyAgreedAt,
          equals(DateTime(2026, 1, 14, 10, 30)),
        );
      });

      test('needsReview without previouslyAgreedAt', () {
        final status = DayPlanStatus.needsReview(
          triggeredAt: DateTime(2026, 1, 14, 14),
          reason: DayPlanReviewReason.budgetModified,
        );

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(
          (fromJson as DayPlanStatusNeedsReview).previouslyAgreedAt,
          isNull,
        );
      });
    });

    group('TimeBudget', () {
      test('can be serialized and deserialized', () {
        const budget = TimeBudget(
          id: 'budget-1',
          categoryId: 'category-work',
          plannedMinutes: 180,
        );

        final json = jsonEncode(budget.toJson());
        final fromJson = TimeBudget.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(budget));
        expect(fromJson.plannedDuration, equals(const Duration(hours: 3)));
      });

      test('plannedDuration extension works correctly', () {
        const budget = TimeBudget(
          id: 'budget-1',
          categoryId: 'category-work',
          plannedMinutes: 90,
        );

        expect(
          budget.plannedDuration,
          equals(const Duration(hours: 1, minutes: 30)),
        );
      });
    });

    group('PlannedBlock', () {
      test('can be serialized and deserialized', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 12),
          note: 'Focus time',
        );

        final json = jsonEncode(block.toJson());
        final fromJson = PlannedBlock.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(block));
        expect(fromJson.note, equals('Focus time'));
      });

      test('duration extension works correctly', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 11, 30),
        );

        expect(
          block.duration,
          equals(const Duration(hours: 2, minutes: 30)),
        );
      });

      test('can be serialized without note', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 12),
        );

        final json = jsonEncode(block.toJson());
        final fromJson = PlannedBlock.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(block));
        expect(fromJson.note, isNull);
      });
    });

    group('PinnedTaskRef', () {
      test('can be serialized and deserialized', () {
        const ref = PinnedTaskRef(
          taskId: 'task-123',
          budgetId: 'budget-1',
          sortOrder: 2,
        );

        final json = jsonEncode(ref.toJson());
        final fromJson = PinnedTaskRef.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(ref));
      });

      test('defaults sortOrder to 0', () {
        const ref = PinnedTaskRef(
          taskId: 'task-123',
          budgetId: 'budget-1',
        );

        expect(ref.sortOrder, equals(0));
      });
    });

    group('DayPlanData', () {
      test('can be serialized and deserialized with all fields', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: DayPlanStatus.agreed(
            agreedAt: DateTime(2026, 1, 14, 8),
          ),
          dayLabel: 'Focused Workday',
          agreedAt: DateTime(2026, 1, 14, 8),
          completedAt: DateTime(2026, 1, 14, 18),
          budgets: const [
            TimeBudget(
              id: 'budget-1',
              categoryId: 'category-work',
              plannedMinutes: 180,
            ),
            TimeBudget(
              id: 'budget-2',
              categoryId: 'category-personal',
              plannedMinutes: 60,
              sortOrder: 1,
            ),
          ],
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'category-work',
              startTime: DateTime(2026, 1, 14, 9),
              endTime: DateTime(2026, 1, 14, 12),
            ),
          ],
          pinnedTasks: const [
            PinnedTaskRef(
              taskId: 'task-1',
              budgetId: 'budget-1',
            ),
          ],
        );

        final json = jsonEncode(data.toJson());
        final fromJson = DayPlanData.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(data));
        expect(fromJson.budgets.length, equals(2));
        expect(fromJson.plannedBlocks.length, equals(1));
        expect(fromJson.pinnedTasks.length, equals(1));
      });

      test('defaults to empty lists', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
        );

        expect(data.budgets, isEmpty);
        expect(data.plannedBlocks, isEmpty);
        expect(data.pinnedTasks, isEmpty);
      });

      test('totalPlannedDuration calculates correctly', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          budgets: const [
            TimeBudget(
              id: 'budget-1',
              categoryId: 'cat-1',
              plannedMinutes: 120,
            ),
            TimeBudget(
              id: 'budget-2',
              categoryId: 'cat-2',
              plannedMinutes: 60,
            ),
            TimeBudget(
              id: 'budget-3',
              categoryId: 'cat-3',
              plannedMinutes: 30,
            ),
          ],
        );

        expect(
          data.totalPlannedDuration,
          equals(const Duration(hours: 3, minutes: 30)),
        );
      });

      test('budgetById finds correct budget', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          budgets: const [
            TimeBudget(
              id: 'budget-1',
              categoryId: 'cat-1',
              plannedMinutes: 120,
            ),
            TimeBudget(
              id: 'budget-2',
              categoryId: 'cat-2',
              plannedMinutes: 60,
            ),
          ],
        );

        expect(data.budgetById('budget-2')?.categoryId, equals('cat-2'));
        expect(data.budgetById('nonexistent'), isNull);
      });

      test('budgetByCategoryId finds correct budget', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          budgets: const [
            TimeBudget(
              id: 'budget-1',
              categoryId: 'cat-1',
              plannedMinutes: 120,
            ),
            TimeBudget(
              id: 'budget-2',
              categoryId: 'cat-2',
              plannedMinutes: 60,
            ),
          ],
        );

        expect(data.budgetByCategoryId('cat-2')?.id, equals('budget-2'));
        expect(data.budgetByCategoryId('nonexistent'), isNull);
      });

      test('pinnedTasksForBudget returns sorted tasks', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          pinnedTasks: const [
            PinnedTaskRef(taskId: 'task-3', budgetId: 'budget-1', sortOrder: 2),
            PinnedTaskRef(taskId: 'task-1', budgetId: 'budget-1'),
            PinnedTaskRef(taskId: 'task-2', budgetId: 'budget-1', sortOrder: 1),
            PinnedTaskRef(taskId: 'task-4', budgetId: 'budget-2'),
          ],
        );

        final tasks = data.pinnedTasksForBudget('budget-1');
        expect(tasks.length, equals(3));
        expect(tasks[0].taskId, equals('task-1'));
        expect(tasks[1].taskId, equals('task-2'));
        expect(tasks[2].taskId, equals('task-3'));
      });

      test('blocksForCategory returns sorted blocks', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 14),
              endTime: DateTime(2026, 1, 14, 16),
            ),
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 9),
              endTime: DateTime(2026, 1, 14, 12),
            ),
            PlannedBlock(
              id: 'block-3',
              categoryId: 'cat-2',
              startTime: DateTime(2026, 1, 14, 10),
              endTime: DateTime(2026, 1, 14, 11),
            ),
          ],
        );

        final blocks = data.blocksForCategory('cat-1');
        expect(blocks.length, equals(2));
        expect(blocks[0].id, equals('block-1'));
        expect(blocks[1].id, equals('block-2'));
      });

      test('status helper methods work correctly', () {
        final draft = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
        );
        expect(draft.isDraft, isTrue);
        expect(draft.isAgreed, isFalse);
        expect(draft.needsReview, isFalse);

        final agreed = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 14)),
        );
        expect(agreed.isDraft, isFalse);
        expect(agreed.isAgreed, isTrue);
        expect(agreed.needsReview, isFalse);

        final review = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: DayPlanStatus.needsReview(
            triggeredAt: DateTime(2026, 1, 14),
            reason: DayPlanReviewReason.newDueTask,
          ),
        );
        expect(review.isDraft, isFalse);
        expect(review.isAgreed, isFalse);
        expect(review.needsReview, isTrue);
      });

      test('isComplete helper method works correctly', () {
        final notComplete = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
        );
        expect(notComplete.isComplete, isFalse);

        final complete = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          completedAt: DateTime(2026, 1, 14, 18),
        );
        expect(complete.isComplete, isTrue);
      });
    });

    group('DayPlanReviewReason', () {
      test('all reasons can be serialized', () {
        for (final reason in DayPlanReviewReason.values) {
          final status = DayPlanStatus.needsReview(
            triggeredAt: DateTime(2026, 1, 14),
            reason: reason,
          );

          final json = jsonEncode(status.toJson());
          final fromJson = DayPlanStatus.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );

          expect(
            (fromJson as DayPlanStatusNeedsReview).reason,
            equals(reason),
          );
        }
      });
    });
  });
}
