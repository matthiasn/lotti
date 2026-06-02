import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_time_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTimePicker', () {
    testWidgets('renders at 212px height with 24-hour format', (
      tester,
    ) async {
      const pickerKey = Key('24h-picker');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            key: pickerKey,
            onTimeChanged: (_) {},
            semanticsLabel: 'Select time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.getSize(find.byKey(pickerKey)).height, 212);
      // 24h mode has 2 columns (hour + minute), no AM/PM
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });

    testWidgets('renders 12-hour format with AM/PM column', (tester) async {
      const pickerKey = Key('12h-picker');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            key: pickerKey,
            format: DesignSystemTimeFormat.twelveHour,
            initialTime: const TimeOfDay(hour: 9, minute: 41),
            onTimeChanged: (_) {},
            semanticsLabel: 'Select time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('AM'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
    });

    testWidgets('calls onTimeChanged when scrolling minute column', (
      tester,
    ) async {
      TimeOfDay? changedTime;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            initialTime: const TimeOfDay(hour: 9, minute: 41),
            onTimeChanged: (time) => changedTime = time,
            semanticsLabel: 'Select time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Find the ListWheelScrollViews (hour and minute columns)
      final scrollViews = find.byType(ListWheelScrollView);
      expect(scrollViews, findsAtLeastNWidgets(2));

      // Scroll the minute column (second one)
      await tester.drag(scrollViews.at(1), const Offset(0, -31));
      await tester.pumpAndSettle();

      expect(changedTime, isNotNull);
    });

    testWidgets('reports updated hour when scrolling hour column', (
      tester,
    ) async {
      TimeOfDay? changedTime;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            initialTime: const TimeOfDay(hour: 9, minute: 41),
            onTimeChanged: (time) => changedTime = time,
            semanticsLabel: 'Select time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Hour column is the first ListWheelScrollView. Dragging up by one item
      // extent (31px) advances the selected hour index from 9 to 10.
      final scrollViews = find.byType(ListWheelScrollView);
      await tester.drag(scrollViews.first, const Offset(0, -31));
      await tester.pumpAndSettle();

      expect(changedTime, isNotNull);
      // 24h mode: selected hour index maps directly to the hour.
      expect(changedTime!.hour, 10);
      // Minute is untouched by the hour-column scroll.
      expect(changedTime!.minute, 41);
    });

    testWidgets('reports period change when scrolling AM/PM column', (
      tester,
    ) async {
      TimeOfDay? changedTime;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            format: DesignSystemTimeFormat.twelveHour,
            // 9:41 AM -> hourOfPeriod 9, period AM (index 0).
            initialTime: const TimeOfDay(hour: 9, minute: 41),
            onTimeChanged: (time) => changedTime = time,
            semanticsLabel: 'Select time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // AM/PM column is the third ListWheelScrollView in 12h mode. Dragging up
      // by one item extent moves the period from AM (0) to PM (1).
      final scrollViews = find.byType(ListWheelScrollView);
      expect(scrollViews, findsNWidgets(3));
      await tester.drag(scrollViews.at(2), const Offset(0, -31));
      await tester.pumpAndSettle();

      expect(changedTime, isNotNull);
      // Flipping AM -> PM keeps the hour-of-period (9) but adds 12 hours.
      expect(changedTime!.hour, 21);
      // Minute is untouched by the period-column scroll.
      expect(changedTime!.minute, 41);
    });

    testWidgets('provides semantics label', (tester) async {
      const pickerKey = Key('semantics-picker');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            key: pickerKey,
            onTimeChanged: (_) {},
            semanticsLabel: 'Choose departure time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(pickerKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Choose departure time',
          ),
        ),
      );

      expect(semantics.properties.label, 'Choose departure time');
    });

    testWidgets('renders selection overlay lines', (tester) async {
      const pickerKey = Key('overlay-picker');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            key: pickerKey,
            onTimeChanged: (_) {},
            semanticsLabel: 'Time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // The selection overlay is a 31px tall box with border
      final decoratedBoxes = find.descendant(
        of: find.byKey(pickerKey),
        matching: find.byType(DecoratedBox),
      );
      expect(decoratedBoxes, findsAtLeastNWidgets(1));
    });

    testWidgets('12h format reports correct PM time', (tester) async {
      TimeOfDay? changedTime;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            format: DesignSystemTimeFormat.twelveHour,
            initialTime: const TimeOfDay(hour: 14, minute: 30),
            onTimeChanged: (time) => changedTime = time,
            semanticsLabel: 'Time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Scroll minute slightly to trigger callback
      final scrollViews = find.byType(ListWheelScrollView);
      await tester.drag(scrollViews.at(1), const Offset(0, -31));
      await tester.pumpAndSettle();

      // Should report a PM time (hour >= 12)
      expect(changedTime, isNotNull);
      expect(changedTime!.hour, greaterThanOrEqualTo(12));
    });

    testWidgets('applies fade-out opacity to non-center items', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            onTimeChanged: (_) {},
            semanticsLabel: 'Time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final scrollView = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView).first,
      );

      expect(scrollView.overAndUnderCenterOpacity, 0.35);
      expect(scrollView.squeeze, 1.1);
      expect(scrollView.diameterRatio, 1.2);
      expect(scrollView.magnification, 1.15);
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimePicker(
            onTimeChanged: (_) {},
            semanticsLabel: 'Time',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
