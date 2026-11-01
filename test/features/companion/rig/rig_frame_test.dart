import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/companion_animator.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/arm_solver.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

void main() {
  test('the head sits above the neck, the neck above the pelvis', () {
    final f = RigFrame(const CompanionPose());
    expect(f.pelvis, const Offset(0, pelvisY));
    expect(f.neckBase.dy, lessThan(f.pelvis.dy));
    expect(f.headPivot.dy, lessThan(f.neckBase.dy));
    expect(f.head.origin.dy, closeTo(f.headPivot.dy - 40, 1e-9));
    expect(f.head.angle, 0);
  });

  test('a breath in lifts the body', () {
    final out = RigFrame(const CompanionPose(breath: -1));
    final inn = RigFrame(const CompanionPose(breath: 1));
    expect(inn.pelvis.dy, lessThan(out.pelvis.dy));
    expect(inn.head.origin.dy, lessThan(out.head.origin.dy));
  });

  test('a lean tilts the head further than the body', () {
    final f = RigFrame(const CompanionPose(lean: 0.1, headRoll: 0.05));
    expect(f.head.angle, closeTo(0.1 * 1.4 + 0.05, 1e-12));
    expect(f.head.origin.dx, greaterThan(0));
  });

  test('the head offset moves the head alone', () {
    final f = RigFrame(const CompanionPose(headOffset: Offset(0, 3)));
    final g = RigFrame(const CompanionPose());
    expect(f.head.origin.dy - g.head.origin.dy, closeTo(3, 1e-9));
    expect(f.neckBase, g.neckBase);
  });

  test('the ankles stand apart, mirrored', () {
    final f = RigFrame(const CompanionPose());
    expect(f.ankle(-1).dx, -f.ankle(1).dx);
    expect(f.ankle(1).dy, f.ankle(-1).dy);
  });

  group('legs', () {
    test('at rest each knee sits between its hip and ankle, bowed out', () {
      final f = RigFrame(const CompanionPose());
      for (final side in [-1, 1]) {
        final hip = f.hip(side);
        final ankle = f.ankle(side);
        final knee = f.knee(side);
        expect(knee.dy, inExclusiveRange(hip.dy, ankle.dy));
        // Outward of the hip-ankle line, on its own side.
        final lineX =
            hip.dx +
            (ankle.dx - hip.dx) * (knee.dy - hip.dy) / (ankle.dy - hip.dy);
        expect((knee.dx - lineX) * side, greaterThan(5));
        expect((knee - hip).distance, closeTo(thigh, 1));
      }
    });

    test('a lift raises her upper body by its height above the hem, and '
        'leaves her hips and legs where they stand', () {
      final still = RigFrame(const CompanionPose());
      final lifted = RigFrame(const CompanionPose(lift: 5));
      // The hem stays, the neck rises by all of it, the waist by part.
      expect(lifted.torso(0, 103), still.torso(0, 103));
      expect(
        lifted.torso(0, -128).dy,
        closeTo(still.torso(0, -128).dy - 5, 1e-9),
      );
      final waist = still.torso(0, 0).dy - lifted.torso(0, 0).dy;
      expect(waist, inExclusiveRange(1, 4));
      expect(lifted.head.origin.dy, closeTo(still.head.origin.dy - 5, 1e-9));
      for (final side in [-1, 1]) {
        expect(lifted.hip(side), still.hip(side));
        expect(lifted.knee(side), still.knee(side));
      }
    });

    // The gate the dancing_cats rig keeps for its own joints: sampled frame
    // by frame, a bounce of joy moves her upper body and never her legs.
    test('a bounce lifts her upper body and leaves her knees still', () {
      final animator = CompanionAnimator()..play(GestureName.celebrate);
      final knees = <Offset>[];
      final heads = <double>[];
      for (var i = 0; i < 90; i++) {
        final f = RigFrame(
          animator.step(1 / 60, mood: CompanionMood.delighted),
        );
        knees.add(f.knee(1));
        heads.add(f.head.origin.dy);
      }
      double range(Iterable<double> v) =>
          v.reduce(math.max) - v.reduce(math.min);
      // She does bounce...
      expect(range(heads), greaterThan(3));
      // ...and her knees only drift with her slow sway and breath.
      expect(range(knees.map((k) => k.dx)), lessThan(1));
      expect(range(knees.map((k) => k.dy)), lessThan(1));
      var worst = 0.0;
      for (var i = 1; i < knees.length; i++) {
        worst = math.max(worst, (knees[i] - knees[i - 1]).distance);
      }
      expect(worst, lessThan(0.05));
    });
  });

  group('armSpine', () {
    test('runs root, shoulder, elbow, wrist, the root inside the torso', () {
      final f = RigFrame(const CompanionPose());
      final spine = f.armSpine(const CompanionPose().right, 1);
      expect(spine, hasLength(4));
      expect(spine[0].dx, lessThan(spine[1].dx));
      expect(spine[1], f.torso.of(shoulderRight));
    });

    test('uses a given elbow and lifts the shoulder', () {
      final f = RigFrame(const CompanionPose());
      const arm = ArmPose(
        wrist: Offset(60, -30),
        handAngle: 0,
        lift: 5,
        elbow: Offset(60, -70),
      );
      final spine = f.armSpine(arm, 1);
      expect(spine[2], f.torso(60, -70));
      expect(spine[1], f.torso(shoulderRight.dx, shoulderRight.dy - 5));
      expect(spine[3], f.torso(60, -30));
    });
  });
}
