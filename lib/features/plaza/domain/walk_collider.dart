/// Keeps the walker out of buildings: a point-versus-rotated-rectangle push
/// against every placement, with a margin so the camera never clips a wall.
///
/// Pure Dart, O(buildings) per resolve — trivially cheap at prototype scale.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/street_layout.dart';

class WalkCollider {
  WalkCollider(Iterable<PlotPlacement> placements, {this.margin = 0.6})
    : _placements = placements.toList(growable: false);

  final List<PlotPlacement> _placements;

  /// Extra clearance around every footprint, world meters.
  final double margin;

  /// Returns the nearest point outside every footprint to (x, z).
  (double, double) resolve(double x, double z) {
    var rx = x;
    var rz = z;
    for (final p in _placements) {
      // Into the building's local frame: `u` along the road (width),
      // `v` toward the road (depth), facing = +v.
      final sinF = math.sin(p.facingRadians);
      final cosF = math.cos(p.facingRadians);
      final dx = rx - p.x;
      final dz = rz - p.z;
      final v = dx * sinF + dz * cosF;
      final u = dx * cosF - dz * sinF;
      final halfW = p.width / 2 + margin;
      final halfD = p.depth / 2 + margin;
      if (u.abs() >= halfW || v.abs() >= halfD) continue;
      // Push out through the nearest face.
      final pushU = halfW - u.abs();
      final pushV = halfD - v.abs();
      var nu = u;
      var nv = v;
      if (pushU < pushV) {
        nu = u.isNegative ? -halfW : halfW;
      } else {
        nv = v.isNegative ? -halfD : halfD;
      }
      rx = p.x + nu * cosF + nv * sinF;
      rz = p.z - nu * sinF + nv * cosF;
    }
    return (rx, rz);
  }
}
