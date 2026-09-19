import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/block_marker_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('paints the week label in mono, sized to the plate', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        const Center(
          child: SizedBox(
            width: 800,
            height: 260,
            child: BlockMarkerWidget(
              label: 'W3 · Jun 22',
              heightMeters: 6.5,
              pxPerMeter: 40,
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('W3 · Jun 22'));
    expect(text.style?.fontFamily, 'Inconsolata');
    expect(text.style?.fontSize, closeTo(6.5 * 40 * 0.4, 1e-9));
  });

  for (final heightMeters in [4.0, 9.0]) {
    testWidgets(
      'sizes the type and plate corners to a ${heightMeters}m plate',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget2(
            Center(
              child: SizedBox(
                width: 800,
                height: heightMeters * 40,
                child: BlockMarkerWidget(
                  label: 'W7 · Jul 20',
                  heightMeters: heightMeters,
                  pxPerMeter: 40,
                ),
              ),
            ),
          ),
        );
        final fontPx = heightMeters * 40 * 0.4;
        final text = tester.widget<Text>(find.text('W7 · Jul 20'));
        expect(text.style?.fontSize, closeTo(fontPx, 1e-9));
        final plate = tester.widget<Container>(find.byType(Container).first);
        expect(
          (plate.decoration! as BoxDecoration).borderRadius,
          BorderRadius.circular(fontPx * 0.25),
        );
      },
    );
  }
}
