/// Keeps the walker out of every solid: a point-versus-rotated-rectangle
/// push against every footprint, with a margin so the camera never clips a
/// wall.
///
/// Pure Dart, O(footprints) per resolve; each footprint's frame is fixed
/// once, and a footprint too far away to touch is rejected before it is
/// rotated into.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:meta/meta.dart';

class WalkCollider {
  WalkCollider(Iterable<Footprint> footprints, {this.margin = solidClearance})
    : footprints = _mergeAligned(footprints.toList(), margin) {
    _walls = [for (final p in this.footprints) _Wall(p, margin)];
  }

  /// The footprints the walker is kept out of, after merging.
  @visibleForTesting
  final List<Footprint> footprints;

  late final List<_Wall> _walls;

  /// Two neighbours in a crowded week can stand closer than twice the
  /// margin. Resolved one after the other, the first pushes the walker into
  /// the second's clearance and the second pushes it back: the sweep never
  /// settles. Aligned neighbours (same facing, same row line, same depth)
  /// whose clearances overlap are merged into one footprint, repeatedly, so
  /// the alley between them is solid and every footprint left is at least
  /// a clearance from the next.
  static List<Footprint> _mergeAligned(List<Footprint> input, double margin) {
    final out = [...input];
    var merged = true;
    while (merged) {
      merged = false;
      outer:
      for (var i = 0; i < out.length; i++) {
        for (var j = i + 1; j < out.length; j++) {
          final union = _union(out[i], out[j], margin);
          if (union == null) continue;
          out[i] = union;
          out.removeAt(j);
          merged = true;
          break outer;
        }
      }
    }
    return List.unmodifiable(out);
  }

  static Footprint? _union(Footprint a, Footprint b, double margin) {
    const eps = 1e-3;
    if ((a.facingRadians - b.facingRadians).abs() > eps ||
        (a.depth - b.depth).abs() > eps) {
      return null;
    }
    final sinF = math.sin(a.facingRadians);
    final cosF = math.cos(a.facingRadians);
    final (u, v) = a.local(b.x, b.z);
    if (v.abs() > eps) return null;
    if (u.abs() - (a.width + b.width) / 2 >= 2 * margin) return null;
    final left = math.min(-a.width / 2, u - b.width / 2);
    final right = math.max(a.width / 2, u + b.width / 2);
    final centre = (left + right) / 2;
    return Footprint(
      x: a.x + centre * cosF,
      z: a.z - centre * sinF,
      facingRadians: a.facingRadians,
      width: right - left,
      depth: a.depth,
    );
  }

  /// Extra clearance around every footprint, world meters.
  final double margin;

  /// Returns the nearest point outside every footprint to (x, z).
  (double, double) resolve(double x, double z) {
    var rx = x;
    var rz = z;
    for (final w in _walls) {
      final dx = rx - w.x;
      final dz = rz - w.z;
      // Too far to touch: no point of the box is farther from its centre
      // than its corner.
      if (dx * dx + dz * dz >= w.cornerDistanceSquared) continue;
      // Into the footprint's local frame: `u` along its width (local X),
      // `v` along its depth (local Z).
      final u = dx * w.cosF - dz * w.sinF;
      final v = dx * w.sinF + dz * w.cosF;
      if (u.abs() >= w.halfW || v.abs() >= w.halfD) continue;
      // Push out through the nearest face.
      final pushU = w.halfW - u.abs();
      final pushV = w.halfD - v.abs();
      var nu = u;
      var nv = v;
      if (pushU < pushV) {
        nu = u.isNegative ? -w.halfW : w.halfW;
      } else {
        nv = v.isNegative ? -w.halfD : w.halfD;
      }
      rx = w.x + nu * w.cosF + nv * w.sinF;
      rz = w.z - nu * w.sinF + nv * w.cosF;
    }
    return (rx, rz);
  }
}

/// A footprint with its margin, its frame fixed once for the walk.
class _Wall {
  _Wall(Footprint p, double margin)
    : x = p.x,
      z = p.z,
      sinF = math.sin(p.facingRadians),
      cosF = math.cos(p.facingRadians),
      halfW = p.width / 2 + margin,
      halfD = p.depth / 2 + margin;

  final double x;
  final double z;
  final double sinF;
  final double cosF;
  final double halfW;
  final double halfD;

  /// The corner is the box's farthest point from its centre: a point at
  /// least this far (squared, so no root per footprint) is outside.
  double get cornerDistanceSquared => halfW * halfW + halfD * halfD;
}
