import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/companion/rig/rig_math.dart';

void main() {
  group('clampUnit / smoothstep', () {
    test('clamps to the unit range by default and to given bounds', () {
      expect(clampUnit(-0.5), 0);
      expect(clampUnit(1.5), 1);
      expect(clampUnit(0.25), 0.25);
      expect(clampUnit(-3, -1), -1);
      expect(clampUnit(9, -5, 5), 5);
    });

    test('smoothstep is flat at both ends and half way in the middle', () {
      expect(smoothstep(-1), 0);
      expect(smoothstep(0), 0);
      expect(smoothstep(0.5), 0.5);
      expect(smoothstep(1), 1);
      expect(smoothstep(2), 1);
    });

    glados.Glados2(
      glados.any.intInRange(0, 1000),
      glados.any.intInRange(0, 1000),
      glados.ExploreConfig(numRuns: 150),
    ).test('smoothstep never decreases', (a, b) {
      final lo = math.min(a, b) / 1000;
      final hi = math.max(a, b) / 1000;
      expect(smoothstep(lo), lessThanOrEqualTo(smoothstep(hi)));
    }, tags: 'glados');
  });

  test('rotate turns a quarter turn y-down', () {
    final p = rotate(const Offset(1, 0), math.pi / 2);
    expect(p.dx, closeTo(0, 1e-9));
    expect(p.dy, closeTo(1, 1e-9));
  });

  test('noise1 stays within [-1, 1] and is deterministic', () {
    for (var t = 0.0; t < 50; t += 0.37) {
      expect(noise1(t, 3).abs(), lessThanOrEqualTo(1));
      expect(noise1(t, 3), noise1(t, 3));
    }
    expect(noise1(1, 1), isNot(noise1(1, 2)));
  });

  group('twoBoneIk', () {
    glados.Glados2(
      glados.any.intInRange(-150, 150),
      glados.any.intInRange(-150, 150),
      glados.ExploreConfig(numRuns: 200),
    ).test('keeps both bones at their length, wrist toward the target', (
      x,
      y,
    ) {
      final target = Offset(x.toDouble(), y.toDouble());
      final r = twoBoneIk(Offset.zero, target, 50, 47, 1);
      expect(r.elbow.distance, closeTo(50, 1e-6));
      expect((r.wrist - r.elbow).distance, closeTo(47, 1e-6));
      if (target.distance > 4 && target.distance < 96) {
        expect((r.wrist - target).distance, closeTo(0, 1e-6));
      }
    }, tags: 'glados');

    test('the bend picks the side the elbow folds to', () {
      const target = Offset(60, 0);
      final up = twoBoneIk(Offset.zero, target, 50, 47, -1).elbow;
      final down = twoBoneIk(Offset.zero, target, 50, 47, 1).elbow;
      expect(up.dy, lessThan(0));
      expect(down.dy, greaterThan(0));
    });
  });

  group('Spring', () {
    test('settles on its target', () {
      final s = Spring(0, freq: 3, zeta: 0.8);
      for (var i = 0; i < 240; i++) {
        s.step(10, 1 / 60);
      }
      expect(s.x, closeTo(10, 0.01));
      expect(s.v.abs(), lessThan(0.05));
    });

    test('an underdamped spring overshoots, a critically damped one not', () {
      double peak(double zeta) {
        final s = Spring(0, freq: 2, zeta: zeta);
        var top = 0.0;
        for (var i = 0; i < 240; i++) {
          top = math.max(top, s.step(1, 1 / 60));
        }
        return top;
      }

      expect(peak(0.4), greaterThan(1.05));
      expect(peak(1), lessThanOrEqualTo(1.0001));
    });
  });

  test('Affine rotates about its origin, then translates', () {
    const a = Affine(Offset(10, 20), math.pi);
    final p = a(1, 0);
    expect(p.dx, closeTo(9, 1e-9));
    expect(p.dy, closeTo(20, 1e-9));
    expect(a.of(const Offset(1, 0)), a(1, 0));
  });
}
