import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/date_label_row.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_label_chip.dart';
import 'package:lotti/utils/device_region.dart';

import '../../../../../test_helper.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createDateLabelRowWidget({
    DateTime? selectedDate,
    DayBudgetStats? stats,
    String? dayLabel,
    VoidCallback? onTodayPressed,
  }) {
    final date = selectedDate ?? testDate;
    final effectiveStats =
        stats ??
        const DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );
    final plan = createTestPlan(date: date, dayLabel: dayLabel);
    final unifiedData = createUnifiedData(date: date, plan: plan);

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWith(
          () => TestDailyOsSelectedDate(date),
        ),
        unifiedDailyOsDataControllerProvider(date: date).overrideWith(
          () => TestUnifiedController(unifiedData),
        ),
        dayBudgetStatsProvider(date: date).overrideWith(
          (ref) async => effectiveStats,
        ),
        firstDayOfWeekIndexProvider.overrideWith((ref) async => 1),
      ],
      child: DateLabelRow(
        selectedDate: date,
        onTodayPressed: onTodayPressed ?? () {},
      ),
    );
  }

  group('DateLabelRow', () {
    testWidgets('displays formatted date with day name', (tester) async {
      await tester.pumpWidget(createDateLabelRowWidget());
      await tester.pump();

      // January 15, 2026 is a Thursday
      expect(find.textContaining('Thursday'), findsOneWidget);
      expect(find.textContaining('Jan 15'), findsOneWidget);
    });

    testWidgets('date area tap opens date picker', (tester) async {
      await tester.pumpWidget(createDateLabelRowWidget());
      await tester.pump();

      // Find and tap the date text containing Thursday
      final dateFinder = find.textContaining('Thursday');
      expect(dateFinder, findsOneWidget);

      await tester.tap(dateFinder);
      await tester.pump();

      // Date picker dialog should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('date picker cancellation keeps original date', (tester) async {
      await tester.pumpWidget(createDateLabelRowWidget());
      await tester.pump();

      // Tap the date text to open picker
      final dateFinder = find.textContaining('Thursday');
      await tester.tap(dateFinder);
      await tester.pump();

      // Date picker should be open
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Tap Cancel to dismiss without selecting
      final cancelButton = find.text('Cancel');
      await tester.tap(cancelButton);
      await tester.pump();

      // Original date should still be displayed
      expect(find.textContaining('Jan 15'), findsOneWidget);
    });

    testWidgets('shows/hides Today button based on selected date', (
      tester,
    ) async {
      // Use fixed date to avoid flakiness around midnight
      final fixedToday = DateTime(2024, 1, 2, 12);
      final todayMidnight = DateTime(2024, 1, 2);

      // Mock the clock so _isToday uses our fixed "today"
      await withClock(Clock.fixed(fixedToday), () async {
        await tester.pumpWidget(
          createDateLabelRowWidget(selectedDate: todayMidnight),
        );
        await tester.pump();

        // When viewing today - no Today button
        expect(find.byIcon(MdiIcons.calendarToday), findsNothing);
      });
    });

    testWidgets('shows Today button when not viewing today', (tester) async {
      // Use fixed date to avoid flakiness around midnight
      final fixedToday = DateTime(2024, 1, 2, 12);
      final yesterdayMidnight = DateTime(2024);

      await withClock(Clock.fixed(fixedToday), () async {
        await tester.pumpWidget(
          createDateLabelRowWidget(selectedDate: yesterdayMidnight),
        );
        await tester.pump();

        // When viewing yesterday - Today button should appear
        expect(find.byIcon(MdiIcons.calendarToday), findsOneWidget);
      });
    });

    testWidgets('displays day label chip when present', (tester) async {
      await tester.pumpWidget(
        createDateLabelRowWidget(dayLabel: 'Focus Day'),
      );
      await tester.pump();

      expect(find.text('Focus Day'), findsOneWidget);
    });

    testWidgets('hides day label chip when label is empty', (tester) async {
      await tester.pumpWidget(
        createDateLabelRowWidget(dayLabel: ''),
      );
      await tester.pump();

      // Should not find any chip with empty label
      expect(find.byType(DayLabelChip), findsNothing);
    });

    testWidgets('displays budget status indicator', (tester) async {
      await tester.pumpWidget(
        createDateLabelRowWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 2),
            budgetCount: 2,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pump();

      // Should show remaining time indicator
      expect(find.text('2 hours left'), findsOneWidget);
    });

    testWidgets('hides status indicator when no budgets', (tester) async {
      await tester.pumpWidget(
        createDateLabelRowWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration.zero,
            totalRecorded: Duration.zero,
            budgetCount: 0,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pump();

      // No status indicator icons should be present
      expect(find.byIcon(MdiIcons.clockOutline), findsNothing);
      expect(find.byIcon(MdiIcons.alertCircle), findsNothing);
      expect(find.byIcon(MdiIcons.checkCircle), findsNothing);
    });

    testWidgets('Today button triggers callback when pressed', (tester) async {
      var callbackCalled = false;
      final fixedToday = DateTime(2024, 1, 2, 12);
      final yesterday = DateTime(2024);

      await withClock(Clock.fixed(fixedToday), () async {
        await tester.pumpWidget(
          createDateLabelRowWidget(
            selectedDate: yesterday,
            onTodayPressed: () => callbackCalled = true,
          ),
        );
        await tester.pump();

        final todayButton = find.byIcon(MdiIcons.calendarToday);
        expect(todayButton, findsOneWidget);

        await tester.tap(todayButton);
        await tester.pump();

        expect(callbackCalled, true);
      });
    });
  });
}
