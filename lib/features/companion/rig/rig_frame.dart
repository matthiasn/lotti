import 'dart:ui';

import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/arm_solver.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// The pelvis height above the floor.
const pelvisY = -178.0;
const thigh = 78.0;
const shin = 75.0;

/// Where the standing right leg's knee sits: the share of the way down its
/// hip-to-ankle line, and how far out from that line, solved once.
final ({double along, double out}) _restKnee = () {
  final standing = RigFrame(const CompanionPose());
  final hip = standing.hip(1);
  final d = standing.ankle(1) - hip;
  final knee = twoBoneIk(hip, standing.ankle(1), thigh, shin, -1).elbow - hip;
  final length = d.distance;
  final down = d / length;
  return (
    along: (knee.dx * down.dx + knee.dy * down.dy) / length,
    out: knee.dx * down.dy - knee.dy * down.dx,
  );
}();

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

  /// The hip joint of leg [side], riding on the pelvis.
  Offset hip(int side) => Offset(pelvis.dx + side * 15, pelvis.dy + 12);

  /// The knee of leg [side], between its hip and its planted ankle.
  ///
  /// She faces us, so a knee that bends goes towards us, not sideways: when
  /// the pelvis bobs, the leg foreshortens and the knee keeps its place
  /// across the leg. It sits where the standing leg's solved knee sits — as
  /// far down the hip-to-ankle line, and as far out from it ([_restKnee]) —
  /// rather than being solved afresh each frame: with the legs this close to
  /// straight, a fresh solve swung the knees sideways by twice the bob, and a
  /// bounce read as legs shaking.
  Offset knee(int side) {
    final h = hip(side);
    final d = ankle(side) - h;
    final length = d.distance;
    if (length == 0) return h;
    // Across the leg, outwards on the leg's own side.
    final across = Offset(d.dy, -d.dx) / length * side.toDouble();
    return h + d * _restKnee.along + across * _restKnee.out;
  }

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
