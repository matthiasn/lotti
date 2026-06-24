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

  /// Resolves the frame for [clip] at [timeSeconds]. [expression] sets the base
  /// emotion (blink/eye-darts are layered on top); [base] places the character
  /// in the target canvas.
  CharacterFrame frameAt({
    required Clip clip,
    required double timeSeconds,
    Expression expression = Expression.neutral,
    Affine2D base = Affine2D.identity,
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
    final face = faceSolver.applyAutonomic(expression.state, auto);
    final locomotion = evaluator.locomotionOffset(clip, timeSeconds);
    return CharacterFrame(world: world, face: face, locomotionX: locomotion);
  }
}
