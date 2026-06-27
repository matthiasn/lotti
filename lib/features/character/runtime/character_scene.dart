import 'dart:math' as math;

import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/engine/clip_evaluator.dart';
import 'package:lotti/features/character/engine/face_solver.dart';
import 'package:lotti/features/character/engine/skeleton_solver.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
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
    final targeted = _limbTargetedPose(clip, timeSeconds, breathed);
    final posed = _contactLockedPose(clip, timeSeconds, targeted);

    final rawWorld = solver.solve(posed, base: base);
    final footStabilizedWorld = _danceSupportFootStabilizedWorld(
      clip,
      timeSeconds,
      rawWorld,
    );
    final world = _rigidHeadWorld(
      clip,
      footStabilizedWorld,
      timeSeconds: timeSeconds,
      baseScale: _uniformScale(base),
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

  Pose _limbTargetedPose(Clip clip, double timeSeconds, Pose pose) {
    if (clip.limbTargets.isEmpty) return pose;

    final phase = evaluator.phaseAt(clip, timeSeconds);
    final joints = Map<String, JointPose>.of(pose.joints);
    var currentPose = pose;

    for (final target in clip.limbTargets) {
      final sample = target.channel.sample(phase);
      final weight = sample.weight.clamp(0.0, 1.0);
      if (weight <= 0) continue;

      final solved = _solveLimbTarget(
        target,
        sample,
        currentPose,
        weight,
      );
      if (solved == null) continue;

      joints[target.upperBoneId] = solved.upper;
      joints[target.lowerBoneId] = solved.lower;
      currentPose = Pose(
        joints: joints,
        rootDx: pose.rootDx,
        rootDy: pose.rootDy,
        rootRotation: pose.rootRotation,
      );
    }

    return currentPose;
  }

  ({JointPose upper, JointPose lower})? _solveLimbTarget(
    LimbIkTarget target,
    IkTargetPose sample,
    Pose pose,
    double weight,
  ) {
    final upper = rig.bone(target.upperBoneId);
    final lower = rig.bone(target.lowerBoneId);
    final end = rig.bone(target.endBoneId);
    final anchor = rig.bone(target.anchorBoneId);
    if (upper == null || lower == null || end == null || anchor == null) {
      return null;
    }
    if (lower.parent != upper.id || end.parent != lower.id) return null;

    final world = solver.solve(pose);
    final upperWorld = world[upper.id];
    final lowerWorld = world[lower.id];
    final endWorld = world[end.id];
    final anchorWorld = world[anchor.id];
    if (upperWorld == null ||
        lowerWorld == null ||
        endWorld == null ||
        anchorWorld == null) {
      return null;
    }

    final shoulder = upperWorld.origin;
    final elbow = lowerWorld.origin;
    final wrist = endWorld.origin;
    final targetPoint = anchorWorld.transformPoint(sample.x, sample.y);
    final upperLength = _pointDistance(shoulder, elbow);
    final lowerLength = _pointDistance(elbow, wrist);
    if (upperLength <= 0 || lowerLength <= 0) return null;

    final toTargetX = targetPoint.x - shoulder.x;
    final toTargetY = targetPoint.y - shoulder.y;
    final targetDistance = math.sqrt(
      toTargetX * toTargetX + toTargetY * toTargetY,
    );
    if (targetDistance <= 1e-6) return null;

    final minReach = (upperLength - lowerLength).abs() + 1e-6;
    final maxReach = upperLength + lowerLength - 1e-6;
    final solvedDistance = targetDistance.clamp(minReach, maxReach);
    final targetAngle = math.atan2(toTargetY, toTargetX);
    final shoulderCos =
        (upperLength * upperLength +
            solvedDistance * solvedDistance -
            lowerLength * lowerLength) /
        (2 * upperLength * solvedDistance);
    final shoulderOffset = math.acos(shoulderCos.clamp(-1.0, 1.0));
    final upperSegmentAngle =
        targetAngle + target.bendDirection * shoulderOffset;
    final solvedElbow = (
      x: shoulder.x + math.cos(upperSegmentAngle) * upperLength,
      y: shoulder.y + math.sin(upperSegmentAngle) * upperLength,
    );
    final lowerSegmentAngle = math.atan2(
      targetPoint.y - solvedElbow.y,
      targetPoint.x - solvedElbow.x,
    );

    final parentRotation = _parentWorldRotation(world, upper, pose);
    final upperTargetRotation =
        upperSegmentAngle -
        parentRotation -
        upper.restRotation -
        _localPivotAngle(lower);
    final upperTransformRotation =
        parentRotation + upper.restRotation + upperTargetRotation;
    final lowerTargetRotation =
        lowerSegmentAngle -
        upperTransformRotation -
        lower.restRotation -
        _localPivotAngle(end);
    final currentUpper = pose.jointOf(upper.id);
    final currentLower = pose.jointOf(lower.id);

    return (
      upper: JointPose(
        rotation: _lerpAngle(
          currentUpper.rotation,
          upperTargetRotation,
          weight,
        ),
        scaleX: currentUpper.scaleX,
        scaleY: currentUpper.scaleY,
      ),
      lower: JointPose(
        rotation: _lerpAngle(
          currentLower.rotation,
          lowerTargetRotation,
          weight,
        ),
        scaleX: currentLower.scaleX,
        scaleY: currentLower.scaleY,
      ),
    );
  }

  double _parentWorldRotation(
    Map<String, Affine2D> world,
    Bone bone,
    Pose pose,
  ) {
    final parentId = bone.parent;
    if (parentId == null) return pose.rootRotation;
    final parentWorld = world[parentId];
    return parentWorld == null
        ? pose.rootRotation
        : _worldRotation(parentWorld);
  }

  double _localPivotAngle(Bone child) => math.atan2(child.pivotY, child.pivotX);

  double _pointDistance(({double x, double y}) a, ({double x, double y}) b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _lerpAngle(double from, double to, double weight) =>
      from + _shortestAngle(to - from) * weight;

  /// The body can squash, stretch, and groove; the skull should not. Because
  /// the Phase-1 rig is a parented skeleton, torso scale would otherwise
  /// propagate into the head/ears and make the face look rubbery. Replace the
  /// head subtree's linear transform with a rigid, uniform-scale transform while
  /// preserving the solved neck position. Dance additionally counter-rotates a
  /// little so the face stays controlled while the chest moves underneath it.
  Map<String, Affine2D> _rigidHeadWorld(
    Clip clip,
    Map<String, Affine2D> world, {
    required double timeSeconds,
    required double baseScale,
    required double rootDy,
  }) {
    final headId = rig.face?.anchorBoneId;
    if (headId == null) return world;
    if (!world.containsKey(headId)) return world;

    final headWorld = world[headId]!;
    final headRotation = _worldRotation(headWorld);
    final danceAttitude = _isDanceFamily(clip)
        ? _danceHeadAttitude(_clipPhase(clip, timeSeconds))
        : 0.0;
    final rotationCorrection = _isDanceFamily(clip)
        ? -headRotation * 0.92 + danceAttitude
        : 0.0;
    final correction = _rigidLinearCorrection(
      headWorld,
      targetRotation: headRotation + rotationCorrection,
      targetScale: baseScale,
    );
    if (correction == null) {
      return world;
    }
    final anchor = headWorld.origin;
    final stabilizeHead = Affine2D.translation(
      anchor.x,
      anchor.y,
    ).multiply(correction).multiply(Affine2D.translation(-anchor.x, -anchor.y));
    final headCounterTranslate = _isDanceFamily(clip)
        ? Affine2D.translation(
            0,
            _danceHeadVerticalCounter(rootDy) * baseScale,
          )
        : Affine2D.identity;
    final headTransform = headCounterTranslate.multiply(stabilizeHead);
    final shifted = Map<String, Affine2D>.of(world);
    for (final bone in rig.bones) {
      if (bone.id == headId || _hasAncestor(bone.id, headId)) {
        shifted[bone.id] = headTransform.multiply(world[bone.id]!);
      }
    }
    return shifted;
  }

  double _danceHeadVerticalCounter(double rootDy) {
    // The dance phrase now gets its level change from knees/hips/torso.
    // Counter only part of the root bob so the skull reads rigid without
    // visually detaching from the neck.
    const neutralDanceRootDy = 17.4;
    return -(rootDy - neutralDanceRootDy) * 0.32;
  }

  double _danceHeadAttitude(double p) {
    double pulse(double centre, double width) {
      final distance = _cyclicDistance(p, centre);
      if (distance >= width) return 0;
      final t = 1 - distance / width;
      return t * t * (3 - 2 * t);
    }

    // Small, deliberate accents only: enough for the head to answer the body,
    // not enough to return to the rubber bobble that the rigid pass removed.
    return -0.018 * pulse(1 / 8, 1 / 18) +
        0.018 * pulse(3 / 8, 1 / 18) -
        0.016 * pulse(5 / 8, 1 / 18) +
        0.022 * pulse(15 / 16, 1 / 16);
  }

  double _cyclicDistance(double a, double b) {
    final d = (a - b).abs();
    return math.min(d, 1 - d);
  }

  static double _uniformScale(Affine2D transform) =>
      math.sqrt(transform.a * transform.a + transform.b * transform.b);

  Affine2D? _rigidLinearCorrection(
    Affine2D current, {
    required double targetRotation,
    required double targetScale,
  }) {
    final det = current.a * current.d - current.b * current.c;
    if (det.abs() < 1e-9 || targetScale <= 0) return null;
    final handedness = det < 0 ? -1.0 : 1.0;
    final cos = math.cos(targetRotation);
    final sin = math.sin(targetRotation);
    final desired = Affine2D(
      cos * targetScale,
      sin * targetScale,
      -sin * targetScale * handedness,
      cos * targetScale * handedness,
      0,
      0,
    );
    final inv = Affine2D(
      current.d / det,
      -current.b / det,
      -current.c / det,
      current.a / det,
      0,
      0,
    );
    final correction = desired.multiply(inv);
    if ((correction.a - 1).abs() < 0.001 &&
        correction.b.abs() < 0.001 &&
        correction.c.abs() < 0.001 &&
        (correction.d - 1).abs() < 0.001) {
      return null;
    }
    return correction;
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
    if (!_isDanceFamily(clip)) return world;
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

    final contactStrength = _contactLockStrength(
      clip,
      contact.span,
      contact.strengthPhase,
    ).x;
    final strength = _isDanceFamily(clip)
        ? math.min(1, contactStrength * 1.35)
        : contactStrength;
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
    final dance = _isDanceFamily(clip);
    final baseX = dance ? 0.55 : (clip.loop ? 0.8 : 0.94);
    final baseY = dance ? 0.94 : (clip.loop ? 0.8 : 0.94);
    final spanLength = span.end - span.start;
    final fade = dance
        ? (spanLength * 0.24).clamp(0.044, 0.058)
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

  bool _isDanceFamily(Clip clip) =>
      clip.name == 'dance' || clip.name.startsWith('danceBackup');

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
