import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_borders.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const color = Color(0xFF3366FF);

  PulsingBorder pulsingBorder({double strokeWidth = 0.5}) => PulsingBorder(
    color: color,
    radius: 0,
    strokeWidth: strokeWidth,
    duration: const Duration(milliseconds: 400),
    loopCount: 1,
    startDelay: const Duration(milliseconds: 100),
  );

  Widget sized(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(width: 100, height: 100, child: child),
    ),
  );

  Finder ringPaint() => find.descendant(
    of: find.byType(PulsingBorder),
    matching: find.byType(CustomPaint),
  );

  double opacityOf(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(PulsingBorder),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  group('PulsingBorder', () {
    // A 0.5 logical stroke rounds to whole physical pixels: one pixel (a full
    // logical point) at 1x, but two pixels (2/3 of a point) at 3x. A point
    // 0.8 in from the edge therefore sits inside the ring only at 1x.
    const insideOnlyAt1x = Offset(0.8, 50);
    const insideAtBoth = Offset(0.3, 50);

    for (final (ratio, includes, excludes) in [
      (1.0, [insideAtBoth, insideOnlyAt1x], <Offset>[]),
      (3.0, [insideAtBoth], [insideOnlyAt1x]),
    ]) {
      testWidgets('snaps the ring to whole device pixels at ${ratio}x', (
        tester,
      ) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(devicePixelRatio: ratio),
            child: sized(pulsingBorder()),
          ),
        );

        expect(
          ringPaint(),
          paints..path(includes: includes, excludes: excludes),
        );
      });
    }

    testWidgets(
      'stays hidden through the start delay, pulses, then fades out',
      (
        tester,
      ) async {
        await tester.pumpWidget(sized(pulsingBorder()));
        expect(opacityOf(tester), 0);

        await tester.pump(const Duration(milliseconds: 99));
        expect(opacityOf(tester), 0);

        // Delay elapses, then halfway through the single loop is the peak.
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(opacityOf(tester), closeTo(1, 0.01));

        await tester.pump(const Duration(milliseconds: 250));
        expect(opacityOf(tester), 0);
      },
    );
  });

  group('TimerBorder', () {
    testWidgets('strokes a rounded rectangle inset by half its width', (
      tester,
    ) async {
      await tester.pumpWidget(
        sized(const TimerBorder(color: color, radius: 8, strokeWidth: 2)),
      );

      expect(
        find.descendant(
          of: find.byType(TimerBorder),
          matching: find.byType(CustomPaint),
        ),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 1, 98, 98),
            const Radius.circular(8),
          ),
          color: color,
          strokeWidth: 2,
          style: PaintingStyle.stroke,
        ),
      );
    });
  });
}
