import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/features/companion/rig/rig_math.dart';

/// The arm: where the elbow goes, inside what a real arm can do.
///
/// A gesture names only where the wrist goes. A plain two-bone IK answers
/// with one of two elbows, and close to the shoulder both are wrong: the arm
/// folds flat and the elbow flares, so two arms reaching in front of the chest
/// cross into an X. A real arm reaches there with the elbow hanging at the
/// side and the forearm pointing at the camera.
///
/// So the solver searches the elbow positions a real arm can take and keeps
/// the most relaxed one. It has no depth axis, so a bone pointing at the
/// camera is drawn shorter, down to a floor. The rules ([elbowAllowed]):
///
/// - **No stretching.** A projected bone is never longer than the bone.
/// - **The elbow folds, never closes**, to at least [foldMin] in depth.
/// - **The elbow stays on its own side**, never more than [medial] inside the
///   shoulder.
/// - **The elbow is never hiked** above the shoulder while the hand hangs
///   below it.
/// - **The elbow points out and down**, never bending the arm backwards.

/// The right shoulder in the torso frame; the left one is mirrored.
const shoulderRight = Offset(46, -106);
const double upperArm = 50;
const double forearm = 47;

const double foldMin = 34 * math.pi / 180;
const double medial = 0.22 * upperArm;
const upperMin = 0.6;
const foreMin = 0.38;

/// How far the shoulder rises when the hand goes over it.
const shrugHeight = 7.0;

final List<Offset> _directions = [
  for (var k = 0; k < 120; k++)
    Offset(math.cos(2 * math.pi * k / 120), math.sin(2 * math.pi * k / 120)),
];
const List<double> _upperFractions = [1.0, 0.9, 0.8, 0.7, upperMin];

/// The shoulder's rise because the hand is above it: a raised arm lifts the
/// shoulder girdle with it.
double shrug(Offset shoulder, Offset wrist) =>
    shrugHeight * smoothstep(clampUnit((shoulder.dy - wrist.dy) / 90.0));

Offset _rest(int side) {
  final d = Offset(side * 0.22, 1);
  return d / d.distance;
}

/// Whether a real arm can take this [elbow], by the rules above.
bool elbowAllowed(Offset shoulder, Offset elbow, Offset wrist, int side) {
  final upper = elbow - shoulder;
  final fore = wrist - elbow;
  final lu = upper.distance;
  final lf = fore.distance;
  if (lu > upperArm + 1e-6 || lf > forearm + 1e-6) return false;
  if (lu < upperMin * upperArm - 1e-6 || lf < foreMin * forearm - 1e-6) {
    return false;
  }
  // The interior angle at the elbow, in depth: a bone drawn short points at
  // the camera by what it lost, so a forearm reaching forward is no fold.
  final du = math.sqrt(math.max(0, upperArm * upperArm - lu * lu));
  final df = math.sqrt(math.max(0, forearm * forearm - lf * lf));
  final cosA =
      (-upper.dx * fore.dx - upper.dy * fore.dy - du * df) /
      (upperArm * forearm);
  if (math.acos(clampUnit(cosA, -1)) < foldMin) return false;
  if (side * (elbow.dx - shoulder.dx) < -medial) return false;
  if (elbow.dy < shoulder.dy - 4 && wrist.dy > elbow.dy) return false;
  // The outer side of the shoulder-to-wrist line: the normal pointing out
  // and down.
  final sw = wrist - shoulder;
  var n = Offset(sw.dy, -sw.dx);
  if (n.dx * side * 0.5 + n.dy < 0) n = -n;
  final len = n.distance == 0 ? 1.0 : n.distance;
  return (upper.dx * n.dx + upper.dy * n.dy) / len >= -2.0;
}

/// The elbow for a wrist target, and the wrist itself pulled in to the arm's
/// reach. [previous] is last frame's elbow, so the choice holds steady;
/// [rest] is the unit direction the upper arm would rather take, hanging a
/// little out by default.
({Offset elbow, Offset wrist}) solveArm(
  Offset shoulder,
  Offset wrist,
  int side, {
  Offset? previous,
  Offset? rest,
}) {
  final d = wrist - shoulder;
  final reach = d.distance;
  const full = upperArm + forearm - 1e-3;
  final target = reach > full ? shoulder + d * (full / reach) : wrist;
  final preferred = rest ?? _rest(side);
  Offset? best;
  var bestCost = double.infinity;
  for (final u in _directions) {
    final hang = math.acos(
      clampUnit(u.dx * preferred.dx + u.dy * preferred.dy, -1),
    );
    for (final ru in _upperFractions) {
      final elbow = shoulder + u * (upperArm * ru);
      if (!elbowAllowed(shoulder, elbow, target, side)) continue;
      final rf = (target - elbow).distance / forearm;
      var cost =
          1.6 * hang * hang +
          4.0 * (1 - ru) * (1 - ru) +
          1.1 * (1 - rf) * (1 - rf);
      if (previous != null) {
        cost += 0.0009 * (elbow - previous).distanceSquared;
      }
      if (cost < bestCost) {
        best = elbow;
        bestCost = cost;
      }
    }
  }
  if (best == null) {
    // Nothing allowed (a target the springs overshot into): the plain
    // two-bone answer, elbow out and down.
    final a = twoBoneIk(shoulder, target, upperArm, forearm, 1);
    final b = twoBoneIk(shoulder, target, upperArm, forearm, -1);
    double score(Offset e) =>
        (e.dx - shoulder.dx) * side * 0.3 + (e.dy - shoulder.dy);
    best = score(a.elbow) >= score(b.elbow) ? a.elbow : b.elbow;
  }
  return (elbow: best, wrist: target);
}

/// Pulls an elbow that is between solutions back onto bones of a real
/// length: neither bone longer than it is, nor shorter than its floor.
Offset fitElbow(Offset shoulder, Offset elbow, Offset wrist) {
  var e = elbow;
  for (var i = 0; i < 40; i++) {
    var d = e - shoulder;
    var lu = d.distance;
    if (lu < 1e-6) {
      d = const Offset(0, 1);
      lu = 1;
    }
    e = shoulder + d * (clampUnit(lu, upperMin * upperArm, upperArm) / lu);
    final f = e - wrist;
    final lf = f.distance == 0 ? 1e-6 : f.distance;
    e = wrist + f * (clampUnit(lf, foreMin * forearm, forearm) / lf);
  }
  return e;
}
