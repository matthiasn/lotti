import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/ui/widgets/compressed_timeline_region.dart';
import 'package:lotti/features/daily_os/ui/widgets/zigzag_fold_indicator.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompressedTimelineRegion', () {
    testWidgets('renders time range label', (tester) async {
      const region = CompressedRegion(startHour: 3, endHour: 13);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('03:00 - 13:00'), findsOneWidget);
    });

    testWidgets('renders zigzag indicator', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(ZigzagFoldIndicator), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CompressedTimelineRegion));
      expect(tapped, isTrue);
    });

    testWidgets('has correct height based on hour count', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 10); // 10 hours

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      // Height should be 10 hours * 8px per hour = 80px
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(sizedBox.height, 10 * kCompressedHourHeightDefault);
    });

    testWidgets('has expand icon', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('has accessibility semantics', (tester) async {
      const region = CompressedRegion(startHour: 3, endHour: 9);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(
        find.byType(CompressedTimelineRegion),
      );
      expect(
        semantics.label,
        contains('Compressed time region from 3:00 to 9:00'),
      );
    });
  });

  group('ZigzagFoldIndicator', () {
    testWidgets('renders CustomPaint with ZigzagFoldPainter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 100,
              child: ZigzagFoldIndicator(
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );

      // Use specific finder since Scaffold may add its own CustomPaint
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is ZigzagFoldPainter,
        ),
        findsOneWidget,
      );
    });
  });

  group('ZigzagFoldPainter', () {
    test('shouldRepaint returns true when color changes', () {
      const painter1 = ZigzagFoldPainter(color: Colors.grey);
      const painter2 = ZigzagFoldPainter(color: Colors.blue);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when same properties', () {
      const painter1 = ZigzagFoldPainter(color: Colors.grey);
      const painter2 = ZigzagFoldPainter(color: Colors.grey);

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true when zigzagWidth changes', () {
      const painter1 = ZigzagFoldPainter(color: Colors.grey, zigzagWidth: 5);
      const painter2 = ZigzagFoldPainter(color: Colors.grey, zigzagWidth: 8);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when zigzagHeight changes', () {
      const painter1 = ZigzagFoldPainter(color: Colors.grey, zigzagHeight: 3);
      const painter2 = ZigzagFoldPainter(color: Colors.grey, zigzagHeight: 7);

      expect(painter1.shouldRepaint(painter2), isTrue);
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
      expect(sizedBox.height, 8 * kCompressedHourHeightDefault);
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
      const collapsedHeight = 8 * kCompressedHourHeightDefault; // 64px
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
      const collapsedHeight = 8 * kCompressedHourHeightDefault; // 64px
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
  });

  group('CompressedTimelineRegion edge cases', () {
    testWidgets('formats midnight correctly (00:00)', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('00:00 - 06:00'), findsOneWidget);
    });

    testWidgets('formats end of day correctly (24:00)', (tester) async {
      const region = CompressedRegion(startHour: 22, endHour: 24);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('22:00 - 24:00'), findsOneWidget);
    });

    testWidgets('handles single hour region', (tester) async {
      const region = CompressedRegion(startHour: 12, endHour: 13);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('12:00 - 13:00'), findsOneWidget);
      // Height should be 1 hour * 8px = 8px
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(sizedBox.height, 1 * kCompressedHourHeightDefault);
    });

    testWidgets('handles full day region (0-24)', (tester) async {
      const region = CompressedRegion(startHour: 0, endHour: 24);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('00:00 - 24:00'), findsOneWidget);
      // Height should be 24 hours * 8px = 192px
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CompressedTimelineRegion),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(sizedBox.height, 24 * kCompressedHourHeightDefault);
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressedTimelineRegion(
              region: region,
              timeAxisWidth: 50,
              onTap: () {},
            ),
          ),
        ),
      );

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
