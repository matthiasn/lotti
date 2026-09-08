import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';

void main() {
  const loop = CharacterLoop(
    x: 10,
    z: 20,
    heading: 0.7,
    radius: 6,
    halfStraight: 6,
  );
  const gait = CharacterGait(loop: loop, scale: 1, phase: 0);

  double distance(CharacterFootPose a, CharacterFootPose b) => math.sqrt(
    math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2) + math.pow(a.z - b.z, 2),
  );

  test('stance locks both feet to the paving on straights and bends', () {
    for (var stride = 0; stride < 40; stride++) {
      for (final offset in [0.0, 0.5]) {
        final a = gait.at((stride + offset + 0.05) * gait.period);
        final b = gait.at((stride + offset + 0.30) * gait.period);
        final footA = offset == 0 ? a.left : a.right;
        final footB = offset == 0 ? b.left : b.right;
        expect(footA.planted, isTrue);
        expect(footB.planted, isTrue);
        expect(distance(footA, footB), lessThan(1e-10));
        expect(footA.yaw, footB.yaw);
        expect(footA.pitch, 0);
        expect(footA.y, loop.ground + CharacterGait.ankleHeight);
      }
    }
  });

  test('walking always has support and transfers through double stance', () {
    var doubleSupport = 0;
    for (var frame = 0; frame < 100; frame++) {
      final pose = gait.at(frame / 100 * gait.period);
      expect(
        pose.left.planted || pose.right.planted,
        isTrue,
        reason: 'Walking must not have an aerial phase at frame $frame',
      );
      if (pose.left.planted && pose.right.planted) doubleSupport++;
      expect(pose.bounce.abs(), lessThan(0.02));
    }
    expect(doubleSupport, inInclusiveRange(15, 25));
  });

  test(
    'contacts and body velocity remain continuous across phase boundaries',
    () {
      const dt = 1e-5;
      for (final phase in [
        0.0,
        CharacterGait.stance,
        0.5,
        0.5 + CharacterGait.stance,
        1.0,
      ]) {
        final t = phase * gait.period;
        final before = gait.at(t - dt);
        final at = gait.at(t);
        final after = gait.at(t + dt);
        final leftContact = phase < 0.5 || phase == 1;
        expect(
          distance(
            leftContact ? before.left : before.right,
            leftContact ? after.left : after.right,
          ),
          lessThan(1e-7),
        );
        // The other leg can be in mid-swing, but still moves continuously.
        expect(distance(before.right, after.right), lessThan(0.001));
        final velocityIn = (at.bounce - before.bounce) / dt;
        final velocityOut = (after.bounce - at.bounce) / dt;
        expect(velocityIn, closeTo(velocityOut, 0.001));
      }
    },
  );

  test(
    'smaller companions take shorter, quicker strides at the same speed',
    () {
      const small = CharacterGait(loop: loop, scale: 0.82, phase: 0);
      expect(small.period / gait.period, closeTo(0.82, 1e-10));
      expect(small.strideDistance / gait.strideDistance, closeTo(0.82, 1e-10));
      final a = gait.at(3);
      final b = small.at(3);
      expect((a.root.x, a.root.z), (b.root.x, b.root.z));
      expect(b.cycle, greaterThan(a.cycle));
    },
  );

  test(
    'short legs recover the heel below the belly before reaching forward',
    () {
      final recovery = gait.at(
        gait.period * (CharacterGait.stance + (1 - CharacterGait.stance) / 3),
      );
      final reach = gait.at(gait.period * 0.9);
      final groundAnkle = loop.ground + CharacterGait.ankleHeight;
      expect(recovery.left.y - groundAnkle, greaterThan(0.06));
      expect(recovery.left.pitch, greaterThan(0.14));
      expect(recovery.left.y - groundAnkle, lessThan(0.09));
      expect(reach.left.y - groundAnkle, lessThan(0.04));
      expect(reach.left.pitch, closeTo(0, 1e-10));
    },
  );

  glados.Glados(glados.any.int, glados.ExploreConfig(numRuns: 80)).test(
    'feet clear the paving and arbitrary frame sampling preserves poses',
    (value) {
      final t = (value % 100000) / 73;
      final first = gait.at(t);
      gait.at(t + 100);
      final repeated = gait.at(t);
      expect(distance(first.left, repeated.left), 0);
      expect(distance(first.right, repeated.right), 0);
      for (final foot in [first.left, first.right]) {
        expect(
          foot.y,
          greaterThanOrEqualTo(
            loop.ground + CharacterGait.ankleHeight,
          ),
        );
        expect(
          foot.y,
          lessThanOrEqualTo(
            loop.ground +
                CharacterGait.ankleHeight +
                CharacterGait.recoveryLift,
          ),
        );
      }
      expect(first.bank.abs(), lessThan(0.2));
      expect(first.left.planted || first.right.planted, isTrue);
    },
    tags: 'glados',
  );
}
