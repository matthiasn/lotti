/// The animated local transform for one bone at an instant.
///
/// [rotation] is added to the bone's rest rotation; [scaleX]/[scaleY] multiply
/// the bone's rest scale (so 1,1 is "no change"). Squash/stretch lives here.
class JointPose {
  const JointPose({
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  static const JointPose identity = JointPose();

  final double rotation;
  final double scaleX;
  final double scaleY;
}

/// A full evaluated pose: per-bone animated transforms plus root-level motion.
///
/// [rootDx]/[rootDy] are body offsets (e.g. the vertical bob of a walk),
/// applied at the root before forward kinematics. World-space locomotion
/// (moving across the screen) is handled by the caller, not stored here.
class Pose {
  const Pose({
    required this.joints,
    this.rootDx = 0,
    this.rootDy = 0,
    this.rootRotation = 0,
  });

  final Map<String, JointPose> joints;
  final double rootDx;
  final double rootDy;
  final double rootRotation;

  /// Returns the [JointPose] for [boneId], or [JointPose.identity] when the
  /// clip does not animate that bone (it holds its rest pose).
  JointPose jointOf(String boneId) => joints[boneId] ?? JointPose.identity;
}
