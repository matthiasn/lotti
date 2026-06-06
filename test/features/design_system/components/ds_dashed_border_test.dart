import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';

void main() {
  group('DsDashedBorder', () {
    testWidgets('paints around its child without altering its layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: DsDashedBorder(
              color: Colors.teal,
              radius: 12,
              child: SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(DsDashedBorder)), const Size(120, 48));
      expect(tester.takeException(), isNull);
    });

    test('shouldRepaint reacts to every visual parameter', () {
      DashedBorderPainter painter({
        Color color = Colors.teal,
        double radius = 12,
        double strokeWidth = 1,
        double dashLength = 4,
        double dashGap = 3,
      }) => DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        dashGap: dashGap,
      );

      final base = painter();
      expect(painter().shouldRepaint(base), isFalse);
      expect(painter(color: Colors.red).shouldRepaint(base), isTrue);
      expect(painter(radius: 8).shouldRepaint(base), isTrue);
      expect(painter(strokeWidth: 2).shouldRepaint(base), isTrue);
      expect(painter(dashLength: 6).shouldRepaint(base), isTrue);
      expect(painter(dashGap: 5).shouldRepaint(base), isTrue);
    });
  });
}
