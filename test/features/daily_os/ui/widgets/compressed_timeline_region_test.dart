import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/ui/widgets/compressed_timeline_region.dart';
import 'package:lotti/features/daily_os/ui/widgets/zigzag_fold_indicator.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';

import '../../../../widget_test_utils.dart';

/// Pumps a [CompressedTimelineRegion] through the shared harness — the
/// static region renders in a single frame, no settle needed.
Future<void> _pumpRegion(
  WidgetTester tester, {
  required CompressedRegion region,
  VoidCallback? onTap,
  double timeAxisWidth = 50,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      CompressedTimelineRegion(
        region: region,
        timeAxisWidth: timeAxisWidth,
        onTap: onTap ?? () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompressedTimelineRegion', () {
    testWidgets('renders time range label', (tester) async {
      const region = CompressedRegion(startHour: 3, endHour: 13);

      await _pumpRegion(tester, region: region);

      expect(find.text('03:00 - 13:00'), findsOneWidget);
    });

    testWidgets('renders zigzag indicator', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await _pumpRegion(tester, region: region);

      expect(find.byType(ZigzagFoldIndicator), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await _pumpRegion(
        tester,
        region: region,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(CompressedTimelineRegion));
      expect(tapped, isTrue);
    });

    testWidgets('has correct height based on hour count', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 10); // 10 hours

      await _pumpRegion(tester, region: region);

      // Height should be 10 hours * 8px per hour = 80px
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(sizedBox.height, 10 * kCompressedHourHeight);
    });

    testWidgets('has expand icon', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await _pumpRegion(tester, region: region);

      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('has accessibility semantics', (tester) async {
      const region = CompressedRegion(startHour: 3, endHour: 9);

      await _pumpRegion(tester, region: region);

      final semantics = tester.getSemantics(
        find.byType(CompressedTimelineRegion),
      );
      expect(
        semantics.label,
        contains('Compressed time region from 3:00 to 9:00'),
      );
    });
  });

  group('AnimatedTimelineRegion', () {
    testWidgets('renders with correct height when collapsed', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 8);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTimelineRegion(
              region: region,
              isExpanded: false,
              normalHourHeight: 40,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should be 8 hours * 8px = 64px when collapsed
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, 8 * kCompressedHourHeight);
    });

    testWidgets('renders with correct height when expanded', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 8);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTimelineRegion(
              region: region,
              isExpanded: true,
              normalHourHeight: 40,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should be 8 hours * 40px = 320px when expanded
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, 8 * 40.0);
    });

    testWidgets('animates height when expanding', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 8);
      const collapsedHeight = 8 * kCompressedHourHeight; // 64px
      const expandedHeight = 8 * 40.0; // 320px

      var isExpanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => isExpanded = !isExpanded),
                      child: const Text('Toggle'),
                    ),
                    AnimatedTimelineRegion(
                      region: region,
                      isExpanded: isExpanded,
                      normalHourHeight: 40,
                      child: Container(color: Colors.blue),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initial collapsed state
      var sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, collapsedHeight);

      // Trigger expansion
      await tester.tap(find.text('Toggle'));
      await tester.pump();

      // Pump partway through animation (150ms of 300ms)
      await tester.pump(const Duration(milliseconds: 150));

      // Height should be between collapsed and expanded (animation in progress)
      sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, greaterThan(collapsedHeight));
      expect(sizedBox.height, lessThan(expandedHeight));

      // Complete the animation
      await tester.pumpAndSettle();

      // Final expanded state
      sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, expandedHeight);
    });

    testWidgets('animates height when collapsing', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 8);
      const collapsedHeight = 8 * kCompressedHourHeight; // 64px
      const expandedHeight = 8 * 40.0; // 320px

      var isExpanded = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => isExpanded = !isExpanded),
                      child: const Text('Toggle'),
                    ),
                    AnimatedTimelineRegion(
                      region: region,
                      isExpanded: isExpanded,
                      normalHourHeight: 40,
                      child: Container(color: Colors.blue),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial expanded state
      var sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, expandedHeight);

      // Trigger collapse
      await tester.tap(find.text('Toggle'));
      await tester.pump();

      // Pump partway through animation (150ms of 300ms)
      await tester.pump(const Duration(milliseconds: 150));

      // Height should be between collapsed and expanded (animation in progress)
      sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, greaterThan(collapsedHeight));
      expect(sizedBox.height, lessThan(expandedHeight));

      // Complete the animation
      await tester.pumpAndSettle();

      // Final collapsed state
      sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, collapsedHeight);
    });

    testWidgets('recomputes heights when region changes via didUpdateWidget', (
      tester,
    ) async {
      // Drive didUpdateWidget's region-change branch: rebuild the SAME
      // AnimatedTimelineRegion element with a different region and assert the
      // collapsed height is recomputed from the new hour count.
      var region = const CompressedRegion(startHour: 0, endHour: 4); // 4h

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() {
                        region = const CompressedRegion(
                          startHour: 0,
                          endHour: 10,
                        ); // 10h
                      }),
                      child: const Text('Grow'),
                    ),
                    AnimatedTimelineRegion(
                      region: region,
                      isExpanded: false,
                      normalHourHeight: 40,
                      child: Container(color: Colors.blue),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      SizedBox animatedSizedBox() => tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AnimatedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );

      // Initial collapsed height for 4 hours.
      expect(animatedSizedBox().height, 4 * kCompressedHourHeight);

      // Change the region (same element) -> didUpdateWidget recomputes heights.
      await tester.tap(find.text('Grow'));
      await tester.pumpAndSettle();

      // Collapsed height now reflects the new 10-hour region.
      expect(animatedSizedBox().height, 10 * kCompressedHourHeight);
    });

    testWidgets(
      'recomputes expanded height when normalHourHeight changes via '
      'didUpdateWidget',
      (tester) async {
        // Drive didUpdateWidget's normalHourHeight-change branch while expanded
        // so the recomputed _expandedHeight is observable in the rendered box.
        const region = CompressedRegion(startHour: 0, endHour: 6); // 6h
        var normalHourHeight = 40.0;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() {
                          normalHourHeight = 60;
                        }),
                        child: const Text('Resize'),
                      ),
                      AnimatedTimelineRegion(
                        region: region,
                        isExpanded: true,
                        normalHourHeight: normalHourHeight,
                        child: Container(color: Colors.blue),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        SizedBox animatedSizedBox() => tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(AnimatedTimelineRegion),
            matching: find.byType(SizedBox),
          ),
        );

        // Expanded height for 6 hours at 40px/hour.
        expect(animatedSizedBox().height, 6 * 40.0);

        // Change normalHourHeight (same element) -> heights recomputed.
        await tester.tap(find.text('Resize'));
        await tester.pumpAndSettle();

        // Expanded height now reflects the new 60px/hour.
        expect(animatedSizedBox().height, 6 * 60.0);
      },
    );
  });

  group('CompressedTimelineRegion edge cases', () {
    testWidgets('formats midnight correctly (00:00)', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await _pumpRegion(tester, region: region);

      expect(find.text('00:00 - 06:00'), findsOneWidget);
    });

    testWidgets('formats end of day correctly (24:00)', (tester) async {
      const region = CompressedRegion(startHour: 22, endHour: 24);

      await _pumpRegion(tester, region: region);

      expect(find.text('22:00 - 24:00'), findsOneWidget);
    });

    testWidgets('handles single hour region', (tester) async {
      const region = CompressedRegion(startHour: 12, endHour: 13);

      await _pumpRegion(tester, region: region);

      expect(find.text('12:00 - 13:00'), findsOneWidget);
      // Height should be 1 hour * 8px = 8px
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(sizedBox.height, 1 * kCompressedHourHeight);
    });

    testWidgets('handles full day region (0-24)', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 24);

      await _pumpRegion(tester, region: region);

      expect(find.text('00:00 - 24:00'), findsOneWidget);
      // Height should be 24 hours * 8px = 192px
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(sizedBox.height, 24 * kCompressedHourHeight);
    });

    testWidgets('respects custom timeAxisWidth', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 100,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find the SizedBox that has the timeAxisWidth
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(SizedBox),
        ),
      );
      final widthBox = sizedBoxes.firstWhere(
        (box) => box.width == 100,
        orElse: () => throw StateError('No SizedBox with width 100 found'),
      );
      expect(widthBox.width, 100);
    });

    testWidgets('tracks tap count', (tester) async {
      var tapCount = 0;
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      // Tap multiple times
      await tester.tap(find.byType(CompressedTimelineRegion));
      await tester.tap(find.byType(CompressedTimelineRegion));
      await tester.tap(find.byType(CompressedTimelineRegion));

      expect(tapCount, 3);
    });
  });

  group('CompressedTimelineRegion visual elements', () {
    testWidgets('contains hour markers based on region size', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 4);

      await _pumpRegion(tester, region: region);

      // The widget generates hour markers in a Stack using List.generate
      // There should be 4 Positioned widgets for hour markers
      final positioned = find.descendant(
        of: find.byType(CompressedTimelineRegion),
        matching: find.byType(Positioned),
      );
      // At least one positioned widget should exist (hour markers)
      expect(positioned, findsWidgets);
    });

    testWidgets('has Row layout with time axis and content', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await _pumpRegion(tester, region: region);

      expect(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(Row),
        ),
        findsWidgets,
      );
    });
  });
}
