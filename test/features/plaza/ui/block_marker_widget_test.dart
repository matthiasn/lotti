import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/block_marker_widget.dart';

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
}
