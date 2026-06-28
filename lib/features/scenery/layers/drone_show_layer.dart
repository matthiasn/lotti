import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:lotti/features/scenery/layers/backdrop_layer.dart';

/// First text held by the drone formation.
const String kDroneShowOpeningText = 'Omah Lay';

/// Final text shown by the drone formation.
const String kDroneShowFinalText = 'Moving';

/// Number of light points in the deterministic show.
const int kDroneShowDroneCount = 220;

/// Length of one complete drone-show loop.
///
/// This is intentionally song-scale rather than particle-scale: the aircraft
/// spend tens of seconds climbing from the bridge before they hold readable sky
/// text. That keeps the implied vertical and lateral speeds in the range of a
/// real light-show drone instead of a firework.
const double kDroneShowCycleSeconds = 144;

const double _launchEnd = 0.22;
const double _beamEnd = 0.38;
const double _fanEnd = 0.58;
const double _launchHoldProgress = 0.14;
const double _openingSettleEnd = 0.16;
const double _textTransitionStart = 0.44;
const double _stagingHoldStart = 0.56;
const double _stagingHoldEnd = 0.62;
const double _textTransitionEnd = 0.74;
const double _reducedMotionCycleProgress = 0.9;

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
/// Drones launch from evenly spaced bridge-road anchors, rise vertically before
/// converging into an ascending beam, fan outward, hold [kDroneShowOpeningText],
/// then morph through a staging row into [kDroneShowFinalText].
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
      ctx.reducedMotion
          ? cycleSeconds * _reducedMotionCycleProgress
          : ctx.timeSeconds,
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

/// Generates normalized destination points for a drone-show text label.
List<ui.Offset> droneShowFormationPoints({
  int count = kDroneShowDroneCount,
  String text = kDroneShowOpeningText,
}) {
  if (count <= 0) return const [];
  final cells = _textDotCells(text);
  return List<ui.Offset>.generate(count, (i) {
    final cellIndex = (i * cells.length) ~/ count;
    final cell = cells[math.min(cellIndex, cells.length - 1)];
    final angle = _unitForIndex(i + 211) * math.pi * 2;
    final radius = math.sqrt(_unitForIndex(i + 307)) * 0.08;
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
    reducedMotion ? safeCycle * _reducedMotionCycleProgress : timeSeconds,
    cycleSeconds: safeCycle,
  );
  final openingFormation = droneShowFormationPoints(count: count);
  final finalFormation = droneShowFormationPoints(
    count: count,
    text: kDroneShowFinalText,
  );
  return List<DroneShowSample>.generate(count, (i) {
    final t = _easeInOut(timeline.progress);
    final launch = _launchPoint(i, count);
    final rise = _risePoint(i, count);
    final beam = _beamPoint(i, count);
    final fan = _fanPoint(i, count);
    final position = switch (timeline.phase) {
      DroneShowPhase.launch => _launchPhasePoint(
        launch,
        rise,
        timeline.progress,
      ),
      DroneShowPhase.beam => ui.Offset.lerp(rise, beam, t)!,
      DroneShowPhase.fan => ui.Offset.lerp(beam, fan, t)!,
      DroneShowPhase.formation => _formationPoint(
        i,
        count,
        fan,
        openingFormation[i],
        finalFormation[i],
        timeline.progress,
      ),
    };
    final twinkle = reducedMotion
        ? 0.0
        : 0.045 *
              math.sin(timeSeconds * 1.35 + i * 0.42 + _unitForIndex(i) * 2);
    final coordinated = timeline.phase == DroneShowPhase.launch;
    final formation = timeline.phase == DroneShowPhase.formation;
    return DroneShowSample(
      position: position,
      opacity: (coordinated ? 0.8 : 0.74 + twinkle).clamp(0.0, 1.0),
      radius: coordinated || formation
          ? 0.00235
          : 0.0020 + _unitForIndex(i + 17) * 0.0009,
      phase: timeline.phase,
    );
  }, growable: false);
}

ui.Offset _launchPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final x = 0.44 + u * 0.34;
  final y = 0.476 + (u - 0.5) * 0.006;
  return ui.Offset(x, y);
}

ui.Offset _launchPhasePoint(ui.Offset launch, ui.Offset rise, double progress) {
  if (progress < _launchHoldProgress) return launch;
  final t = (progress - _launchHoldProgress) / (1 - _launchHoldProgress);
  return ui.Offset.lerp(launch, rise, _easeInOut(t))!;
}

ui.Offset _risePoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  return ui.Offset(
    0.44 + u * 0.34,
    0.392 - u * 0.018,
  );
}

ui.Offset _beamPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  return ui.Offset(
    0.61 + (u - 0.5) * 0.04,
    0.365 - u * 0.135,
  );
}

ui.Offset _fanPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final band = ((index * 7) % 11) / 10;
  final crown = -0.032 * math.sin(u * math.pi);
  return ui.Offset(
    0.35 + u * 0.30,
    0.205 + band * 0.085 + crown,
  );
}

ui.Offset _formationPoint(
  int index,
  int count,
  ui.Offset fan,
  ui.Offset opening,
  ui.Offset finalText,
  double progress,
) {
  if (progress < _openingSettleEnd) {
    return ui.Offset.lerp(
      fan,
      opening,
      _easeInOut(progress / _openingSettleEnd),
    )!;
  }
  if (progress < _textTransitionStart) return opening;
  final staging = _transitionStagingPoint(index, count);
  if (progress < _stagingHoldStart) {
    final t =
        (progress - _textTransitionStart) /
        (_stagingHoldStart - _textTransitionStart);
    return ui.Offset.lerp(opening, staging, _easeInOut(t))!;
  }
  if (progress < _stagingHoldEnd) return staging;
  if (progress < _textTransitionEnd) {
    final t =
        (progress - _stagingHoldEnd) / (_textTransitionEnd - _stagingHoldEnd);
    return ui.Offset.lerp(staging, finalText, _easeInOut(t))!;
  }
  return finalText;
}

ui.Offset _transitionStagingPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final row = ((index * 5) % 7 - 3) * 0.004;
  return ui.Offset(0.37 + u * 0.26, 0.245 + row);
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

  rawCells.sort((a, b) {
    final x = a.x.compareTo(b.x);
    return x != 0 ? x : a.y.compareTo(b.y);
  });

  final width = math.max(cursor - glyphGap, 1);
  const rows = 7;
  const targetWidth = 0.3;
  const targetHeight = 0.08;
  const left = 0.35;
  const top = 0.205;
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
    'V' => const _DotGlyph([
      '10001',
      '10001',
      '10001',
      '10001',
      '01010',
      '01010',
      '00100',
    ]),
    'I' => const _DotGlyph([
      '111',
      '010',
      '010',
      '010',
      '010',
      '010',
      '111',
    ]),
    'N' => const _DotGlyph([
      '10001',
      '11001',
      '10101',
      '10011',
      '10001',
      '10001',
      '10001',
    ]),
    'G' => const _DotGlyph([
      '01110',
      '10001',
      '10000',
      '10111',
      '10001',
      '10001',
      '01110',
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
