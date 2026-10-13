import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';
import 'package:lotti/features/companion/rig/arm_solver.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// One arm's springs: the hand travels in polar coordinates around the
/// shoulder, so a path arcs round it instead of cutting through it (which
/// would fold the arm flat and flip it in one frame); the elbow the solver
/// picks is chased by a stiff spring, so a change of solution travels instead
/// of jumping.
class ArmRig {
  ArmRig(GestureArm start, this.side) {
    final (r, th) = _polar(start);
    _r = Spring(r, freq: 1.6, zeta: 0.68);
    _th = Spring(th, freq: 1.6, zeta: 0.68);
    _angle = Spring(start.angle * math.pi / 180, freq: 2.1, zeta: 0.7);
    _lift = Spring(start.lift, freq: 2.2, zeta: 0.8);
    _fingers = [
      for (final v in start.hand.shape.values) Spring(v, freq: 4.5, zeta: 0.85),
    ];
  }

  /// -1 for the arm on the left of the screen, +1 for the right.
  final int side;
  late final Spring _r;
  late final Spring _th;
  late final Spring _angle;
  late final Spring _lift;
  late final List<Spring> _fingers;
  final Spring _oscEnvelope = Spring(0, freq: 2, zeta: 1);
  Oscillation? _osc;
  Spring? _elbowX;
  Spring? _elbowY;

  Offset get _shoulder => Offset(side * shoulderRight.dx, shoulderRight.dy);

  (double, double) _polar(GestureArm a) {
    final d = Offset(a.x, a.y) - _shoulder;
    return (math.max(34, d.distance), math.atan2(d.dy, d.dx));
  }

  /// Picks the way round the shoulder that never sweeps over the head: the
  /// right hand may not pass up-and-left of its shoulder (-135°), the left
  /// hand mirrored (-45°). Arms drop out and down instead.
  double _unwrap(double th) {
    final cur = _th.x;
    final forbidden = (side > 0 ? -135 : -45) * math.pi / 180;
    double? best;
    for (var k = -2; k <= 2; k++) {
      final cand = th + 2 * math.pi * k;
      final lo = math.min(cur, cand);
      final hi = math.max(cur, cand);
      var crosses = false;
      for (var j = -2; j <= 2; j++) {
        final f = forbidden + 2 * math.pi * j;
        if (lo < f && f < hi) crosses = true;
      }
      if (!crosses &&
          (best == null || (cand - cur).abs() < (best - cur).abs())) {
        best = cand;
      }
    }
    return best ?? th;
  }

  /// Advances the springs towards [target] by [dt] at time [t] and returns
  /// the arm's pose. [osc] wobbles the wrist; [beatKick] is a downward hand
  /// beat on a stressed word.
  ArmPose step(
    GestureArm target,
    Oscillation? osc,
    double t,
    double dt, {
    double beatKick = 0,
  }) {
    if (beatKick != 0) _r.v += beatKick * 0.4;
    final env = _oscEnvelope.step(osc == null ? 0 : 1, dt);
    if (osc != null) _osc = osc;
    var wobble = Offset.zero;
    var wobbleAngle = 0.0;
    final o = _osc;
    if (o != null && env > 0.001) {
      final ph = 2 * math.pi * o.hz * t;
      wobble = Offset(o.dx * math.sin(ph) * env, o.dy * math.sin(2 * ph) * env);
      wobbleAngle = o.angle * math.pi / 180 * math.sin(ph) * env;
    }
    final targetHand = target.hand.shape.values;
    final hand = HandShape.fromValues([
      for (var i = 0; i < _fingers.length; i++)
        _fingers[i].step(targetHand[i], dt),
    ]);
    var targetAngle = target.angle * math.pi / 180;
    while (targetAngle - _angle.x > math.pi) {
      targetAngle -= 2 * math.pi;
    }
    while (targetAngle - _angle.x < -math.pi) {
      targetAngle += 2 * math.pi;
    }
    final (tr, tth) = _polar(target);
    final r = _r.step(tr, dt);
    final th = _th.step(_unwrap(tth), dt);
    final sh = _shoulder;
    final rawWrist = sh + Offset(r * math.cos(th), r * math.sin(th)) + wobble;
    // A hand raised over the shoulder lifts the shoulder with it.
    final lift = _lift.step(target.lift + shrug(sh, rawWrist), dt);
    final shoulder = Offset(sh.dx, sh.dy - lift);
    final prev = _elbowX == null ? null : Offset(_elbowX!.x, _elbowY!.x);
    final solved = solveArm(shoulder, rawWrist, side, previous: prev);
    _elbowX ??= Spring(solved.elbow.dx, freq: 5, zeta: 1);
    _elbowY ??= Spring(solved.elbow.dy, freq: 5, zeta: 1);
    final chased = Offset(
      _elbowX!.step(solved.elbow.dx, dt),
      _elbowY!.step(solved.elbow.dy, dt),
    );
    return ArmPose(
      wrist: solved.wrist,
      handAngle: _angle.step(targetAngle, dt) + wobbleAngle,
      hand: hand,
      lift: lift,
      elbow: fitElbow(shoulder, chased, solved.wrist),
    );
  }
}
