import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:vector_math/vector_math.dart';

/// Analytic two-bone IK in world space, including lateral movement on turns.
/// Each rotation maps the authored rest vector onto the solved limb vector;
/// the ankle cancels its parents so the planted sole keeps its ground pose.
class CharacterLimb {
  CharacterLimb(this.hip, this.knee, this.ankle)
    : upper = knee.position.clone(),
      lower = ankle.position.clone();

  final Node hip;
  final Node knee;
  final Node ankle;
  final Vector3 upper;
  final Vector3 lower;

  static Quaternion _rotation(Node node) {
    final rotation = Quaternion.identity();
    node.globalTransform.decompose(Vector3.zero(), rotation, Vector3.zero());
    return rotation;
  }

  /// Unlike fromTwoVectors, retain small rotations: snapping even a degree
  /// at a knee makes a planted foot visibly skid.
  static Quaternion _align(Vector3 from, Vector3 to) {
    final a = from.normalized();
    final b = to.normalized();
    final cross = a.cross(b);
    return Quaternion(cross.x, cross.y, cross.z, 1 + a.dot(b))..normalize();
  }

  void solve(
    CharacterFootPose foot, {
    required Vector3 forward,
    required double scale,
  }) {
    final origin = hip.globalTransform.getTranslation();
    final target = Vector3(foot.x, foot.y, foot.z);
    final delta = target - origin;
    final a = upper.length * scale;
    final b = lower.length * scale;
    final distance = delta.length.clamp((a - b).abs() + 1e-6, a + b - 1e-6);
    final direction = delta.normalized();
    final bend = (forward - direction * forward.dot(direction)).normalized();
    final along = (a * a - b * b + distance * distance) / (2 * distance);
    final rise = math.sqrt(math.max(0, a * a - along * along));
    final wantedKnee = origin + direction * along + bend * rise;
    final parentRotation = _rotation(hip.parent!);
    // vector_math's Quaternion.rotated applies q^-1 * v * q: this converts
    // world vectors into the parent's local frame without conjugating q.
    final localUpper = parentRotation.rotated(wantedKnee - origin);
    hip.rotation = _align(upper, localUpper);
    final kneeOrigin = knee.globalTransform.getTranslation();
    final localLower = _rotation(hip).rotated(target - kneeOrigin);
    knee.rotation = _align(lower, localLower);
    final desired =
        Quaternion.axisAngle(Vector3(0, 1, 0), foot.yaw) *
        Quaternion.axisAngle(Vector3(1, 0, 0), foot.pitch);
    ankle.rotation = _rotation(knee).conjugated() * desired;
  }
}
