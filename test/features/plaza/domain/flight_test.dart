import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/flight.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';

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
}
