import 'dart:ui';

import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/arm_solver.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// The pelvis height above the floor.
const pelvisY = -178.0;
const thigh = 78.0;
const shin = 75.0;

/// A pose resolved into the frames the painters draw in: the torso's, the
/// head's, and each arm's joints.
class RigFrame {
  factory RigFrame(CompanionPose pose) {
    final pelvis = Offset(
      pose.pelvis.dx,
      pelvisY + pose.pelvis.dy - pose.breath * 0.6,
    );
    final torso = Affine(pelvis, pose.lean);
    final headAngle = pose.lean * 1.4 + pose.headRoll;
    final pivot = torso(0, -128 - pose.breath * 0.8);
    final centre =
        pivot + rotate(const Offset(0, -40), headAngle) + pose.headOffset;
    return RigFrame._(
      pose: pose,
      pelvis: pelvis,
      torso: torso,
      neckBase: torso(0, -112 - pose.breath * 0.8),
      headPivot: pivot,
      head: Affine(centre, headAngle),
    );
  }

  RigFrame._({
    required this.pose,
    required this.pelvis,
    required this.torso,
    required this.neckBase,
    required this.headPivot,
    required this.head,
  });

  final CompanionPose pose;
  final Offset pelvis;

  /// The torso frame: origin at the pelvis, rotated with the lean.
  final Affine torso;
  final Offset neckBase;
  final Offset headPivot;

  /// The head frame: origin at the face's centre.
  final Affine head;

  /// The ankle of leg [side] (-1 left, +1 right), standing.
  Offset ankle(int side) => Offset(side * 19.0, -20);

  /// The arm's joints in world space, from a root inside the torso, so the
  /// shoulder is a round cap that turns with the arm, not a corner it hinges
  /// on: root, shoulder, elbow, wrist.
  List<Offset> armSpine(ArmPose arm, int side) {
    final sh = Offset(side * shoulderRight.dx, shoulderRight.dy - arm.lift);
    final solved = arm.elbow == null
        ? solveArm(sh, arm.wrist, side)
        : (elbow: arm.elbow!, wrist: arm.wrist);
    return [
      torso(side * 30.0, -103 - arm.lift * 0.6),
      torso.of(sh),
      torso.of(solved.elbow),
      torso.of(solved.wrist),
    ];
  }
}
