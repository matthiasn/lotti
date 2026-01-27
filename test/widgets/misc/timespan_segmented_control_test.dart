import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

import '../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeSpanSegmentedControl', () {
    testWidgets('displays default segments [30, 90, 180, 365] with short labels on phone',
        (tester) async {
      // Default phoneMediaQueryData has width 390 < 450, so short labels are shown
      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display all 4 segment options with short labels
      expect(find.text('30d'), findsOneWidget);
      expect(find.text('90d'), findsOneWidget);
      expect(find.text('180d'), findsOneWidget);
      expect(find.text('365d'), findsOneWidget);
    });

    testWidgets('displays custom segments when provided', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 7,
            segments: const [7, 14, 28],
            onValueChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Short labels on phone screen
      expect(find.text('7d'), findsOneWidget);
      expect(find.text('14d'), findsOneWidget);
      expect(find.text('28d'), findsOneWidget);
      // Default segments should not be present
      expect(find.text('30d'), findsNothing);
      expect(find.text('90d'), findsNothing);
    });

    testWidgets('highlights selected segment', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 180,
            onValueChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the SegmentedButton
      final segmentedButton = find.byType(SegmentedButton<int>);
      expect(segmentedButton, findsOneWidget);

      // The selected value should be 180
      final widget = tester.widget<SegmentedButton<int>>(segmentedButton);
      expect(widget.selected, equals({180}));
    });

    testWidgets('calls onValueChanged when segment is tapped', (tester) async {
      int? selectedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: (value) => selectedValue = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 30d segment (short label on phone)
      await tester.tap(find.text('30d'));
      await tester.pumpAndSettle();

      expect(selectedValue, equals(30));
    });

    testWidgets('calls onValueChanged with 365 when yearly segment is tapped',
        (tester) async {
      int? selectedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: (value) => selectedValue = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('365d'));
      await tester.pumpAndSettle();

      expect(selectedValue, equals(365));
    });

    testWidgets('shows short labels on narrow screens', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          mediaQueryData: const MediaQueryData(
            size: Size(400, 800), // Narrow width < 450
          ),
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show short labels like "30d" instead of "30 days"
      expect(find.text('30d'), findsOneWidget);
      expect(find.text('90d'), findsOneWidget);
      expect(find.text('180d'), findsOneWidget);
      expect(find.text('365d'), findsOneWidget);
    });

    testWidgets('shows full labels on wide screens', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          mediaQueryData: const MediaQueryData(
            size: Size(600, 800), // Wide width >= 450
          ),
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('90 days'), findsOneWidget);
      expect(find.text('180 days'), findsOneWidget);
      expect(find.text('365 days'), findsOneWidget);
    });

    testWidgets('can switch between all segment options', (tester) async {
      final selectedValues = <int>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: StatefulBuilder(
            builder: (context, setState) {
              return TimeSpanSegmentedControl(
                timeSpanDays: selectedValues.isEmpty ? 90 : selectedValues.last,
                onValueChanged: (value) {
                  setState(() => selectedValues.add(value));
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap through all segments
      await tester.tap(find.text('30d'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('180d'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('365d'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('90d'));
      await tester.pumpAndSettle();

      expect(selectedValues, containsAllInOrder([30, 180, 365, 90]));
    });
  });
}
