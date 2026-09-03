import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/domain/walk_collider.dart';

PlotPlacement _box({
  double x = 0,
  double z = 0,
  double facing = 0,
  double width = 10,
  double depth = 6,
}) => PlotPlacement(
  taskId: 'b',
  bucketIndex: 0,
  side: PlotSide.left,
  x: x,
  z: z,
  facingRadians: facing,
  width: width,
  depth: depth,
  height: 5,
);

void main() {
  test('a point outside every footprint is untouched', () {
    final c = WalkCollider([_box()]);
    expect(c.resolve(20, 20), (20, 20));
    expect(c.resolve(0, 3.7), (0, 3.7)); // just outside depth/2 + margin
  });

  test(
    'a point inside is pushed out through the nearest face, with margin',
    () {
      final c = WalkCollider([_box()]);
      // Near the front face (z = +3): pushed to z = 3.6.
      final (x1, z1) = c.resolve(0, 2.5);
      expect(x1, 0);
      expect(z1, closeTo(3.6, 1e-9));
      // Near the right end (x = +5): pushed to x = 5.6.
      final (x2, z2) = c.resolve(4.8, 0);
      expect(x2, closeTo(5.6, 1e-9));
      expect(z2, 0);
      // Deep inside, closer to the back: pushed to the back face.
      final (_, z3) = c.resolve(0, -2.9);
      expect(z3, closeTo(-3.6, 1e-9));
    },
  );

  test('respects the building rotation', () {
    // Facing +X: the footprint's depth axis is world X.
    final c = WalkCollider([_box(facing: math.pi / 2)]);
    final (x, z) = c.resolve(2.5, 0);
    expect(x, closeTo(3.6, 1e-9));
    expect(z, closeTo(0, 1e-9));
    // Near the end wall along the building's width (world Z): pushed out
    // through that end, not sideways.
    final (x2, z2) = c.resolve(0, 4.9);
    expect(x2, closeTo(0, 1e-9));
    expect(z2, closeTo(5.6, 1e-9));
  });

  test('walks along a wall rather than sticking to it', () {
    final c = WalkCollider([_box()]);
    // Sliding along the front face keeps the lateral motion.
    final (xa, za) = c.resolve(-2, 3);
    final (xb, zb) = c.resolve(-1, 3);
    expect(za, zb);
    expect(xb - xa, 1);
  });
}
