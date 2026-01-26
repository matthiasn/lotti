import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_summary.dart';
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

  DayPlanEntry createTestPlan({
    bool isComplete = false,
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
        status: DayPlanStatus.agreed(agreedAt: testDate),
        completedAt: isComplete ? testDate : null,
      ),
    );
  }

  Widget createTestWidget({
    DayPlanEntry? plan,
    DayBudgetStats? stats,
    List<Override> additionalOverrides = const [],
  }) {
    final effectiveStats = stats ??
        const DayBudgetStats(
          totalPlanned: Duration(hours: 4),
          totalRecorded: Duration(hours: 2),
          budgetCount: 2,
          overBudgetCount: 0,
        );
    final effectivePlan = plan ?? createTestPlan();

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        dayPlanControllerProvider(date: testDate).overrideWith(
          () => _TestDayPlanController(effectivePlan),
        ),
        dayBudgetStatsProvider(date: testDate).overrideWith(
          (ref) async => effectiveStats,
        ),
        ...additionalOverrides,
      ],
      child: const SingleChildScrollView(
        child: DaySummary(),
      ),
    );
  }

  group('DaySummary', () {
    testWidgets('renders Day Summary header', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Day Summary'), findsOneWidget);
      expect(find.byIcon(MdiIcons.sunCompass), findsOneWidget);
    });

    testWidgets('shows planned duration', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 2),
            budgetCount: 2,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 hours'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);
    });

    testWidgets('shows recorded duration', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 3),
            budgetCount: 2,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 hours'), findsOneWidget);
      expect(find.text('Recorded'), findsOneWidget);
    });

    testWidgets('shows remaining duration when under budget', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 2),
            budgetCount: 2,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remaining'), findsOneWidget);
    });

    testWidgets('shows over label when over budget', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 2),
            totalRecorded: Duration(hours: 4),
            budgetCount: 2,
            overBudgetCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Over'), findsOneWidget);
    });

    testWidgets('shows progress bar when budgets exist', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 2),
            budgetCount: 2,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overall Progress'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('renders DaySummary widget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DaySummary), findsOneWidget);
    });
  });
}
