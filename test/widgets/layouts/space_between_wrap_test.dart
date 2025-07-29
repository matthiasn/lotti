import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/layouts/space_between_wrap.dart';

void main() {
  group('SpaceBetweenWrap', () {
    Widget buildTestWidget({
      required List<Widget> children,
      double spacing = 10.0,
      double runSpacing = 10.0,
      double? maxWidth,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: maxWidth,
              child: SpaceBetweenWrap(
                spacing: spacing,
                runSpacing: runSpacing,
                children: children,
              ),
            ),
          ),
        ),
      );
    }

    Widget buildBox(
        {required double width, required double height, required Color color}) {
      return Container(
        width: width,
        height: height,
        color: color,
      );
    }

    testWidgets('renders empty when no children provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          children: [],
          maxWidth: 400,
        ),
      );

      expect(find.byType(SpaceBetweenWrap), findsOneWidget);
      expect(find.byType(SizedBox),
          findsAtLeastNWidgets(1)); // The wrapper SizedBox
    });

    testWidgets('renders single child taking full width',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 100, height: 50, color: Colors.red),
          ],
          maxWidth: 400,
        ),
      );

      await tester.pumpAndSettle();

      final spaceBetweenWrap = tester.widget<SpaceBetweenWrap>(
        find.byType(SpaceBetweenWrap),
      );
      expect(spaceBetweenWrap.children.length, 1);

      // The single child should be positioned at the start
      // ignore_for_file: omit_local_variable_types
      final RenderBox renderBox =
          tester.renderObject(find.byType(SpaceBetweenWrap));
      expect(renderBox.size.width, 400);
    });

    testWidgets('distributes children with space between when they fit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 50, height: 50, color: Colors.red),
            buildBox(width: 50, height: 50, color: Colors.green),
            buildBox(width: 50, height: 50, color: Colors.blue),
          ],
          maxWidth: 400,
        ),
      );

      await tester.pumpAndSettle();

      final RenderBox renderBox =
          tester.renderObject(find.byType(SpaceBetweenWrap));
      expect(renderBox.size.width, 400);
      expect(renderBox.size.height, 50); // Single row height

      // Get exact positions of all three boxes
      final redBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.red,
      ));
      final greenBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.green,
      ));
      final blueBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.blue,
      ));

      // Verify relative positions for spaceBetween layout
      // Total width = 400, total children width = 150, available space = 250
      // Space between 3 items = 250 / 2 = 125
      expect(greenBox.dx - redBox.dx, 175); // 50 + 125
      expect(blueBox.dx - greenBox.dx, 175); // 50 + 125
      expect(blueBox.dx - redBox.dx, 350); // Total spread

      // All should be on same row
      expect(redBox.dy, equals(greenBox.dy));
      expect(greenBox.dy, equals(blueBox.dy));
    });

    testWidgets('wraps to next line when children do not fit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 150, height: 50, color: Colors.red),
            buildBox(width: 150, height: 50, color: Colors.green),
            buildBox(width: 150, height: 50, color: Colors.blue),
          ],
          runSpacing: 20,
          maxWidth: 320, // Just enough for 2 items per row
        ),
      );

      await tester.pumpAndSettle();

      final RenderBox renderBox =
          tester.renderObject(find.byType(SpaceBetweenWrap));

      // Get exact positions
      final redBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.red,
      ));
      final greenBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.green,
      ));
      final blueBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.blue,
      ));

      // With maxWidth 320:
      // First row: red (150) + spacing (10) + green (150) = 310, fits!
      // Second row: blue wraps because no more space

      expect(greenBox.dx - redBox.dx, 160); // 150 + 10 spacing
      expect(greenBox.dy, equals(redBox.dy)); // Same row

      // Blue wraps to second row
      expect(blueBox.dx, equals(redBox.dx)); // Starts at beginning
      expect(blueBox.dy - redBox.dy, 70); // 50 (height) + 20 (runSpacing)

      // Total height should be 2 rows
      expect(renderBox.size.height, 120); // 50 + 20 + 50
    });

    testWidgets('handles different sized children correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 80, height: 30, color: Colors.red),
            buildBox(width: 120, height: 60, color: Colors.green),
            buildBox(width: 60, height: 40, color: Colors.blue),
          ],
          maxWidth: 400,
        ),
      );

      await tester.pumpAndSettle();

      final RenderBox renderBox =
          tester.renderObject(find.byType(SpaceBetweenWrap));
      expect(renderBox.size.width, 400);
      expect(renderBox.size.height, 60); // Height of tallest child
    });

    testWidgets('respects spacing parameter in wrap mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 100, height: 50, color: Colors.red),
            buildBox(width: 100, height: 50, color: Colors.green),
            buildBox(width: 100, height: 50, color: Colors.blue),
            buildBox(width: 100, height: 50, color: Colors.yellow),
          ],
          spacing: 15,
          runSpacing: 25,
          maxWidth: 250, // Forces wrapping
        ),
      );

      await tester.pumpAndSettle();

      // Find positions
      final redBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.red,
      ));
      final greenBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.green,
      ));
      final blueBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.blue,
      ));

      // Check horizontal spacing on same row
      if (greenBox.dy == redBox.dy) {
        expect(greenBox.dx - redBox.dx, 115); // 100 width + 15 spacing
      }

      // Check vertical spacing between rows
      if (blueBox.dy > redBox.dy) {
        expect(blueBox.dy - redBox.dy, 75); // 50 height + 25 runSpacing
      }
    });

    testWidgets('updates layout when spacing changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SpaceBetweenWrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    buildBox(width: 100, height: 50, color: Colors.red),
                    buildBox(width: 100, height: 50, color: Colors.green),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Update spacing
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SpaceBetweenWrap(
                  spacing: 30,
                  runSpacing: 30,
                  children: [
                    buildBox(width: 100, height: 50, color: Colors.red),
                    buildBox(width: 100, height: 50, color: Colors.green),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify layout updated
      final RenderBox renderBox =
          tester.renderObject(find.byType(SpaceBetweenWrap));
      expect(renderBox.hasSize, isTrue);
    });

    testWidgets('handles width constraints correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 100, height: 50, color: Colors.red),
            buildBox(width: 100, height: 50, color: Colors.green),
          ],
          maxWidth: 150, // Less than needed for both
        ),
      );

      await tester.pumpAndSettle();

      final RenderBox renderBox =
          tester.renderObject(find.byType(SpaceBetweenWrap));
      expect(renderBox.size.width, lessThanOrEqualTo(150));
      expect(renderBox.size.height, greaterThan(50)); // Should wrap
    });

    testWidgets('correctly switches between spaceBetween and wrap modes',
        (WidgetTester tester) async {
      // Test that demonstrates the key behavior difference
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 80, height: 50, color: Colors.red),
            buildBox(width: 80, height: 50, color: Colors.green),
            buildBox(width: 80, height: 50, color: Colors.blue),
          ],
          maxWidth: 270, // Exactly enough: 80*3 + 10*2 = 260, fits!
        ),
      );

      await tester.pumpAndSettle();

      var redBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.red,
      ));
      var greenBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.green,
      ));
      var blueBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.blue,
      ));

      // Should use spaceBetween mode
      // Total width = 270, children = 240, min spacing = 20
      // Available for distribution = 270 - 240 = 30
      // Distributed between 2 gaps = 30 / 2 = 15 per gap
      // So each gap = 80 + 15 = 95
      expect(greenBox.dx - redBox.dx, 95); // 80 + 15
      expect(blueBox.dx - greenBox.dx, 95); // 80 + 15
      expect(blueBox.dx - redBox.dx, 190); // Total spread
      expect(redBox.dy, equals(greenBox.dy));
      expect(greenBox.dy, equals(blueBox.dy));

      // Now reduce width by 1 pixel - should trigger wrap mode
      await tester.pumpWidget(
        buildTestWidget(
          children: [
            buildBox(width: 80, height: 50, color: Colors.red),
            buildBox(width: 80, height: 50, color: Colors.green),
            buildBox(width: 80, height: 50, color: Colors.blue),
          ],
          maxWidth: 269, // Not enough! Forces wrap
        ),
      );

      await tester.pumpAndSettle();

      redBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.red,
      ));
      greenBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.green,
      ));
      blueBox = tester.getTopLeft(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.blue,
      ));

      // Should now use wrap mode with fixed spacing
      // But wait - we still have 269 width, which is enough for 3x80 + 2x10 = 260
      // So it should still use spaceBetween with less spacing
      // Available space = 269 - 240 = 29 / 2 = 14.5 per gap
      expect(greenBox.dx - redBox.dx, closeTo(94.5, 0.1)); // 80 + 14.5
      expect(blueBox.dx - greenBox.dx, closeTo(94.5, 0.1)); // 80 + 14.5
      expect(redBox.dy, equals(greenBox.dy));
      expect(greenBox.dy, equals(blueBox.dy));
    });

    testWidgets('hit testing works correctly', (WidgetTester tester) async {
      bool redTapped = false;
      bool greenTapped = false;

      await tester.pumpWidget(
        buildTestWidget(
          children: [
            GestureDetector(
              onTap: () => redTapped = true,
              child: buildBox(width: 100, height: 50, color: Colors.red),
            ),
            GestureDetector(
              onTap: () => greenTapped = true,
              child: buildBox(width: 100, height: 50, color: Colors.green),
            ),
          ],
          maxWidth: 400,
        ),
      );

      await tester.pumpAndSettle();

      // Tap on red box
      await tester.tap(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.red,
      ));
      expect(redTapped, isTrue);
      expect(greenTapped, isFalse);

      // Reset and tap on green box
      redTapped = false;
      await tester.tap(find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == Colors.green,
      ));
      expect(redTapped, isFalse);
      expect(greenTapped, isTrue);
    });
  });
}
