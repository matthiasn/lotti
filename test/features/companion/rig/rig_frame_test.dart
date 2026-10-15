import 'package:flutter_test/flutter_test.dart';
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
