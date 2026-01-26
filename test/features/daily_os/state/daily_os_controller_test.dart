import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/utils/date_utils_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  DayPlanEntry createTestPlan({
    DayPlanStatus status = const DayPlanStatus.draft(),
    List<PlannedBlock> plannedBlocks = const [],
  }) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(testDate),
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: testDate,
        status: status,
        plannedBlocks: plannedBlocks,
      ),
    );
  }

  DailyTimelineData createTestTimelineData() {
    return DailyTimelineData(
      date: testDate,
      plannedSlots: [],
      actualSlots: [],
      dayStartHour: 8,
      dayEndHour: 18,
    );
  }

  group('DailyOsState', () {
    test('isDraft returns true for draft plans', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isDraft, isTrue);
      expect(state.isAgreed, isFalse);
      expect(state.needsReview, isFalse);
    });

    test('isAgreed returns true for agreed plans', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(
          status: DayPlanStatus.agreed(agreedAt: testDate),
        ),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isDraft, isFalse);
      expect(state.isAgreed, isTrue);
      expect(state.needsReview, isFalse);
    });

    test('needsReview returns true for needsReview plans', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(
          status: DayPlanStatus.needsReview(
            triggeredAt: testDate,
            reason: DayPlanReviewReason.blockModified,
          ),
        ),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isDraft, isFalse);
      expect(state.isAgreed, isFalse);
      expect(state.needsReview, isTrue);
    });

    test('isToday returns true when selectedDate is today', () {
      final today = DateTime.now().dayAtMidnight;
      final state = DailyOsState(
        selectedDate: today,
        dayPlan: null,
        budgetProgress: [],
        timelineData: DailyTimelineData(
          date: today,
          plannedSlots: [],
          actualSlots: [],
          dayStartHour: 8,
          dayEndHour: 18,
        ),
      );

      expect(state.isToday, isTrue);
    });

    test('isToday returns false when selectedDate is not today', () {
      final state = DailyOsState(
        selectedDate: testDate, // Jan 15, 2026
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isToday, isFalse);
    });

    test('totalBudgetedTime sums planned block durations', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-1',
              startTime: testDate.add(const Duration(hours: 9)),
              endTime: testDate.add(const Duration(hours: 11)), // 2 hours
            ),
            PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-2',
              startTime: testDate.add(const Duration(hours: 14)),
              endTime: testDate.add(const Duration(hours: 15)), // 1 hour
            ),
          ],
        ),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.totalBudgetedTime, equals(const Duration(hours: 3)));
    });

    test('totalBudgetedTime returns zero when no plan', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.totalBudgetedTime, equals(Duration.zero));
    });

    test('totalRecordedTime sums budget progress durations', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [
          const TimeBudgetProgress(
            categoryId: 'cat-1',
            category: null,
            plannedDuration: Duration(hours: 2),
            recordedDuration: Duration(hours: 1, minutes: 30),
            status: BudgetProgressStatus.underBudget,
            blocks: [],
            contributingEntries: [],
            pinnedTasks: [],
          ),
          const TimeBudgetProgress(
            categoryId: 'cat-2',
            category: null,
            plannedDuration: Duration(hours: 1),
            recordedDuration: Duration(minutes: 45),
            status: BudgetProgressStatus.underBudget,
            blocks: [],
            contributingEntries: [],
            pinnedTasks: [],
          ),
        ],
        timelineData: createTestTimelineData(),
      );

      expect(
        state.totalRecordedTime,
        equals(const Duration(hours: 2, minutes: 15)),
      );
    });

    test('overBudgetCount counts budgets over their limit', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [
          const TimeBudgetProgress(
            categoryId: 'cat-1',
            category: null,
            plannedDuration: Duration(hours: 2),
            recordedDuration: Duration(hours: 3), // Over by 1 hour
            status: BudgetProgressStatus.overBudget,
            blocks: [],
            contributingEntries: [],
            pinnedTasks: [],
          ),
          const TimeBudgetProgress(
            categoryId: 'cat-2',
            category: null,
            plannedDuration: Duration(hours: 2),
            recordedDuration: Duration(hours: 1), // Under
            status: BudgetProgressStatus.underBudget,
            blocks: [],
            contributingEntries: [],
            pinnedTasks: [],
          ),
          const TimeBudgetProgress(
            categoryId: 'cat-3',
            category: null,
            plannedDuration: Duration(hours: 1),
            recordedDuration: Duration(hours: 1, minutes: 30), // Over
            status: BudgetProgressStatus.overBudget,
            blocks: [],
            contributingEntries: [],
            pinnedTasks: [],
          ),
        ],
        timelineData: createTestTimelineData(),
      );

      expect(state.overBudgetCount, equals(2));
    });

    test('copyWith creates new state with specified changes', () {
      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        highlightedCategoryId: 'cat-1',
      );

      final modified = original.copyWith(
        isEditingPlan: true,
        highlightedCategoryId: 'cat-2',
      );

      expect(modified.isEditingPlan, isTrue);
      expect(modified.highlightedCategoryId, equals('cat-2'));
      // Original unchanged
      expect(original.isEditingPlan, isFalse);
      expect(original.highlightedCategoryId, equals('cat-1'));
    });

    test('copyWith with clearExpandedSection clears section', () {
      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedSection: DailyOsSection.timeline,
      );

      final modified = original.copyWith(clearExpandedSection: true);

      expect(modified.expandedSection, isNull);
    });

    test('copyWith with clearHighlight clears highlight', () {
      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        highlightedCategoryId: 'cat-1',
      );

      final modified = original.copyWith(clearHighlight: true);

      expect(modified.highlightedCategoryId, isNull);
    });

    test('copyWith preserves values when not specified', () {
      final plan = createTestPlan();
      final timeline = createTestTimelineData();
      final budgets = [
        const TimeBudgetProgress(
          categoryId: 'cat-1',
          category: null,
          plannedDuration: Duration(hours: 1),
          recordedDuration: Duration.zero,
          status: BudgetProgressStatus.underBudget,
          blocks: [],
          contributingEntries: [],
          pinnedTasks: [],
        ),
      ];

      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: plan,
        budgetProgress: budgets,
        timelineData: timeline,
        expandedSection: DailyOsSection.budgets,
        isEditingPlan: true,
        highlightedCategoryId: 'cat-1',
      );

      final modified = original.copyWith();

      expect(modified.selectedDate, equals(testDate));
      expect(modified.dayPlan, equals(plan));
      expect(modified.budgetProgress, equals(budgets));
      expect(modified.timelineData, equals(timeline));
      expect(modified.expandedSection, equals(DailyOsSection.budgets));
      expect(modified.isEditingPlan, isTrue);
      expect(modified.highlightedCategoryId, equals('cat-1'));
    });
  });

  group('DailyOsSection', () {
    test('enum has correct values', () {
      expect(DailyOsSection.values.length, equals(3));
      expect(DailyOsSection.values, contains(DailyOsSection.timeline));
      expect(DailyOsSection.values, contains(DailyOsSection.budgets));
      expect(DailyOsSection.values, contains(DailyOsSection.summary));
    });
  });
}
