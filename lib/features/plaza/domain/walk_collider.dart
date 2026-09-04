/// Keeps the walker out of every solid: a point-versus-rotated-rectangle
/// push against every footprint, with a margin so the camera never clips a
/// wall.
///
/// Pure Dart, O(footprints) per resolve — trivially cheap at prototype
/// scale.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/street_layout.dart';

class WalkCollider {
  WalkCollider(Iterable<Footprint> footprints, {this.margin = 0.6})
    : _footprints = _mergeAligned(footprints.toList(), margin);

  final List<Footprint> _footprints;

  /// The footprints the walker is kept out of, after merging.
  List<Footprint> get footprints => _footprints;

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
    final dx = b.x - a.x;
    final dz = b.z - a.z;
    final v = dx * sinF + dz * cosF;
    if (v.abs() > eps) return null;
    final u = dx * cosF - dz * sinF;
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
    for (final p in _footprints) {
      // Into the footprint's local frame: `u` along its width (local X),
      // `v` along its depth (local Z).
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
