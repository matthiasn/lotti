import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

import '../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeSpanSegmentedControl', () {
    testWidgets(
      'displays default segments [30, 90, 180, 365] with short labels on phone',
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
        await tester.pump(const Duration(milliseconds: 50));

        // Should display all 4 segment options with short labels
        expect(find.text('30d'), findsOneWidget);
        expect(find.text('90d'), findsOneWidget);
        expect(find.text('180d'), findsOneWidget);
        expect(find.text('365d'), findsOneWidget);
      },
    );

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
      await tester.pump(const Duration(milliseconds: 50));

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
      await tester.pump(const Duration(milliseconds: 50));

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
      await tester.pump(const Duration(milliseconds: 50));

      // Tap the 30d segment (short label on phone)
      await tester.tap(find.text('30d'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(selectedValue, equals(30));
    });

    testWidgets('calls onValueChanged with 365 when yearly segment is tapped', (
      tester,
    ) async {
      int? selectedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: (value) => selectedValue = value,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('365d'));
      await tester.pump(const Duration(milliseconds: 50));

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
      await tester.pump(const Duration(milliseconds: 50));

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
      await tester.pump(const Duration(milliseconds: 50));

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
      await tester.pump(const Duration(milliseconds: 50));

      // Tap through all segments
      await tester.tap(find.text('30d'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('180d'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('365d'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('90d'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(selectedValues, containsAllInOrder([30, 180, 365, 90]));
    });

    // ── Property: selection + label form over arbitrary segment lists ──────
    final propertyCases =
        <({List<int> segments, int selectedIndex, double width})>[
          (segments: [7, 14, 21], selectedIndex: 0, width: 320),
          (segments: [30, 90, 180, 365], selectedIndex: 2, width: 449),
          (segments: [1, 5], selectedIndex: 1, width: 450),
          (segments: [10, 20, 40, 80, 160], selectedIndex: 4, width: 1024),
          (segments: [365], selectedIndex: 0, width: 200),
        ];
    for (final c in propertyCases) {
      testWidgets(
        'property: segments=${c.segments} sel=${c.selectedIndex} '
        'width=${c.width}',
        (tester) async {
          final selectedDays = c.segments[c.selectedIndex];
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(c.width, 800)),
                child: Scaffold(
                  body: TimeSpanSegmentedControl(
                    timeSpanDays: selectedDays,
                    onValueChanged: (_) {},
                    segments: c.segments,
                  ),
                ),
              ),
            ),
          );

          // The selected set is exactly {timeSpanDays}.
          final button = tester.widget<SegmentedButton<int>>(
            find.byType(SegmentedButton<int>),
          );
          expect(button.selected, {selectedDays});

          // Labels are exactly the short form below 450px, long form at/above.
          final shortLabels = c.width < 450;
          for (final days in c.segments) {
            expect(
              find.text(shortLabels ? '${days}d' : '$days days'),
              findsOneWidget,
            );
            expect(
              find.text(shortLabels ? '$days days' : '${days}d'),
              findsNothing,
            );
          }
        },
      );
    }
  });
}
