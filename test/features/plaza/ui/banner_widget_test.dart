import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/banner_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('runs the label vertically in mono capitals with a neon edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        const Center(
          child: SizedBox(
            width: 72,
            height: 560,
            child: BannerWidget(
              label: 'supplies',
              color: Color(0xFFFF4FD8),
              widthMeters: 1.8,
              heightMeters: 14,
              pxPerMeter: 40,
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('SUPPLIES'));
    expect(text.style?.fontFamily, 'Inconsolata');
    expect(text.style?.color, const Color(0xFFFF4FD8));
    expect(
      tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
      1,
    );
    final box = tester.widget<Container>(find.byType(Container).first);
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.left.color, const Color(0xFFFF4FD8));
    expect(tester.takeException(), isNull);
  });

  for (final (widthMeters, pxPerMeter) in [(1.8, 40.0), (3.0, 25.0)]) {
    testWidgets(
      'scales type and edges with a ${widthMeters}m strip at '
      '$pxPerMeter px/m',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget2(
            Center(
              child: SizedBox(
                width: widthMeters * pxPerMeter,
                height: 560,
                child: BannerWidget(
                  label: 'rookery',
                  color: const Color(0xFF4FD8FF),
                  widthMeters: widthMeters,
                  heightMeters: 14,
                  pxPerMeter: pxPerMeter,
                ),
              ),
            ),
          ),
        );
        final stripPx = widthMeters * pxPerMeter;
        final text = tester.widget<Text>(find.text('ROOKERY'));
        expect(text.style?.fontSize, closeTo(stripPx * 0.5, 1e-9));
        expect(text.style?.letterSpacing, closeTo(stripPx * 0.5 * 0.35, 1e-9));
        final box = tester.widget<Container>(find.byType(Container).first);
        final border = (box.decoration! as BoxDecoration).border! as Border;
        expect(border.left.width, closeTo(stripPx * 0.08, 1e-9));
        expect(border.right.width, closeTo(stripPx * 0.04, 1e-9));
        expect(border.right.color.a, closeTo(0.35, 1e-2));
      },
    );
  }
}
