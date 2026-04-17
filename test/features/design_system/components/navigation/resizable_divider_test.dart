import 'dart:ui';

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
    testWidgets('renders a 3px line with the default hit target width', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      // The visible line occupies a constant 3 px in the Row layout so
      // hover/drag only change its colour, never its width.
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 3);

      // A wider OverflowBox on top preserves the full hit target area.
      final overflowBox = tester.widget<OverflowBox>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(OverflowBox),
        ),
      );
      expect(overflowBox.maxWidth, 8);
    });

    testWidgets('custom hitTargetWidth drives the OverflowBox, not the line', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}, hitTargetWidth: 12),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 3);

      final overflowBox = tester.widget<OverflowBox>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(OverflowBox),
        ),
      );
      expect(overflowBox.maxWidth, 12);
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

  group('ResizableDivider hover interaction', () {
    testWidgets(
      'changes colour on hover without changing width (so adjacent panes '
      'never shift while the pointer crosses the divider)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onDrag: (_) {}),
        );

        final center = tester.getCenter(find.byType(ResizableDivider));

        // Simulate mouse hover enter
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        AnimatedContainer readContainer() => tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(ResizableDivider),
            matching: find.byType(AnimatedContainer),
          ),
        );

        Color? readColor() =>
            (readContainer().decoration as BoxDecoration?)?.color;

        final idleColor = readColor();

        await gesture.moveTo(center);
        await tester.pump();

        // The visible line widens to 3 on hover but the outer SizedBox
        // reserving space in the Row stays a constant 3 px either way, so
        // adjacent panes never shift.
        expect(readContainer().constraints!.maxWidth, 3);
        final hoverColor = readColor();
        expect(hoverColor, isNot(idleColor));

        // Simulate mouse hover exit
        await gesture.moveTo(Offset.zero);
        await tester.pump();

        expect(readContainer().constraints!.maxWidth, 1);
        expect(readColor(), idleColor);
      },
    );
  });

  group('ResizableDivider drag cancel', () {
    testWidgets('resets active state when drag is cancelled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      final center = tester.getCenter(find.byType(ResizableDivider));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();

      // Cancel the drag
      await gesture.cancel();
      await tester.pump();

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(ResizableDivider),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(animatedContainer.constraints, isNotNull);
      expect(animatedContainer.constraints!.maxWidth, 1);
    });
  });

  group('ResizableDivider visual line width', () {
    SizedBox readOuterSizedBox(WidgetTester tester) => tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(ResizableDivider),
        matching: find.byType(SizedBox),
      ),
    );

    AnimatedContainer readLine(WidgetTester tester) =>
        tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(ResizableDivider),
            matching: find.byType(AnimatedContainer),
          ),
        );

    testWidgets('line is a thin 1px hairline by default', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      expect(readOuterSizedBox(tester).width, 3);
      expect(readLine(tester).constraints!.maxWidth, 1);
    });

    testWidgets(
      'line widens to 3px during drag while the outer reserved width '
      'stays 3px (so adjacent panes do not shift)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onDrag: (_) {}),
        );

        final center = tester.getCenter(find.byType(ResizableDivider));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();

        expect(readOuterSizedBox(tester).width, 3);
        expect(readLine(tester).constraints!.maxWidth, 3);

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets('line shrinks back to a 1px hairline after drag ends', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(onDrag: (_) {}),
      );

      final center = tester.getCenter(find.byType(ResizableDivider));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();

      await gesture.up();
      await tester.pump();

      expect(readOuterSizedBox(tester).width, 3);
      expect(readLine(tester).constraints!.maxWidth, 1);
    });
  });
}
