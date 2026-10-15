import 'package:flutter/foundation.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// How a hand is held: the curl of each finger from 0 (straight) to 1
/// (tucked), how far the thumb sticks out, and how the fingers spread.
@immutable
class HandShape {
  const HandShape({
    this.thumb = 0.4,
    this.index = 0.35,
    this.middle = 0.4,
    this.ring = 0.45,
    this.pinky = 0.5,
    this.thumbOut = 0.4,
    this.spread = 0.2,
  });

  factory HandShape.fromValues(List<double> v) => HandShape(
    thumb: v[0],
    index: v[1],
    middle: v[2],
    ring: v[3],
    pinky: v[4],
    thumbOut: v[5],
    spread: v[6],
  );

  final double thumb;
  final double index;
  final double middle;
  final double ring;
  final double pinky;
  final double thumbOut;
  final double spread;

  List<double> get values => [
    thumb,
    index,
    middle,
    ring,
    pinky,
    thumbOut,
    spread,
  ];

  /// The curl of the four fingers, index first.
  List<double> get fingerCurls => [index, middle, ring, pinky];

  HandShape blend(HandShape other, double t) {
    final a = values;
    final b = other.values;
    return HandShape.fromValues([
      for (var i = 0; i < a.length; i++) lerpDouble(a[i], b[i], t),
    ]);
  }
}

/// The hand shapes the gestures name.
enum HandPose {
  relaxed(HandShape()),
  open(
    HandShape(
      thumb: 0,
      index: 0,
      middle: 0,
      ring: 0.02,
      pinky: 0.05,
      thumbOut: 0.75,
      spread: 0.35,
    ),
  ),
  flat(
    HandShape(
      thumb: 0.05,
      index: 0,
      middle: 0,
      ring: 0,
      pinky: 0,
      thumbOut: 0.3,
      spread: 0,
    ),
  ),
  point(
    HandShape(
      thumb: 0.75,
      index: 0,
      middle: 0.95,
      ring: 1,
      pinky: 1,
      thumbOut: 0.15,
      spread: 0,
    ),
  ),
  two(
    HandShape(
      thumb: 0.8,
      index: 0,
      middle: 0,
      ring: 1,
      pinky: 1,
      thumbOut: 0.1,
      spread: 0.6,
    ),
  ),
  thumbs(
    HandShape(
      thumb: 0,
      index: 1,
      middle: 1,
      ring: 1,
      pinky: 1,
      thumbOut: 1,
      spread: 0,
    ),
  ),
  cup(
    HandShape(
      thumb: 0.25,
      index: 0.3,
      middle: 0.3,
      ring: 0.32,
      pinky: 0.35,
      thumbOut: 0.55,
      spread: 0.1,
    ),
  ),

  /// Index and pinky up, the rest tucked: rock on.
  horns(
    HandShape(
      thumb: 0.85,
      index: 0,
      middle: 1,
      ring: 1,
      pinky: 0,
      thumbOut: 0.1,
      spread: 0.55,
    ),
  );

  const HandPose(this.shape);

  final HandShape shape;
}
