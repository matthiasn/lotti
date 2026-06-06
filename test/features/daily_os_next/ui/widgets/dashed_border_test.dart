import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/dashed_border.dart';

void main() {
  group('DottedBorder', () {
    testWidgets('paints around its child and repaints on color change', (
      tester,
    ) async {
      Future<void> pump(Color color) {
        return tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: DottedBorder(
                color: color,
                radius: 12,
                child: const SizedBox(width: 120, height: 48),
              ),
            ),
          ),
        );
      }

      await pump(Colors.teal);
      // The border decorates the child without altering its layout.
      final size = tester.getSize(find.byType(DottedBorder));
      expect(size, const Size(120, 48));

      final painterBefore = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(DottedBorder),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter;

      await pump(Colors.red);
      final painterAfter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(DottedBorder),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter;

      expect(painterBefore, isNotNull);
      expect(painterAfter, isNotNull);
      expect(
        painterAfter!.shouldRepaint(painterBefore!),
        isTrue,
        reason: 'a color change must trigger a repaint',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
