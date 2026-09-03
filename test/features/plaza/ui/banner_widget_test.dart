import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/banner_widget.dart';

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
}
