import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lotti/features/plaza/domain/building_architecture.dart';
import 'package:lotti/features/plaza/domain/plaza_connection.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// Cable dimensions in world metres. Geometry is generated once per snapshot;
/// the light budget bounds animated instances independently of graph size.
class CableConfig {
  const CableConfig({
    this.radius = 0.16,
    this.sagRatio = 0.09,
    this.maxSag = 8,
    this.mountHeight = 3,
    this.clearance = 1.5,
    this.maxSupports = 2,
    this.samplesPerSpan = 24,
    this.maxAnimatedCables = 96,
  }) : assert(radius > 0, 'cables need a positive radius'),
       assert(sagRatio >= 0 && maxSag >= 0, 'sag cannot be negative'),
       assert(mountHeight > 0 && clearance > 0, 'mounts need clearance'),
       assert(maxSupports >= 0, 'support budget cannot be negative'),
       assert(samplesPerSpan >= 4, 'curves need at least four intervals'),
       assert(maxAnimatedCables >= 0, 'light budget cannot be negative');

  final double radius;
  final double sagRatio;
  final double maxSag;
  final double mountHeight;
  final double clearance;
  final int maxSupports;
  final int samplesPerSpan;
  final int maxAnimatedCables;

  double sag(double distance) => math.min(maxSag, distance * sagRatio);
}

/// A roof-mounted endpoint or an intermediate structural support. Supports do
/// not introduce graph nodes or change the relationship's semantic endpoints.
typedef CableSupport = ({double x, double y, double z, double baseY});

/// A sampled chain of sagging spans, in the relationship's from → to order.
/// Arc distances let light packets move at a constant physical speed. Sampling
/// into an existing buffer performs no allocations during animation.
class CablePath {
  CablePath._({
    required this.connection,
    required this.supports,
    required CableConfig config,
  }) {
    final count = (supports.length - 1) * config.samplesPerSpan + 1;
    positions = Float64List(count * 3);
    distances = Float64List(count);
    var index = 0;
    for (var span = 0; span < supports.length - 1; span++) {
      final a = supports[span];
      final b = supports[span + 1];
      final sag = config.sag(groundDistanceBetween(a.x, a.z, b.x, b.z));
      for (
        var step = span == 0 ? 0 : 1;
        step <= config.samplesPerSpan;
        step++
      ) {
        final t = step / config.samplesPerSpan;
        final offset = index * 3;
        positions[offset] = a.x + (b.x - a.x) * t;
        positions[offset + 1] = _height(a.y, b.y, sag, t);
        positions[offset + 2] = a.z + (b.z - a.z) * t;
        if (index > 0) {
          final dx = positions[offset] - positions[offset - 3];
          final dy = positions[offset + 1] - positions[offset - 2];
          final dz = positions[offset + 2] - positions[offset - 1];
          distances[index] =
              distances[index - 1] + math.sqrt(dx * dx + dy * dy + dz * dz);
        }
        index++;
      }
    }
  }

  /// Raises supports only where needed to clear the intersected roof envelopes.
  /// Each span is checked analytically against rotated footprints, including
  /// narrow obstacles between samples. Raising either end only improves the
  /// clearance of an already checked neighbouring span.
  factory CablePath.plan({
    required PlazaConnection connection,
    required PlotPlacement from,
    required PlotPlacement to,
    required BuildingArchitecture fromArchitecture,
    required BuildingArchitecture toArchitecture,
    required List<Solid> solids,
    CableConfig config = const CableConfig(),
  }) {
    _Mount mount(PlotPlacement plot, BuildingArchitecture architecture) {
      final roof = architecture.volumes.last;
      final u =
          roof.x +
          (stableUnit(plot.taskId, 'cable-mount') - 0.5) * roof.width * 0.5;
      final (x, z) = plot.footprint.toWorld(u, roof.z + roof.depth * 0.25);
      return _Mount(x, roof.top + config.mountHeight, z, roof.top);
    }

    final a = mount(from, fromArchitecture);
    final b = mount(to, toArchitecture);
    final directSag = config.sag(groundDistanceBetween(a.x, a.z, b.x, b.z));
    final candidates = <({double t, double top, double deficit})>[];
    for (final solid in solids) {
      final interval = _interval(a, b, solid.footprint, config);
      if (interval == null) continue;
      final (lo, hi) = interval;
      final deficit =
          solid.top +
          config.clearance +
          config.radius -
          _minimum(a.y, b.y, directSag, lo, hi);
      final t = (lo + hi) / 2;
      if (deficit > 0 && t > 0.05 && t < 0.95) {
        candidates.add((t: t, top: solid.top, deficit: deficit));
      }
    }
    candidates.sort((a, b) {
      final byHeight = b.deficit.compareTo(a.deficit);
      return byHeight == 0 ? a.t.compareTo(b.t) : byHeight;
    });
    final chosen = <({double t, double top, double deficit})>[];
    for (final candidate in candidates) {
      if (chosen.length >= config.maxSupports) break;
      if (chosen.any((other) => (other.t - candidate.t).abs() < 0.05)) continue;
      chosen.add(candidate);
    }
    chosen.sort((a, b) => a.t.compareTo(b.t));
    final mounts = [
      a,
      for (final support in chosen)
        _Mount(
          a.x + (b.x - a.x) * support.t,
          support.top + config.mountHeight,
          a.z + (b.z - a.z) * support.t,
          support.top,
        ),
      b,
    ];
    for (var i = 0; i < mounts.length - 1; i++) {
      final left = mounts[i];
      final right = mounts[i + 1];
      final sag = config.sag(
        groundDistanceBetween(left.x, left.z, right.x, right.z),
      );
      for (final solid in solids) {
        final interval = _interval(left, right, solid.footprint, config);
        if (interval == null) continue;
        final (lo, hi) = interval;
        final raise =
            solid.top +
            config.clearance +
            config.radius -
            _minimum(left.y, right.y, sag, lo, hi);
        if (raise > 0) {
          left.y += raise;
          right.y += raise;
        }
      }
    }
    return CablePath._(
      connection: connection,
      supports: List.unmodifiable([
        for (final mount in mounts)
          (x: mount.x, y: mount.y, z: mount.z, baseY: mount.baseY),
      ]),
      config: config,
    );
  }

  final PlazaConnection connection;
  final List<CableSupport> supports;
  late final Float64List positions;
  late final Float64List distances;

  double get length => distances.last;

  /// Writes x/y/z into [output] at [offset], clamping to either endpoint.
  void writePosition(double distance, List<double> output, int offset) {
    final d = distance.clamp(0.0, length);
    var lo = 0;
    var hi = distances.length - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) ~/ 2;
      if (distances[mid] < d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = distances[hi] - distances[lo];
    final t = span == 0 ? 0.0 : (d - distances[lo]) / span;
    for (var axis = 0; axis < 3; axis++) {
      final a = positions[lo * 3 + axis];
      output[offset + axis] = a + (positions[hi * 3 + axis] - a) * t;
    }
  }

  static double _height(double a, double b, double sag, double t) =>
      a + (b - a) * t - 4 * sag * t * (1 - t);

  static double _minimum(double a, double b, double sag, double lo, double hi) {
    final t = sag == 0 ? lo : ((4 * sag + a - b) / (8 * sag)).clamp(lo, hi);
    return math.min(
      _height(a, b, sag, t),
      math.min(_height(a, b, sag, lo), _height(a, b, sag, hi)),
    );
  }

  static (double, double)? _interval(
    _Mount a,
    _Mount b,
    Footprint footprint,
    CableConfig config,
  ) {
    final (u, v) = footprint.local(a.x, a.z);
    final (endU, endV) = footprint.local(b.x, b.z);
    var lo = 0.0;
    var hi = 1.0;
    for (final (start, delta, half) in [
      (u, endU - u, footprint.width / 2 + config.radius + config.clearance),
      (v, endV - v, footprint.depth / 2 + config.radius + config.clearance),
    ]) {
      if (delta.abs() < 1e-12) {
        if (start.abs() > half) return null;
      } else {
        final near = (-half - start) / delta;
        final far = (half - start) / delta;
        lo = math.max(lo, math.min(near, far));
        hi = math.min(hi, math.max(near, far));
        if (lo > hi) return null;
      }
    }
    return (lo, hi);
  }
}

class _Mount {
  _Mount(this.x, this.y, this.z, this.baseY);
  final double x;
  double y;
  final double z;
  final double baseY;
}
