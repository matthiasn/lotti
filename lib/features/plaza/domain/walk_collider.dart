/// Keeps the walker out of every solid: swept movement against rotated
/// footprints, with a margin so the camera never clips a wall, even when
/// a fast step crosses an entire building.
///
/// Pure Dart, O(footprints) for normal movement; each footprint's frame is
/// fixed once. Overlapping-wall recovery uses O(footprints log footprints)
/// interval unions only when a nearest-face push cannot leave all buildings.
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
  /// the alley between them is solid. Other overlaps, including rotated
  /// skyline towers, are handled by point recovery.
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

  /// Sweeps the entire step, stopping at the first wall and sliding along it.
  ///
  /// At most four contacts are processed, independent of speed or frame time;
  /// any remaining motion is discarded at a complex corner. The slabs and
  /// contact normals use cached wall frames, with no per-wall allocations.
  (double, double) move(double fromX, double fromZ, double toX, double toZ) {
    var (x, z) = resolve(fromX, fromZ);
    var dx = toX - fromX;
    var dz = toZ - fromZ;
    const epsilon = 1e-9;
    for (var contact = 0; contact < 4; contact++) {
      if (dx.abs() + dz.abs() < epsilon) break;
      var earliest = 1.0;
      var normalX = 0.0;
      var normalZ = 0.0;
      var hit = false;
      for (final w in _walls) {
        final u = (x - w.x) * w.cosF - (z - w.z) * w.sinF;
        final v = (x - w.x) * w.sinF + (z - w.z) * w.cosF;
        final du = dx * w.cosF - dz * w.sinF;
        final dv = dx * w.sinF + dz * w.cosF;
        var enterU = double.negativeInfinity;
        var exitU = double.infinity;
        var enterV = double.negativeInfinity;
        var exitV = double.infinity;
        if (du.abs() < epsilon) {
          if (u.abs() >= w.halfW) continue;
        } else {
          final a = (-w.halfW - u) / du;
          final b = (w.halfW - u) / du;
          enterU = math.min(a, b);
          exitU = math.max(a, b);
        }
        if (dv.abs() < epsilon) {
          if (v.abs() >= w.halfD) continue;
        } else {
          final a = (-w.halfD - v) / dv;
          final b = (w.halfD - v) / dv;
          enterV = math.min(a, b);
          exitV = math.max(a, b);
        }
        final enter = math.max(enterU, enterV);
        final exit = math.min(exitU, exitV);
        // Ignore grazing, motion away from a face, and walls beyond this step.
        if (enter < -epsilon ||
            enter > earliest ||
            exit <= math.max(0, enter)) {
          continue;
        }
        earliest = math.max(0, enter);
        hit = true;
        if (enterU > enterV) {
          normalX = -du.sign * w.cosF;
          normalZ = du.sign * w.sinF;
        } else {
          normalX = -dv.sign * w.sinF;
          normalZ = -dv.sign * w.cosF;
        }
      }
      x += dx * earliest;
      z += dz * earliest;
      if (!hit) break;
      // A sub-micron separation avoids round-off placing the next sweep inside.
      x += normalX * 1e-7;
      z += normalZ * 1e-7;
      dx *= 1 - earliest;
      dz *= 1 - earliest;
      final intoWall = dx * normalX + dz * normalZ;
      dx -= intoWall * normalX;
      dz -= intoWall * normalZ;
    }
    return (x, z);
  }

  /// Pushes through the nearest faces to leave the footprints around (x, z).
  ///
  /// If overlapping buildings push back into an earlier wall, escape the
  /// complete overlap along the shorter world-axis exit. This recovery path
  /// sorts wall intersections; ordinary movement allocates no interval lists.
  (double, double) resolve(double x, double z) {
    var rx = x;
    var rz = z;
    var displaced = false;
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
      displaced = true;
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
    if (displaced && _walls.any((wall) => wall.contains(rx, rz))) {
      final escapeX = _escapeDistance(x, z, alongX: true);
      final escapeZ = _escapeDistance(x, z, alongX: false);
      return escapeX.abs() < escapeZ.abs()
          ? (x + escapeX, z)
          : (x, z + escapeZ);
    }
    return (rx, rz);
  }

  /// Nearest end of the union containing the origin on an axis through it.
  double _escapeDistance(double x, double z, {required bool alongX}) {
    final intervals = <(double, double)>[];
    for (final wall in _walls) {
      final u = (x - wall.x) * wall.cosF - (z - wall.z) * wall.sinF;
      final v = (x - wall.x) * wall.sinF + (z - wall.z) * wall.cosF;
      final du = alongX ? wall.cosF : -wall.sinF;
      final dv = alongX ? wall.sinF : wall.cosF;
      var enter = double.negativeInfinity;
      var exit = double.infinity;
      if (du.abs() < 1e-12) {
        if (u.abs() >= wall.halfW) continue;
      } else {
        final a = (-wall.halfW - u) / du;
        final b = (wall.halfW - u) / du;
        enter = math.min(a, b);
        exit = math.max(a, b);
      }
      if (dv.abs() < 1e-12) {
        if (v.abs() >= wall.halfD) continue;
      } else {
        final a = (-wall.halfD - v) / dv;
        final b = (wall.halfD - v) / dv;
        enter = math.max(enter, math.min(a, b));
        exit = math.min(exit, math.max(a, b));
      }
      if (enter < exit) intervals.add((enter, exit));
    }
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    // Recovery starts inside a wall, so each axis has a component containing
    // zero. Ignore separate buildings before and after that component.
    var (lower, upper) = intervals.first;
    const separation = 1e-7;
    for (var i = 1; i < intervals.length; i++) {
      final (start, end) = intervals[i];
      if (start <= upper + 2 * separation) {
        upper = math.max(upper, end);
      } else {
        if (upper >= 0) break;
        lower = start;
        upper = end;
      }
    }
    return lower.abs() < upper.abs() ? lower - separation : upper + separation;
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

  /// Ignore sub-nanometre round-off on an already resolved face.
  bool contains(double px, double pz) {
    final dx = px - x;
    final dz = pz - z;
    return (dx * cosF - dz * sinF).abs() < halfW - 1e-9 &&
        (dx * sinF + dz * cosF).abs() < halfD - 1e-9;
  }
}
