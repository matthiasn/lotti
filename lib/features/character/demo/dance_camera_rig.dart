import 'package:lotti/features/character/demo/dance_camera_director.dart';

/// Default smoothing time (seconds) for the dance camera rig. Roughly how long a
/// framing change takes to resolve, so re-stagings read as deliberate dolly
/// moves rather than snaps. Tuned for a graceful, high-production-value glide;
/// the one hard cut in the piece bypasses it (see [DanceCameraRig.update]).
const double kDanceCameraSmoothTime = 0.7;

/// Critically-damped smoothing toward [target] — the standard SmoothDamp. Unlike
/// a first-order lag it eases BOTH in and out (an S-shaped approach) with no
/// overshoot, which is what makes a move read as an intentional dolly rather than
/// a spring or a snap. Returns the new value and the carried [velocity] (the
/// caller threads velocity across frames). Frame-rate independent in [dt].
({double value, double velocity}) smoothDamp({
  required double current,
  required double target,
  required double velocity,
  required double smoothTime,
  required double dt,
}) {
  if (dt <= 0) return (value: current, velocity: velocity);
  // Guard against a zero/negative time constant (would divide by zero).
  final st = smoothTime < 1e-4 ? 1e-4 : smoothTime;
  final omega = 2 / st;
  final x = omega * dt;
  // Rational approximation of exp(-x); cheaper and stable for the tick rates here.
  final exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
  final change = current - target;
  final temp = (velocity + omega * change) * dt;
  var newVelocity = (velocity - omega * temp) * exp;
  var output = target + (change + temp) * exp;
  // Clamp overshoot so a fast move parks exactly on target instead of sailing
  // past it (which would read as a wobble, not a dolly settle).
  if ((target - current > 0) == (output > target)) {
    output = target;
    newVelocity = (output - target) / dt;
  }
  return (value: output, velocity: newVelocity);
}

/// The dolly operator: holds the live camera [current] and eases it toward the
/// director's per-frame [Shot] target so every framing change becomes a smooth,
/// motivated move. The ONE exception is a flagged hard cut (the reserved hero
/// arrival), which snaps instantly — the single cut in an otherwise all-dolly
/// piece. Stateful by design (a dolly has momentum); the director that produces
/// the targets stays pure.
class DanceCameraRig {
  DanceCameraRig({this.smoothTime = kDanceCameraSmoothTime});

  /// Seconds-scale smoothing constant shared by all three shot components, so
  /// zoom and pan arrive together as one coordinated move.
  final double smoothTime;

  Shot _current = (zoom: 1, dx: 0, dy: 0);
  double _velZoom = 0;
  double _velDx = 0;
  double _velDy = 0;
  bool _initialized = false;

  /// The eased camera as of the last [update].
  Shot get current => _current;

  /// Whether the rig has snapped to its first target yet (before this it has no
  /// meaningful momentum).
  bool get isInitialized => _initialized;

  /// Advance one frame toward [target]. A [cut] (or the very first frame) snaps
  /// instantly and clears momentum; otherwise each component eases as a
  /// critically-damped dolly over [smoothTime]. A non-positive [dt] holds the
  /// current framing (unless it is a snap). Returns the new [current].
  Shot update({
    required Shot target,
    required bool cut,
    required double dt,
  }) {
    if (!_initialized || cut) {
      _current = target;
      _velZoom = 0;
      _velDx = 0;
      _velDy = 0;
      _initialized = true;
      return _current;
    }
    if (dt <= 0) return _current;
    final z = smoothDamp(
      current: _current.zoom,
      target: target.zoom,
      velocity: _velZoom,
      smoothTime: smoothTime,
      dt: dt,
    );
    final x = smoothDamp(
      current: _current.dx,
      target: target.dx,
      velocity: _velDx,
      smoothTime: smoothTime,
      dt: dt,
    );
    final y = smoothDamp(
      current: _current.dy,
      target: target.dy,
      velocity: _velDy,
      smoothTime: smoothTime,
      dt: dt,
    );
    _velZoom = z.velocity;
    _velDx = x.velocity;
    _velDy = y.velocity;
    return _current = (zoom: z.value, dx: x.value, dy: y.value);
  }
}
