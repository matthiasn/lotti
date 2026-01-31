import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_list.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../test_helper.dart';

/// Mock controller that returns fixed unified data.
class _TestUnifiedController extends UnifiedDailyOsDataController {
  _TestUnifiedController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    return _data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  final testCategory = CategoryDefinition(
    id: 'cat-1',
    name: 'Work',
    color: '#4285F4',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
    private: false,
    active: true,
  );

  final testCategory2 = CategoryDefinition(
    id: 'cat-2',
    name: 'Exercise',
    color: '#34A853',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
    private: false,
    active: true,
  );

  TimeBudgetProgress createProgress({
    required String id,
    required CategoryDefinition category,
    Duration planned = const Duration(hours: 2),
    Duration recorded = const Duration(hours: 1),
    BudgetProgressStatus status = BudgetProgressStatus.underBudget,
  }) {
    return TimeBudgetProgress(
      categoryId: category.id,
      category: category,
      plannedDuration: planned,
      recordedDuration: recorded,
      status: status,
      contributingEntries: const [],
      taskProgressItems: const [],
      blocks: [
        PlannedBlock(
          id: id,
          categoryId: category.id,
          startTime: testDate.add(const Duration(hours: 9)),
          endTime: testDate.add(Duration(hours: 9 + planned.inHours)),
        ),
      ],
    );
  }

  DayPlanEntry createEmptyDayPlan(DateTime date) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(date),
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: date,
        status: const DayPlanStatus.draft(),
      ),
    );
  }

  Widget createTestWidget({
    required List<TimeBudgetProgress> budgets,
    List<Override> additionalOverrides = const [],
  }) {
    final unifiedData = DailyOsData(
      date: testDate,
      dayPlan: createEmptyDayPlan(testDate),
      timelineData: DailyTimelineData(
        date: testDate,
        plannedSlots: const [],
        actualSlots: const [],
        dayStartHour: 8,
        dayEndHour: 18,
      ),
      budgetProgress: budgets,
    );

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        unifiedDailyOsDataControllerProvider(date: testDate).overrideWith(
          () => _TestUnifiedController(unifiedData),
        ),
        highlightedCategoryIdProvider.overrideWith((ref) => null),
        // Override stream provider to avoid timer issues in tests
        activeFocusCategoryIdProvider.overrideWith(
          (ref) => Stream.value(null),
        ),
        // Override to avoid TimeService dependency in tests
        runningTimerCategoryIdProvider.overrideWithValue(null),
        ...additionalOverrides,
      ],
      child: const SingleChildScrollView(
        child: TimeBudgetList(),
      ),
    );
  }

  group('TimeBudgetList', () {
    testWidgets('renders empty state when no budgets', (tester) async {
      await tester.pumpWidget(createTestWidget(budgets: []));
      await tester.pumpAndSettle();

      expect(find.text('No time budgets'), findsOneWidget);
      expect(find.text('Add Budget'), findsOneWidget);
    });

    testWidgets('renders section header with icon', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [createProgress(id: 'b1', category: testCategory)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.chartDonut), findsOneWidget);
      expect(find.text('Time Budgets'), findsOneWidget);
    });

    testWidgets('renders multiple budget cards', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [
            createProgress(id: 'b1', category: testCategory),
            createProgress(id: 'b2', category: testCategory2),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Exercise'), findsOneWidget);
    });

    testWidgets('shows summary chip with totals', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [
            createProgress(
              id: 'b1',
              category: testCategory,
              planned: const Duration(hours: 3),
            ),
            createProgress(
              id: 'b2',
              category: testCategory2,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 2h recorded / 5h planned
      expect(find.text('2h / 5h'), findsOneWidget);
    });

    testWidgets('renders TimeBudgetList widget', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [createProgress(id: 'b1', category: testCategory)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimeBudgetList), findsOneWidget);
    });

    testWidgets('shows budget status indicators', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [
            createProgress(
              id: 'b1',
              category: testCategory,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should show "1h left" for under budget
      expect(find.text('1h left'), findsOneWidget);
    });

    testWidgets('shows over budget indicator', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [
            createProgress(
              id: 'b1',
              category: testCategory,
              planned: const Duration(hours: 1),
              recorded: const Duration(hours: 2),
              status: BudgetProgressStatus.overBudget,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should show "+1h over" for over budget
      expect(find.text('+1h over'), findsOneWidget);
    });

    testWidgets('shows summary chip with hours and minutes', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [
            createProgress(
              id: 'b1',
              category: testCategory,
              planned: const Duration(hours: 3, minutes: 30),
              recorded: const Duration(hours: 1, minutes: 15),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Time format appears in both summary and card
      expect(find.text('1h 15m / 3h 30m'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows summary chip with minutes only', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [
            createProgress(
              id: 'b1',
              category: testCategory,
              planned: const Duration(minutes: 45),
              recorded: const Duration(minutes: 30),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Time format appears in both summary and card
      expect(find.text('30m / 45m'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows add block button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [createProgress(id: 'b1', category: testCategory)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('tapping add button shows sheet', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budgets: [createProgress(id: 'b1', category: testCategory)],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the add button
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      // The sheet should appear (or try to)
      // We just verify the tap doesn't crash
      expect(find.byType(TimeBudgetList), findsOneWidget);
    });
  });
}
