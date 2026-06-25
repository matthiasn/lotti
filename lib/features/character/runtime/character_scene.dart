import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/engine/clip_evaluator.dart';
import 'package:lotti/features/character/engine/face_solver.dart';
import 'package:lotti/features/character/engine/skeleton_solver.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/pose.dart';
import 'package:lotti/features/character/model/rig_spec.dart';

/// One fully-resolved frame: world transforms for every bone, the face state to
/// draw, and how far the character has travelled (locomotion). Everything the
/// renderer needs and nothing it doesn't.
class CharacterFrame {
  const CharacterFrame({
    required this.world,
    required this.face,
    required this.locomotionX,
  });

  final Map<String, Affine2D> world;
  final FaceState face;

  /// How far the character has travelled along x for this clip+time, in local
  /// units. Phase 1 deliberately animates in place (each film-strip cell is a
  /// phase sample, and the live widget loops on the spot), so **no caller wires
  /// this yet** — it is the kinematic hook the Phase-2 "walks across the screen"
  /// surface will fold into its placement transform.
  final double locomotionX;
}

/// Ties the engine pieces together: evaluate a clip, layer the autonomic
/// "alive" signals, run forward kinematics, resolve the face. Deterministic in
/// time, so a film strip and the live widget produce identical frames.
class CharacterScene {
  CharacterScene(this.rig, {AutonomicLayer? autonomic})
    : solver = SkeletonSolver(rig),
      autonomic = autonomic ?? AutonomicLayer();

  final RigSpec rig;
  final SkeletonSolver solver;
  final ClipEvaluator evaluator = const ClipEvaluator();
  final FaceSolver faceSolver = const FaceSolver();
  final AutonomicLayer autonomic;

  /// Memoized foot-lock offset tables, keyed by clip name (built once per clip).
  final Map<String, _LocoTable> _locoTables = {};

  /// The clip's world-space horizontal travel at [timeSeconds]. For clips with
  /// [Clip.groundSpans] this is **foot-locked**: travel is the negative of the
  /// planted foot's leg-sweep, so the planted foot holds world position (no
  /// skate) and the COM sway still reads. Clips without spans fall back to the
  /// evaluator's constant-speed travel. Deterministic (the table is a pure
  /// function of the rig + clip), so film-strip renders stay reproducible.
  double locomotionOffset(Clip clip, double timeSeconds) {
    if (clip.groundSpans.isEmpty) {
      return evaluator.locomotionOffset(clip, timeSeconds);
    }
    final table = _locoTables.putIfAbsent(
      clip.name,
      () => _buildLocoTable(clip),
    );
    if (clip.duration <= 0) return 0;
    final phase = timeSeconds / clip.duration;
    final cycles = phase.floorToDouble();
    final frac = phase - cycles; // 0..1, handles negative time too
    return cycles * table.cycleAdvance + table.sample(frac);
  }

  /// Samples the planted-foot leg-sweep across the cycle and integrates it into a
  /// monotonic travel curve that pins each foot during its [GroundSpan]. The
  /// leg-sweep is `foot.x - root.x` (the root carries the COM sway, so
  /// subtracting it leaves the pure leg contribution — the body keeps swaying
  /// while the foot stays put to within that small sway).
  _LocoTable _buildLocoTable(Clip clip) {
    const n = 240;
    final rootId = rig.bones.firstWhere((b) => b.parent == null).id;

    double legSweep(String foot, double p) {
      final world = solver.solve(evaluator.evaluate(clip, p * clip.duration));
      return world[foot]!.transformPoint(0, 0).x -
          world[rootId]!.transformPoint(0, 0).x;
    }

    String footAt(double p) {
      for (final s in clip.groundSpans) {
        if (p >= s.start && p < s.end) return s.bone;
      }
      return clip.groundSpans.last.bone;
    }

    final samples = List<double>.filled(n + 1, 0);
    var offset = 0.0;
    var prevFoot = footAt(0);
    var prevSweep = legSweep(prevFoot, 0);
    for (var i = 1; i <= n; i++) {
      final p = i / n;
      final foot = footAt(p >= 1 ? 0.999999 : p);
      if (foot == prevFoot) {
        final sweep = legSweep(foot, p);
        // The painter MIRRORS the rig while travelling, so the body advances as
        // the planted foot's body-x increases (it sweeps from front to back of
        // the body); travel tracks +legSweep so that foot holds screen-x.
        final next = offset + (sweep - prevSweep);
        // Clamp monotonic: never travel backward (a brief foot reversal at
        // heel-strike/toe-off must not moonwalk the whole body).
        offset = next > offset ? next : offset;
        prevSweep = sweep;
      } else {
        // Handoff: the new foot just planted — continue the offset unchanged and
        // start tracking the new foot from here.
        prevFoot = foot;
        prevSweep = legSweep(foot, p);
      }
      samples[i] = offset;
    }
    return _LocoTable(samples, offset);
  }

  /// Distance (in local units) from the rig origin down to the lowest drawn
  /// pixel of the **rest** pose — i.e. how far the feet sit below the hips.
  /// Used to ground the character so the feet land on the floor instead of the
  /// origin (which would push the legs off the bottom of the canvas).
  late final double restFeetOffset = lowestDrawnY(
    solver.solve(const Pose(joints: {})),
  );

  /// The lowest drawn world-Y across all parts for a solved [world] — a proxy
  /// for where the feet currently are. Drives both rest grounding and the live
  /// contact shadow (which shrinks/fades as the feet lift off the floor).
  double lowestDrawnY(Map<String, Affine2D> world) {
    var maxY = double.negativeInfinity;
    for (final bone in rig.bones) {
      final d = bone.drawable;
      if (d == null) continue;
      // Bottom-centre of the drawable, in the bone's local space, mapped to
      // world. A good proxy for the lowest painted pixel of that part.
      final p = world[bone.id]!.transformPoint(d.dx, d.dy + d.height / 2);
      if (p.y > maxY) maxY = p.y;
    }
    return maxY;
  }

  /// Resolves the frame for [clip] at [timeSeconds]. [expression] sets the base
  /// emotion (blink/eye-darts are layered on top); [base] places the character
  /// in the target canvas.
  ///
  /// [eyeOpenScale] further multiplies eyelid openness (1 = no change, 0 =
  /// shut). It composes with the autonomic blink and lets a caller drive a
  /// *manual* blink (the demo's blink button / keyboard) without disturbing the
  /// deterministic autonomic schedule.
  CharacterFrame frameAt({
    required Clip clip,
    required double timeSeconds,
    Expression expression = Expression.neutral,
    Affine2D base = Affine2D.identity,
    double eyeOpenScale = 1,
  }) {
    final pose = evaluator.evaluate(clip, timeSeconds);
    final auto = autonomic.sampleAt(timeSeconds);

    // Breathing nudges the whole body subtly, even mid-walk.
    final posed = Pose(
      joints: pose.joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy + auto.breath * 1.4,
      rootRotation: pose.rootRotation,
    );

    final world = solver.solve(posed, base: base);
    var face = faceSolver.applyAutonomic(expression.state, auto);
    if (eyeOpenScale != 1) {
      face = face.copyWith(
        eyeOpenLeft: face.eyeOpenLeft * eyeOpenScale,
        eyeOpenRight: face.eyeOpenRight * eyeOpenScale,
      );
    }
    final locomotion = locomotionOffset(clip, timeSeconds);
    return CharacterFrame(world: world, face: face, locomotionX: locomotion);
  }
}

/// A precomputed foot-lock travel curve: [samples] are the cumulative offset at
/// evenly spaced phases `i/(len-1)` across one cycle, [cycleAdvance] the total
/// per-cycle stride. Linear interpolation between samples.
class _LocoTable {
  _LocoTable(this.samples, this.cycleAdvance);

  final List<double> samples;
  final double cycleAdvance;

  double sample(double frac) {
    final n = samples.length - 1;
    final x = frac.clamp(0.0, 1.0) * n;
    final i = x.floor().clamp(0, n - 1);
    return samples[i] + (samples[i + 1] - samples[i]) * (x - i);
  }
}
