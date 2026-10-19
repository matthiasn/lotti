import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/arm_rig.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';
import 'package:lotti/features/companion/rig/arm_solver.dart';

void main() {
  const dt = 1 / 60;

  test('the wrist travels to its target and stays there', () {
    final rig = ArmRig(CompanionGesture.readyRight, 1);
    const target = GestureArm(100, -80, -12, HandPose.open);
    var pose = rig.step(target, null, 0, dt);
    for (var i = 1; i < 240; i++) {
      pose = rig.step(target, null, i * dt, dt);
    }
    expect((pose.wrist - const Offset(100, -80)).distance, lessThan(1));
    expect(pose.hand.index, closeTo(0, 0.01));
  });

  test('the elbow it reports is always on bones of a real length', () {
    final rig = ArmRig(CompanionGesture.readyRight, 1);
    final targets = [
      GestureName.wave.gesture.right!,
      GestureName.think.gesture.right!,
      GestureName.clap.gesture.right!,
    ];
    var t = 0.0;
    for (final target in targets) {
      for (var i = 0; i < 90; i++) {
        t += dt;
        final pose = rig.step(target, null, t, dt);
        final sh = Offset(shoulderRight.dx, shoulderRight.dy - pose.lift);
        expect((pose.elbow! - sh).distance, lessThanOrEqualTo(upperArm + 1e-6));
        expect(
          (pose.wrist - pose.elbow!).distance,
          lessThanOrEqualTo(forearm + 1e-3),
        );
      }
    }
  });

  test('raising the hand over the shoulder lifts the shoulder', () {
    final rig = ArmRig(CompanionGesture.readyRight, 1);
    final low = rig.step(CompanionGesture.readyRight, null, 0, dt).lift;
    var high = low;
    for (var i = 0; i < 180; i++) {
      high = rig
          .step(GestureName.celebrate.gesture.right!, null, i * dt, dt)
          .lift;
    }
    expect(high, greaterThan(low + 5));
  });

  test('an oscillation wobbles the wrist, and fades out after it ends', () {
    final rig = ArmRig(CompanionGesture.readyRight, 1);
    const target = GestureArm(88, -176, -78, HandPose.open, 6);
    final osc = GestureName.wave.gesture.oscRight;
    final xs = <double>[];
    for (var i = 0; i < 300; i++) {
      xs.add(rig.step(target, osc, i * dt, dt).wrist.dx);
    }
    final settled = xs.sublist(180);
    final spread =
        settled.reduce((a, b) => a > b ? a : b) -
        settled.reduce((a, b) => a < b ? a : b);
    expect(spread, greaterThan(4));

    final still = <double>[];
    for (var i = 300; i < 700; i++) {
      still.add(rig.step(target, null, i * dt, dt).wrist.dx);
    }
    final tail = still.sublist(300);
    expect(
      tail.reduce((a, b) => a > b ? a : b) -
          tail.reduce((a, b) => a < b ? a : b),
      lessThan(0.5),
    );
  });

  test('a beat kick dips the hand, then it returns', () {
    final rig = ArmRig(CompanionGesture.readyRight, 1);
    var rest = rig.step(CompanionGesture.readyRight, null, 0, dt);
    for (var i = 1; i < 120; i++) {
      rest = rig.step(CompanionGesture.readyRight, null, i * dt, dt);
    }
    final kicked = rig.step(
      CompanionGesture.readyRight,
      null,
      2,
      dt,
      beatKick: 55,
    );
    expect((kicked.wrist - rest.wrist).distance, greaterThan(0.1));
  });

  test("a gesture's elbow preference reaches the solved arm, mirrored", () {
    double elbowOut(GestureArm target, int side) {
      final rig = ArmRig(
        side > 0 ? CompanionGesture.readyRight : CompanionGesture.readyLeft,
        side,
      );
      var pose = rig.step(target, null, 0, dt);
      for (var i = 1; i < 240; i++) {
        pose = rig.step(target, null, i * dt, dt);
      }
      return side * pose.elbow!.dx;
    }

    final hip = GestureName.handsOnHips.gesture;
    for (final (arm, side) in [(hip.right!, 1), (hip.left!, -1)]) {
      final hanging = GestureArm(arm.x, arm.y, arm.angle, arm.hand);
      expect(
        elbowOut(arm, side),
        greaterThan(elbowOut(hanging, side) + 10),
        reason: 'side $side',
      );
    }
  });
}
