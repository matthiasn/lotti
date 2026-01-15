import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_list.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../test_helper.dart';

/// Mock controller that returns fixed budget progress data.
class _TestBudgetProgressController extends TimeBudgetProgressController {
  _TestBudgetProgressController(this._budgets);

  final List<TimeBudgetProgress> _budgets;

  @override
  Future<List<TimeBudgetProgress>> build({required DateTime date}) async {
    return _budgets;
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
      budget: TimeBudget(
        id: id,
        categoryId: category.id,
        plannedMinutes: planned.inMinutes,
      ),
      category: category,
      plannedDuration: planned,
      recordedDuration: recorded,
      status: status,
      contributingEntries: const [],
    );
  }

  Widget createTestWidget({
    required List<TimeBudgetProgress> budgets,
    List<Override> additionalOverrides = const [],
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        timeBudgetProgressControllerProvider(date: testDate).overrideWith(
          () => _TestBudgetProgressController(budgets),
        ),
        highlightedCategoryIdProvider.overrideWith((ref) => null),
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
  });
}
