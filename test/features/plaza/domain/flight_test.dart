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
      const CameraPose(x: 0, y: 2.2, z: 100, yaw: 0),
    );
    expect(short.arc, 0);
    expect(short.poseAt(0.5).y, 2.2);

    final long = Flight.plan(a, const CameraPose(x: 0, y: 2.2, z: 200, yaw: 0));
    expect(long.arc, closeTo(40, 1e-9));
    expect(long.poseAt(0.5).y, closeTo(2.2 + 40, 1e-9));
    expect(long.poseAt(0).y, 2.2);
    expect(long.poseAt(1).y, closeTo(2.2, 1e-9));

    final veryLong = Flight.plan(
      a,
      const CameraPose(x: 0, y: 2.2, z: 2000, yaw: 0),
    );
    expect(veryLong.arc, 55);
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

  test('advance accumulates time and clamps at the end', () {
    final f = Flight.plan(a, const CameraPose(x: 1, y: 2.2, z: 0, yaw: 0));
    expect(f.done, isFalse);
    f.advance(const Duration(milliseconds: 400));
    expect(f.progress, closeTo(0.5, 1e-9));
    expect(f.done, isFalse);
    final end = f.advance(const Duration(seconds: 5));
    expect(f.done, isTrue);
    expect(f.progress, 1);
    expect(end.x, 1);
  });
}
