import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';

/// One arm in the torso frame: where the wrist is, which way the hand
/// points, how it is held, the shoulder's rise, and the solved elbow.
@immutable
class ArmPose {
  const ArmPose({
    required this.wrist,
    required this.handAngle,
    this.hand = const HandShape(),
    this.lift = 0,
    this.elbow,
  });

  final Offset wrist;

  /// Radians in the torso frame; 0 points the fingers to screen-right.
  final double handAngle;
  final HandShape hand;
  final double lift;

  /// Null asks the painter to solve it.
  final Offset? elbow;
}

/// Everything the painter needs for one frame of the companion.
///
/// Character space is y-down with the origin on the floor between the feet;
/// she stands about 455 units tall. Arm targets are in the torso frame
/// (origin at the pelvis, rotated with the lean), so a gesture travels with
/// the body.
@immutable
class CompanionPose {
  const CompanionPose({
    this.pelvis = Offset.zero,
    this.lift = 0,
    this.lean = 0,
    this.breath = 0,
    this.headRoll = 0,
    this.headYaw = 0,
    this.headPitch = 0,
    this.headOffset = Offset.zero,
    this.hairLag = Offset.zero,
    this.hemLag = 0,
    this.tail = 0,
    this.earFlick = 0,
    this.left = const ArmPose(
      wrist: Offset(-28, -40),
      handAngle: 60 * math.pi / 180,
    ),
    this.right = const ArmPose(
      wrist: Offset(28, -40),
      handAngle: 120 * math.pi / 180,
    ),
    this.gaze = Offset.zero,
    this.blink = 0,
    this.wink = 0,
    this.squint = 0,
    this.browRaise = 0,
    this.browTilt = 0,
    this.browSkew = 0,
    this.smile = 0.3,
    this.smileSkew = 0,
    this.mouth = const MouthShape(),
    this.handInFrontOfFace = false,
  });

  final Offset pelvis;

  /// How far her upper body is raised above her hips, in units: a bounce of
  /// joy. Her shoulders, arms and head rise by all of it, her dress by less
  /// the lower it reaches; her hips, legs and hem stay where they stand.
  final double lift;
  final double lean;

  /// -1..1 over a breath.
  final double breath;
  final double headRoll;
  final double headYaw;
  final double headPitch;
  final Offset headOffset;

  /// How far the loose strands trail the head's motion.
  final Offset hairLag;

  /// How far the hem trails the hips' sway.
  final double hemLag;

  /// An animal's tail swing, about -1..1; the grandmother has none.
  final double tail;

  /// An animal's ear flick: the left ear for a negative value, the right for
  /// a positive one, 0 at rest and ±1 at the flick's height.
  final double earFlick;
  final ArmPose left;
  final ArmPose right;

  /// Where the eyes look, each axis in about -1..1.
  final Offset gaze;

  /// 0 open .. 1 shut.
  final double blink;

  /// Shuts one eye on top of [blink]: the right (screen right) towards 1, the
  /// left towards -1.
  final double wink;

  /// How far the eye on [side] (-1 left, +1 right) is shut: [blink], and
  /// the [wink] if it is that eye's.
  double blinkOf(int side) =>
      side * wink > 0 ? blink + (1 - blink) * wink.abs() : blink;
  final double squint;
  final double browRaise;

  /// Positive draws the inner ends of the brows up: worry; negative draws
  /// them down: sternness.
  final double browTilt;

  /// Raises the right brow (screen right) and lowers the left by as much.
  final double browSkew;

  /// About -1..1: below zero turns the mouth's corners down.
  final double smile;

  /// Lifts the right corner of the mouth and lowers the left: a smirk.
  final double smileSkew;
  final MouthShape mouth;

  /// The right hand reaches the face, so it draws over the head.
  final bool handInFrontOfFace;
}
