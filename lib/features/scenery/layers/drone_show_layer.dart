import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:lotti/features/scenery/layers/backdrop_layer.dart';

/// Final text shown by the drone formation.
const String kDroneShowFinalText = 'Omah Lay';

/// Number of light points in the deterministic show.
const int kDroneShowDroneCount = 220;

/// Length of one complete drone-show loop.
///
/// Real drone shows read as slow, coordinated aircraft rather than particles:
/// a long launch, a deliberate grouped climb, then a held formation.
const double kDroneShowCycleSeconds = 144;

const double _launchEnd = 0.44;
const double _beamEnd = 0.62;
const double _fanEnd = 0.70;
const double _formationSettleFraction = 0.24;

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
  final cells = _textDotCells(kDroneShowFinalText);
  return List<ui.Offset>.generate(count, (i) {
    final cell = cells[(i * 73) % cells.length];
    final angle = _unitForIndex(i + 211) * math.pi * 2;
    final radius = math.sqrt(_unitForIndex(i + 307)) * 0.24;
    return cell.center.translate(
      math.cos(angle) * cell.width * radius,
      math.sin(angle) * cell.height * radius,
    );
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
    final launch = _launchPoint(i, count);
    final beam = _beamPoint(i);
    final fan = _fanPoint(i, count);
    final dest = formation[i];
    final position = switch (timeline.phase) {
      DroneShowPhase.launch => ui.Offset.lerp(launch, beam, t)!,
      DroneShowPhase.beam => ui.Offset.lerp(beam, _beamLiftPoint(i), t)!,
      DroneShowPhase.fan => ui.Offset.lerp(_beamLiftPoint(i), fan, t)!,
      DroneShowPhase.formation => _formationPoint(
        fan,
        dest,
        timeline.progress,
      ),
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

ui.Offset _launchPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final x = 0.48 + u * 0.27 + (_unitForIndex(index + 101) - 0.5) * 0.006;
  final y =
      0.515 -
      0.018 * math.sin(u * math.pi) +
      (_unitForIndex(index + 127) - 0.5) * 0.007;
  return ui.Offset(x, y);
}

ui.Offset _beamPoint(int index) {
  final wobble = (_unitForIndex(index + 11) - 0.5) * 0.035;
  final height = _unitForIndex(index + 29) * 0.22;
  return ui.Offset(0.62 + wobble, 0.47 - height);
}

ui.Offset _beamLiftPoint(int index) {
  final wobble = (_unitForIndex(index + 3) - 0.5) * 0.026;
  final height = _unitForIndex(index + 47) * 0.24;
  return ui.Offset(0.62 + wobble, 0.34 - height);
}

ui.Offset _fanPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final wave = math.sin(u * math.pi * 2.0);
  return ui.Offset(
    0.15 + u * 0.70,
    0.15 + 0.18 * _unitForIndex(index + 5) + wave * 0.034,
  );
}

ui.Offset _formationPoint(ui.Offset fan, ui.Offset dest, double progress) {
  final settle = _easeInOut(
    (progress / _formationSettleFraction).clamp(0.0, 1.0),
  );
  return ui.Offset.lerp(fan, dest, settle)!;
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

List<_DotCell> _textDotCells(String text) {
  const glyphGap = 1;
  const spaceWidth = 2;
  final rawCells = <({int x, int y})>[];
  var cursor = 0.0;
  for (final codePoint in text.runes) {
    final char = String.fromCharCode(codePoint).toUpperCase();
    if (char == ' ') {
      cursor += spaceWidth;
      continue;
    }
    final glyph = _dotGlyphFor(char);
    for (var y = 0; y < glyph.rows.length; y++) {
      final row = glyph.rows[y];
      for (var x = 0; x < row.length; x++) {
        if (row.codeUnitAt(x) == 49) {
          rawCells.add((x: cursor.round() + x, y: y));
        }
      }
    }
    cursor += glyph.width + glyphGap;
  }

  if (rawCells.isEmpty) {
    return const [_DotCell(ui.Offset(0.5, 0.22), 0.01, 0.01)];
  }

  final width = math.max(cursor - glyphGap, 1);
  const rows = 7;
  const targetWidth = 0.68;
  const targetHeight = 0.18;
  const left = 0.16;
  const top = 0.15;
  final cellWidth = targetWidth / width;
  const cellHeight = targetHeight / rows;
  return [
    for (final cell in rawCells)
      _DotCell(
        ui.Offset(
          left + (cell.x + 0.5) * cellWidth,
          top + (cell.y + 0.5) * cellHeight,
        ),
        cellWidth,
        cellHeight,
      ),
  ];
}

_DotGlyph _dotGlyphFor(String char) {
  return switch (char) {
    'O' => const _DotGlyph([
      '01110',
      '10001',
      '10001',
      '10001',
      '10001',
      '10001',
      '01110',
    ]),
    'M' => const _DotGlyph([
      '10001',
      '11011',
      '10101',
      '10101',
      '10001',
      '10001',
      '10001',
    ]),
    'A' => const _DotGlyph([
      '01110',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ]),
    'H' => const _DotGlyph([
      '10001',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ]),
    'L' => const _DotGlyph([
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '11111',
    ]),
    'Y' => const _DotGlyph([
      '10001',
      '01010',
      '00100',
      '00100',
      '00100',
      '00100',
      '00100',
    ]),
    _ => const _DotGlyph([
      '111',
      '001',
      '010',
      '010',
      '000',
      '010',
      '000',
    ]),
  };
}

class _DotGlyph {
  const _DotGlyph(this.rows);

  final List<String> rows;

  int get width => rows.first.length;
}

class _DotCell {
  const _DotCell(this.center, this.width, this.height);

  final ui.Offset center;
  final double width;
  final double height;
}
