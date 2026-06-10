import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';

void main() {
  group('SizedWoltSideSheetType', () {
    const type = SizedWoltSideSheetType();

    test('targets 45% of the window width within the clamp band', () {
      final constraints = type.layoutModal(const Size(1440, 900));
      expect(constraints.minWidth, 648); // 0.45 * 1440
      expect(constraints.maxWidth, 648);
      expect(constraints.minHeight, 900);
      expect(constraints.maxHeight, 900);
    });

    test('clamps to the minimum width on narrow desktop windows', () {
      final constraints = type.layoutModal(const Size(900, 700));
      // 0.45 * 900 = 405 → clamped up to 480.
      expect(constraints.maxWidth, 480);
      expect(constraints.maxHeight, 700);
    });

    test('clamps to the maximum width on very wide screens', () {
      final constraints = type.layoutModal(const Size(2560, 1400));
      // 0.45 * 2560 = 1152 → clamped down to 720.
      expect(constraints.maxWidth, 720);
    });

    test('never exceeds the window itself on tiny windows', () {
      final constraints = type.layoutModal(const Size(400, 600));
      expect(constraints.maxWidth, 400);
    });

    test('anchors to the trailing edge in LTR', () {
      final offset = type.positionModal(
        const Size(1440, 900),
        const Size(648, 900),
        TextDirection.ltr,
      );
      expect(offset.dx, 1440 - 648);
      expect(offset.dy, 0);
    });

    test('spans full height (forceMaxHeight inherited)', () {
      expect(type.forceMaxHeight, isTrue);
    });
  });
}
