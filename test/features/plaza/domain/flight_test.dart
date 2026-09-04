import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/plaza/domain/flight.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// Whether [f] enters any of [solids] anywhere on its way, sampled finely.
bool passesThrough(Flight f, List<Solid> solids) {
  for (var t = 0.0; t <= 1.0001; t += 0.001) {
    final p = f.poseAt(t);
    if (solids.any((s) => s.contains(p.x, p.y, p.z))) return true;
  }
  return false;
}

Solid box({
  required double x,
  required double z,
  double width = 10,
  double depth = 10,
  double top = 30,
  double bottom = 0,
  double facing = 0,
}) => Solid(
  footprint: Footprint(
    x: x,
    z: z,
    facingRadians: facing,
    width: width,
    depth: depth,
  ),
  bottom: bottom,
  top: top,
);

void main() {
  const a = CameraPose(x: 0, y: 2.2, z: 0, yaw: 0);

  test('duration follows the square root of distance within 0.8–2.5 s', () {
    expect(
      Flight.plan(a, const CameraPose(x: 1, y: 2.2, z: 0, yaw: 0)).duration,
      const Duration(milliseconds: 800),
    );
    expect(
      Flight.plan(a, const CameraPose(x: 0, y: 2.2, z: 36, yaw: 0)).duration,
      const Duration(milliseconds: 1920),
    );
    expect(
      Flight.plan(a, const CameraPose(x: 0, y: 2.2, z: 1000, yaw: 0)).duration,
      const Duration(milliseconds: 2500),
    );
    expect(
      Flight.plan(
        a,
        const CameraPose(x: 0, y: 2.2, z: 36, yaw: 0),
        timeScale: 2,
      ).duration,
      const Duration(milliseconds: 960),
    );
  });

  test('short flights stay level; long ones arc up and land level', () {
    final short = Flight.plan(
      a,
      const CameraPose(x: 0, y: 2.2, z: 50, yaw: 0),
    );
    expect(short.arc, 0);
    expect(short.poseAt(0.5).y, 2.2);

    final long = Flight.plan(a, const CameraPose(x: 0, y: 2.2, z: 200, yaw: 0));
    expect(long.arc, closeTo(44, 1e-9));
    expect(long.poseAt(0.5).y, closeTo(2.2 + 44, 1e-9));
    // A climb over the first 35 % of the way, a cruise, a descent over the
    // last 35 %.
    expect(long.rampStart, Flight.defaultRamp);
    expect(long.rampEnd, Flight.defaultRamp);
    expect(long.liftAt(0.175), closeTo(22, 1e-9));
    expect(long.liftAt(0.35), closeTo(44, 1e-9));
    expect(long.liftAt(0.65), closeTo(44, 1e-9));
    expect(long.liftAt(0.825), closeTo(22, 1e-9));
    // Over the arc the camera looks down at what it crosses, then levels.
    expect(long.poseAt(0.5).pitch, lessThan(-0.5));
    expect(long.poseAt(1).pitch, closeTo(0, 1e-9));
    expect(long.poseAt(0).y, 2.2);
    expect(long.poseAt(1).y, closeTo(2.2, 1e-9));

    final veryLong = Flight.plan(
      a,
      const CameraPose(x: 0, y: 2.2, z: 2000, yaw: 0),
    );
    expect(veryLong.arc, 45);
  });

  test('eases in and out, ending exactly on the target', () {
    const to = CameraPose(x: 10, y: 2.2, z: 0, yaw: 0, pitch: 0.3);
    final f = Flight.plan(a, to);
    expect(f.poseAt(0).x, 0);
    expect(f.poseAt(0.25).x, lessThan(2.5)); // slow start
    expect(f.poseAt(0.5).x, closeTo(5, 1e-9));
    expect(f.poseAt(0.75).x, greaterThan(7.5)); // slow end
    expect(f.poseAt(1).x, 10);
    expect(f.poseAt(1).pitch, 0.3);
  });

  test('yaw takes the short way round', () {
    final f = Flight.plan(
      const CameraPose(x: 0, y: 0, z: 0, yaw: 0.2),
      const CameraPose(x: 0, y: 0, z: 0, yaw: 2 * math.pi - 0.2),
    );
    final mid = f.poseAt(0.5).yaw;
    // Half-way between 0.2 and -0.2 (not through π).
    expect(mid, closeTo(0, 1e-9));
    // Lands on the target heading (modulo a full turn).
    expect((f.poseAt(1).yaw + 0.2).abs() % (2 * math.pi), closeTo(0, 1e-9));
  });

  test('yaw takes the short way round the other way too', () {
    final f = Flight.plan(
      const CameraPose(x: 0, y: 0, z: 0, yaw: 2 * math.pi - 0.2),
      const CameraPose(x: 0, y: 0, z: 0, yaw: 0.2),
    );
    // Half-way between -0.2 and 0.2: a full turn, not back through π.
    expect(f.poseAt(0.5).yaw % (2 * math.pi), closeTo(0, 1e-9));
  });

  test('advance accumulates time and clamps at the end', () {
    final f = Flight.plan(a, const CameraPose(x: 1, y: 2.2, z: 0, yaw: 0));
    expect(f.done, isFalse);
    f.advance(const Duration(milliseconds: 400));
    expect(f.elapsed, const Duration(milliseconds: 400));
    expect(f.progress, closeTo(0.5, 1e-9));
    expect(f.done, isFalse);
    final end = f.advance(const Duration(seconds: 5));
    expect(f.done, isTrue);
    expect(f.progress, 1);
    expect(end.x, 1);
  });

  group('look along the path', () {
    test('turns into the travel direction mid-flight, settles at the end', () {
      // Fly 50 m along +X while facing +Z before and after.
      const from = CameraPose(x: 0, y: 2.2, z: 0, yaw: 0);
      const to = CameraPose(x: 50, y: 2.2, z: 0, yaw: 0);
      final f = Flight.plan(from, to);
      expect(f.travelYaw, closeTo(math.pi / 2, 1e-9));
      expect(f.poseAt(0).yaw, 0);
      expect(f.poseAt(0.15).yaw, inExclusiveRange(0, math.pi / 2));
      expect(f.poseAt(0.5).yaw, closeTo(math.pi / 2, 1e-9));
      expect(f.poseAt(0.9).yaw, inExclusiveRange(0, math.pi / 2));
      expect(f.poseAt(1).yaw, closeTo(0, 1e-9));
    });

    test('a short hop blends yaw directly', () {
      const from = CameraPose(x: 0, y: 2.2, z: 0, yaw: 0);
      const to = CameraPose(x: 3, y: 2.2, z: 0, yaw: 1);
      final f = Flight.plan(from, to);
      expect(f.travelYaw, isNull);
      expect(f.poseAt(0.5).yaw, closeTo(0.5, 1e-9));
    });

    test('flying backwards turns round rather than reversing', () {
      // Facing +Z, flying toward -Z: the middle of the flight faces -Z.
      const from = CameraPose(x: 0, y: 2.2, z: 100, yaw: 0);
      const to = CameraPose(x: 0, y: 2.2, z: 0, yaw: 0);
      final f = Flight.plan(from, to);
      expect(f.poseAt(0.5).yaw.abs(), closeTo(math.pi, 1e-9));
    });
  });

  group('vertical trips', () {
    test('a climb keeps its heading and gets no extra arc', () {
      // Home to overview: mostly up, a little back.
      const from = CameraPose(x: 0, y: 2.2, z: 0, yaw: 3.1);
      const to = CameraPose(x: 0, y: 140, z: -60, yaw: 3.1, pitch: -0.9);
      final f = Flight.plan(from, to);
      expect(f.travelYaw, isNull);
      expect(f.horizontalFraction, lessThan(0.55));
      expect(f.poseAt(0.5).yaw, closeTo(3.1, 1e-9));
      // Height is monotonic: no overshoot above the destination.
      var last = from.y;
      for (var t = 0.0; t <= 1.0001; t += 0.05) {
        final y = f.poseAt(t).y;
        expect(y, greaterThanOrEqualTo(last - 1e-9));
        expect(y, lessThanOrEqualTo(to.y + 1e-9));
        last = y;
      }
    });

    test(
      'a long, mostly horizontal trip still arcs, scaled by its ground share',
      () {
        const from = CameraPose(x: 0, y: 2.2, z: 0, yaw: 0);
        const to = CameraPose(x: 0, y: 60, z: 200, yaw: 0);
        final f = Flight.plan(from, to);
        final dist = from.distanceTo(to);
        expect(f.arc, closeTo(math.min(45, dist * 0.22) * (200 / dist), 1e-9));
        expect(f.travelYaw, isNotNull);
      },
    );
  });

  group('over solids', () {
    // Fifty metres along +Z at eye height.
    const to = CameraPose(x: 0, y: 2.2, z: 50, yaw: 0);

    test('a hop through a building lifts over it: up before, held past', () {
      final building = box(x: 0, z: 25);
      // The bug: planned blind, the line runs through the building.
      expect(passesThrough(Flight.plan(a, to), [building]), isTrue);
      final f = Flight.plan(a, to, solids: [building]);
      expect(passesThrough(f, [building]), isFalse);
      expect(f.arc, closeTo(30 + Flight.clearance - 2.2, 1e-9));
      // The building spans 0.4 to 0.6 of the way: the climb is done at
      // 0.85 of the way to it, the descent starts 0.85 of the way after.
      expect(f.rampStart, closeTo(0.85 * 0.4, 1e-9));
      expect(f.rampEnd, closeTo(0.85 * 0.4, 1e-9));
      expect(f.liftAt(0), 0);
      expect(f.liftAt(f.rampStart), closeTo(f.arc, 1e-9));
      expect(f.liftAt(0.4), closeTo(f.arc, 1e-9));
      expect(f.liftAt(0.6), closeTo(f.arc, 1e-9));
      expect(f.liftAt(1), closeTo(0, 1e-9));
      expect(f.poseAt(0.5).y, closeTo(30 + Flight.clearance, 1e-9));
      // Looks down at what it crosses, levels out to land.
      expect(f.poseAt(0.5).pitch, lessThan(-0.4));
      expect(f.poseAt(1).pitch, closeTo(0, 1e-9));
      expect(f.poseAt(1).y, closeTo(2.2, 1e-9));
    });

    test('beside a building, and under a beam, the line stays level', () {
      final beside = box(x: 6, z: 25); // its near face at x = 1
      final beam = box(
        x: 0,
        z: 25,
        width: 22,
        depth: 0.5,
        bottom: 10.5,
        top: 12.7,
      );
      final f = Flight.plan(a, to, solids: [beside, beam]);
      expect(f.arc, 0);
      expect(f.rampStart, Flight.defaultRamp);
      expect(f.poseAt(0.5).y, 2.2);
    });

    test('from altitude, a roof already under the line asks for nothing', () {
      const high = CameraPose(x: 0, y: 60, z: 0, yaw: 0);
      const far = CameraPose(x: 0, y: 60, z: 50, yaw: 0);
      final f = Flight.plan(high, far, solids: [box(x: 0, z: 25)]);
      expect(f.arc, 0);
    });

    test('a lift that would raise the line into a beam clears the beam', () {
      final beam = box(
        x: 0,
        z: 8.5,
        width: 22,
        depth: 0.5,
        bottom: 10.5,
        top: 12.7,
      );
      final tower = box(x: 0, z: 25, width: 4, depth: 4, top: 20);
      // Over the tower alone, the climb runs up through the beam.
      expect(
        passesThrough(Flight.plan(a, to, solids: [tower]), [beam]),
        isTrue,
      );
      final f = Flight.plan(a, to, solids: [beam, tower]);
      expect(passesThrough(f, [beam, tower]), isFalse);
      // The climb now ends before the beam, not before the tower.
      expect(f.rampStart, closeTo(0.85 * (8.5 - 0.25) / 50, 1e-9));
      expect(f.arc, closeTo(20 + Flight.clearance - 2.2, 1e-9));
    });

    test('a stop a step past the wall it came over drops beside it', () {
      // From over the roof to the ground 0.6 m past the wall: the descent
      // is short, the ask is what the roof needs, and the line never
      // enters the box.
      const over = CameraPose(x: 0, y: 60, z: 25, yaw: 0);
      const beside = CameraPose(x: 0, y: 2.2, z: 30.6, yaw: 0);
      final building = box(x: 0, z: 25);
      final f = Flight.plan(over, beside, solids: [building]);
      expect(passesThrough(f, [building]), isFalse);
      expect(f.rampEnd, closeTo(0.85 * 0.6 / 5.6, 1e-9));
      expect(f.arc, lessThan(30));
    });

    glados.Glados3<double, double, int>(
      glados.any.doubleInRange(-60, 60),
      glados.any.doubleInRange(-60, 60),
      glados.any.intInRange(0, 1 << 20),
      glados.ExploreConfig(numRuns: 60),
    ).test('never passes through a solid, whatever stands on the way', (
      fx,
      fz,
      seed,
    ) {
      final rng = math.Random(seed);
      double pick(double lo, double hi) => lo + rng.nextDouble() * (hi - lo);
      final solids = [
        for (var i = 0; i < 5; i++)
          box(
            x: pick(-50, 50),
            z: pick(-50, 50),
            width: pick(3, 24),
            depth: i < 3 ? pick(3, 24) : pick(0.5, 1),
            facing: pick(-math.pi, math.pi),
            bottom: i < 3 ? 0 : pick(4, 14),
            top: pick(16, 70),
          ),
      ];
      final from = CameraPose(x: fx, y: eyeHeight, z: fz, yaw: 0);
      final to = CameraPose(
        x: -fz,
        y: rng.nextBool() ? eyeHeight : pick(eyeHeight, 140),
        z: fx,
        yaw: 1,
      );
      // A pose inside, under or over a solid is not the planner's to fix:
      // the stop poses stand clear of every footprint.
      for (final p in [from, to]) {
        for (final s in solids) {
          final mid = (s.bottom + s.top) / 2;
          if (s.contains(p.x, mid, p.z, clearance: solidClearance)) return;
        }
      }
      final f = Flight.plan(from, to, solids: solids);
      expect(passesThrough(f, solids), isFalse, reason: '$from → $to');
    }, tags: 'glados');
  });
}
