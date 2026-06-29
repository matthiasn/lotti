import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart'
    show coverFit;
import 'package:lotti/features/scenery/layers/drone_show_layer.dart'
    show kDroneShowCycleSeconds;

/// Number of strobe units in the bridge cordon.
const int kBridgePoliceUnitCount = 13;

/// Police road-closure strobes on the cable-stayed bridge deck.
///
/// A cordon of flashing emergency lights — dominantly **blue** with a few red
/// accents — lines the bridge roadway to stop traffic so the drone formation can
/// launch from the cleared deck. The cordon is timed to the drone-show loop
/// ([kDroneShowCycleSeconds]): it rolls in while the previous formation is still
/// dispersing, holds at full while the drones sit on the road, then clears out as
/// the aircraft climb away — so by the time the show is in the sky the road is
/// dark again. Stateless and deterministic from [BackdropContext.timeSeconds];
/// suppressed entirely under reduce-motion (strobes are exactly the flashing the
/// setting exists to calm).
class BridgePoliceLayer implements BackdropLayer {
  const BridgePoliceLayer({
    this.cycleSeconds = kDroneShowCycleSeconds,
    this.unitCount = kBridgePoliceUnitCount,
  });

  /// Length of the drone-show loop this cordon is timed against.
  final double cycleSeconds;

  /// How many strobe units span the roadway.
  final int unitCount;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    if (ctx.reducedMotion) return;
    final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
    final cordon = trafficStopIntensity(_fraction(ctx.timeSeconds / safeCycle));
    if (cordon <= 0) return;

    final cover = coverFit(ctx.size);
    final units = policeCordonPoints(count: unitCount);
    final r = cover.width * 0.0016;
    final blue = ctx.palette.policeBlue;
    final red = ctx.palette.policeRed;
    final haloPaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    final corePaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    final reflectPaint = ui.Paint()..blendMode = ui.BlendMode.plus;

    for (final unit in units) {
      final intensity = policeStrobe(ctx.timeSeconds, unit.phase) * cordon;
      final c = Offset(
        cover.left + unit.position.dx * cover.width,
        cover.top + unit.position.dy * cover.height,
      );
      final color = unit.isRed ? red : blue;
      // A tight steep-falloff halo around a hot near-white core — a vehicle LED
      // bar, not a soft bubble.
      haloPaint.shader = ui.Gradient.radial(
        c,
        r * 3.4,
        [
          color.withValues(alpha: 0.40 * intensity),
          color.withValues(alpha: 0.10 * intensity),
          color.withValues(alpha: 0),
        ],
        [0.0, 0.4, 1.0],
      );
      corePaint.color = ui.Color.lerp(
        color,
        const ui.Color(0xFFFFFFFF),
        0.6,
      )!.withValues(alpha: 0.82 * intensity);
      // A short vertical smear below the lamp: the strobe glancing off the wet
      // roadway, so the cordon sits ON the deck instead of floating over it.
      canvas
        ..drawCircle(c, r * 3.4, haloPaint)
        ..save()
        ..translate(c.dx, c.dy + r * 1.4)
        ..scale(0.5, 2.2)
        ..drawCircle(
          Offset.zero,
          r * 2.2,
          reflectPaint
            ..shader = ui.Gradient.radial(
              Offset.zero,
              r * 2.2,
              [
                color.withValues(alpha: 0.18 * intensity),
                color.withValues(alpha: 0),
              ],
              [0.0, 1.0],
            ),
        )
        ..restore()
        ..drawCircle(c, r * 0.85, corePaint);
    }
  }
}

/// One strobe unit in the cordon.
class PoliceCordonUnit {
  const PoliceCordonUnit({
    required this.position,
    required this.phase,
    required this.isRed,
  });

  /// Normalized (0..1) position on the artwork canvas.
  final ui.Offset position;

  /// Strobe phase offset in seconds, so the units don't flash in unison.
  final double phase;

  /// Whether this unit carries the red accent (the rest are blue).
  final bool isRed;
}

/// Deterministic, evenly spaced cordon units along the bridge roadway.
///
/// The line follows the painted deck (normalized y ≈ 0.476→0.481 across
/// x ≈ 0.555→0.745 — the same road the drones launch from) with a small
/// deterministic vertical jitter so the lamps sit naturally rather than ruler
/// straight. Most units are blue; a sparse few are red accents.
List<PoliceCordonUnit> policeCordonPoints({
  int count = kBridgePoliceUnitCount,
}) {
  if (count <= 0) return const [];
  const startX = 0.555;
  const endX = 0.745;
  const startY = 0.476;
  const endY = 0.481;
  return List<PoliceCordonUnit>.generate(count, (i) {
    final u = count <= 1 ? 0.5 : i / (count - 1);
    final jitter = (_unitForIndex(i + 41) - 0.5) * 0.004;
    // Two evenly spread red accents in a mostly-blue cordon.
    final isRed = i == (count * 0.3).round() || i == (count * 0.78).round();
    return PoliceCordonUnit(
      position: ui.Offset(
        startX + u * (endX - startX),
        startY + u * (endY - startY) + jitter,
      ),
      phase: _unitForIndex(i * 3 + 7) * 0.9,
      isRed: isRed,
    );
  }, growable: false);
}

/// Cordon brightness for the drone-loop position [cycleProgress] (0..1).
///
/// The launch instant is `cycleProgress == 0` (drones held on the road). The
/// cordon ramps in over the preceding ~0.10 of the loop, holds full from just
/// before launch through the on-road hold, then ramps back out as the drones
/// climb away — keyed so the lights are gone well before the formation reaches
/// the sky. Pure for unit testing.
double trafficStopIntensity(double cycleProgress) {
  final p = _fraction(cycleProgress);
  // Signed distance to the launch instant, in loop fractions [-0.5, 0.5).
  final d = p <= 0.5 ? p : p - 1.0;
  if (d < -0.20 || d >= 0.12) return 0;
  if (d < -0.10) return _smoothstep((d + 0.20) / 0.10); // roll in
  if (d < 0.04) return 1; // full hold across the launch
  return 1 - _smoothstep((d - 0.04) / 0.08); // clear out as drones climb
}

/// Instantaneous strobe value for an LED police bar at [time] seconds, offset by
/// [phase]. Models a quad-flash burst: four crisp pulses bunched into the first
/// ~0.4 of a 0.9 s period that peg the lamp to full, over a dim [_strobeFloor]
/// presence the rest of the cycle. The floor means every unit stays softly lit
/// between flashes, so a cordon of these reads as a populated line of vehicles
/// (not one or two lone dots in any given still) while the bright peaks still
/// give the staccato strobe. Range `[_strobeFloor, 1]`. Pure for unit testing.
double policeStrobe(double time, double phase) {
  const period = 0.9;
  const flash = 0.05;
  const gap = 0.05;
  final t = _fraction((time + phase) / period) * period;
  for (var i = 0; i < 4; i++) {
    final start = i * (flash + gap);
    if (t >= start && t < start + flash) return 1;
  }
  return _strobeFloor;
}

/// Dim always-on presence between strobe flashes (see [policeStrobe]).
const double _strobeFloor = 0.3;

double _unitForIndex(int index) {
  final n = math.sin((index + 1) * 12.9898) * 43758.5453;
  return _fraction(n);
}

double _fraction(double value) {
  final f = value - value.floorToDouble();
  return f < 0 ? f + 1 : f;
}

double _smoothstep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
