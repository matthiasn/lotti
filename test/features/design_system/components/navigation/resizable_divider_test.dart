import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';

import '../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildTestWidget({
    required ValueChanged<double> onDrag,
    double hitTargetWidth = 8,
  }) {
    return makeTestableWidgetNoScroll(
      Row(
        children: [
          const Expanded(child: SizedBox()),
          ResizableDivider(
            onDrag: onDrag,
            hitTargetWidth: hitTargetWidth,
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
      mediaQueryData: const MediaQueryData(size: Size(800, 600)),
    );
  }

  group('ResizableDivider rendering', () {
    testWidgets('renders with correct hit target width', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 8);
    });

    testWidgets('renders with custom hit target width', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}, hitTargetWidth: 12),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 12);
    });

    testWidgets('shows resize column cursor via MouseRegion', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(mouseRegion.cursor, SystemMouseCursors.resizeColumn);
    });

    testWidgets('contains an AnimatedContainer for the visual line', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      expect(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget,
      );
    });
  });

  group('ResizableDivider drag interaction', () {
    testWidgets('calls onDrag with positive delta when dragged right', (
      tester,
    ) async {
      final deltas = <double>[];
      await tester.pumpWidget(
        buildTestWidget(onDrag: deltas.add),
      );

      final center = tester.getCenter(find.byType(ResizableDivider));
      await tester.timedDragFrom(
        center,
        const Offset(50, 0),
        const Duration(milliseconds: 200),
      );

      expect(deltas, isNotEmpty);
      final totalDelta = deltas.fold<double>(0, (sum, d) => sum + d);
      expect(totalDelta, greaterThan(0));
    });

    testWidgets('calls onDrag with negative delta when dragged left', (
      tester,
    ) async {
      final deltas = <double>[];
      await tester.pumpWidget(
        buildTestWidget(onDrag: deltas.add),
      );

      final center = tester.getCenter(find.byType(ResizableDivider));
      await tester.timedDragFrom(
        center,
        const Offset(-50, 0),
        const Duration(milliseconds: 200),
      );

      expect(deltas, isNotEmpty);
      final totalDelta = deltas.fold<double>(0, (sum, d) => sum + d);
      expect(totalDelta, lessThan(0));
    });

    testWidgets('reports zero horizontal delta for vertical-only drags', (
      tester,
    ) async {
      final deltas = <double>[];
      await tester.pumpWidget(
        buildTestWidget(onDrag: deltas.add),
      );

      final center = tester.getCenter(find.byType(ResizableDivider));
      await tester.timedDragFrom(
        center,
        const Offset(0, 50),
        const Duration(milliseconds: 200),
      );

      // Vertical drags produce zero horizontal deltas
      final totalDelta = deltas.fold<double>(0, (sum, d) => sum + d);
      expect(totalDelta, 0);
    });
  });

  group('ResizableDivider visual line width', () {
    testWidgets('line is thin (1px) by default', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(AnimatedContainer),
        ),
      );
      // Default state: not hovering, not dragging → width should be 1
      expect(animatedContainer.constraints, isNotNull);
      expect(animatedContainer.constraints!.maxWidth, 1);
    });

    testWidgets('line thickens during drag', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      // Start a drag but hold it
      final center = tester.getCenter(find.byType(ResizableDivider));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(AnimatedContainer),
        ),
      );
      // During drag: width should be 3
      expect(animatedContainer.constraints, isNotNull);
      expect(animatedContainer.constraints!.maxWidth, 3);

      await gesture.up();
      await tester.pump();
    });
  });
}
