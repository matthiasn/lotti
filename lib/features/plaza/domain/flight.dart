/// Camera flights: the only way the camera moves other than walking.
///
/// Pure Dart. A flight is planned once, from two poses and the world's
/// solids, with collision-checked curved joins between the guide legs and
/// one eased speed profile over the whole way. A precomputed timing spline
/// limits translation and rotation without abrupt changes between samples.
/// [Flight.plan] is the direct line, lifted over whatever stands on it;
/// [Flight.route] follows the street between two stops on the ground.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:meta/meta.dart';

part 'flight_leg_part.dart';

/// A planned camera flight between two poses.
class Flight {
  Flight._({
    required this.from,
    required this.to,
    required List<_Leg> legs,
    required _Profile profile,
    required this.routed,
    required List<Solid> solids,
    double? wayEnd,
  }) : _legs = legs,
       _profile = profile,
       _bends = _Bend.plan(legs, solids),
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
    final obstacles = solids.toList();
    final leg = _Leg.plan(from, to, obstacles, districtArc: true);
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
      solids: obstacles,
    );
  }

  /// Plans the flight from [from] to [to] along the street: through every
  /// guide point of [via] in order at [streetFlightHeight], cruising at
  /// [streetSpeed] and looking [lookAhead] metres down the way, so the
  /// facades and billboards pass by. Corners are rounded within [cornerRadius];
  /// bends shrink until their entire Bezier hull clears [solids].
  factory Flight.route(
    CameraPose from,
    CameraPose to, {
    required List<(double, double)> via,
    Iterable<Solid> solids = const [],
  }) {
    final obstacles = solids.toList();
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
        _Leg.plan(points[i - 1], points[i], obstacles, districtArc: false),
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
      solids: obstacles,
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

  /// Maximum guide distance trimmed on each side of a street corner.
  static const cornerRadius = 8.0;

  /// A stop beside the road joins it, and leaves it, on a diagonal this
  /// long along the way (see `StreetNetwork.pathBetween`).
  static const joinDistance = 8.0;

  /// A via point this close to the previous point is dropped.
  static const viaMergeDistance = 0.5;

  static const arcThreshold = 60.0;

  /// How far above a solid's top, or below its bottom, legs and rounded
  /// bends must stay to count as clearing it; a lift ends this high.
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

  late final _FlightTiming _timing = _FlightTiming(
    _profile.duration,
    _basePoseAt,
    routed ? streetSpeed : directSpeed,
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
  final List<_Bend> _bends;

  /// Guide distance, world metres, before rounding corners or adding lift.
  double get length => _profile.length;

  /// How many guide legs the smoothed path follows.
  @visibleForTesting
  int get legCount => _legs.length;

  /// The speed the flight cruises at once its ramp is done, and how long
  /// each ramp takes; both shrink on a hop too short to reach the cruise.
  @visibleForTesting
  double get cruiseSpeed => _profile.v;
  @visibleForTesting
  double get rampTime => _profile.t;

  /// Maximum planned obstacle lift among the guide legs, world metres.
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
    // Hand over to the next leg once [d] passes a leg's end; the last leg
    // absorbs any overshoot. Every flight has at least one leg.
    var start = 0.0;
    var index = 0;
    while (index < _legs.length - 1 && d > start + _legs[index].length) {
      start += _legs[index].length;
      index++;
    }
    final leg = _legs[index];
    final f = leg.length == 0 ? 1.0 : ((d - start) / leg.length);
    return (leg, f.clamp(0.0, 1.0));
  }

  /// The curved position at guide distance [d], including obstacle clearance.
  _Point _positionAt(double d) {
    for (final bend in _bends) {
      if (d >= bend.start && d <= bend.end) {
        return bend.at((d - bend.start) / (bend.end - bend.start));
      }
    }
    final (leg, f) = _locate(d);
    return leg.pointAt(f);
  }

  (double, double) _groundAt(double d) {
    final p = _positionAt(d);
    return (p.x, p.z);
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
    final p = _positionAt(d);
    final x = p.x;
    final z = p.z;
    final y = p.y;
    final lift = math.max(0, y - _lerp(leg.from.y, leg.to.y, f));
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
    final (leg, _) = _locate(d);
    final p = _positionAt(d);
    return _lookAheadYaw(d, p.x, p.z, leg);
  }

  /// The heading from ([x], [z]) to the point [lookAhead] metres further
  /// along the way, which ends where the way leaves the road; past that,
  /// the road's last heading.
  double _lookAheadYaw(double d, double x, double z, _Leg leg) {
    // The rounded pull-off must not steer the camera toward the stop before
    // its final orientation blend: look only as far as the last straight.
    final lastBend = _bends.isEmpty ? null : _bends.last;
    final roadEnd =
        arrival &&
            lastBend != null &&
            lastBend.start < _wayEnd &&
            lastBend.end > _wayEnd
        ? lastBend.start
        : _wayEnd;
    final ahead = math.min(roadEnd, d + lookAhead);
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
