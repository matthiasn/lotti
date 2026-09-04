/// A solid the camera must not pass through: a [Footprint] on the ground
/// plane and the band of height it fills.
///
/// Pure Dart. The walker collider reads the footprints of the solids that
/// reach down to eye level; a flight sweeps its line against all of them,
/// the ones in the air included (a pylon's sign, the gantry's beam), and
/// lifts over whatever it would cross.
library;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// How close the camera may come to a solid, world metres: the walker's
/// margin and the width a flight keeps from a wall it passes beside.
const solidClearance = 0.6;

class Solid {
  const Solid({required this.footprint, required this.top, this.bottom = 0});

  final Footprint footprint;

  /// Height of the underside above the ground; 0 for anything standing on
  /// it.
  final double bottom;

  /// Height of the top above the ground.
  final double top;

  /// Whether a walker at [eyeHeight] can bump into it. A solid that hangs
  /// above eye level is for flights alone: you walk under a pylon's sign.
  bool get atWalkHeight => bottom < eyeHeight;

  /// Whether the point is inside, with [clearance] metres of margin on
  /// every side.
  bool contains(double x, double y, double z, {double clearance = 0}) {
    if (y <= bottom - clearance || y >= top + clearance) return false;
    final (u, v) = footprint.local(x, z);
    return u.abs() < footprint.width / 2 + clearance &&
        v.abs() < footprint.depth / 2 + clearance;
  }
}
