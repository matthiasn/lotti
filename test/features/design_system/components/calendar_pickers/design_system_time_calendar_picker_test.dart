import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_time_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTimeCalendarPicker', () {
    Future<void> pumpPicker(
      WidgetTester tester, {
      required DesignSystemTimeCalendarPickerPresentation presentation,
      required DesignSystemTimeCalendarPickerMode mode,
      VoidCallback? onMonthYearPressed,
      VoidCallback? onPreviousPressed,
      VoidCallback? onNextPressed,
      ValueChanged<DateTime>? onDayPressed,
      ValueChanged<DateTime>? onMonthPressed,
    }) {
      return tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimeCalendarPicker(
            mode: mode,
            presentation: presentation,
            visibleMonth: DateTime(2025, 4),
            selectedDate: DateTime(2025, 4, 17),
            currentDate: DateTime(2025, 4),
            onMonthYearPressed: onMonthYearPressed,
            onPreviousPressed: onPreviousPressed,
            onNextPressed: onNextPressed,
            onDayPressed: onDayPressed,
            onMonthPressed: onMonthPressed,
          ),
          theme: mode == DesignSystemTimeCalendarPickerMode.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
        ),
      );
    }

    Future<void> pumpInteractivePicker(
      WidgetTester tester, {
      required DesignSystemTimeCalendarPickerPresentation presentation,
      required DesignSystemTimeCalendarPickerMode mode,
    }) {
      return tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemInteractiveTimeCalendarPicker(
            mode: mode,
            presentation: presentation,
            initialSelectedDate: DateTime(2025, 4, 17),
            currentDate: DateTime(2025, 4),
          ),
          theme: mode == DesignSystemTimeCalendarPickerMode.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
        ),
      );
    }

    testWidgets('regular presentation forwards header and day callbacks', (
      tester,
    ) async {
      var monthYearTapCount = 0;
      var previousTapCount = 0;
      var nextTapCount = 0;
      DateTime? pressedDay;

      await pumpPicker(
        tester,
        presentation: DesignSystemTimeCalendarPickerPresentation.regular,
        mode: DesignSystemTimeCalendarPickerMode.light,
        onMonthYearPressed: () => monthYearTapCount += 1,
        onPreviousPressed: () => previousTapCount += 1,
        onNextPressed: () => nextTapCount += 1,
        onDayPressed: (date) => pressedDay = date,
      );

      expect(find.text('April 2025'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);

      await tester.tap(find.text('April 2025'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
      await tester.pump();
      await tester.tap(find.text('17'));
      await tester.pump();

      expect(monthYearTapCount, 1);
      expect(previousTapCount, 1);
      expect(nextTapCount, 1);
      expect(pressedDay, DateTime(2025, 4, 17));
    });

    testWidgets('compact presentation renders the compact calendar card', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        presentation: DesignSystemTimeCalendarPickerPresentation.compact,
        mode: DesignSystemTimeCalendarPickerMode.light,
      );

      expect(find.text('April 2025'), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('month dialog presentation shows months without disclosure', (
      tester,
    ) async {
      DateTime? selectedMonth;

      await pumpPicker(
        tester,
        presentation: DesignSystemTimeCalendarPickerPresentation.monthDialog,
        mode: DesignSystemTimeCalendarPickerMode.light,
        onMonthPressed: (date) => selectedMonth = date,
      );

      expect(find.text('2025'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);

      await tester.tap(find.text('Sep'));
      await tester.pump();

      expect(selectedMonth, DateTime(2025, 9));
    });

    testWidgets('dark mode uses the MCP selected and current-day colors', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        presentation: DesignSystemTimeCalendarPickerPresentation.regular,
        mode: DesignSystemTimeCalendarPickerMode.dark,
      );

      final selectedDay = tester.widget<Text>(find.text('17'));
      final currentDay = tester.widget<Text>(find.text('1'));

      expect(selectedDay.style?.color, const Color(0xFF0E0E0E));
      expect(currentDay.style?.color, const Color(0xFF5ED4B7));
    });

    testWidgets('interactive compact picker opens the month dialog', (
      tester,
    ) async {
      await pumpInteractivePicker(
        tester,
        presentation: DesignSystemTimeCalendarPickerPresentation.compact,
        mode: DesignSystemTimeCalendarPickerMode.light,
      );

      await tester.tap(find.text('April 2025'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('2025'), findsOneWidget);
      expect(find.text('Sep'), findsOneWidget);

      await tester.tap(find.text('Sep'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('September 2025'), findsOneWidget);
    });

    testWidgets(
      'interactive compact picker dismisses the month dialog outside',
      (
        tester,
      ) async {
        await pumpInteractivePicker(
          tester,
          presentation: DesignSystemTimeCalendarPickerPresentation.compact,
          mode: DesignSystemTimeCalendarPickerMode.light,
        );

        await tester.tap(find.text('April 2025'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('2025'), findsOneWidget);

        await tester.tapAt(const Offset(8, 8));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('2025'), findsNothing);
        expect(find.text('April 2025'), findsOneWidget);
      },
    );
  });
}
