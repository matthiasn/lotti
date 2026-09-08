import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';

/// A camera-facing sentinel turns with alternating small hind-paw steps.
/// One hind paw always supports the body; a planted contact never slides.
class MeerkatLookout {
  double? _yaw;
  _PivotFoot? _left;
  _PivotFoot? _right;

  ({double yaw, CharacterFootPose left, CharacterFootPose right}) update({
    required MeerkatPose pose,
    required double eyeX,
    required double eyeZ,
    required double dt,
    required double scale,
  }) {
    if (pose.action == MeerkatAction.scamper ||
        pose.action == MeerkatAction.settle) {
      _yaw = null;
      _left = null;
      _right = null;
      return (yaw: pose.root.yaw, left: pose.rearLeft, right: pose.rearRight);
    }
    _yaw ??= pose.root.yaw;
    _left ??= _PivotFoot(pose.rearLeft);
    _right ??= _PivotFoot(pose.rearRight);
    final looking =
        pose.action == MeerkatAction.lookout ||
        pose.action == MeerkatAction.rise ||
        (pose.action == MeerkatAction.lower && pose.upright > 0.8);
    final target = looking
        ? math.atan2(eyeX - pose.root.x, eyeZ - pose.root.z)
        : pose.root.yaw;
    final delta = dt.clamp(0.0, 0.25);
    _yaw = _yaw! + _angle(target - _yaw!).clamp(-3 * delta, 3 * delta);
    final left = _left!;
    final right = _right!;
    left.advance(delta, scale);
    right.advance(delta, scale);
    if (delta > 0 && !left.stepping && !right.stepping) {
      final a = rotateFoot(pose.rearLeft, pose.root, _yaw! - pose.root.yaw);
      final b = rotateFoot(pose.rearRight, pose.root, _yaw! - pose.root.yaw);
      final da = left.distanceTo(a);
      final db = right.distanceTo(b);
      if (math.max(da, db) > 0.0001 * scale) {
        if (da >= db) {
          left.start(a);
        } else {
          right.start(b);
        }
      }
    }
    return (yaw: _yaw!, left: left.contact, right: right.contact);
  }

  static double _angle(double value) =>
      math.atan2(math.sin(value), math.cos(value));

  /// Rotate a lifted target around the stationary pelvis, preserving height.
  static CharacterFootPose rotateFoot(
    CharacterFootPose foot,
    CharacterPose root,
    double angle,
  ) {
    final x = foot.x - root.x;
    final z = foot.z - root.z;
    return CharacterFootPose(
      x: root.x + x * math.cos(angle) + z * math.sin(angle),
      y: foot.y,
      z: root.z - x * math.sin(angle) + z * math.cos(angle),
      yaw: foot.yaw + angle,
      pitch: foot.pitch,
      planted: foot.planted,
    );
  }
}

class _PivotFoot {
  _PivotFoot(this.contact);
  CharacterFootPose contact;
  CharacterFootPose? _from;
  CharacterFootPose? _to;
  double _time = 0;
  static const _duration = 0.16;
  bool get stepping => _to != null;

  double distanceTo(CharacterFootPose target) => math.sqrt(
    math.pow(contact.x - target.x, 2) + math.pow(contact.z - target.z, 2),
  );

  void start(CharacterFootPose target) {
    _from = contact;
    _to = target;
    _time = 0;
  }

  void advance(double dt, double scale) {
    final to = _to;
    if (to == null || dt == 0) return;
    _time += dt;
    if (_time >= _duration) {
      contact = to;
      _to = null;
      _from = null;
      return;
    }
    final from = _from!;
    final t = _time / _duration;
    final ease = t * t * t * (10 + t * (-15 + 6 * t));
    contact = CharacterFootPose(
      x: from.x + (to.x - from.x) * ease,
      y: from.y + 0.04 * scale * math.pow(math.sin(math.pi * t), 2),
      z: from.z + (to.z - from.z) * ease,
      yaw: from.yaw + MeerkatLookout._angle(to.yaw - from.yaw) * ease,
      pitch: 0,
      planted: false,
    );
  }
}
