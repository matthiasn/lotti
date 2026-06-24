import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/pose.dart';

/// Samples a [Clip] at a wall-clock time into a [Pose]. Stateless and
/// deterministic: the same `(clip, time)` always yields the same pose, which is
/// what makes the film-strip render reproducible and the engine unit-testable.
class ClipEvaluator {
  const ClipEvaluator();

  /// The normalized cycle phase (0..1) of [clip] at [timeSeconds]. Looping
  /// clips wrap; one-shots clamp at their end.
  double phaseAt(Clip clip, double timeSeconds) {
    if (clip.duration <= 0) return 0;
    final raw = timeSeconds / clip.duration;
    if (clip.loop) {
      final wrapped = raw - raw.floorToDouble();
      // Guard against -0.0 for negative times.
      return wrapped < 0 ? wrapped + 1 : wrapped;
    }
    return raw.clamp(0.0, 1.0);
  }

  /// Evaluates [clip] at [timeSeconds] into a full [Pose].
  Pose evaluate(Clip clip, double timeSeconds) {
    final p = phaseAt(clip, timeSeconds);
    final joints = <String, JointPose>{};
    clip.channels.forEach((boneId, channel) {
      joints[boneId] = channel.sample(p);
    });
    final root = clip.root.sample(p);
    return Pose(
      joints: joints,
      rootDx: root.dx,
      rootDy: root.dy,
      rootRotation: root.rotation,
    );
  }

  /// The world-space horizontal distance travelled by [clip]'s locomotion at
  /// [timeSeconds]. Kept separate from the [Pose] so locomotion composes with
  /// any in-place cycle (the plan's D7).
  double locomotionOffset(Clip clip, double timeSeconds) {
    // One-shots freeze at their end (like [phaseAt]); only looping clips keep
    // travelling. Without this a finite clip with locomotion would drift forever
    // after its pose has stopped.
    final effectiveTime = clip.loop
        ? timeSeconds
        : timeSeconds.clamp(0.0, clip.duration);
    return clip.locomotionSpeed * effectiveTime;
  }
}
