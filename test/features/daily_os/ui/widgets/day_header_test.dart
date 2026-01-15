import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_header.dart';
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
    String? dayLabel,
    DayPlanStatus status = const DayPlanStatus.draft(),
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
        dayLabel: dayLabel,
      ),
    );
  }

  Widget createTestWidget({
    DayPlanEntry? plan,
    DayBudgetStats? stats,
    DateTime? selectedDate,
    List<Override> additionalOverrides = const [],
  }) {
    final date = selectedDate ?? testDate;
    final effectiveStats = stats ??
        const DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );
    final effectivePlan = plan ?? createTestPlan();

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(date),
        dayPlanControllerProvider(date: date).overrideWith(
          () => _TestDayPlanController(effectivePlan),
        ),
        dayBudgetStatsProvider(date: date).overrideWith(
          (ref) async => effectiveStats,
        ),
        ...additionalOverrides,
      ],
      child: const DayHeader(),
    );
  }

  group('DayHeader', () {
    testWidgets('renders the widget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Debug: check if DayHeader exists
      expect(find.byType(DayHeader), findsOneWidget);
    });

    testWidgets('displays formatted date', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // January 15, 2026 is a Thursday
      expect(find.text('Thursday'), findsOneWidget);
      // Should display the formatted date
      expect(find.text('January 15, 2026'), findsOneWidget);
    });

    testWidgets('displays day label chip when set', (tester) async {
      await tester.pumpWidget(
        createTestWidget(plan: createTestPlan(dayLabel: 'Focus Day')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus Day'), findsOneWidget);
    });

    testWidgets('does not show Today button on current day', (tester) async {
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);

      await tester.pumpWidget(
        createTestWidget(
          selectedDate: todayMidnight,
          plan: DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(todayMidnight),
              createdAt: todayMidnight,
              updatedAt: todayMidnight,
              dateFrom: todayMidnight,
              dateTo: todayMidnight.add(const Duration(days: 1)),
            ),
            data: DayPlanData(
              planDate: todayMidnight,
              status: const DayPlanStatus.draft(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Today button should NOT be visible
      expect(find.byIcon(MdiIcons.calendarToday), findsNothing);
    });

    testWidgets('shows Today button when not on current day', (tester) async {
      // Use a date that is definitely not today (yesterday)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayMidnight =
          DateTime(yesterday.year, yesterday.month, yesterday.day);

      await tester.pumpWidget(
        createTestWidget(
          selectedDate: yesterdayMidnight,
          plan: DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(yesterdayMidnight),
              createdAt: yesterdayMidnight,
              updatedAt: yesterdayMidnight,
              dateFrom: yesterdayMidnight,
              dateTo: yesterdayMidnight.add(const Duration(days: 1)),
            ),
            data: DayPlanData(
              planDate: yesterdayMidnight,
              status: const DayPlanStatus.draft(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Today button should be visible since we're viewing yesterday
      expect(find.byIcon(MdiIcons.calendarToday), findsOneWidget);
    });

    testWidgets('shows status indicator when budgets exist', (tester) async {
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

      // Should show remaining time indicator
      expect(find.text('2h left'), findsOneWidget);
    });

    testWidgets('shows over budget indicator', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 2),
            totalRecorded: Duration(hours: 3),
            budgetCount: 1,
            overBudgetCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show over budget indicator
      expect(find.text('Over budget'), findsOneWidget);
    });

    testWidgets('has navigation buttons', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have left and right chevron buttons
      expect(find.byIcon(MdiIcons.chevronLeft), findsOneWidget);
      expect(find.byIcon(MdiIcons.chevronRight), findsOneWidget);
    });
  });
}
