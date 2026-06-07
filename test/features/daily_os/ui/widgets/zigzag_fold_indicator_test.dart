import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/ui/widgets/zigzag_fold_indicator.dart';

import '../../../../widget_test_utils.dart';

void main() {
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

  group('ZigzagFoldPainter — canvas output', () {
    testWidgets('paints a single zigzag path spanning the full height', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 12,
            height: 40,
            child: ZigzagFoldIndicator(color: Colors.teal),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(ZigzagFoldIndicator),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = customPaint.painter! as ZigzagFoldPainter;

      final canvas = _RecordingCanvas();
      painter.paint(canvas, const Size(12, 40));

      expect(canvas.paths, hasLength(1));
      final bounds = canvas.paths.single.getBounds();
      // The zigzag alternates between x=0 and x=zigzagWidth and runs the
      // full height of the indicator.
      expect(bounds.height, 40);
      expect(bounds.width, painter.zigzagWidth);
      expect(canvas.paints.single.color.toARGB32(), Colors.teal.toARGB32());
      expect(canvas.paints.single.strokeWidth, painter.strokeWidth);
    });
  });
}

/// Captures drawPath invocations so the painter geometry can be asserted.
class _RecordingCanvas implements Canvas {
  final List<Path> paths = [];
  final List<Paint> paints = [];

  @override
  void drawPath(Path path, Paint paint) {
    paths.add(path);
    paints.add(paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
