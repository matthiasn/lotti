import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:lotti/features/scenery/layers/backdrop_layer.dart';

/// Final text shown by the drone formation.
const String kDroneShowFinalText = 'Omah Lay';

/// Number of light points in the deterministic show.
const int kDroneShowDroneCount = 120;

/// Length of one complete drone-show loop.
const double kDroneShowCycleSeconds = 18;

const double _launchEnd = 0.28;
const double _beamEnd = 0.50;
const double _fanEnd = 0.72;

/// Coarse segment in the repeatable drone-show choreography.
enum DroneShowPhase { launch, beam, fan, formation }

/// One timeline sample for the current loop.
class DroneShowTimeline {
  const DroneShowTimeline({
    required this.phase,
    required this.progress,
    required this.cycleProgress,
  });

  /// Active show segment.
  final DroneShowPhase phase;

  /// Normalized 0..1 progress inside [phase].
  final double progress;

  /// Normalized 0..1 progress inside the full loop.
  final double cycleProgress;
}

/// One sampled drone light in normalized backdrop coordinates.
class DroneShowSample {
  const DroneShowSample({
    required this.position,
    required this.opacity,
    required this.radius,
    required this.phase,
  });

  final ui.Offset position;
  final double opacity;
  final double radius;
  final DroneShowPhase phase;
}

/// Additive drone-show layer for the blue-hour sky.
///
/// Drones launch from bridge-ish normalized anchors, climb into an ascending
/// beam, fan outward, then hold a point formation spelling [kDroneShowFinalText].
/// The layer is stateless and deterministic from [BackdropContext.timeSeconds].
class DroneShowLayer implements BackdropLayer {
  const DroneShowLayer({
    this.droneCount = kDroneShowDroneCount,
    this.cycleSeconds = kDroneShowCycleSeconds,
  });

  final int droneCount;
  final double cycleSeconds;

  @override
  void paint(ui.Canvas canvas, BackdropContext ctx) {
    final samples = sampleDroneShow(
      ctx.reducedMotion ? cycleSeconds * 0.86 : ctx.timeSeconds,
      reducedMotion: ctx.reducedMotion,
      count: droneCount,
      cycleSeconds: cycleSeconds,
    );
    if (samples.isEmpty) return;

    final shortestSide = math.min(ctx.size.width, ctx.size.height);
    final haloPaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    final corePaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    final cool = ctx.palette.moonHalo;
    final warm = ctx.palette.windowLed;

    for (final sample in samples) {
      final c = ui.Offset(
        sample.position.dx * ctx.size.width,
        sample.position.dy * ctx.size.height,
      );
      final radius = shortestSide * sample.radius;
      final alpha = sample.opacity.clamp(0.0, 1.0);
      final color = ui.Color.lerp(cool, warm, _unitForIndex(c.dx.toInt()))!;
      haloPaint.shader = ui.Gradient.radial(
        c,
        radius * 4.5,
        [
          color.withValues(alpha: 0.16 * alpha),
          color.withValues(alpha: 0.04 * alpha),
          color.withValues(alpha: 0),
        ],
        [0, 0.45, 1],
      );
      corePaint.color = ui.Color.lerp(
        color,
        const ui.Color(0xFFFFFFFF),
        0.55,
      )!.withValues(alpha: 0.82 * alpha);
      canvas
        ..drawCircle(c, radius * 4.5, haloPaint)
        ..drawCircle(c, radius, corePaint);
    }
  }
}

/// Resolves the repeatable choreography phase for [timeSeconds].
DroneShowTimeline droneShowTimelineAt(
  double timeSeconds, {
  double cycleSeconds = kDroneShowCycleSeconds,
}) {
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final cycleProgress = _fraction(timeSeconds / safeCycle);
  if (cycleProgress < _launchEnd) {
    return DroneShowTimeline(
      phase: DroneShowPhase.launch,
      progress: cycleProgress / _launchEnd,
      cycleProgress: cycleProgress,
    );
  }
  if (cycleProgress < _beamEnd) {
    return DroneShowTimeline(
      phase: DroneShowPhase.beam,
      progress: (cycleProgress - _launchEnd) / (_beamEnd - _launchEnd),
      cycleProgress: cycleProgress,
    );
  }
  if (cycleProgress < _fanEnd) {
    return DroneShowTimeline(
      phase: DroneShowPhase.fan,
      progress: (cycleProgress - _beamEnd) / (_fanEnd - _beamEnd),
      cycleProgress: cycleProgress,
    );
  }
  return DroneShowTimeline(
    phase: DroneShowPhase.formation,
    progress: (cycleProgress - _fanEnd) / (1 - _fanEnd),
    cycleProgress: cycleProgress,
  );
}

/// Generates normalized destination points for [kDroneShowFinalText].
List<ui.Offset> droneShowFormationPoints({int count = kDroneShowDroneCount}) {
  if (count <= 0) return const [];
  final strokes = _textStrokes(kDroneShowFinalText);
  return List<ui.Offset>.generate(count, (i) {
    final u = count == 1 ? 0.5 : i / (count - 1);
    return _pointAlongStrokes(strokes, u);
  }, growable: false);
}

/// Deterministically samples all drone lights for a frame.
List<DroneShowSample> sampleDroneShow(
  double timeSeconds, {
  bool reducedMotion = false,
  int count = kDroneShowDroneCount,
  double cycleSeconds = kDroneShowCycleSeconds,
}) {
  if (count <= 0) return const [];
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final timeline = droneShowTimelineAt(
    reducedMotion ? safeCycle * 0.86 : timeSeconds,
    cycleSeconds: safeCycle,
  );
  final formation = droneShowFormationPoints(count: count);
  return List<DroneShowSample>.generate(count, (i) {
    final t = _easeInOut(timeline.progress);
    final launch = _launchPoint(i);
    final beam = _beamPoint(i);
    final fan = _fanPoint(i, count);
    final dest = formation[i];
    final position = switch (timeline.phase) {
      DroneShowPhase.launch => ui.Offset.lerp(launch, beam, t)!,
      DroneShowPhase.beam => ui.Offset.lerp(beam, _beamLiftPoint(i), t)!,
      DroneShowPhase.fan => ui.Offset.lerp(_beamLiftPoint(i), fan, t)!,
      DroneShowPhase.formation => ui.Offset.lerp(fan, dest, t)!,
    };
    final twinkle = reducedMotion
        ? 0.0
        : 0.10 * math.sin(timeSeconds * 2.4 + i * 1.618 + _unitForIndex(i) * 2);
    return DroneShowSample(
      position: position,
      opacity: (0.74 + twinkle).clamp(0.0, 1.0),
      radius: 0.0020 + _unitForIndex(i + 17) * 0.0009,
      phase: timeline.phase,
    );
  }, growable: false);
}

ui.Offset _launchPoint(int index) {
  final u = _unitForIndex(index);
  final x = 0.30 + u * 0.40;
  final y = 0.61 + 0.025 * math.sin(index * 1.9);
  return ui.Offset(x, y);
}

ui.Offset _beamPoint(int index) {
  final wobble = (_unitForIndex(index + 11) - 0.5) * 0.035;
  final height = _unitForIndex(index + 29) * 0.22;
  return ui.Offset(0.50 + wobble, 0.50 - height);
}

ui.Offset _beamLiftPoint(int index) {
  final wobble = (_unitForIndex(index + 3) - 0.5) * 0.026;
  final height = _unitForIndex(index + 47) * 0.24;
  return ui.Offset(0.50 + wobble, 0.36 - height);
}

ui.Offset _fanPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final wave = math.sin(u * math.pi * 2.0);
  return ui.Offset(
    0.18 + u * 0.64,
    0.19 + 0.17 * _unitForIndex(index + 5) + wave * 0.035,
  );
}

double _unitForIndex(int index) {
  final n = math.sin((index + 1) * 12.9898) * 43758.5453;
  return _fraction(n);
}

double _fraction(double value) {
  final f = value - value.floorToDouble();
  return f < 0 ? f + 1 : f;
}

double _easeInOut(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

List<_Stroke> _textStrokes(String text) {
  const gap = 0.18;
  final glyphs = <_Glyph>[];
  var cursor = 0.0;
  for (final codePoint in text.runes) {
    final char = String.fromCharCode(codePoint);
    if (char == ' ') {
      cursor += 0.58;
      continue;
    }
    final glyph = _glyphFor(char);
    glyphs.add(glyph.shift(cursor));
    cursor += glyph.width + gap;
  }

  final width = math.max(cursor - gap, 1);
  const targetWidth = 0.58;
  const targetHeight = 0.18;
  const left = 0.21;
  const top = 0.18;
  return [
    for (final glyph in glyphs)
      for (final stroke in glyph.strokes)
        _Stroke(
          ui.Offset(
            left + stroke.a.dx / width * targetWidth,
            top + stroke.a.dy * targetHeight,
          ),
          ui.Offset(
            left + stroke.b.dx / width * targetWidth,
            top + stroke.b.dy * targetHeight,
          ),
        ),
  ];
}

ui.Offset _pointAlongStrokes(List<_Stroke> strokes, double progress) {
  final total = strokes.fold<double>(0, (sum, s) => sum + s.length);
  var remaining = progress.clamp(0.0, 1.0) * total;
  for (final stroke in strokes) {
    if (remaining <= stroke.length) {
      return ui.Offset.lerp(stroke.a, stroke.b, remaining / stroke.length)!;
    }
    remaining -= stroke.length;
  }
  return strokes.last.b;
}

_Glyph _glyphFor(String char) {
  return switch (char) {
    'O' => const _Glyph(1, [
      _Stroke(ui.Offset(0.50, 0), ui.Offset(0.15, 0.12)),
      _Stroke(ui.Offset(0.15, 0.12), ui.Offset(0, 0.50)),
      _Stroke(ui.Offset(0, 0.50), ui.Offset(0.15, 0.88)),
      _Stroke(ui.Offset(0.15, 0.88), ui.Offset(0.50, 1)),
      _Stroke(ui.Offset(0.50, 1), ui.Offset(0.85, 0.88)),
      _Stroke(ui.Offset(0.85, 0.88), ui.Offset(1, 0.50)),
      _Stroke(ui.Offset(1, 0.50), ui.Offset(0.85, 0.12)),
      _Stroke(ui.Offset(0.85, 0.12), ui.Offset(0.50, 0)),
    ]),
    'm' => const _Glyph(1.05, [
      _Stroke(ui.Offset(0, 1), ui.Offset(0, 0.35)),
      _Stroke(ui.Offset(0, 0.42), ui.Offset(0.25, 0.18)),
      _Stroke(ui.Offset(0.25, 0.18), ui.Offset(0.50, 0.42)),
      _Stroke(ui.Offset(0.50, 0.42), ui.Offset(0.50, 1)),
      _Stroke(ui.Offset(0.50, 0.42), ui.Offset(0.75, 0.18)),
      _Stroke(ui.Offset(0.75, 0.18), ui.Offset(1.05, 0.42)),
      _Stroke(ui.Offset(1.05, 0.42), ui.Offset(1.05, 1)),
    ]),
    'a' => const _Glyph(0.82, [
      _Stroke(ui.Offset(0.72, 1), ui.Offset(0.72, 0.35)),
      _Stroke(ui.Offset(0.72, 0.35), ui.Offset(0.40, 0.18)),
      _Stroke(ui.Offset(0.40, 0.18), ui.Offset(0.08, 0.35)),
      _Stroke(ui.Offset(0.08, 0.35), ui.Offset(0.08, 0.78)),
      _Stroke(ui.Offset(0.08, 0.78), ui.Offset(0.40, 1)),
      _Stroke(ui.Offset(0.40, 1), ui.Offset(0.72, 0.78)),
      _Stroke(ui.Offset(0.08, 0.58), ui.Offset(0.72, 0.58)),
    ]),
    'h' => const _Glyph(0.78, [
      _Stroke(ui.Offset(0, 1), ui.Offset.zero),
      _Stroke(ui.Offset(0, 0.45), ui.Offset(0.32, 0.20)),
      _Stroke(ui.Offset(0.32, 0.20), ui.Offset(0.72, 0.42)),
      _Stroke(ui.Offset(0.72, 0.42), ui.Offset(0.72, 1)),
    ]),
    'L' => const _Glyph(0.78, [
      _Stroke(ui.Offset.zero, ui.Offset(0, 1)),
      _Stroke(ui.Offset(0, 1), ui.Offset(0.78, 1)),
    ]),
    'y' => const _Glyph(0.78, [
      _Stroke(ui.Offset(0, 0.24), ui.Offset(0.34, 0.78)),
      _Stroke(ui.Offset(0.72, 0.24), ui.Offset(0.34, 0.78)),
      _Stroke(ui.Offset(0.34, 0.78), ui.Offset(0.08, 1.18)),
    ]),
    _ => const _Glyph(0.7, [
      _Stroke(ui.Offset.zero, ui.Offset(0.70, 1)),
      _Stroke(ui.Offset(0.70, 0), ui.Offset(0, 1)),
    ]),
  };
}

class _Glyph {
  const _Glyph(this.width, this.strokes);

  final double width;
  final List<_Stroke> strokes;

  _Glyph shift(double dx) => _Glyph(
    width,
    [
      for (final stroke in strokes)
        _Stroke(
          stroke.a.translate(dx, 0),
          stroke.b.translate(dx, 0),
        ),
    ],
  );
}

class _Stroke {
  const _Stroke(this.a, this.b);

  final ui.Offset a;
  final ui.Offset b;

  double get length => (b - a).distance;
}
