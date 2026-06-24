import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/affine2d.dart';

void main() {
  group('Affine2D', () {
    test('identity maps points unchanged', () {
      final p = Affine2D.identity.transformPoint(3, -7);
      expect(p.x, 3);
      expect(p.y, -7);
    });

    test('translation moves the origin', () {
      final t = Affine2D.translation(10, -5);
      final p = t.transformPoint(0, 0);
      expect(p.x, 10);
      expect(p.y, -5);
      expect(t.origin.x, 10);
      expect(t.origin.y, -5);
    });

    test('rotation by 90 degrees sends +x to +y', () {
      final r = Affine2D.rotation(math.pi / 2);
      final p = r.transformPoint(1, 0);
      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(1, 1e-9));
    });

    test('scale stretches each axis independently', () {
      final s = Affine2D.scale(2, 3);
      final p = s.transformPoint(4, 5);
      expect(p.x, 8);
      expect(p.y, 15);
    });

    test('multiply applies the right-hand transform first', () {
      // Translate-then-rotate vs rotate-then-translate differ; verify order.
      final translateThenRotate = Affine2D.rotation(
        math.pi / 2,
      ).multiply(Affine2D.translation(10, 0));
      final p = translateThenRotate.transformPoint(0, 0);
      // Point (10,0) rotated 90° -> (0,10).
      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(10, 1e-9));
    });

    test('trs rotates and scales about the pivot', () {
      final trs = Affine2D.trs(
        pivotX: 5,
        pivotY: 0,
        rotation: math.pi / 2,
        scaleX: 2,
        scaleY: 2,
      );
      // Local origin lands on the pivot.
      final origin = trs.transformPoint(0, 0);
      expect(origin.x, closeTo(5, 1e-9));
      expect(origin.y, closeTo(0, 1e-9));
      // Local (1,0) scaled by 2 then rotated 90° -> (0,2), offset by pivot.
      final tip = trs.transformPoint(1, 0);
      expect(tip.x, closeTo(5, 1e-9));
      expect(tip.y, closeTo(2, 1e-9));
    });

    test('toMatrix4Storage emits a column-major 4x4 and reuses the buffer', () {
      const a = Affine2D(1, 2, 3, 4, 5, 6);
      final m = a.toMatrix4Storage();
      expect(m.length, 16);
      expect([m[0], m[1], m[4], m[5], m[12], m[13]], [1, 2, 3, 4, 5, 6]);
      expect(m[10], 1);
      expect(m[15], 1);
      final reused = a.toMatrix4Storage(m);
      expect(identical(reused, m), isTrue);
    });

    test('equality and hashCode are value-based', () {
      const a = Affine2D(1, 0, 0, 1, 2, 3);
      const b = Affine2D(1, 0, 0, 1, 2, 3);
      const c = Affine2D(1, 0, 0, 1, 2, 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
