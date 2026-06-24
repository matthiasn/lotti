import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/pose.dart';
import 'package:lotti/features/character/model/rig_spec.dart';

/// Forward kinematics: turns a [RigSpec] + a [Pose] into a world [Affine2D] for
/// every bone. Pure Dart and allocation-light — the math hot path the plan
/// requires to be trivial on low-end devices.
class SkeletonSolver {
  SkeletonSolver(this.rig);

  final RigSpec rig;

  /// Computes the world transform of each bone, keyed by bone id.
  ///
  /// [base] places the character in the world (locomotion + canvas position);
  /// it defaults to the identity. The root pose offset ([Pose.rootDx] etc.) is
  /// applied on top of [base] so body bob and lean move the whole skeleton.
  Map<String, Affine2D> solve(Pose pose, {Affine2D base = Affine2D.identity}) {
    final world = <String, Affine2D>{};
    final rootBase = base
        .multiply(Affine2D.translation(pose.rootDx, pose.rootDy))
        .multiply(Affine2D.rotation(pose.rootRotation));

    for (final bone in rig.topoOrder) {
      final jp = pose.jointOf(bone.id);
      final local = Affine2D.trs(
        pivotX: bone.pivotX,
        pivotY: bone.pivotY,
        rotation: bone.restRotation + jp.rotation,
        scaleX: bone.restScaleX * jp.scaleX,
        scaleY: bone.restScaleY * jp.scaleY,
      );
      final parentId = bone.parent;
      final parentWorld = parentId == null ? rootBase : world[parentId]!;
      world[bone.id] = parentWorld.multiply(local);
    }
    return world;
  }

  /// Convenience: the world-space position of a bone's pivot (its joint).
  /// Handy for tests (assert the hand lands where the math says) and for the
  /// gap-detection gauntlet later.
  ({double x, double y}) jointWorldPosition(
    Map<String, Affine2D> world,
    String boneId,
  ) {
    final w = world[boneId]!;
    return w.origin;
  }

  /// The world-space position of a point [localX], [localY] expressed in a
  /// bone's local space.
  ({double x, double y}) localToWorld(
    Map<String, Affine2D> world,
    String boneId,
    double localX,
    double localY,
  ) => world[boneId]!.transformPoint(localX, localY);

  /// Returns the bone that owns a given [BoneDrawable] reference identity,
  /// kept for symmetry with the painter; unused drawables are tolerated.
  Bone? boneFor(String id) => rig.bone(id);
}
