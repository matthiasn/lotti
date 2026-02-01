import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/date_label_row.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_label_chip.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/today_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
    final effectiveStats = stats ??
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
      await tester.pumpAndSettle();

      // January 15, 2026 is a Thursday
      expect(find.textContaining('Thursday'), findsOneWidget);
      expect(find.textContaining('Jan 15'), findsOneWidget);
    });

    testWidgets('date area tap opens date picker', (tester) async {
      await tester.pumpWidget(createDateLabelRowWidget());
      await tester.pumpAndSettle();

      // Find and tap the date text containing Thursday
      final dateFinder = find.textContaining('Thursday');
      expect(dateFinder, findsOneWidget);

      await tester.tap(dateFinder);
      await tester.pumpAndSettle();

      // Date picker dialog should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('date picker cancellation keeps original date', (tester) async {
      await tester.pumpWidget(createDateLabelRowWidget());
      await tester.pumpAndSettle();

      // Tap the date text to open picker
      final dateFinder = find.textContaining('Thursday');
      await tester.tap(dateFinder);
      await tester.pumpAndSettle();

      // Date picker should be open
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Tap Cancel to dismiss without selecting
      final cancelButton = find.text('Cancel');
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Original date should still be displayed
      expect(find.textContaining('Jan 15'), findsOneWidget);
    });

    testWidgets('shows/hides Today button based on selected date',
        (tester) async {
      // Use fixed date to avoid flakiness around midnight
      final fixedToday = DateTime(2024, 1, 2, 12);
      final todayMidnight = DateTime(2024, 1, 2);

      // Mock the clock so _isToday uses our fixed "today"
      await withClock(Clock.fixed(fixedToday), () async {
        await tester.pumpWidget(
          createDateLabelRowWidget(selectedDate: todayMidnight),
        );
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        // When viewing yesterday - Today button should appear
        expect(find.byIcon(MdiIcons.calendarToday), findsOneWidget);
      });
    });

    testWidgets('displays day label chip when present', (tester) async {
      await tester.pumpWidget(
        createDateLabelRowWidget(dayLabel: 'Focus Day'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus Day'), findsOneWidget);
    });

    testWidgets('hides day label chip when label is empty', (tester) async {
      await tester.pumpWidget(
        createDateLabelRowWidget(dayLabel: ''),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        final todayButton = find.byIcon(MdiIcons.calendarToday);
        expect(todayButton, findsOneWidget);

        await tester.tap(todayButton);
        await tester.pumpAndSettle();

        expect(callbackCalled, true);
      });
    });
  });

  group('DayLabelChip', () {
    testWidgets('displays label text', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: DayLabelChip(label: 'Test Label'),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
    });

    testWidgets('truncates long labels', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: DayLabelChip(
            label: 'This is a very long label that should be truncated',
          ),
        ),
      );

      // The text should be found but constrained
      expect(
        find.text('This is a very long label that should be truncated'),
        findsOneWidget,
      );

      // Check that DayLabelChip has a max width constraint
      final constrainedBox = find.descendant(
        of: find.byType(DayLabelChip),
        matching: find.byType(ConstrainedBox),
      );
      expect(constrainedBox, findsOneWidget);
    });
  });

  group('TodayButton', () {
    testWidgets('displays Today text', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TodayButton(onPressed: () {}),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('displays calendar icon', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TodayButton(onPressed: () {}),
        ),
      );

      expect(find.byIcon(MdiIcons.calendarToday), findsOneWidget);
    });

    testWidgets('triggers callback on press', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: TodayButton(onPressed: () => pressed = true),
        ),
      );

      await tester.tap(find.byType(TodayButton));
      expect(pressed, true);
    });
  });
}
