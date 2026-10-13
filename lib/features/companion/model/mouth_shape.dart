import 'package:flutter/foundation.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// The mouth in head-local units: half width, opening, pucker, how much of
/// the teeth and tongue show, the lips' thickness, and the F/V bite.
@immutable
class MouthShape {
  const MouthShape({
    this.halfWidth = 10.5,
    this.open = 0,
    this.round = 0,
    this.teethTop = 0,
    this.teethBottom = 0,
    this.tongue = 0,
    this.tongueUp = 0,
    this.upperLip = 3.2,
    this.lowerLip = 3.6,
    this.bite = 0,
  });

  final double halfWidth;
  final double open;
  final double round;
  final double teethTop;
  final double teethBottom;
  final double tongue;
  final double tongueUp;
  final double upperLip;
  final double lowerLip;
  final double bite;

  List<double> get _values => [
    halfWidth,
    open,
    round,
    teethTop,
    teethBottom,
    tongue,
    tongueUp,
    upperLip,
    lowerLip,
    bite,
  ];

  MouthShape blend(MouthShape other, double t) {
    final a = _values;
    final b = other._values;
    final v = [for (var i = 0; i < a.length; i++) lerpDouble(a[i], b[i], t)];
    return MouthShape(
      halfWidth: v[0],
      open: v[1],
      round: v[2],
      teethTop: v[3],
      teethBottom: v[4],
      tongue: v[5],
      tongueUp: v[6],
      upperLip: v[7],
      lowerLip: v[8],
      bite: v[9],
    );
  }
}

/// The nine mouth shapes of the Rhubarb lip-sync convention, as the pitch
/// videos draw them.
enum Viseme {
  /// Rest.
  x(MouthShape(upperLip: 3, lowerLip: 3.5)),

  /// Closed: M, B, P.
  a(MouthShape(halfWidth: 10, upperLip: 2.2, lowerLip: 2.6)),

  /// Slightly open, teeth together: most consonants, "ee".
  b(
    MouthShape(
      halfWidth: 11.5,
      open: 3,
      teethTop: 1,
      teethBottom: 1,
      upperLip: 2.9,
      lowerLip: 3.2,
    ),
  ),

  /// Open: "eh", "ae".
  c(
    MouthShape(
      halfWidth: 11.5,
      open: 6.8,
      teethTop: 1,
      teethBottom: 0.4,
      tongue: 0.3,
      upperLip: 2.9,
      lowerLip: 3.3,
    ),
  ),

  /// Wide open: "aa".
  d(
    MouthShape(
      halfWidth: 12.2,
      open: 10.5,
      teethTop: 1,
      teethBottom: 0.2,
      tongue: 0.7,
      upperLip: 2.7,
      lowerLip: 3.2,
    ),
  ),

  /// Slightly rounded: "ao", "er".
  e(
    MouthShape(
      halfWidth: 9,
      open: 6.2,
      round: 0.45,
      teethTop: 0.6,
      tongue: 0.3,
    ),
  ),

  /// Puckered: "oo", "w".
  f(
    MouthShape(halfWidth: 7, open: 3.4, round: 1, upperLip: 3.8, lowerLip: 4.2),
  ),

  /// Upper teeth on the lower lip: F, V.
  g(
    MouthShape(
      halfWidth: 11,
      open: 2.2,
      teethTop: 1,
      bite: 1,
      upperLip: 2.9,
      lowerLip: 3,
    ),
  ),

  /// Tongue up behind the teeth: L.
  h(
    MouthShape(
      halfWidth: 11,
      open: 6.5,
      teethTop: 0.8,
      tongueUp: 1,
      upperLip: 2.9,
      lowerLip: 3.3,
    ),
  );

  const Viseme(this.shape);

  final MouthShape shape;
}
