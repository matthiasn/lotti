import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_time_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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

      final enabledHeaderButtons = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.onPressed != null,
      );

      expect(find.text('April 2025'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);
      expect(enabledHeaderButtons, findsNWidgets(2));
      expect(tester.getSize(enabledHeaderButtons.first), const Size(48, 48));
      expect(tester.getSize(enabledHeaderButtons.last), const Size(48, 48));

      await tester.tap(find.text('April 2025'));
      await tester.pump();
      await tester.tap(enabledHeaderButtons.first);
      await tester.pump();
      await tester.tap(enabledHeaderButtons.last);
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

      expect(
        selectedDay.style?.color,
        dsTokensDark.colors.text.onInteractiveAlert,
      );
      expect(currentDay.style?.color, dsTokensDark.colors.interactive.enabled);
    });

    testWidgets('uses token typography for header and calendar labels', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        presentation: DesignSystemTimeCalendarPickerPresentation.regular,
        mode: DesignSystemTimeCalendarPickerMode.light,
      );

      final header = tester.widget<Text>(find.text('April 2025'));
      final weekday = tester.widget<Text>(find.text('SUN'));
      final selectedDay = tester.widget<Text>(find.text('17'));

      expectTextStyle(
        header.style!,
        dsTokensLight.typography.styles.subtitle.subtitle1,
        dsTokensLight.colors.text.highEmphasis,
      );
      expectTextStyle(
        weekday.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.text.lowEmphasis,
      );
      expectTextStyle(
        selectedDay.style!,
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
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

    // Lines 234–237: _selectDay updates _selectedDate and _visibleMonth
    testWidgets(
      'interactive picker updates selected day when a day cell is tapped',
      (tester) async {
        await pumpInteractivePicker(
          tester,
          presentation: DesignSystemTimeCalendarPickerPresentation.regular,
          mode: DesignSystemTimeCalendarPickerMode.light,
        );

        // Day 17 is initially selected (accent background).
        final day17Before = tester.widget<Text>(find.text('17'));
        expect(
          day17Before.style?.color,
          dsTokensLight.colors.text.onInteractiveAlert,
        );

        // Tap day 10 — this exercises _selectDay (lines 234–237).
        await tester.tap(find.text('10'));
        await tester.pump();

        // Day 10 is now the selected day (onAccent color).
        final day10After = tester.widget<Text>(find.text('10'));
        expect(
          day10After.style?.color,
          dsTokensLight.colors.text.onInteractiveAlert,
        );

        // Day 17 is no longer selected — reverts to highEmphasis color.
        final day17After = tester.widget<Text>(find.text('17'));
        expect(
          day17After.style?.color,
          dsTokensLight.colors.text.highEmphasis,
        );
      },
    );

    // Lines 228–230 + 250–251: _changeMonth via prev/next arrow buttons
    testWidgets(
      'interactive picker previous/next buttons navigate months',
      (tester) async {
        await pumpInteractivePicker(
          tester,
          presentation: DesignSystemTimeCalendarPickerPresentation.regular,
          mode: DesignSystemTimeCalendarPickerMode.light,
        );

        expect(find.text('April 2025'), findsOneWidget);

        final headerButtons = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.onPressed != null,
        );

        // Tap the "previous" (left) button → exercises _changeMonth(-1), line 250.
        await tester.tap(headerButtons.first);
        await tester.pump();
        expect(find.text('March 2025'), findsOneWidget);

        // Tap the "next" (right) button twice to go back to April then May.
        await tester.tap(headerButtons.last);
        await tester.pump();
        expect(find.text('April 2025'), findsOneWidget);

        await tester.tap(headerButtons.last);
        await tester.pump();
        // → exercises _changeMonth(+1), line 251.
        expect(find.text('May 2025'), findsOneWidget);
      },
    );

    // Lines 482–483: year prev/next in _MonthSelectionDialogCard
    testWidgets(
      'month dialog year navigation changes displayed year',
      (tester) async {
        await pumpPicker(
          tester,
          presentation: DesignSystemTimeCalendarPickerPresentation.monthDialog,
          mode: DesignSystemTimeCalendarPickerMode.light,
          onMonthPressed: (_) {},
        );

        expect(find.text('2025'), findsOneWidget);

        final yearButtons = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.onPressed != null,
        );

        // Tap previous → _visibleYear -= 1 (line 482).
        await tester.tap(yearButtons.first);
        await tester.pump();
        expect(find.text('2024'), findsOneWidget);
        expect(find.text('2025'), findsNothing);

        // Tap next → _visibleYear += 1 (line 483).
        await tester.tap(yearButtons.last);
        await tester.pump();
        expect(find.text('2025'), findsOneWidget);
        expect(find.text('2024'), findsNothing);
      },
    );

    // Line 186: no-op onTap on the GestureDetector wrapping the picker card
    // inside the month dialog prevents taps on the card from closing the dialog.
    testWidgets(
      'tapping inside the dialog card does not dismiss the month dialog',
      (tester) async {
        await pumpInteractivePicker(
          tester,
          presentation: DesignSystemTimeCalendarPickerPresentation.compact,
          mode: DesignSystemTimeCalendarPickerMode.light,
        );

        // Open the month dialog.
        await tester.tap(find.text('April 2025'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('2025'), findsOneWidget);

        // Tap a month label inside the card — the inner GestureDetector's no-op
        // onTap (line 186) prevents the tap from reaching the barrier dismisser.
        await tester.tap(find.text('Jan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Dialog is dismissed after selecting a month.
        expect(find.text('2025'), findsNothing);
        expect(find.text('January 2025'), findsOneWidget);
      },
    );
  });
}
