import 'dart:math' as math;
import 'dart:ui';

/// Small 2D math kit for the companion rig: easing, a damped spring, a
/// two-bone IK and smooth noise.
///
/// Character space is y-down with the origin on the floor between the feet,
/// the same space the pitch videos' Python rig draws in, so the numbers port
/// one to one.

double clampUnit(double x, [double lo = 0, double hi = 1]) =>
    x < lo ? lo : (x > hi ? hi : x);

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Hermite ease from 0 to 1, flat at both ends.
double smoothstep(double t) {
  final c = clampUnit(t);
  return c * c * (3 - 2 * c);
}

/// Rotates [p] about the origin by [angle] radians.
Offset rotate(Offset p, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
}

/// Cheap smooth pseudo-noise in about [-1, 1]: a sum of incommensurate sines.
double noise1(double t, double seed) =>
    math.sin(t * 1.13 + seed * 7.1) * 0.5 +
    math.sin(t * 2.31 + seed * 3.7) * 0.3 +
    math.sin(t * 0.47 + seed * 1.9) * 0.2;

/// Elbow and (reach-clamped) wrist of a two-bone limb from [root] towards
/// [target]; [bend] +1 or -1 picks the side the elbow folds to.
({Offset elbow, Offset wrist}) twoBoneIk(
  Offset root,
  Offset target,
  double l1,
  double l2,
  double bend,
) {
  final d = target - root;
  final dist = clampUnit(d.distance, (l1 - l2).abs() + 1e-3, l1 + l2 - 1e-3);
  final base = math.atan2(d.dy, d.dx);
  final cosA = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist);
  final a = math.acos(clampUnit(cosA, -1));
  return (
    elbow:
        root +
        Offset(l1 * math.cos(base + bend * a), l1 * math.sin(base + bend * a)),
    wrist: root + Offset(dist * math.cos(base), dist * math.sin(base)),
  );
}

/// A damped spring (semi-implicit Euler, fixed substeps). Overshoot and
/// settle come from [zeta] below 1, speed from [freq] in Hz.
class Spring {
  Spring(this.x, {this.freq = 2.5, this.zeta = 0.75});

  double x;
  double v = 0;
  final double freq;
  final double zeta;

  double step(double target, double dt, {int subSteps = 4}) {
    final w = 2 * math.pi * freq;
    final h = dt / subSteps;
    for (var i = 0; i < subSteps; i++) {
      final a = w * w * (target - x) - 2 * zeta * w * v;
      v += a * h;
      x += v * h;
    }
    return x;
  }
}

/// Rotation about the origin, then translation: a bone's frame.
class Affine {
  const Affine(this.origin, this.angle);

  final Offset origin;
  final double angle;

  Offset call(double x, double y) => rotate(Offset(x, y), angle) + origin;

  Offset of(Offset p) => rotate(p, angle) + origin;
}
