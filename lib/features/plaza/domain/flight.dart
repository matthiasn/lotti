/// Camera flights: the only way the camera moves other than walking.
///
/// Pure Dart. A flight is planned once from two poses and evaluated by
/// normalised time, so it is testable without a clock.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';

/// A planned camera flight between two poses.
class Flight {
  Flight._({
    required this.from,
    required this.to,
    required this.duration,
    required this.arc,
  });

  /// Plans a flight from [from] to [to].
  ///
  /// Duration grows with the square root of distance (0.8 s to 2.5 s, before
  /// [timeScale]); flights over [arcThreshold] metres rise into an arc
  /// proportional to distance so the route stays legible.
  factory Flight.plan(CameraPose from, CameraPose to, {double timeScale = 1}) {
    final dist = from.distanceTo(to);
    final seconds = (0.32 * math.sqrt(dist)).clamp(0.8, 2.5) / timeScale;
    final dx = to.x - from.x;
    final dz = to.z - from.z;
    final ground = math.sqrt(dx * dx + dz * dz);
    // The arc is for crossing the district; a climb is already an arc.
    final horizontal = dist == 0 ? 1.0 : (ground / dist).clamp(0.0, 1.0);
    return Flight._(
      from: from,
      to: to,
      duration: Duration(microseconds: (seconds * 1e6).round()),
      arc: dist > arcThreshold ? math.min(45, dist * 0.22) * horizontal : 0,
    );
  }

  static const arcThreshold = 60.0;

  /// Flights shorter than this on the ground keep a direct yaw blend; the
  /// heading would swing too fast to be worth turning into.
  static const lookAlongThreshold = 8.0;

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

  /// Peak extra height at the middle of the flight, world meters.
  final double arc;

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

  /// Ease-in-out (quadratic) along the path, the height arc, and a yaw
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
    // Over an arc the camera looks down at the district it is crossing,
    // then levels out to the destination's pitch.
    final lift = arc * math.sin(math.pi * s);
    final pitchDip = arc == 0 ? 0.0 : -math.atan2(lift, 40) * 0.9;
    return CameraPose(
      x: from.x + (to.x - from.x) * s,
      y: from.y + (to.y - from.y) * s + lift,
      z: from.z + (to.z - from.z) * s,
      yaw: yaw,
      pitch: from.pitch + (to.pitch - from.pitch) * s + pitchDip,
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
