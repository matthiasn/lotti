import 'dart:math' as math;

import 'package:lotti/features/character/model/easing.dart';
import 'package:lotti/features/character/model/pose.dart';

/// Produces a [JointPose] for one bone given a normalized cycle phase `p`
/// in 0..1. Two flavours exist: [SineChannel] for cyclic motion (walk/run) and
/// [KeyframeChannel] for one-shots (sit/jump). New cycles are just new data —
/// no new code — which is the whole point of the data-driven design.
sealed class JointChannel {
  const JointChannel();

  JointPose sample(double p);
}

/// Cyclic joint motion as a phase-shifted sinusoid plus an optional second
/// harmonic (for the sharper snap of a knee/elbow that a pure sine can't make).
///
/// `rotation = bias + amplitude*sin(2π(p)+phase) + harmonicAmp*sin(4π(p)+...)`
class SineChannel extends JointChannel {
  const SineChannel({
    this.amplitude = 0,
    this.phase = 0,
    this.bias = 0,
    this.harmonicAmplitude = 0,
    this.harmonicPhase = 0,
    this.scaleYAmplitude = 0,
    this.scaleYPhase = 0,
    this.scaleYHarmonic = 1,
    this.scaleXAmplitude = 0,
    this.scaleXPhase = 0,
    this.scaleXHarmonic = 1,
  });

  /// Primary rotation amplitude in radians.
  final double amplitude;

  /// Phase offset in turns (0..1); shifting legs/arms apart is how a walk is
  /// built. Expressed in turns so authoring reads as "half a cycle later".
  final double phase;

  /// Static rotation offset in radians, added every frame.
  final double bias;

  final double harmonicAmplitude;
  final double harmonicPhase;

  /// Squash/stretch oscillation (multiplier delta around 1). The `*Harmonic`
  /// fields set the frequency: a walk takes weight **twice** per cycle, so a
  /// body-squash uses harmonic 2 to compress on each footfall. Pairing a
  /// negative `scaleYAmplitude` with a positive `scaleXAmplitude` (or vice
  /// versa) preserves volume — the classic squash that sells weight.
  final double scaleYAmplitude;
  final double scaleYPhase;
  final double scaleYHarmonic;

  final double scaleXAmplitude;
  final double scaleXPhase;
  final double scaleXHarmonic;

  @override
  JointPose sample(double p) {
    const twoPi = 2 * math.pi;
    final rot =
        bias +
        amplitude * math.sin(twoPi * (p + phase)) +
        harmonicAmplitude * math.sin(2 * twoPi * (p + harmonicPhase));
    final scaleY = scaleYAmplitude == 0
        ? 1.0
        : 1 +
              scaleYAmplitude *
                  math.sin(twoPi * scaleYHarmonic * (p + scaleYPhase));
    final scaleX = scaleXAmplitude == 0
        ? 1.0
        : 1 +
              scaleXAmplitude *
                  math.sin(twoPi * scaleXHarmonic * (p + scaleXPhase));
    return JointPose(rotation: rot, scaleX: scaleX, scaleY: scaleY);
  }
}

/// A single keyframe for a [KeyframeChannel].
class Keyframe {
  const Keyframe({
    required this.p,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.ease = Ease.easeInOut,
  });

  /// Phase position of the key, 0..1.
  final double p;
  final double rotation;
  final double scaleX;
  final double scaleY;

  /// Easing applied on the segment *leading into* this key.
  final Ease ease;
}

/// One-shot joint motion as eased keyframes. Keys must be sorted by [Keyframe.p]
/// and span 0..1.
///
/// [phase] shifts the sample point (0..1, wrapping) so a single authored cycle
/// can drive two limbs half a beat apart — e.g. the left and right legs share
/// one step cycle, the right at `phase: 0.5`. It is only meaningful for looping
/// clips whose first and last keys match; one-shots leave it at 0.
class KeyframeChannel extends JointChannel {
  const KeyframeChannel(this.keys, {this.phase = 0});

  final List<Keyframe> keys;
  final double phase;

  @override
  JointPose sample(double rawP) {
    final p = phase == 0
        ? rawP
        : (rawP + phase) - (rawP + phase).floorToDouble();
    if (keys.isEmpty) return JointPose.identity;
    if (p <= keys.first.p) {
      final k = keys.first;
      return JointPose(
        rotation: k.rotation,
        scaleX: k.scaleX,
        scaleY: k.scaleY,
      );
    }
    if (p >= keys.last.p) {
      final k = keys.last;
      return JointPose(
        rotation: k.rotation,
        scaleX: k.scaleX,
        scaleY: k.scaleY,
      );
    }
    for (var i = 0; i < keys.length - 1; i++) {
      final k0 = keys[i];
      final k1 = keys[i + 1];
      if (p >= k0.p && p <= k1.p) {
        final span = k1.p - k0.p;
        final local = span == 0 ? 0.0 : (p - k0.p) / span;
        final t = k1.ease.apply(local);
        return JointPose(
          rotation: k0.rotation + (k1.rotation - k0.rotation) * t,
          scaleX: k0.scaleX + (k1.scaleX - k0.scaleX) * t,
          scaleY: k0.scaleY + (k1.scaleY - k0.scaleY) * t,
        );
      }
    }
    return JointPose.identity;
  }
}

/// Root-level body motion layered under forward kinematics: the vertical bob,
/// horizontal sway and torso lean that give a cycle its weight. Sealed so cyclic
/// ([SineRootChannel]) and one-shot ([KeyframeRootChannel]) root motion share a
/// type the evaluator can sample uniformly.
sealed class RootChannel {
  const RootChannel();

  ({double dx, double dy, double rotation}) sample(double p);
}

/// Sinusoidal root motion for cyclic clips (walk/run/idle).
class SineRootChannel extends RootChannel {
  const SineRootChannel({
    this.bobAmplitude = 0,
    this.bobPhase = 0,
    this.bobHarmonic = 2,
    this.swayAmplitude = 0,
    this.swayPhase = 0,
    this.leanAmplitude = 0,
    this.leanPhase = 0,
  });

  /// Vertical bob amplitude in local units.
  final double bobAmplitude;
  final double bobPhase;

  /// Bob frequency multiplier. A walk bobs twice per cycle (one per footfall),
  /// so this defaults to 2.
  final double bobHarmonic;

  final double swayAmplitude;
  final double swayPhase;

  final double leanAmplitude;
  final double leanPhase;

  @override
  ({double dx, double dy, double rotation}) sample(double p) {
    const twoPi = 2 * math.pi;
    return (
      dx: swayAmplitude * math.sin(twoPi * (p + swayPhase)),
      dy: bobAmplitude * math.sin(bobHarmonic * twoPi * (p + bobPhase)),
      rotation: leanAmplitude * math.sin(twoPi * (p + leanPhase)),
    );
  }
}

/// A single root keyframe for one-shot body motion (sit/jump): where the body
/// origin sits and how it leans at phase [p].
class RootKeyframe {
  const RootKeyframe({
    required this.p,
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.ease = Ease.easeInOut,
  });

  final double p;
  final double dx;
  final double dy;
  final double rotation;
  final Ease ease;
}

/// Eased keyframed root motion for one-shots. Keys must be sorted by phase.
class KeyframeRootChannel extends RootChannel {
  const KeyframeRootChannel(this.keys);

  final List<RootKeyframe> keys;

  @override
  ({double dx, double dy, double rotation}) sample(double p) {
    if (keys.isEmpty) return (dx: 0, dy: 0, rotation: 0);
    if (p <= keys.first.p) {
      final k = keys.first;
      return (dx: k.dx, dy: k.dy, rotation: k.rotation);
    }
    if (p >= keys.last.p) {
      final k = keys.last;
      return (dx: k.dx, dy: k.dy, rotation: k.rotation);
    }
    for (var i = 0; i < keys.length - 1; i++) {
      final k0 = keys[i];
      final k1 = keys[i + 1];
      if (p >= k0.p && p <= k1.p) {
        final span = k1.p - k0.p;
        final local = span == 0 ? 0.0 : (p - k0.p) / span;
        final t = k1.ease.apply(local);
        return (
          dx: k0.dx + (k1.dx - k0.dx) * t,
          dy: k0.dy + (k1.dy - k0.dy) * t,
          rotation: k0.rotation + (k1.rotation - k0.rotation) * t,
        );
      }
    }
    return (dx: 0, dy: 0, rotation: 0);
  }
}

/// A named animation: a bag of per-bone channels plus root motion, evaluated by
/// the clip evaluator. [loop] distinguishes cyclic clips (walk/run/idle) from
/// one-shots (sit/jump).
class Clip {
  const Clip({
    required this.name,
    required this.duration,
    required this.channels,
    this.loop = true,
    this.root = const SineRootChannel(),
    this.locomotionSpeed = 0,
  });

  /// Display/lookup name.
  final String name;

  /// Cycle period (loop) or total length (one-shot), in seconds.
  final double duration;

  /// Whether the clip repeats.
  final bool loop;

  /// Per-bone channels, keyed by bone id. Bones absent here hold their rest
  /// pose (channels are sparse).
  final Map<String, JointChannel> channels;

  final RootChannel root;

  /// World-space horizontal speed in local units/sec, speed-matched to the
  /// cycle to avoid foot-skate. Consumed by the caller for locomotion, not
  /// baked into the pose.
  final double locomotionSpeed;
}
