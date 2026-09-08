import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/meerkat_lookout.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';

void main() {
  const motion = MeerkatMotion(
    id: 'one',
    loop: CharacterLoop(x: 0, z: 0, heading: 0, radius: 3, halfStraight: 4),
    scale: 0.72,
    phase: 0,
  );

  test(
    'a half-turn faces the camera with alternating planted hind contacts',
    () {
      final pose = motion.at(5);
      final turn = MeerkatLookout();
      final target = pose.root.yaw + math.pi;
      var previousLeft = pose.rearLeft;
      var previousRight = pose.rearRight;
      var steps = 0;
      var yaw = pose.root.yaw;
      for (var frame = 0; frame < 150; frame++) {
        final facing = turn.update(
          pose: pose,
          eyeX: pose.root.x + 5 * math.sin(target),
          eyeZ: pose.root.z + 5 * math.cos(target),
          dt: 1 / 60,
          scale: motion.scale,
        );
        expect(facing.left.planted || facing.right.planted, isTrue);
        for (final pair in [
          (facing.left, previousLeft),
          (facing.right, previousRight),
        ]) {
          if (pair.$1.planted && pair.$2.planted) {
            expect(pair.$1.x, pair.$2.x);
            expect(pair.$1.z, pair.$2.z);
          }
          if (!pair.$1.planted) steps++;
        }
        expect((facing.yaw - yaw).abs(), lessThanOrEqualTo(3 / 60 + 1e-9));
        yaw = facing.yaw;
        previousLeft = facing.left;
        previousRight = facing.right;
      }
      expect(math.cos(yaw - target), closeTo(1, 1e-9));
      expect(steps, greaterThan(30));
    },
  );

  test(
    'returns to route facing before the forepaws land and freezes with no delta',
    () {
      final turn = MeerkatLookout();
      final pose = motion.at(5);
      for (var frame = 0; frame < 90; frame++) {
        turn.update(
          pose: pose,
          eyeX: pose.root.x,
          eyeZ: pose.root.z - 10,
          dt: 1 / 60,
          scale: motion.scale,
        );
      }
      final held = turn.update(
        pose: pose,
        eyeX: 100,
        eyeZ: 100,
        dt: 0,
        scale: motion.scale,
      );
      final still = turn.update(
        pose: pose,
        eyeX: -100,
        eyeZ: -100,
        dt: 0,
        scale: motion.scale,
      );
      expect(still.yaw, held.yaw);
      expect(still.left.x, held.left.x);
      expect(still.right.z, held.right.z);
      for (var frame = 0; frame <= 120; frame++) {
        final returning = motion.at(7.4 + frame / 60);
        final facing = turn.update(
          pose: returning,
          eyeX: 100,
          eyeZ: 100,
          dt: 1 / 60,
          scale: motion.scale,
        );
        if (frame == 120) {
          expect(math.cos(facing.yaw - returning.root.yaw), closeTo(1, 1e-9));
          expect(facing.left.x, closeTo(returning.rearLeft.x, 0.02));
          expect(facing.right.z, closeTo(returning.rearRight.z, 0.02));
        }
      }
    },
  );
}
