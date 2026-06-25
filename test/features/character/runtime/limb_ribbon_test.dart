import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/runtime/limb_ribbon.dart';

void main() {
  group('limbRibbonPath', () {
    test('a straight tapered chain fills its centreline and tapers', () {
      // Vertical spine, wide at the top (half-width 12) tapering to 6.
      final path = limbRibbonPath(
        const [Offset(0, 0), Offset(0, 60), Offset(0, 120)],
        const [12, 9, 6],
      );

      final b = path.getBounds();
      // Widest at the top cap: spans roughly ±12 in x, and the round caps add the
      // half-width beyond each end in y.
      expect(b.left, closeTo(-12, 1.5));
      expect(b.right, closeTo(12, 1.5));
      expect(b.top, closeTo(-12, 1.5));
      expect(b.bottom, closeTo(126, 1.5));

      // The centreline is inside the filled ribbon.
      expect(path.contains(const Offset(0, 60)), isTrue);
      expect(path.contains(const Offset(0, 5)), isTrue);

      // Taper: x=10 is inside near the WIDE top (half-width ~12) but outside near
      // the NARROW bottom (half-width ~6).
      expect(path.contains(const Offset(10, 6)), isTrue);
      expect(path.contains(const Offset(10, 116)), isFalse);

      // Well outside the limb entirely.
      expect(path.contains(const Offset(60, 60)), isFalse);
    });

    test('a bent chain produces a continuous shape spanning the bend', () {
      // Knee kicks out to +x: hip (0,0) -> knee (30,55) -> ankle (0,110).
      final path = limbRibbonPath(
        const [Offset(0, 0), Offset(30, 55), Offset(0, 110)],
        const [12, 10, 7],
      );
      final b = path.getBounds();
      // The ribbon must reach out past the knee (x well beyond 30 - its width).
      expect(b.right, greaterThan(34));
      // And it stays a single closed region: a point just inside the knee bend is
      // filled, a point far outside is not.
      expect(path.contains(const Offset(28, 55)), isTrue);
      expect(path.contains(const Offset(80, 55)), isFalse);
    });

    test('degenerate input is handled (no crash, empty path)', () {
      expect(limbRibbonPath(const [Offset(0, 0)], const [10]).getBounds(),
          Rect.zero);
    });
  });
}
