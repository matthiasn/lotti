import 'dart:math' as math;

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

  /// Builds the foot-lock travel curve. Per step it advances by the planted
  /// foot's leg-sweep delta (`foot.x - root.x`; root carries the COM sway, so
  /// subtracting it keeps the sway while the foot pins). The raw curve tracks the
  /// foot EXACTLY but its velocity is non-constant (fast at toe-off, slow at each
  /// contact) — pinning the foot perfectly makes the BODY lurch twice per cycle.
  /// So the per-step velocity is **low-pass smoothed** (periodically): the body
  /// travels smoothly while the foot still pins to within the smoothing residual
  /// (a few px). The total per-cycle advance is preserved (smoothing conserves
  /// the sum), so the loop stays seamless.
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

    // 1. Raw per-step travel velocity (delta[i] = advance from i/n to (i+1)/n).
    final delta = List<double>.filled(n, 0);
    var prevFoot = footAt(0);
    var prevSweep = legSweep(prevFoot, 0);
    for (var i = 0; i < n; i++) {
      final p = (i + 1) / n;
      final foot = footAt(p >= 1 ? 0.999999 : p);
      if (foot == prevFoot) {
        delta[i] = legSweep(foot, p) - prevSweep;
        prevSweep += delta[i];
      } else {
        // Handoff: continue position; start tracking the new (just-planted) foot.
        prevFoot = foot;
        prevSweep = legSweep(foot, p);
      }
    }
    // 2. Periodic low-pass on the velocity — this is what turns the per-contact
    //    lurch into a smooth travel. The owner prefers smooth over pixel-pinned,
    //    so the window is generous.
    final smooth = _smoothPeriodic(delta, window: 46, passes: 3);
    // 3. Re-integrate into the cumulative offset table.
    final samples = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      samples[i + 1] = samples[i] + smooth[i];
    }
    return _LocoTable(samples, samples[n]);
  }

  /// Box-filter low-pass over a periodic (wrapping) signal, applied [passes]
  /// times. Conserves the sum (so the integrated travel keeps its total stride).
  static List<double> _smoothPeriodic(
    List<double> v, {
    required int window,
    int passes = 1,
  }) {
    final n = v.length;
    var cur = v;
    for (var pass = 0; pass < passes; pass++) {
      final next = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        var sum = 0.0;
        for (var k = -window; k <= window; k++) {
          sum += cur[((i + k) % n + n) % n];
        }
        next[i] = sum / (2 * window + 1);
      }
      cur = next;
    }
    return cur;
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
    final breathed = Pose(
      joints: pose.joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy + auto.breath * 1.4,
      rootRotation: pose.rootRotation,
    );
    final posed = _contactLockedPose(clip, timeSeconds, breathed);

    final rawWorld = solver.solve(posed, base: base);
    final massShiftedWorld = _danceSupportMassShiftedWorld(
      clip,
      timeSeconds,
      rawWorld,
    );
    final footStabilizedWorld = _danceSupportFootStabilizedWorld(
      clip,
      timeSeconds,
      massShiftedWorld,
    );
    final world = _headStabilizedWorld(
      clip,
      footStabilizedWorld,
      rootDy: posed.rootDy,
    );
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

  /// The dance phrase deliberately puts micro-motion into the torso/hips, but
  /// because the Phase-1 rig is a pure parented skeleton, that bounce otherwise
  /// drags the whole head around like a rubber mask. Counter-translate the head
  /// subtree a little in screen space so the body can groove underneath a more
  /// controlled skull/neck.
  Map<String, Affine2D> _headStabilizedWorld(
    Clip clip,
    Map<String, Affine2D> world, {
    required double rootDy,
  }) {
    final headId = rig.face?.anchorBoneId;
    if (headId == null) return world;
    if (clip.name != 'dance' || !world.containsKey(headId)) return world;

    final headWorld = world[headId]!;
    final headRotation = _worldRotation(headWorld);
    final rotationCorrection = -headRotation * 0.84;
    final worldScale = math.sqrt(
      headWorld.a * headWorld.a + headWorld.b * headWorld.b,
    );
    final verticalCorrection = (-rootDy * worldScale * 0.34).clamp(-2.4, 2.4);
    if (rotationCorrection.abs() < 0.001 && verticalCorrection.abs() < 0.05) {
      return world;
    }

    final anchor = headWorld.origin;
    final stabilizeHead = Affine2D.translation(0, verticalCorrection).multiply(
      Affine2D.translation(anchor.x, anchor.y)
          .multiply(Affine2D.rotation(rotationCorrection))
          .multiply(Affine2D.translation(-anchor.x, -anchor.y)),
    );
    final shifted = Map<String, Affine2D>.of(world);
    for (final bone in rig.bones) {
      if (bone.id == headId || _hasAncestor(bone.id, headId)) {
        shifted[bone.id] = stabilizeHead.multiply(world[bone.id]!);
      }
    }
    return shifted;
  }

  double _worldRotation(Affine2D transform) =>
      math.atan2(transform.b, transform.a);

  /// The contact-lock pins the support point, but the shoe can still rotate
  /// through the planted frames as the leg keys keep moving. That reads as
  /// sliding on a deck. During the stable middle of a dance contact, keep the
  /// support foot's world orientation close to its contact-frame orientation,
  /// rotating only the foot subtree around the already-planted contact point.
  Map<String, Affine2D> _danceSupportFootStabilizedWorld(
    Clip clip,
    double timeSeconds,
    Map<String, Affine2D> world,
  ) {
    if (clip.name != 'dance') return world;
    final contact = _activeContactAt(clip, _clipPhase(clip, timeSeconds));
    if (contact == null) return world;
    final boneId = contact.span.bone;
    final current = world[boneId];
    final contactPoint = _contactPoint(world, boneId);
    if (current == null || contactPoint == null) return world;

    final anchorPose = evaluator.evaluate(
      clip,
      contact.anchorPhase * clip.duration,
    );
    final anchorWorld = solver.solve(anchorPose);
    final anchor = anchorWorld[boneId];
    if (anchor == null) return world;

    final strength = _contactLockStrength(
      clip,
      contact.span,
      contact.strengthPhase,
    ).x;
    if (strength < 0.05) return world;

    final delta = _shortestAngle(
      _worldRotation(anchor) - _worldRotation(current),
    );
    if (delta.abs() < 0.01) return world;

    final correction = Affine2D.translation(contactPoint.x, contactPoint.y)
        .multiply(Affine2D.rotation(delta * strength))
        .multiply(Affine2D.translation(-contactPoint.x, -contactPoint.y));
    final shifted = Map<String, Affine2D>.of(world);
    for (final bone in rig.bones) {
      if (bone.id == boneId || _hasAncestor(bone.id, boneId)) {
        shifted[bone.id] = correction.multiply(world[bone.id]!);
      }
    }
    return shifted;
  }

  double _shortestAngle(double radians) =>
      math.atan2(math.sin(radians), math.cos(radians));

  /// The dance contacts lock the feet, but the Phase-1 skeleton can still read
  /// floaty when the torso mass stays centered between both feet during a side
  /// transfer. Shift only the upper-body subtree a small, clamped amount toward
  /// the active support foot: legs/feet remain planted, while the visible COM
  /// agrees more clearly with the support.
  Map<String, Affine2D> _danceSupportMassShiftedWorld(
    Clip clip,
    double timeSeconds,
    Map<String, Affine2D> world,
  ) {
    if (clip.name != 'dance') return world;
    const torsoId = 'torso';
    if (!world.containsKey(torsoId)) return world;
    final contact = _activeContactAt(clip, _clipPhase(clip, timeSeconds));
    if (contact == null) return world;
    final hips = world[rig.bones.firstWhere((b) => b.parent == null).id];
    final support = _contactPoint(world, contact.span.bone);
    if (hips == null || support == null) return world;

    final dx = ((support.x - hips.origin.x) * 0.26).clamp(-18.0, 18.0);
    if (dx.abs() < 0.5) return world;

    final shift = Affine2D.translation(dx, 0);
    final shifted = Map<String, Affine2D>.of(world);
    for (final bone in rig.bones) {
      if (bone.id == torsoId || _hasAncestor(bone.id, torsoId)) {
        shifted[bone.id] = shift.multiply(world[bone.id]!);
      }
    }
    return shifted;
  }

  bool _hasAncestor(String boneId, String ancestorId) {
    var parent = rig.bone(boneId)?.parent;
    while (parent != null) {
      if (parent == ancestorId) return true;
      parent = rig.bone(parent)?.parent;
    }
    return false;
  }

  /// In-place performance clips do not locomote, but their support foot still
  /// needs to feel planted. [Clip.contactSpans] marks that support foot; this
  /// pass translates the root toward the contact-start anchor. Loops use a
  /// weaker correction than one-shots so dance contacts gain weight without
  /// snapping at support handoffs.
  Pose _contactLockedPose(Clip clip, double timeSeconds, Pose pose) {
    final p = _clipPhase(clip, timeSeconds);
    final contact = _activeContactAt(clip, p);
    if (contact == null) return pose;

    final span = contact.span;
    final anchorPose = evaluator.evaluate(
      clip,
      contact.anchorPhase * clip.duration,
    );
    final currentWorld = solver.solve(pose);
    final anchorWorld = solver.solve(anchorPose);
    final current = _contactPoint(currentWorld, span.bone);
    final anchor = _contactPoint(anchorWorld, span.bone);
    if (current == null || anchor == null) return pose;
    final strength = _contactLockStrength(clip, span, contact.strengthPhase);

    return Pose(
      joints: pose.joints,
      rootDx: pose.rootDx + (anchor.x - current.x) * strength.x,
      rootDy: pose.rootDy + (anchor.y - current.y) * strength.y,
      rootRotation: pose.rootRotation,
    );
  }

  double _clipPhase(Clip clip, double timeSeconds) {
    if (clip.duration <= 0) return 0;
    final raw = timeSeconds / clip.duration;
    return clip.loop ? raw - raw.floorToDouble() : raw.clamp(0.0, 1.0);
  }

  ({GroundSpan span, double anchorPhase, double strengthPhase})?
  _activeContactAt(Clip clip, double p) {
    if (clip.contactSpans.isEmpty) return null;
    final first = clip.contactSpans.first;
    final last = clip.contactSpans.last;
    if (clip.loop && first.bone == last.bone) {
      if (p >= last.start) {
        return (
          span: GroundSpan(last.bone, last.start, first.end + 1),
          anchorPhase: last.start,
          strengthPhase: p,
        );
      }
      if (p < first.end) {
        return (
          span: GroundSpan(first.bone, last.start, first.end + 1),
          anchorPhase: last.start,
          strengthPhase: p + 1,
        );
      }
    }
    for (final span in clip.contactSpans) {
      if (p >= span.start && p < span.end) {
        return (span: span, anchorPhase: span.start, strengthPhase: p);
      }
    }
    return (span: last, anchorPhase: last.start, strengthPhase: p);
  }

  ({double x, double y}) _contactLockStrength(
    Clip clip,
    GroundSpan span,
    double p,
  ) {
    final dance = clip.name == 'dance';
    final baseX = dance ? 0.985 : (clip.loop ? 0.8 : 0.94);
    final baseY = dance ? 1.0 : (clip.loop ? 0.8 : 0.94);
    final spanLength = span.end - span.start;
    final fade = dance
        ? (spanLength * 0.12).clamp(0.018, 0.028)
        : (clip.loop ? (spanLength * 0.2).clamp(0.018, 0.035) : 0.08);
    final fadeIn = _smoothUnit((p - span.start) / fade);
    final fadeOut = _smoothUnit((span.end - p) / fade);
    final edge = fadeIn < fadeOut ? fadeIn : fadeOut;
    return (x: baseX * edge, y: baseY * edge);
  }

  double _smoothUnit(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  ({double x, double y})? _contactPoint(
    Map<String, Affine2D> world,
    String boneId,
  ) {
    final transform = world[boneId];
    final drawable = rig.bone(boneId)?.drawable;
    if (transform == null || drawable == null) return null;
    return transform.transformPoint(
      drawable.dx,
      drawable.dy + drawable.height / 2,
    );
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
