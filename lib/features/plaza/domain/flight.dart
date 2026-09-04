/// Camera flights: the only way the camera moves other than walking.
///
/// Pure Dart. A flight is planned once from two poses and evaluated by
/// normalised time, so it is testable without a clock. Planned over the
/// world's solids, it lifts over everything its line would cross.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';

/// A planned camera flight between two poses.
class Flight {
  Flight._({
    required this.from,
    required this.to,
    required this.duration,
    required this.arc,
    required this.rampStart,
    required this.rampEnd,
  });

  /// Plans a flight from [from] to [to].
  ///
  /// Duration grows with the square root of distance (0.8 s to 2.5 s, before
  /// [timeScale]). The straight line is swept against [solids]: whatever it
  /// would pass through, the flight lifts over by [clearance], climbing
  /// before the first solid on the way and descending after the last.
  /// Flights over [arcThreshold] metres rise into an arc proportional to
  /// distance regardless, so the route stays legible.
  factory Flight.plan(
    CameraPose from,
    CameraPose to, {
    double timeScale = 1,
    Iterable<Solid> solids = const [],
  }) {
    final dist = from.distanceTo(to);
    final seconds = (0.32 * math.sqrt(dist)).clamp(0.8, 2.5) / timeScale;
    final dx = to.x - from.x;
    final dz = to.z - from.z;
    final ground = math.sqrt(dx * dx + dz * dz);
    // The arc is for crossing the district; a climb is already an arc.
    final horizontal = dist == 0 ? 1.0 : (ground / dist).clamp(0.0, 1.0);
    final districtArc = dist > arcThreshold
        ? math.min(45, dist * 0.22) * horizontal
        : 0.0;

    // Where the line enters and leaves each solid, seen from above;
    // whether the height matters is decided below.
    final spans = <_Span>[
      for (final solid in solids) ?_span(from, to, solid),
    ];
    // Lifting over one solid can raise the line into another it would
    // have passed under (a gantry beam), so the set grows until it holds.
    final lifted = <_Span>{
      for (final span in spans)
        if (span.blocks(from, to, (_) => 0)) span,
    };
    var arc = districtArc;
    var rampStart = defaultRamp;
    var rampEnd = defaultRamp;
    while (true) {
      if (lifted.isNotEmpty) {
        var first = 1.0;
        var last = 0.0;
        for (final span in lifted) {
          first = math.min(first, span.sIn);
          last = math.max(last, span.sOut);
        }
        rampStart = (rampFit * first).clamp(minRamp, defaultRamp);
        rampEnd = (rampFit * (1 - last)).clamp(minRamp, defaultRamp);
        arc = districtArc;
        for (final span in lifted) {
          for (final s in span.samples) {
            final need = span.ceiling - _lerp(from.y, to.y, s);
            if (need <= 0) continue;
            final profile = math.max(
              _profile(s, rampStart, rampEnd),
              profileFloor,
            );
            arc = math.max(arc, need / profile);
          }
        }
      }
      final rs = rampStart;
      final re = rampEnd;
      final a = arc;
      final grown = spans
          .where((span) => !lifted.contains(span))
          .where(
            (span) => span.blocks(from, to, (s) => a * _profile(s, rs, re)),
          )
          .toList();
      if (grown.isEmpty) break;
      lifted.addAll(grown);
    }
    return Flight._(
      from: from,
      to: to,
      duration: Duration(microseconds: (seconds * 1e6).round()),
      arc: arc,
      rampStart: rampStart,
      rampEnd: rampEnd,
    );
  }

  static const arcThreshold = 60.0;

  /// How far above a solid's top, or below its bottom, the line must stay
  /// to count as clearing it; the lift over a solid ends this high.
  static const clearance = 1.5;

  /// The lift profile: a climb over the first [rampStart] of the way, a
  /// cruise, a descent over the last [rampEnd]. The default ramps make an
  /// arc of a district crossing; over solids the ramps shrink to
  /// [rampFit] of the way to the first and from the last, so the cruise
  /// height is reached before the first wall and held past the last one.
  /// A stop a step from a wall the line crosses makes a ramp as short as
  /// [minRamp]: a near-vertical climb or drop beside that wall, which is
  /// the only path there is.
  static const defaultRamp = 0.35;
  static const minRamp = 0.005;
  static const rampFit = 0.85;

  /// A pose inside a solid would ask for an unbounded lift at a ramp's
  /// foot; the profile is floored here, which bounds the ask. The stop
  /// poses stand outside every solid, so they never reach it.
  static const profileFloor = 0.3;

  /// Flights shorter than this on the ground keep a direct yaw blend; the
  /// heading would swing too fast to be worth turning into.
  static const lookAlongThreshold = 8.0;

  /// The fraction of the way (0..1) the line spends over [solid]'s
  /// footprint, or null when it misses.
  static _Span? _span(CameraPose from, CameraPose to, Solid solid) {
    final f = solid.footprint;
    final (u0, v0) = f.local(from.x, from.z);
    final (u1, v1) = f.local(to.x, to.z);
    var sIn = 0.0;
    var sOut = 1.0;
    for (final (a, b, half) in [
      (u0, u1, f.width / 2),
      (v0, v1, f.depth / 2),
    ]) {
      final d = b - a;
      if (d.abs() < 1e-9) {
        if (a.abs() >= half) return null;
        continue;
      }
      final t0 = (-half - a) / d;
      final t1 = (half - a) / d;
      sIn = math.max(sIn, math.min(t0, t1));
      sOut = math.min(sOut, math.max(t0, t1));
      if (sIn >= sOut) return null;
    }
    return _Span(
      sIn: sIn,
      sOut: sOut,
      floor: solid.bottom - clearance,
      ceiling: solid.top + clearance,
    );
  }

  static double _lerp(double a, double b, double s) => a + (b - a) * s;

  static double _profile(double s, double rampStart, double rampEnd) {
    if (s < rampStart) return _smooth(s / rampStart);
    if (s > 1 - rampEnd) return _smooth((1 - s) / rampEnd);
    return 1;
  }

  /// Horizontal distance of the trip.
  double get groundDistance {
    final dx = to.x - from.x;
    final dz = to.z - from.z;
    return math.sqrt(dx * dx + dz * dz);
  }

  /// Fraction of the trip that is horizontal (0 = straight up/down).
  double get horizontalFraction {
    final total = from.distanceTo(to);
    return total == 0 ? 1 : (groundDistance / total).clamp(0.0, 1.0);
  }

  /// The heading of travel, or null for a short hop or a mostly vertical
  /// trip (a climb to the overview must not whip round to face its path).
  double? get travelYaw {
    if (groundDistance < lookAlongThreshold) return null;
    if (horizontalFraction < 0.55) return null;
    final dx = to.x - from.x;
    final dz = to.z - from.z;
    return math.atan2(dx, dz);
  }

  final CameraPose from;
  final CameraPose to;
  final Duration duration;

  /// Peak extra height over the straight line, world meters.
  final double arc;

  /// The fraction of the way the climb takes, and the descent.
  final double rampStart;
  final double rampEnd;

  /// Extra height over the straight line at [s] of the way (0..1).
  double liftAt(double s) => arc * _profile(s, rampStart, rampEnd);

  Duration _elapsed = Duration.zero;

  Duration get elapsed => _elapsed;
  bool get done => _elapsed >= duration;

  /// Advances the flight and returns the pose for this frame.
  CameraPose advance(Duration dt) {
    _elapsed += dt;
    if (_elapsed > duration) _elapsed = duration;
    return poseAt(progress);
  }

  /// Normalised progress, 0..1.
  double get progress => duration == Duration.zero
      ? 1
      : (_elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);

  /// Ease-in-out (quadratic) along the path, the height lift, and a yaw
  /// that turns into the direction of travel for the middle of the flight
  /// and settles onto the target heading at the end — so the camera never
  /// slides sideways or backwards through the street. Short hops blend yaw
  /// directly.
  CameraPose poseAt(double t) {
    // Smootherstep: continuous acceleration, no kick at the midpoint.
    final s = t * t * t * (t * (t * 6 - 15) + 10);
    final along = travelYaw;
    final double yaw;
    if (along == null) {
      yaw = _turn(from.yaw, to.yaw, s);
    } else if (t < 0.35) {
      // Turn while the body is already moving, not before.
      yaw = _turn(from.yaw, along, _smooth(t / 0.35));
    } else if (t < 0.75) {
      yaw = along;
    } else {
      yaw = _turn(along, to.yaw, _smooth((t - 0.75) / 0.25));
    }
    // Over a lift the camera looks down at what it crosses, then levels
    // out to the destination's pitch.
    final lift = liftAt(s);
    final pitchDip = arc == 0 ? 0.0 : -math.atan2(lift, 40) * 0.9;
    return CameraPose(
      x: _lerp(from.x, to.x, s),
      y: _lerp(from.y, to.y, s) + lift,
      z: _lerp(from.z, to.z, s),
      yaw: yaw,
      pitch: _lerp(from.pitch, to.pitch, s) + pitchDip,
    );
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);

  /// Interpolates a heading the short way round.
  static double _turn(double a, double b, double s) {
    var d = b - a;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return a + d * s;
  }
}

/// The stretch of a flight's line over one solid's footprint, with the
/// heights the line must stay above or below.
class _Span {
  const _Span({
    required this.sIn,
    required this.sOut,
    required this.floor,
    required this.ceiling,
  });

  final double sIn;
  final double sOut;
  final double floor;
  final double ceiling;

  static const sampleCount = 12;

  /// Points along the stretch, both ends included.
  Iterable<double> get samples sync* {
    for (var k = 0; k <= sampleCount; k++) {
      yield sIn + (sOut - sIn) * k / sampleCount;
    }
  }

  /// Whether the line, raised by [lift] at each point, enters the solid's
  /// band of height anywhere along the stretch.
  bool blocks(CameraPose from, CameraPose to, double Function(double) lift) {
    for (final s in samples) {
      final y = from.y + (to.y - from.y) * s + lift(s);
      if (y > floor && y < ceiling) return true;
    }
    return false;
  }
}
