import 'dart:math' as math;

import 'package:lotti/features/character/model/easing.dart';

/// The always-on "alive" signals layered on top of any pose or expression: an
/// asymmetric blink, idle breathing, and micro eye-darts. The plan calls this
/// the soul of a Tamagotchi — a still rig with these reads as alive; a busy rig
/// without them reads as dead.
///
/// It is fully deterministic given a seed (an internal LCG, never
/// `Math.random`/`DateTime.now`), so film strips and tests are reproducible.
class AutonomicSample {
  const AutonomicSample({
    required this.eyeOpen,
    required this.eyeDartX,
    required this.eyeDartY,
    required this.breath,
  });

  /// Eyelid openness multiplier 0..1 (1 = fully open, 0 = mid-blink).
  final double eyeOpen;

  /// Small gaze offset, roughly -1..1 in each axis.
  final double eyeDartX;
  final double eyeDartY;

  /// Breathing signal, roughly -1..1, for a subtle torso scale / body drift.
  final double breath;
}

class AutonomicLayer {
  AutonomicLayer({
    this.seed = 1,
    this.blinkIntervalBase = 3.2,
    this.blinkIntervalJitter = 2.6,
    this.blinkCloseDuration = 0.07,
    this.blinkOpenDuration = 0.16,
    this.breathPeriod = 4.0,
    this.breathAmplitude = 1.0,
    this.eyeDartInterval = 1.7,
    this.eyeDartAmplitude = 0.5,
  });

  final int seed;

  /// Mean and jitter of the gap between blinks, seconds.
  final double blinkIntervalBase;
  final double blinkIntervalJitter;

  /// Asymmetric blink timing — a fast close, a slower open (a symmetric blink
  /// reads as robotic).
  final double blinkCloseDuration;
  final double blinkOpenDuration;

  final double breathPeriod;
  final double breathAmplitude;

  final double eyeDartInterval;
  final double eyeDartAmplitude;

  AutonomicSample sampleAt(double t) => AutonomicSample(
    eyeOpen: _eyeOpenAt(t),
    eyeDartX: _eyeDart(t, 0x9e37),
    eyeDartY: _eyeDart(t, 0x6b3f) * 0.5,
    breath: math.sin(2 * math.pi * t / breathPeriod) * breathAmplitude,
  );

  /// Deterministic [0,1) value for the [index]-th draw of a stream keyed by
  /// [stream]. A small splittable-style hash — no global RNG state.
  double _rand(int stream, int index) {
    var x =
        (seed * 0x2545F491 + stream * 0x9E3779B1 + index * 0x85EBCA77) &
        0x7FFFFFFF;
    x ^= x >> 13;
    x = (x * 0x5bd1e995) & 0x7FFFFFFF;
    x ^= x >> 15;
    return (x & 0xFFFFFF) / 0x1000000;
  }

  // A resumable cursor into the blink schedule: blink [_cursorIndex] starts at
  // [_cursorStart], and the gap leading into it begins at [_cursorPrevEnd] (the
  // end of the previous blink). The schedule is built from t=0 by accumulating
  // jittered gaps, so naively it would be re-walked from 0 every frame —
  // O(elapsed). Since the live widget samples a monotonically increasing t, we
  // resume from the cursor instead: in the steady state a gap frame does zero
  // loop iterations and zero `_rand` calls, and we only draw a new random gap
  // when t actually crosses a blink's end (once per blink, not per frame). A
  // backward seek (t < [_cursorPrevEnd]) restarts the walk from t=0, so the
  // result stays a pure, bit-identical function of t and remains deterministic.
  late double _cursorStart = _firstBlinkStart;
  double _cursorPrevEnd = 0;
  int _cursorIndex = 0;

  /// Initial gap so the character doesn't blink at t=0.
  double get _firstBlinkStart =>
      blinkIntervalBase * (0.35 + _rand(3, 0) * 0.35);

  double _eyeOpenAt(double t) {
    if (t < 0) return 1;
    final blinkSpan = blinkCloseDuration + blinkOpenDuration;
    // Resume from the cached cursor only while t is within its validity window
    // (at or past the gap leading into the cursor blink); otherwise walk anew.
    final resume = t >= _cursorPrevEnd;
    var blinkStart = resume ? _cursorStart : _firstBlinkStart;
    var prevEnd = resume ? _cursorPrevEnd : 0.0;
    var i = resume ? _cursorIndex : 0;
    // Defensive bound: with a positive interval the loop always terminates for
    // finite t; the cap only guards a degenerate (non-positive) configuration.
    for (var guard = 0; guard < 1000000; guard++) {
      if (t < blinkStart) {
        // In the gap before blink i; cache it so later gap frames do no work.
        _cursorStart = blinkStart;
        _cursorPrevEnd = prevEnd;
        _cursorIndex = i;
        return 1;
      }
      final end = blinkStart + blinkSpan;
      if (t <= end) {
        _cursorStart = blinkStart;
        _cursorPrevEnd = prevEnd;
        _cursorIndex = i;
        return _blinkCurve(t - blinkStart);
      }
      // Crossed the end of blink i — draw its trailing gap and advance.
      final gap = blinkIntervalBase + _rand(1, i) * blinkIntervalJitter;
      prevEnd = end;
      blinkStart = end + gap;
      i++;
    }
    return 1;
  }

  double _blinkCurve(double dt) {
    if (dt <= blinkCloseDuration) {
      final local = dt / blinkCloseDuration;
      return 1 - Ease.easeIn.apply(local);
    }
    final local = (dt - blinkCloseDuration) / blinkOpenDuration;
    return Ease.easeOut.apply(local);
  }

  double _eyeDart(double t, int stream) {
    if (t < 0) return 0;
    final idx = (t / eyeDartInterval).floor();
    final phaseInSlot = (t - idx * eyeDartInterval) / eyeDartInterval;
    final from = (_rand(stream, idx) * 2 - 1) * eyeDartAmplitude;
    final to = (_rand(stream, idx + 1) * 2 - 1) * eyeDartAmplitude;
    // Saccades are fast then hold: snap most of the way early, then settle.
    final blend = Ease.easeOut.apply((phaseInSlot * 4).clamp(0.0, 1.0));
    return from + (to - from) * blend;
  }
}
