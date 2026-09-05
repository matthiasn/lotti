/// Camera flights: the only way the camera moves other than walking.
///
/// Pure Dart. A flight is planned once, from two poses and the world's
/// solids, as a chain of straight legs with one speed profile over the
/// whole way: an S-curve that eases up to a cruise and eases down again.
/// [Flight.plan] is the direct line, lifted over whatever stands on it;
/// [Flight.route] follows the street between two stops on the ground.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:meta/meta.dart';

double _lerp(double a, double b, double s) => a + (b - a) * s;

/// A planned camera flight between two poses.
class Flight {
  Flight._({
    required this.from,
    required this.to,
    required List<_Leg> legs,
    required _Profile profile,
    required this.routed,
    double? wayEnd,
    // A private field cannot be a named initializing formal.
    // ignore: prefer_initializing_formals
  }) : _legs = legs,
       _profile = profile,
       _wayEnd = wayEnd ?? profile.length;

  /// Plans the direct flight from [from] to [to]: one straight leg, swept
  /// against [solids] and lifted over whatever it would pass through
  /// ([clearance] above it), climbing before the first solid on the way
  /// and descending after the last; trips over [arcThreshold] metres rise
  /// into an arc proportional to distance regardless, so the route stays
  /// legible. Cruises at [directSpeed].
  factory Flight.plan(
    CameraPose from,
    CameraPose to, {
    Iterable<Solid> solids = const [],
  }) {
    final leg = _Leg.plan(from, to, solids, districtArc: true);
    return Flight._(
      from: from,
      to: to,
      legs: [leg],
      profile: _Profile(
        length: leg.length,
        cruise: directSpeed,
        ramp: rampSeconds,
      ),
      routed: false,
    );
  }

  /// Plans the flight from [from] to [to] along the street: through every
  /// point of [via] in order at [streetFlightHeight], cruising at
  /// [streetSpeed] and looking [lookAhead] metres down the way, so the
  /// facades and the billboards pass by and a corner is turned, not cut.
  /// Every leg is still swept against [solids].
  factory Flight.route(
    CameraPose from,
    CameraPose to, {
    required List<(double, double)> via,
    Iterable<Solid> solids = const [],
  }) {
    final points = <CameraPose>[from];
    for (final (x, z) in via) {
      if (_apart(points.last, x, z) < viaMergeDistance) continue;
      points.add(CameraPose(x: x, y: streetFlightHeight, z: z, yaw: 0));
    }
    // The stop itself, not a via point a step short of it; otherwise the
    // last leg is the hop off the way to the stop.
    final onWay =
        points.length > 1 && _apart(points.last, to.x, to.z) < viaMergeDistance;
    if (onWay) points.removeLast();
    final hop = points.length > 1 && !onWay;
    points.add(to);
    final legs = <_Leg>[
      for (var i = 1; i < points.length; i++)
        _Leg.plan(points[i - 1], points[i], solids, districtArc: false),
    ];
    var length = 0.0;
    for (final leg in legs) {
      length += leg.length;
    }
    return Flight._(
      from: from,
      to: to,
      legs: legs,
      profile: _Profile(
        length: length,
        cruise: streetSpeed,
        ramp: rampSeconds,
      ),
      routed: true,
      wayEnd: hop ? length - legs.last.length : length,
    );
  }

  static double _apart(CameraPose p, double x, double z) =>
      groundDistanceBetween(p.x, p.z, x, z);

  /// Cruise speeds, world metres per second: down a street, and on the
  /// direct line (a climb to the overview, a dive back).
  static const streetSpeed = 10.0;
  static const directSpeed = 36.0;

  /// The speed ramps up over this long and down over this long, on a
  /// smoothstep, so acceleration starts and ends at zero; a short hop
  /// shortens both ramps and never reaches the cruise.
  static const rampSeconds = 1.6;

  /// Maximum rotation rates, radians per second. Turning stretches only
  /// the affected sections of the flight, preserving its collision-safe path.
  static const double maxYawSpeed = math.pi / 4;
  static const double maxPitchSpeed = math.pi / 6;

  /// A street flight cruises this high above the road: over the parade,
  /// level with the screens, under every sign and the gantry.
  static const streetFlightHeight = 5.0;

  /// A street flight looks at the point this far ahead along the way.
  static const lookAhead = 12.0;

  /// A stop beside the road joins it, and leaves it, on a diagonal this
  /// long along the way (see `StreetNetwork.pathBetween`).
  static const joinDistance = 8.0;

  /// A via point this close to the previous point is dropped.
  static const viaMergeDistance = 0.5;

  static const arcThreshold = 60.0;

  /// How far above a solid's top, or below its bottom, a leg must stay to
  /// count as clearing it; the lift over a solid ends this high.
  static const clearance = 1.5;

  /// The lift profile of a leg: a climb over the first [rampStart] of it,
  /// a cruise, a descent over the last [rampEnd]. The default ramps make
  /// an arc of a district crossing; over solids the ramps shrink to
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

  final CameraPose from;
  final CameraPose to;

  /// Travel time including the extra time needed for gentle turns.
  late final Duration duration = Duration(
    microseconds: (_timing.seconds * 1e6).ceil(),
  );

  late final _TurnTiming _timing = _TurnTiming(
    _profile.duration,
    _basePoseAt,
  );

  /// Whether the flight follows the street (see [Flight.route]).
  final bool routed;

  /// Where the way leaves the road, metres along the flight: the whole
  /// length when the stop is on the road, else the start of the last leg,
  /// the hop off the way to a stop beside it.
  final double _wayEnd;

  /// Whether the last leg is the hop off the way to a stop beside it: the
  /// camera holds the road's heading through it and turns onto the stop's
  /// own heading over the last ramp, instead of swinging toward the stop
  /// and back.
  bool get arrival => _wayEnd < length;

  final List<_Leg> _legs;
  final _Profile _profile;

  /// The way, world metres, legs summed.
  double get length => _profile.length;

  /// How many straight legs the way has.
  @visibleForTesting
  int get legCount => _legs.length;

  /// The speed the flight cruises at once its ramp is done, and how long
  /// each ramp takes; both shrink on a hop too short to reach the cruise.
  @visibleForTesting
  double get cruiseSpeed => _profile.v;
  @visibleForTesting
  double get rampTime => _profile.t;

  /// Peak extra height over the straight line of any leg, world meters.
  double get arc => _legs.fold(0, (m, leg) => math.max(m, leg.arc));

  /// The first leg's ramps, as fractions of that leg.
  @visibleForTesting
  double get rampStart => _legs.first.rampStart;
  @visibleForTesting
  double get rampEnd => _legs.first.rampEnd;

  /// Extra height over the straight line [s] of the way along (0..1).
  @visibleForTesting
  double liftAt(double s) {
    final (leg, f) = _locate(s.clamp(0.0, 1.0) * length);
    return leg.liftAt(f);
  }

  /// Horizontal distance of the trip, end to end.
  double get groundDistance =>
      groundDistanceBetween(from.x, from.z, to.x, to.z);

  /// Fraction of the trip that is horizontal (0 = straight up/down).
  double get horizontalFraction {
    final total = from.distanceTo(to);
    return total == 0 ? 1 : (groundDistance / total).clamp(0.0, 1.0);
  }

  /// The heading of a direct flight's travel, or null for a short hop or
  /// a mostly vertical trip (a climb to the overview must not whip round
  /// to face its path).
  late final double? travelYaw = _travelYaw();

  double? _travelYaw() {
    if (groundDistance < lookAlongThreshold) return null;
    if (horizontalFraction < 0.55) return null;
    return math.atan2(to.x - from.x, to.z - from.z);
  }

  /// The way's headings where the first ramp ends and where the last one
  /// starts: fixed for the flight, so the side the camera turns to over a
  /// ramp is settled once.
  late final double _rampInHeading = _wayHeadingAt(_profile.rampDistance);
  late final double _rampOutHeading = _wayHeadingAt(
    length - _profile.rampDistance,
  );

  Duration _elapsed = Duration.zero;

  @visibleForTesting
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

  /// How far along the way the flight is at [t] of its time (0..1).
  double distanceAt(double t) =>
      _profile.distanceAt(_timing.at(t).progress * _profile.duration);

  /// The leg [d] metres along the way is on, and the fraction of it.
  (_Leg, double) _locate(double d) {
    var start = 0.0;
    for (final leg in _legs) {
      if (d <= start + leg.length || identical(leg, _legs.last)) {
        final f = leg.length == 0 ? 1.0 : ((d - start) / leg.length);
        return (leg, f.clamp(0.0, 1.0));
      }
      start += leg.length;
    }
    return (_legs.last, 1);
  }

  /// The point [d] metres along the way, on the ground.
  (double, double) _groundAt(double d) {
    final (leg, f) = _locate(d);
    return (_lerp(leg.from.x, leg.to.x, f), _lerp(leg.from.z, leg.to.z, f));
  }

  /// The pose at [t] of the flight's time (0..1): along the way on the
  /// speed profile, the lift of the leg, and a yaw that turns into the
  /// way during the first ramp, follows it, and settles onto the target
  /// heading during the last; the pitch dips while lifted so the camera
  /// looks down at what it crosses.
  CameraPose poseAt(double t) {
    final sample = _timing.at(t);
    return _basePoseAt(
      sample.progress,
      orientation: (yaw: sample.yaw, pitch: sample.pitch),
    );
  }

  /// Original spatial plan. The timing table changes when each point is
  /// reached; its interpolated orientation bounds rotation between samples.
  CameraPose _basePoseAt(
    double t, {
    ({double yaw, double pitch})? orientation,
  }) {
    final d = _profile.distanceAt(t * _profile.duration);
    final (leg, f) = _locate(d);
    final x = _lerp(leg.from.x, leg.to.x, f);
    final z = _lerp(leg.from.z, leg.to.z, f);
    final lift = leg.liftAt(f);
    final y = _lerp(leg.from.y, leg.to.y, f) + lift;
    if (orientation != null) {
      return CameraPose(
        x: x,
        y: y,
        z: z,
        yaw: orientation.yaw,
        pitch: orientation.pitch,
      );
    }

    final ramp = _profile.rampDistance;
    final total = length;
    // Where in the ramps: 0..1 up the first, 0..1 down the last.
    final inRamp = ramp == 0 ? 1.0 : (d / ramp).clamp(0.0, 1.0);
    final outRamp = ramp == 0
        ? 1.0
        : ((d - (total - ramp)) / ramp).clamp(0.0, 1.0);

    // The ramps blend between two fixed headings (the way's heading where
    // the ramp ends, and where it starts), so the side the camera turns to
    // is settled for the whole ramp; between them the camera looks down
    // the way.
    final double yaw;
    final along = total == 0
        ? null
        : routed
        ? _lookAheadYaw(d, x, z, leg)
        : travelYaw;
    if (along == null) {
      yaw = _blendHeading(from.yaw, to.yaw, _smooth(t));
    } else if (d < ramp) {
      yaw = _blendHeading(from.yaw, _rampInHeading, _smooth(inRamp));
    } else if (d > total - ramp) {
      yaw = _blendHeading(_rampOutHeading, to.yaw, _smooth(outRamp));
    } else {
      yaw = along;
    }

    final double pitch;
    if (routed && total > 0) {
      // Level down the street; the stop's own pitch on arrival.
      pitch = d < ramp
          ? from.pitch * (1 - _smooth(inRamp))
          : d > total - ramp
          ? to.pitch * _smooth(outRamp)
          : 0;
    } else {
      pitch = _lerp(from.pitch, to.pitch, _smooth(t));
    }
    final pitchDip = lift == 0 ? 0.0 : -math.atan2(lift, 40) * 0.9;
    return CameraPose(x: x, y: y, z: z, yaw: yaw, pitch: pitch + pitchDip);
  }

  /// The heading the camera looks in [d] metres along the way: the
  /// look-ahead heading of a routed flight, the travel heading of a direct
  /// one.
  double _wayHeadingAt(double d) {
    if (!routed) return travelYaw ?? to.yaw;
    final (leg, f) = _locate(d);
    final x = _lerp(leg.from.x, leg.to.x, f);
    final z = _lerp(leg.from.z, leg.to.z, f);
    return _lookAheadYaw(d, x, z, leg);
  }

  /// The heading from ([x], [z]) to the point [lookAhead] metres further
  /// along the way, which ends where the way leaves the road; past that,
  /// the road's last heading.
  double _lookAheadYaw(double d, double x, double z, _Leg leg) {
    final ahead = math.min(_wayEnd, d + lookAhead);
    if (ahead <= d + 1e-6) return _heading(_locate(_wayEnd - 1e-6).$1);
    final (ax, az) = _groundAt(ahead);
    final dx = ax - x;
    final dz = az - z;
    if (dx * dx + dz * dz < 1e-6) return _heading(leg);
    return math.atan2(dx, dz);
  }

  static double _heading(_Leg leg) =>
      math.atan2(leg.to.x - leg.from.x, leg.to.z - leg.from.z);

  static double _smooth(double t) => t * t * (3 - 2 * t);

  /// Interpolates a heading the short way round, as a turn of the
  /// direction itself (a slerp of the two unit vectors), so a heading
  /// that crosses the ±π seam of `atan2` between two frames turns the
  /// camera by nothing, not by a full circle. Opposite headings, where the
  /// short way is either way, turn through the angle.
  static double _blendHeading(double a, double b, double s) {
    final ax = math.sin(a);
    final az = math.cos(a);
    final bx = math.sin(b);
    final bz = math.cos(b);
    final dot = (ax * bx + az * bz).clamp(-1.0, 1.0);
    final omega = math.acos(dot);
    if (omega < 1e-4) return a;
    if (omega > math.pi - 1e-3) return _turn(a, b, s);
    final wa = math.sin((1 - s) * omega) / math.sin(omega);
    final wb = math.sin(s * omega) / math.sin(omega);
    return math.atan2(wa * ax + wb * bx, wa * az + wb * bz);
  }

  /// Interpolates a heading the short way round, by angle.
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

/// A bounded table computed once per flight. Each original time interval
/// takes at least enough time to rotate between its endpoints at the limits.
/// Position remains on the original curve; orientation interpolates between
/// knots, so even a sharp look-ahead corner cannot exceed the rotation limits.
class _TurnTiming {
  factory _TurnTiming(
    double travelSeconds,
    CameraPose Function(double) poseAt,
  ) {
    final first = poseAt(0);
    final last = poseAt(1);
    // A pure turn still needs an eased timeline when translation takes no time.
    final baseSeconds = travelSeconds == 0
        ? 1.5 *
              math.max(
                _angle(last.yaw - first.yaw).abs() / Flight.maxYawSpeed,
                (last.pitch - first.pitch).abs() / Flight.maxPitchSpeed,
              )
        : travelSeconds;
    final steps = (baseSeconds * 120).ceil().clamp(1, 4096);
    final times = Float64List(steps + 1);
    final yaws = Float64List(steps + 1)..[0] = first.yaw;
    final pitches = Float64List(steps + 1)..[0] = first.pitch;
    var previous = first;
    for (var i = 1; i <= steps; i++) {
      final pose = poseAt(i / steps);
      final yaw = _angle(pose.yaw - previous.yaw);
      final pitch = pose.pitch - previous.pitch;
      times[i] =
          times[i - 1] +
          math.max(
            baseSeconds / steps,
            math.max(
              yaw.abs() / Flight.maxYawSpeed,
              pitch.abs() / Flight.maxPitchSpeed,
            ),
          );
      yaws[i] = yaws[i - 1] + yaw;
      pitches[i] = pose.pitch;
      previous = pose;
    }
    return _TurnTiming._(times, yaws, pitches);
  }

  const _TurnTiming._(this._times, this._yaws, this._pitches);

  final Float64List _times;
  final Float64List _yaws;
  final Float64List _pitches;

  double get seconds => _times.last;

  static double _angle(double radians) =>
      math.atan2(math.sin(radians), math.cos(radians));

  ({double progress, double yaw, double pitch}) at(double t) {
    final progress = t.clamp(0.0, 1.0);
    final time = progress * seconds;
    var lo = 0;
    var hi = _times.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (_times[mid] <= time) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = _times[hi] - _times[lo];
    final f = span == 0 ? progress : (time - _times[lo]) / span;
    return (
      progress: (lo + f) / (_times.length - 1),
      yaw: _lerp(_yaws[lo], _yaws[hi], f),
      pitch: _lerp(_pitches[lo], _pitches[hi], f),
    );
  }
}

/// One straight leg of a flight, with the lift that keeps it out of the
/// solids on its line.
class _Leg {
  const _Leg({
    required this.from,
    required this.to,
    required this.length,
    required this.arc,
    required this.rampStart,
    required this.rampEnd,
  });

  /// Sweeps the line from [from] to [to] against [solids]: whatever it
  /// would pass through, the leg lifts over. With [districtArc], a leg
  /// over [Flight.arcThreshold] metres rises into an arc regardless.
  factory _Leg.plan(
    CameraPose from,
    CameraPose to,
    Iterable<Solid> solids, {
    required bool districtArc,
  }) {
    final dist = from.distanceTo(to);
    final ground = groundDistanceBetween(from.x, from.z, to.x, to.z);
    // The arc is for crossing the district; a climb is already an arc.
    final horizontal = dist == 0 ? 1.0 : (ground / dist).clamp(0.0, 1.0);
    final baseArc = districtArc && dist > Flight.arcThreshold
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
    var arc = baseArc;
    var rampStart = Flight.defaultRamp;
    var rampEnd = Flight.defaultRamp;
    while (true) {
      if (lifted.isNotEmpty) {
        var first = 1.0;
        var last = 0.0;
        for (final span in lifted) {
          first = math.min(first, span.sIn);
          last = math.max(last, span.sOut);
        }
        rampStart = (Flight.rampFit * first).clamp(
          Flight.minRamp,
          Flight.defaultRamp,
        );
        rampEnd = (Flight.rampFit * (1 - last)).clamp(
          Flight.minRamp,
          Flight.defaultRamp,
        );
        arc = baseArc;
        for (final span in lifted) {
          for (final s in span.samples) {
            final need = span.ceiling - _lerp(from.y, to.y, s);
            if (need <= 0) continue;
            final profile = math.max(
              _profile(s, rampStart, rampEnd),
              Flight.profileFloor,
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
    return _Leg(
      from: from,
      to: to,
      length: dist,
      arc: arc,
      rampStart: rampStart,
      rampEnd: rampEnd,
    );
  }

  final CameraPose from;
  final CameraPose to;

  /// End to end, world metres, the lift not counted.
  final double length;

  /// Peak extra height over the straight line, world meters.
  final double arc;

  /// The fraction of the leg the climb takes, and the descent.
  final double rampStart;
  final double rampEnd;

  /// Extra height over the straight line at [s] of the leg (0..1).
  double liftAt(double s) => arc * _profile(s, rampStart, rampEnd);

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
      floor: solid.bottom - Flight.clearance,
      ceiling: solid.top + Flight.clearance,
    );
  }

  static double _profile(double s, double rampStart, double rampEnd) {
    if (s < rampStart) return Flight._smooth(s / rampStart);
    if (s > 1 - rampEnd) return Flight._smooth((1 - s) / rampEnd);
    return 1;
  }
}

/// The stretch of a leg's line over one solid's footprint, with the
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
      final y = _lerp(from.y, to.y, s) + lift(s);
      if (y > floor && y < ceiling) return true;
    }
    return false;
  }
}

/// The speed profile of a flight: an S-curve up to a cruise and down
/// again. Speed follows a smoothstep over each ramp, so acceleration
/// starts and ends at zero, and the ramps meet in the middle of a way too
/// short to reach the cruise.
class _Profile {
  _Profile({required this.length, required double cruise, required double ramp})
    : assert(length >= 0, 'a way has a length'),
      assert(cruise > 0 && ramp > 0, 'a profile needs a speed and a ramp') {
    if (length == 0) {
      t = 0;
      v = 0;
      cruiseTime = 0;
    } else if (length < cruise * ramp) {
      // No cruise: the ramps take the whole way, shortened so a hop stays
      // brisk (the peak speed scales with the square root of the way).
      t = math.sqrt(length * ramp / cruise);
      v = length / t;
      cruiseTime = 0;
    } else {
      t = ramp;
      v = cruise;
      cruiseTime = (length - cruise * ramp) / cruise;
    }
  }

  final double length;

  /// The cruise speed and the ramp time, as flown.
  late final double v;
  late final double t;
  late final double cruiseTime;

  double get duration => 2 * t + cruiseTime;

  /// The way covered by one ramp: half of what the cruise would cover.
  double get rampDistance => v * t / 2;

  /// The way covered [time] seconds in.
  double distanceAt(double time) {
    if (duration == 0) return length;
    final s = time.clamp(0.0, duration);
    if (s < t) return v * t * _rampWay(s / t);
    if (s <= t + cruiseTime) return rampDistance + v * (s - t);
    return length - v * t * _rampWay((duration - s) / t);
  }

  /// The way covered [tau] of a ramp in, as a fraction of `v × t`: the
  /// integral of the smoothstep speed.
  static double _rampWay(double tau) =>
      tau * tau * tau - tau * tau * tau * tau / 2;
}
