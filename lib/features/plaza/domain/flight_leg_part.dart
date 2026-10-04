part of 'flight.dart';

double _lerp(double a, double b, double s) => a + (b - a) * s;

/// Monotone cubic timing and orientation, computed once per flight. Shared
/// knot derivatives keep velocity continuous; exact cubic derivative bounds
/// stretch the clock when needed to respect the angular speed limits.
class _FlightTiming {
  factory _FlightTiming(
    double travelSeconds,
    CameraPose Function(double) poseAt,
    double speed,
  ) {
    final first = poseAt(0);
    final last = poseAt(1);
    final baseSeconds = travelSeconds == 0
        ? 1.5 *
              math.max(
                _angle(last.yaw - first.yaw).abs() / Flight.maxYawSpeed,
                (last.pitch - first.pitch).abs() / Flight.maxPitchSpeed,
              )
        : travelSeconds;
    final steps = (baseSeconds * 120).ceil().clamp(1, 4096);
    final times = Float64List(steps + 1);
    final intervals = Float64List(steps);
    final progress = Float64List(steps + 1);
    final yaws = Float64List(steps + 1)..[0] = first.yaw;
    final pitches = Float64List(steps + 1)..[0] = first.pitch;
    var previous = first;
    for (var i = 1; i <= steps; i++) {
      final pose = poseAt(i / steps);
      final yaw = _angle(pose.yaw - previous.yaw);
      final pitch = pose.pitch - previous.pitch;
      intervals[i - 1] = math.max(
        math.max(baseSeconds / steps, previous.distanceTo(pose) / speed),
        math.max(
          yaw.abs() / Flight.maxYawSpeed,
          pitch.abs() / Flight.maxPitchSpeed,
        ),
      );
      progress[i] = i / steps;
      yaws[i] = yaws[i - 1] + yaw;
      pitches[i] = pose.pitch;
      previous = pose;
    }
    // Spread each necessary slowdown to both sides before filtering. Every
    // averaging window still contains its original requirement, so smoothing
    // cannot erase a speed limit. This brakes before a tight bend or climb,
    // instead of abruptly changing pace at the limiting sample.
    final radius = baseSeconds == 0
        ? 1
        : (0.35 * steps / baseSeconds).ceil().clamp(1, 120);
    final weights = Float64List(radius + 1);
    for (var i = 0; i <= radius; i++) {
      weights[i] = 1 + math.cos(math.pi * i / (radius + 1));
    }
    final envelope = Float64List(steps);
    for (var i = 0; i < steps; i++) {
      var peak = 0.0;
      for (
        var j = math.max(0, i - radius);
        j <= math.min(steps - 1, i + radius);
        j++
      ) {
        peak = math.max(peak, intervals[j]);
      }
      envelope[i] = peak;
    }
    for (var i = 0; i < steps; i++) {
      var sum = 0.0;
      var totalWeight = 0.0;
      for (
        var j = math.max(0, i - radius);
        j <= math.min(steps - 1, i + radius);
        j++
      ) {
        final weight = weights[(j - i).abs()];
        sum += envelope[j] * weight;
        totalWeight += weight;
      }
      times[i + 1] = times[i] + sum / totalWeight;
    }
    final positions = _Spline(times, progress);
    final headings = _Spline(times, yaws, easeEnds: true);
    final tilts = _Spline(times, pitches, easeEnds: true);
    // A monotone cubic can move faster than its interval's secant. Bound
    // its quadratic derivative analytically instead of sampling at runtime.
    final double stretch = math.max(
      1,
      math.max(
        headings.maxSpeed / Flight.maxYawSpeed,
        tilts.maxSpeed / Flight.maxPitchSpeed,
      ),
    );
    return _FlightTiming._(times, positions, headings, tilts, stretch);
  }

  const _FlightTiming._(
    this._times,
    this._progress,
    this._yaws,
    this._pitches,
    this._stretch,
  );
  final Float64List _times;
  final _Spline _progress;
  final _Spline _yaws;
  final _Spline _pitches;
  final double _stretch;

  double get seconds => _times.last * _stretch;
  static double _angle(double radians) =>
      math.atan2(math.sin(radians), math.cos(radians));

  ({double progress, double yaw, double pitch}) at(double t) {
    final progress = t.clamp(0.0, 1.0);
    final time = progress * _times.last;
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
      progress: _progress.at(lo, f),
      yaw: _yaws.at(lo, f),
      pitch: _pitches.at(lo, f),
    );
  }
}

/// Shape-preserving Hermite interpolation on a nonuniform clock. Harmonic
/// slopes prevent overshoot and join adjacent intervals with the same velocity.
class _Spline {
  _Spline(this.times, this.values, {bool easeEnds = false})
    : slopes = Float64List(values.length) {
    double secant(int i) {
      final dt = times[i + 1] - times[i];
      return dt == 0 ? 0 : (values[i + 1] - values[i]) / dt;
    }

    if (!easeEnds) {
      slopes[0] = secant(0);
      slopes[slopes.length - 1] = secant(values.length - 2);
    }
    for (var i = 1; i < slopes.length - 1; i++) {
      final left = secant(i - 1);
      final right = secant(i);
      if (left * right <= 0) continue;
      final before = times[i] - times[i - 1];
      final after = times[i + 1] - times[i];
      final a = 2 * after + before;
      final b = after + 2 * before;
      slopes[i] = (a + b) / (a / left + b / right);
    }
  }
  final Float64List times;
  final Float64List values;
  final Float64List slopes;

  (double, double, double) coefficients(int i) {
    final span = times[i + 1] - times[i];
    final delta = values[i + 1] - values[i];
    final a = slopes[i] * span;
    final b = slopes[i + 1] * span;
    return (a + b - 2 * delta, 3 * delta - 2 * a - b, a);
  }

  double at(int i, double t) {
    final (a, b, c) = coefficients(i);
    return ((a * t + b) * t + c) * t + values[i];
  }

  double get maxSpeed {
    var result = 0.0;
    for (var i = 0; i < values.length - 1; i++) {
      final span = times[i + 1] - times[i];
      if (span == 0) continue;
      final (a, b, c) = coefficients(i);
      var peak = math.max(c.abs(), (3 * a + 2 * b + c).abs());
      if (a != 0) {
        final t = -b / (3 * a);
        if (t > 0 && t < 1) {
          peak = math.max(peak, ((3 * a * t + 2 * b) * t + c).abs());
        }
      }
      result = math.max(result, peak / span);
    }
    return result;
  }
}

typedef _Point = ({double x, double y, double z});
_Point _mix(_Point a, _Point b, double t) =>
    (x: _lerp(a.x, b.x, t), y: _lerp(a.y, b.y, t), z: _lerp(a.z, b.z, t));

/// A cubic join matching both neighbouring legs' position and tangent.
/// Collision checks use the convex hull of recursively subdivided control
/// points, so a narrow obstacle cannot fall between samples.
class _Bend {
  const _Bend(this.start, this.end, this.a, this.b, this.c, this.d);
  final double start;
  final double end;
  final _Point a;
  final _Point b;
  final _Point c;
  final _Point d;

  static List<_Bend> plan(List<_Leg> legs, List<Solid> solids) {
    final bends = <_Bend>[];
    var along = 0.0;
    for (var i = 1; i < legs.length; i++) {
      final incoming = legs[i - 1];
      final outgoing = legs[i];
      along += incoming.length;
      var radius = math.min(
        Flight.cornerRadius,
        math.min(incoming.length, outgoing.length) * 0.35,
      );
      while (radius > 1e-4) {
        final f = 1 - radius / incoming.length;
        final g = radius / outgoing.length;
        final a = incoming.pointAt(f);
        final d = outgoing.pointAt(g);
        final ta = incoming.tangentAt(f);
        final td = outgoing.tangentAt(g);
        final handle = 2 * radius / 3;
        final bend = _Bend(
          along - radius,
          along + radius,
          a,
          (
            x: a.x + ta.x * handle,
            y: a.y + ta.y * handle,
            z: a.z + ta.z * handle,
          ),
          (
            x: d.x - td.x * handle,
            y: d.y - td.y * handle,
            z: d.z - td.z * handle,
          ),
          d,
        );
        if (solids.every((s) => bend._clears(s, 0))) {
          bends.add(bend);
          break;
        }
        radius /= 2;
      }
    }
    return bends;
  }

  _Point at(double t) {
    final u = 1 - t;
    final wa = u * u * u;
    final wb = 3 * u * u * t;
    final wc = 3 * u * t * t;
    final wd = t * t * t;
    return (
      x: wa * a.x + wb * b.x + wc * c.x + wd * d.x,
      y: wa * a.y + wb * b.y + wc * c.y + wd * d.y,
      z: wa * a.z + wb * b.z + wc * c.z + wd * d.z,
    );
  }

  bool _clears(Solid solid, int depth) {
    final footprint = solid.footprint;
    var minU = double.infinity;
    var maxU = double.negativeInfinity;
    var minV = double.infinity;
    var maxV = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final p in [a, b, c, d]) {
      final (u, v) = footprint.local(p.x, p.z);
      minU = math.min(minU, u);
      maxU = math.max(maxU, u);
      minV = math.min(minV, v);
      maxV = math.max(maxV, v);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    if (minU >= footprint.width / 2 + solidClearance ||
        maxU <= -footprint.width / 2 - solidClearance ||
        minV >= footprint.depth / 2 + solidClearance ||
        maxV <= -footprint.depth / 2 - solidClearance ||
        minY >= solid.top + Flight.clearance ||
        maxY <= solid.bottom - Flight.clearance) {
      return true;
    }
    if (depth >= 10) return false;
    final ab = _mix(a, b, 0.5);
    final bc = _mix(b, c, 0.5);
    final cd = _mix(c, d, 0.5);
    final abc = _mix(ab, bc, 0.5);
    final bcd = _mix(bc, cd, 0.5);
    final mid = _mix(abc, bcd, 0.5);
    return _Bend(start, end, a, ab, abc, mid)._clears(solid, depth + 1) &&
        _Bend(start, end, mid, bcd, cd, d)._clears(solid, depth + 1);
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

  _Point pointAt(double s) => (
    x: _lerp(from.x, to.x, s),
    y: _lerp(from.y, to.y, s) + liftAt(s),
    z: _lerp(from.z, to.z, s),
  );

  _Point tangentAt(double s) {
    var slope = 0.0;
    if (s < rampStart) {
      final t = s / rampStart;
      slope = 6 * t * (1 - t) / rampStart;
    } else if (s > 1 - rampEnd) {
      final t = (1 - s) / rampEnd;
      slope = -6 * t * (1 - t) / rampEnd;
    }
    return (
      x: (to.x - from.x) / length,
      y: (to.y - from.y + arc * slope) / length,
      z: (to.z - from.z) / length,
    );
  }

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
