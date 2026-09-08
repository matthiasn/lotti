import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';

void main() {
  const motion = MeerkatMotion(
    id: 'lookout',
    loop: CharacterLoop(
      x: 4,
      z: -3,
      heading: 0.7,
      radius: 1.1,
      halfStraight: 1.4,
    ),
    scale: 0.72,
    phase: 0.15,
  );

  test('scampers, plants all paws, then rises into a stationary lookout', () {
    expect(motion.at(1).action, MeerkatAction.scamper);
    expect(motion.at(3.3).action, MeerkatAction.settle);
    expect(motion.at(3.8).action, MeerkatAction.rise);
    expect(motion.at(5).action, MeerkatAction.lookout);
    expect(motion.at(7.7).action, MeerkatAction.lower);
    expect(motion.at(8.8).action, MeerkatAction.forage);
    final stopped = motion.at(MeerkatMotion.runDuration);
    expect(stopped.paws.every((paw) => paw.planted), isTrue);
    for (var frame = 321; frame < 945; frame++) {
      final pose = motion.at(frame / 100);
      expect(pose.distance, stopped.distance);
      expect(pose.root.x, stopped.root.x);
      expect(pose.root.z, stopped.root.z);
      expect(pose.speed, 0);
      expect(pose.rearLeft.x, stopped.rearLeft.x);
      expect(pose.rearRight.z, stopped.rearRight.z);
    }
    expect(motion.at(5).upright, 1);
    expect(motion.at(8.8).upright, 0);
    expect(motion.at(5).headYaw, isNot(motion.at(6).headYaw));
    expect(motion.at(1).speed, greaterThan(1.3));
  });

  test(
    'accelerates and stops continuously without resetting route distance',
    () {
      expect(motion.at(0).speed, 0);
      expect(motion.at(0.2).speed, lessThan(motion.at(0.5).speed));
      expect(motion.at(3).speed, lessThan(motion.at(2.5).speed));
      expect(motion.at(3.2).speed, 0);
      const epsilon = 1e-6;
      for (final t in [0.45, 2.75, 3.2, 3.45, 4.2, 7.4, 8.05, 9.45]) {
        final before = motion.at(t - epsilon);
        final after = motion.at(t + epsilon);
        expect(after.distance, closeTo(before.distance, 1e-5));
        expect(after.upright, closeTo(before.upright, 1e-5));
        expect(after.speed, closeTo(before.speed, 1e-5));
        expect(after.headYaw, closeTo(before.headYaw, 1e-5));
        expect(after.headPitch, closeTo(before.headPitch, 1e-5));
        for (var paw = 0; paw < 4; paw++) {
          expect(after.paws[paw].x, closeTo(before.paws[paw].x, 1e-5));
          expect(after.paws[paw].y, closeTo(before.paws[paw].y, 1e-5));
          expect(after.paws[paw].z, closeTo(before.paws[paw].z, 1e-5));
        }
      }
      expect(
        motion.at(MeerkatMotion.cycleDuration).distance,
        closeTo(motion.boutDistance, 1e-9),
      );
    },
  );

  test('diagonal paws move together and planted contacts do not slide', () {
    var previous = motion.at(0);
    var recoverySamples = 0;
    for (var frame = 1; frame <= 9000; frame++) {
      final pose = motion.at(frame / 1000);
      expect(pose.frontLeft.planted, pose.rearRight.planted);
      expect(pose.frontRight.planted, pose.rearLeft.planted);
      for (var i = 0; i < 4; i++) {
        final paw = pose.paws[i];
        expect(paw.y, greaterThanOrEqualTo(motion.loop.ground));
        if (paw.planted && previous.paws[i].planted) {
          expect(paw.x, closeTo(previous.paws[i].x, 1e-9));
          expect(paw.z, closeTo(previous.paws[i].z, 1e-9));
        }
        if (!paw.planted) recoverySamples++;
      }
      previous = pose;
    }
    expect(recoverySamples, greaterThan(100));
  });

  test('sampling order and skipped frames cannot change the pose', () {
    final random = math.Random(21);
    for (var sample = 0; sample < 500; sample++) {
      final t = random.nextDouble() * 500;
      final a = motion.at(t);
      motion.at(t + 200);
      final b = motion.at(t);
      expect(b.distance, a.distance);
      expect(b.frontLeft.x, a.frontLeft.x);
      expect(b.headYaw, a.headYaw);
      expect(b.blink, a.blink);
      expect(b.upright, inInclusiveRange(0, 1));
      expect(b.blink, inInclusiveRange(0, 1));
      expect(b.headYaw.abs(), lessThanOrEqualTo(0.55));
    }
  });
}
