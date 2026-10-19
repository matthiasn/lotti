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
    this.elbow,
  ]);

  final double x;
  final double y;
  final double angle;
  final HandPose hand;
  final double lift;

  /// The way the upper arm would rather point from the shoulder, in degrees
  /// (0 screen-right, 90 down); null lets it hang. The solver still keeps
  /// the elbow inside what a real arm can do — this only biases its choice,
  /// as hands on the hips need the elbows out.
  final double? elbow;
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
    this.smileSkew = 0,
    this.browSkew = 0,
    this.squint = 0,
    this.lids = 0,
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

  /// Added to the mood's: lifts the right mouth corner, lowers the left.
  final double smileSkew;

  /// Added to the mood's: lifts the right brow, lowers the left.
  final double browSkew;
  final double squint;

  /// Added to the mood's resting lids: how far the upper lids close, 0..1.
  final double lids;

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

/// A hand on the hip, fingers forward and down, the elbow out.
const _hipLeft = GestureArm(-50, -58, 30, HandPose.flat, 0, 140);
const _hipRight = GestureArm(50, -58, 150, HandPose.flat, 0, 40);

const _clapApart = CompanionGesture(
  left: GestureArm(-30, -92, -78, HandPose.flat),
  right: GestureArm(30, -92, -102, HandPose.flat),
  smile: 0.1,
  smileSkew: 0.3,
  lids: 0.3,
);
const _clapTogether = CompanionGesture(
  left: GestureArm(-9, -92, -78, HandPose.flat),
  right: GestureArm(9, -92, -102, HandPose.flat),
  smile: 0.1,
  smileSkew: 0.3,
  lids: 0.3,
);

// The eye roll's later phases: up, across, and down to a flat look.
const _eyeRollUp = CompanionGesture(
  right: _hipRight,
  roll: 0.08,
  pitch: -0.06,
  gaze: (0.1, -1),
  lids: 0.1,
  smileSkew: -0.15,
  browSkew: 0.3,
);
const _eyeRollAcross = CompanionGesture(
  right: _hipRight,
  roll: 0.08,
  pitch: -0.06,
  gaze: (0.6, -0.7),
  lids: 0.1,
  smileSkew: -0.15,
  browSkew: 0.3,
);
const _eyeRollDone = CompanionGesture(
  right: _hipRight,
  roll: 0.05,
  gaze: (0.3, 0),
  lids: 0.3,
  smileSkew: -0.15,
  browSkew: 0.3,
);

/// The gesture library of the pitch videos, by name, and the sassy ones
/// added for the companion's reactions (`companionReaction`).
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
  ),

  /// Both hands on the hips, chin a little up: waiting, or proud of you.
  handsOnHips(
    CompanionGesture(
      left: _hipLeft,
      right: _hipRight,
      roll: 0.08,
      pitch: -0.05,
      browSkew: 0.25,
      hold: 2.2,
    ),
  ),

  /// "Uh-uh": the index finger up beside the face, wagging; the other hand
  /// on the hip.
  fingerWag(
    CompanionGesture(
      left: _hipLeft,
      right: GestureArm(70, -146, -90, HandPose.point, 4),
      oscRight: (dx: 3, dy: 0, angle: 18, hz: 3),
      roll: -0.05,
      brow: 0.2,
      browSkew: 0.5,
      smileSkew: 0.25,
      lids: 0.15,
      hold: 1.8,
    ),
  ),

  /// Palms up and out, the shoulders raised: "what can you do?"
  shrug(
    CompanionGesture(
      left: GestureArm(-84, -66, 200, HandPose.open, 9),
      right: GestureArm(84, -66, -20, HandPose.open, 9),
      roll: 0.1,
      brow: 0.7,
      smile: -0.1,
      smileSkew: -0.2,
      hold: 1.4,
    ),
  ),

  /// A hand flat over the brow, head down, eyes shut.
  facepalm(
    CompanionGesture(
      right: GestureArm(16, -170, -150, HandPose.flat, 4),
      pitch: 0.25,
      roll: -0.06,
      brow: -0.2,
      smile: -0.3,
      lids: 0.7,
      faceHand: true,
      hold: 1.8,
    ),
  ),

  /// Three slow claps under a lopsided smile: "well done, finally".
  slowClap(
    CompanionGesture(
      left: GestureArm(-30, -92, -78, HandPose.flat),
      right: GestureArm(30, -92, -102, HandPose.flat),
      smile: 0.1,
      smileSkew: 0.3,
      lids: 0.3,
      hold: 2.1,
      then: [
        (0.45, _clapTogether),
        (0.6, _clapApart),
        (1.05, _clapTogether),
        (1.2, _clapApart),
        (1.65, _clapTogether),
        (1.8, _clapApart),
      ],
    ),
  ),

  /// The eyes roll up and across under a raised brow, a hand on the hip.
  eyeRoll(
    CompanionGesture(
      right: _hipRight,
      roll: 0.08,
      pitch: -0.06,
      gaze: (-0.5, -0.9),
      lids: 0.1,
      smileSkew: -0.15,
      browSkew: 0.3,
      hold: 1.4,
      then: [
        (0.25, _eyeRollUp),
        (0.5, _eyeRollAcross),
        (0.85, _eyeRollDone),
      ],
    ),
  );

  const GestureName(this.gesture);

  final CompanionGesture gesture;
}
