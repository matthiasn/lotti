import 'package:flutter/foundation.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';

/// Where one arm goes in a gesture, in the torso frame.
///
/// The shoulders sit at (±46, -106) with about 97 units of reach; the head's
/// centre is near (0, -168). Angles are degrees, 0 points the fingers to
/// screen-right and -90 up.
@immutable
class GestureArm {
  const GestureArm(
    this.x,
    this.y,
    this.angle, [
    this.hand = HandPose.relaxed,
    this.lift = 0,
  ]);

  final double x;
  final double y;
  final double angle;
  final HandPose hand;
  final double lift;
}

/// An additive wobble on a wrist: x and y amplitude, angle amplitude in
/// degrees, and frequency in Hz.
typedef Oscillation = ({double dx, double dy, double angle, double hz});

/// A gesture: arm targets plus the face and body attitude that go with it.
///
/// A null arm stays at [CompanionGesture.readyLeft] or
/// [CompanionGesture.readyRight]. [then] lists later phases by the seconds
/// after the start at which they take over.
@immutable
class CompanionGesture {
  const CompanionGesture({
    this.left,
    this.right,
    this.lean = 0,
    this.roll = 0,
    this.yaw = 0,
    this.pitch = 0,
    this.brow = 0,
    this.tilt = 0,
    this.smile = 0,
    this.squint = 0,
    this.gaze,
    this.faceHand = false,
    this.oscRight,
    this.oscLeft,
    this.bounce = 0,
    this.hold = 1.5,
    this.then = const [],
  });

  final GestureArm? left;
  final GestureArm? right;
  final double lean;
  final double roll;
  final double yaw;
  final double pitch;
  final double brow;
  final double tilt;

  /// Added to the base smile.
  final double smile;
  final double squint;

  /// Null leaves the eyes to their own glances.
  final (double, double)? gaze;
  final bool faceHand;
  final Oscillation? oscRight;
  final Oscillation? oscLeft;
  final double bounce;

  /// Seconds before relaxing back to ready.
  final double hold;
  final List<(double, CompanionGesture)> then;

  static const readyLeft = GestureArm(-13, -50, 28);
  static const readyRight = GestureArm(11, -56, 152);
  static const ready = CompanionGesture(left: readyLeft, right: readyRight);
}

const _sweepEnd = CompanionGesture(
  right: GestureArm(102, -100, -22, HandPose.open, 3),
  yaw: 0.35,
  gaze: (0.6, -0.1),
  brow: 0.4,
  smile: 0.25,
);
const _apart = CompanionGesture(
  left: GestureArm(-96, -82, -84, HandPose.flat),
  right: GestureArm(96, -82, -96, HandPose.flat),
  brow: 0.5,
);
const _speakOut = CompanionGesture(
  right: GestureArm(100, -94, -18, HandPose.open),
  yaw: 0.3,
  gaze: (0.6, 0),
  brow: 0.3,
  smile: 0.2,
);

/// The gesture library of the pitch videos, by name.
enum GestureName {
  wave(
    CompanionGesture(
      right: GestureArm(88, -176, -78, HandPose.open, 6),
      roll: 0.06,
      brow: 0.6,
      smile: 0.55,
      squint: 0.25,
      oscRight: (dx: 5, dy: 1.5, angle: 16, hz: 2.1),
      hold: 1.7,
    ),
  ),
  openBoth(
    CompanionGesture(
      left: GestureArm(-98, -82, 200, HandPose.open, 2),
      right: GestureArm(98, -82, -20, HandPose.open, 2),
      brow: 0.6,
      smile: 0.35,
      lean: -0.01,
      hold: 1.3,
    ),
  ),
  openSmall(
    CompanionGesture(
      left: GestureArm(-86, -76, 205, HandPose.open),
      right: GestureArm(86, -76, -25, HandPose.open),
      brow: 0.35,
      smile: 0.2,
      roll: -0.03,
      hold: 1.1,
    ),
  ),
  presentRight(
    CompanionGesture(
      right: GestureArm(100, -80, -12, HandPose.open, 2),
      yaw: 0.4,
      gaze: (0.75, 0.05),
      roll: 0.04,
      lean: 0.025,
      brow: 0.35,
      smile: 0.2,
      hold: 1.6,
    ),
  ),
  presentLeft(
    CompanionGesture(
      left: GestureArm(-100, -80, 192, HandPose.open, 2),
      yaw: -0.4,
      gaze: (-0.75, 0.05),
      roll: -0.04,
      lean: -0.025,
      brow: 0.35,
      smile: 0.2,
      hold: 1.6,
    ),
  ),
  pointRight(
    CompanionGesture(
      right: GestureArm(110, -94, -8, HandPose.point, 2),
      yaw: 0.35,
      gaze: (0.75, 0),
      brow: 0.3,
      hold: 1.2,
    ),
  ),
  one(
    CompanionGesture(
      right: GestureArm(98, -150, -82, HandPose.point, 4),
      brow: 0.75,
      roll: 0.03,
      smile: 0.15,
      hold: 1.2,
    ),
  ),
  two(
    CompanionGesture(
      right: GestureArm(98, -150, -82, HandPose.two, 4),
      brow: 0.6,
      roll: 0.03,
      hold: 1.2,
    ),
  ),
  think(
    CompanionGesture(
      right: GestureArm(46, -144, -102, HandPose.point, 3),
      roll: -0.07,
      yaw: -0.1,
      gaze: (-0.4, -0.55),
      brow: 0.5,
      tilt: 0.6,
      faceHand: true,
      hold: 1.2,
    ),
  ),
  listen(
    CompanionGesture(
      right: GestureArm(62, -140, -80, HandPose.cup, 4),
      roll: 0.12,
      yaw: 0.2,
      gaze: (0.3, -0.2),
      brow: 0.3,
      smile: 0.2,
      faceHand: true,
      hold: 1.3,
    ),
  ),
  chest(
    CompanionGesture(
      right: GestureArm(24, -74, 180, HandPose.flat),
      roll: -0.06,
      smile: 0.45,
      squint: 0.2,
      brow: 0.2,
      hold: 1.4,
    ),
  ),
  palmsDown(
    CompanionGesture(
      left: GestureArm(-76, -72, 188, HandPose.flat),
      right: GestureArm(76, -72, -8, HandPose.flat),
      brow: 0.2,
      pitch: 0.2,
      hold: 1.2,
    ),
  ),
  clap(
    CompanionGesture(
      left: GestureArm(-9, -92, -78, HandPose.flat),
      right: GestureArm(9, -92, -102, HandPose.flat),
      brow: 0.6,
      smile: 0.6,
      squint: 0.3,
      bounce: 2,
      hold: 0.9,
    ),
  ),
  thumbs(
    CompanionGesture(
      right: GestureArm(74, -96, 0, HandPose.thumbs, 3),
      smile: 0.7,
      squint: 0.35,
      brow: 0.5,
      roll: 0.05,
      bounce: 1.5,
      hold: 1.2,
    ),
  ),
  celebrate(
    CompanionGesture(
      left: GestureArm(-82, -176, -112, HandPose.open, 7),
      right: GestureArm(82, -176, -68, HandPose.open, 7),
      smile: 0.8,
      squint: 0.4,
      brow: 0.7,
      bounce: 3,
      hold: 1.2,
    ),
  ),
  apart(
    CompanionGesture(
      left: GestureArm(-34, -84, -84, HandPose.flat),
      right: GestureArm(34, -84, -96, HandPose.flat),
      brow: 0.3,
      hold: 1.4,
      then: [(0.32, _apart)],
    ),
  ),
  sweep(
    CompanionGesture(
      right: GestureArm(44, -62, 40, HandPose.open),
      yaw: 0.1,
      then: [(0.18, _sweepEnd)],
    ),
  ),
  speak(
    CompanionGesture(
      right: GestureArm(40, -128, -60, HandPose.open, 2),
      brow: 0.3,
      hold: 1.3,
      then: [(0.25, _speakOut)],
    ),
  ),

  /// Rock on: the right hand thrown up beside the head, held.
  horns(
    CompanionGesture(
      right: GestureArm(74, -170, -84, HandPose.horns, 7),
      smile: 0.75,
      squint: 0.4,
      brow: 0.7,
      roll: 0.07,
      bounce: 2,
      hold: 3,
    ),
  );

  const GestureName(this.gesture);

  final CompanionGesture gesture;
}
