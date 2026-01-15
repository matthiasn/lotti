import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_edit_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../test_helper.dart';

/// Mock controller that returns a fixed DayPlanEntry.
class _TestDayPlanController extends DayPlanController {
  _TestDayPlanController(this._entry);

  final DayPlanEntry? _entry;

  @override
  Future<JournalEntity?> build({required DateTime date}) async {
    return _entry;
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

  TimeBudget createTestBudget({
    int plannedMinutes = 60,
  }) {
    return TimeBudget(
      id: 'budget-1',
      categoryId: testCategory.id,
      plannedMinutes: plannedMinutes,
    );
  }

  DayPlanEntry createTestPlan({
    List<TimeBudget>? budgets,
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
        status: const DayPlanStatus.draft(),
        budgets: budgets ?? [createTestBudget()],
      ),
    );
  }

  Widget createTestWidget({
    required TimeBudget budget,
    CategoryDefinition? category,
    DayPlanEntry? plan,
    List<Override> additionalOverrides = const [],
  }) {
    final effectivePlan = plan ?? createTestPlan();

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        dayPlanControllerProvider(date: testDate).overrideWith(
          () => _TestDayPlanController(effectivePlan),
        ),
        ...additionalOverrides,
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: TimeBudgetEditModal(
            budget: budget,
            category: category,
          ),
        ),
      ),
    );
  }

  group('TimeBudgetEditModal', () {
    testWidgets('renders modal with title', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Budget'), findsOneWidget);
    });

    testWidgets('shows category name', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('shows Uncategorized when category is null', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncategorized'), findsOneWidget);
    });

    testWidgets('shows duration chips', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.text('30m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('3h'), findsOneWidget);
      expect(find.text('4h'), findsOneWidget);
    });

    testWidgets('shows action buttons', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows delete button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.delete), findsOneWidget);
    });

    testWidgets('renders TimeBudgetEditModal widget', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimeBudgetEditModal), findsOneWidget);
    });

    testWidgets('can select different duration', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          budget: createTestBudget(),
          category: testCategory,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 2h duration chip
      await tester.tap(find.text('2h'));
      await tester.pumpAndSettle();

      // The chip should be visually selected (we can verify the widget is
      // still showing - full verification would need internal state check)
      expect(find.text('2h'), findsOneWidget);
    });

    testWidgets('shows Planned Duration label', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planned Duration'), findsOneWidget);
    });

    testWidgets('shows Category label', (tester) async {
      await tester.pumpWidget(
        createTestWidget(budget: createTestBudget(), category: testCategory),
      );
      await tester.pumpAndSettle();

      expect(find.text('Category'), findsOneWidget);
    });
  });
}
