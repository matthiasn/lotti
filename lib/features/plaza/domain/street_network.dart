/// The route a flight follows between two stops on the ground: the
/// street's polyline, every segment of it including gaps and fold
/// connectors, continued through the plaza's mouth up its axis to home.
///
/// Pure Dart. A stop is projected onto the polyline; the way between two
/// stops is the projections and every vertex between them, in travel
/// order, so a flight runs down the street and round the corners instead
/// of over the blocks.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

class StreetNetwork {
  /// A polyline through [points]; consecutive duplicates are dropped.
  /// Needs at least two distinct points.
  StreetNetwork(List<(double, double)> points)
    : vertices = List.unmodifiable(_distinct(points)) {
    assert(vertices.length >= 2, 'a network needs two points');
    final cumulative = <double>[0];
    for (var i = 1; i < vertices.length; i++) {
      final (ax, az) = vertices[i - 1];
      final (bx, bz) = vertices[i];
      cumulative.add(cumulative.last + groundDistanceBetween(ax, az, bx, bz));
    }
    _cumulative = List.unmodifiable(cumulative);
  }

  /// The street from its oldest end to the plaza's mouth and on to home,
  /// or null when the plan has no street.
  static StreetNetwork? of(StreetPlan plan, FrontierPlaza? plaza) {
    final points = <(double, double)>[];
    for (final s in plan.segments) {
      if (points.isEmpty) points.add((s.startX, s.startZ));
      points.add((s.endX, s.endZ));
    }
    if (plaza != null) {
      final sinH = math.sin(plaza.headingRadians);
      final cosH = math.cos(plaza.headingRadians);
      // The mouth: the plaza's front edge on its axis, then home.
      points
        ..add((
          plaza.centerX - sinH * plaza.depth / 2,
          plaza.centerZ - cosH * plaza.depth / 2,
        ))
        ..add((plaza.home.x, plaza.home.z));
    }
    return _distinct(points).length < 2 ? null : StreetNetwork(points);
  }

  /// Two points closer than this are one.
  static const mergeDistance = 0.05;

  final List<(double, double)> vertices;
  late final List<double> _cumulative;

  /// Total length, world metres.
  double get length => _cumulative.last;

  static List<(double, double)> _distinct(List<(double, double)> points) {
    final out = <(double, double)>[];
    for (final p in points) {
      if (out.isEmpty ||
          groundDistanceBetween(out.last.$1, out.last.$2, p.$1, p.$2) >
              mergeDistance) {
        out.add(p);
      }
    }
    return out;
  }

  /// The point [along] metres from the start, clamped to the ends.
  (double, double) pointAt(double along) {
    final d = along.clamp(0.0, length);
    var i = 1;
    while (i < _cumulative.length - 1 && _cumulative[i] < d) {
      i++;
    }
    final a = vertices[i - 1];
    final b = vertices[i];
    final span = _cumulative[i] - _cumulative[i - 1];
    final f = span == 0 ? 0.0 : (d - _cumulative[i - 1]) / span;
    return (a.$1 + (b.$1 - a.$1) * f, a.$2 + (b.$2 - a.$2) * f);
  }

  /// The nearest point of the network to (x, z): how far along it lies,
  /// the point itself and how far off the network (x, z) stands.
  ({double along, double x, double z, double offset}) project(
    double x,
    double z,
  ) {
    var best = (along: 0.0, x: vertices.first.$1, z: vertices.first.$2);
    var bestOffset = double.infinity;
    for (var i = 1; i < vertices.length; i++) {
      final a = vertices[i - 1];
      final b = vertices[i];
      final dx = b.$1 - a.$1;
      final dz = b.$2 - a.$2;
      final span2 = dx * dx + dz * dz;
      final f = span2 == 0
          ? 0.0
          : (((x - a.$1) * dx + (z - a.$2) * dz) / span2).clamp(0.0, 1.0);
      final px = a.$1 + dx * f;
      final pz = a.$2 + dz * f;
      final offset = math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz));
      if (offset < bestOffset) {
        bestOffset = offset;
        best = (
          along: _cumulative[i - 1] + math.sqrt(span2) * f,
          x: px,
          z: pz,
        );
      }
    }
    return (along: best.along, x: best.x, z: best.z, offset: bestOffset);
  }

  /// The way along the network from [a] to [b]: where [a] joins it, every
  /// vertex between, and where [b] leaves it, in travel order. With [join]
  /// the joins slide [join] metres along the way (never past the next
  /// vertex, never past each other), so a stop beside the road merges onto
  /// it and pulls off it on a diagonal instead of a right-angled hop.
  /// Coincident points are merged, so a stop on the way adds nothing.
  List<(double, double)> pathBetween(
    (double, double) a,
    (double, double) b, {
    double join = 0,
  }) {
    assert(join >= 0, 'a join is a distance along the way');
    final pa = project(a.$1, a.$2);
    final pb = project(b.$1, b.$2);
    final forward = pa.along <= pb.along;
    final dir = forward ? 1.0 : -1.0;
    final span = (pb.along - pa.along).abs();
    final slide = math.min(join, span / 2);
    final start = _slide(pa.along, dir * slide);
    final end = _slide(pb.along, -dir * slide);
    final lo = math.min(start, end);
    final hi = math.max(start, end);
    final between = <(double, double)>[
      for (var i = 0; i < vertices.length; i++)
        if (_cumulative[i] > lo + mergeDistance &&
            _cumulative[i] < hi - mergeDistance)
          vertices[i],
    ];
    final way = <(double, double)>[
      pointAt(start),
      ...forward ? between : between.reversed,
      pointAt(end),
    ];
    return _distinct(way);
  }

  /// [along] moved by [by] metres, stopped at the first vertex on the way,
  /// one within [mergeDistance] of [along] included: a join slides along
  /// its own stretch, never round a corner, and a stop at a corner joins
  /// the way there.
  double _slide(double along, double by) {
    if (by == 0) return along;
    var limit = by > 0 ? length : 0.0;
    for (final c in _cumulative) {
      if (by > 0 && c > along - mergeDistance) {
        limit = math.min(limit, c);
      } else if (by < 0 && c < along + mergeDistance) {
        limit = math.max(limit, c);
      }
    }
    return by > 0
        ? math.max(along, math.min(along + by, limit))
        : math.min(along, math.max(along + by, limit));
  }
}
