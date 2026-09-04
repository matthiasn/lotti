import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/domain/walk_collider.dart';

Footprint _box({
  double x = 0,
  double z = 0,
  double facing = 0,
  double width = 10,
  double depth = 6,
}) => Footprint(
  x: x,
  z: z,
  facingRadians: facing,
  width: width,
  depth: depth,
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

  test('neighbours closer than the clearance merge into one footprint', () {
    // A 0.4 m alley between two 10 m buildings, narrower than twice the
    // 0.6 m margin: resolved one after the other, each would push the
    // walker into the other's clearance.
    final c = WalkCollider([_box(), _box(x: 10.4)]);
    expect(c.footprints, hasLength(1));
    final merged = c.footprints.single;
    expect(merged.x, closeTo(5.2, 1e-9));
    expect(merged.width, closeTo(20.4, 1e-9));
    // A point in the alley leaves through the road face, outside both.
    final (x, z) = c.resolve(5.2, 2.5);
    expect(z, closeTo(3.6, 1e-9));
    expect(x, closeTo(5.2, 1e-9));
    expect(c.resolve(x, z), (x, z));
  });

  test('a neighbour a clearance away, or across the road, stays separate', () {
    expect(WalkCollider([_box(), _box(x: 11.3)]).footprints, hasLength(2));
    expect(
      WalkCollider([_box(), _box(z: 20, facing: math.pi)]).footprints,
      hasLength(2),
    );
  });

  test('a crowded week never traps the walker in a wall', () {
    // Fourteen tasks in one week: seven a side on 5 m plots with 0.3 m
    // alleys, the densest row the layout produces.
    final tasks = [
      for (var i = 0; i < 14; i++)
        PlazaTask(
          id: 'crowd-$i',
          createdAt: DateTime.utc(2026, 6, 1, 8 + i),
          title: 'Task $i',
          state: PlazaTaskState.open,
          progress: 0,
          checklistItems: 0,
          linkedTaskIds: const [],
          categoryColor: 0,
        ),
    ];
    final plan = StreetLayout(projectSeed: 7).plan(tasks);
    final placements = plan.placements.values.toList();
    final c = WalkCollider(placements.map((p) => p.footprint));
    expect(c.footprints.length, lessThan(placements.length));

    bool insideAny(double x, double z) => placements.any((p) {
      final sinF = math.sin(p.facingRadians);
      final cosF = math.cos(p.facingRadians);
      final dx = x - p.x;
      final dz = z - p.z;
      final v = dx * sinF + dz * cosF;
      final u = dx * cosF - dz * sinF;
      return u.abs() < p.width / 2 - 1e-9 && v.abs() < p.depth / 2 - 1e-9;
    });

    final rng = math.Random(11);
    for (var i = 0; i < 400; i++) {
      final x = -30 + rng.nextDouble() * 60;
      final z = -10 + rng.nextDouble() * 60;
      final (rx, rz) = c.resolve(x, z);
      expect(insideAny(rx, rz), isFalse, reason: 'resolve($x, $z) → wall');
      final (sx, sz) = c.resolve(rx, rz);
      expect(sx, closeTo(rx, 1e-9), reason: 'resolve not settled at ($x, $z)');
      expect(sz, closeTo(rz, 1e-9), reason: 'resolve not settled at ($x, $z)');
    }
  });
}
