import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/scenery/runtime/stage_effects.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';

/// Concert-stage particle effects for the dancing-cats scene.
///
/// The overlay is driven by audio position, not wall time, so the effects
/// pause/seek with playback. It intentionally lives beside the stage-light pass
/// instead of importing the design-system completion celebrations.
class StageEffectsOverlay extends StatelessWidget {
  const StageEffectsOverlay({
    required this.timeSeconds,
    required this.beat,
    required this.cues,
    required this.lights,
    this.scheduler = const StageEffectScheduler(),
    this.reducedMotion = false,
    super.key,
  });

  final double timeSeconds;
  final double beat;
  final List<StageEffectCue> cues;
  final List<StageLightSample> lights;
  final StageEffectScheduler scheduler;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final rm =
        reducedMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final samples = scheduler.sample(
      positionSeconds: timeSeconds,
      beat: beat,
      cues: cues,
      lights: lights,
      reducedMotion: rm,
    );
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: StageEffectsPainter(
            samples: samples,
            reducedMotion: rm,
          ),
        ),
      ),
    );
  }
}

/// Paints already-resolved [StageParticleSample]s.
///
/// It has no knowledge of audio, BPM, sections or widgets; those belong to the
/// pure scheduler and the owning demo.
class StageEffectsPainter extends CustomPainter {
  const StageEffectsPainter({
    required this.samples,
    this.reducedMotion = false,
  });

  final List<StageParticleSample> samples;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || reducedMotion) return;
    for (final sample in samples) {
      switch (sample.kind) {
        case StageEffectKind.coldSparks:
          _paintColdSparks(canvas, size, sample);
        case StageEffectKind.confetti:
          _paintConfetti(canvas, size, sample);
        case StageEffectKind.bubbles:
          _paintBubbles(canvas, size, sample);
        case StageEffectKind.embers:
          _paintEmbers(canvas, size, sample);
      }
    }
  }

  void _paintColdSparks(Canvas canvas, Size size, StageParticleSample s) {
    final center = _center(size, s.origin);
    final reach = size.height * s.reach;
    final paint = Paint();
    final t = s.progress;
    final baseOpacity = (1 - t * t).clamp(0.0, 1.0) * s.intensity;

    for (var i = 0; i < s.count; i++) {
      final life = 0.58 + _hash01(i * 17 + 3) * 0.34;
      final lt = (t / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;
      final spread = (_hash01(i * 19 + 5) - 0.5) * 0.52;
      final angle = s.directionRadians + spread;
      final speed = 0.62 + _hash01(i * 23 + 7) * 0.48;
      final ease = Curves.easeOutCubic.transform(lt);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final gravity = Offset(0, reach * 0.16 * lt * lt);
      final head = center + dir * (reach * speed * ease) + gravity;
      final tail = center + dir * (reach * speed * (ease - 0.16).clamp(0, 1));
      final opacity = ((1 - lt) * baseOpacity).clamp(0.0, 1.0);
      final r = (1.4 + _hash01(i * 29 + 11) * 2.1) * (1 - 0.25 * lt);
      final color = s.palette[i % s.palette.length];

      paint
        ..blendMode = BlendMode.plus
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.78
        ..color = color.withValues(alpha: opacity * 0.5);
      canvas.drawLine(tail, head, paint);

      paint
        ..strokeWidth = 0
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(head, r, paint);
      paint.color = color.withValues(alpha: opacity * 0.14);
      canvas.drawCircle(head, r * 4.2, paint);
    }
  }

  void _paintConfetti(Canvas canvas, Size size, StageParticleSample s) {
    final center = _center(size, s.origin);
    final reach = size.height * s.reach;
    final paint = Paint()..style = PaintingStyle.fill;
    final t = s.progress;

    for (var i = 0; i < s.count; i++) {
      final life = 0.72 + _hash01(i * 13 + 1) * 0.28;
      final lt = (t / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;
      final spread = (_hash01(i * 17 + 2) - 0.5) * 0.72;
      final angle = s.directionRadians + spread;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final speed = 0.5 + _hash01(i * 19 + 3) * 0.52;
      final rise = reach * speed * Curves.easeOut.transform(lt);
      final gravity = reach * 0.92 * lt * lt;
      final sway = math.sin(lt * math.pi * 4 + i) * reach * 0.055;
      final pos = center + dir * rise + Offset(sway, gravity);
      final fade = lt < 0.72 ? 1.0 : (1 - (lt - 0.72) / 0.28);
      final opacity = (fade * s.intensity * 0.82).clamp(0.0, 1.0);
      final w = 5.0 + _hash01(i * 23 + 5) * 5.5;
      final h = w * (0.32 + _hash01(i * 29 + 7) * 0.32);
      final spin = i * 0.77 + lt * math.pi * 7 * (i.isEven ? 1 : -1);

      paint.color = s.palette[i % s.palette.length].withValues(alpha: opacity);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(spin)
        ..scale(1, 0.34 + 0.66 * math.sin(spin).abs())
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          paint,
        )
        ..restore();
    }
  }

  void _paintBubbles(Canvas canvas, Size size, StageParticleSample s) {
    final center = _center(size, s.origin);
    final reach = size.height * s.reach;
    final paint = Paint();
    final t = s.progress;

    for (var i = 0; i < s.count; i++) {
      final life = 0.72 + _hash01(i * 11 + 1) * 0.28;
      final lt = (t / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;
      final spread = (_hash01(i * 17 + 2) - 0.5) * 0.62;
      final angle = s.directionRadians + spread;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final speed = 0.38 + _hash01(i * 19 + 3) * 0.44;
      final wobble = math.sin(lt * math.pi * 3 + i) * reach * 0.055;
      final pos =
          center +
          dir * (reach * speed * Curves.easeOut.transform(lt)) +
          Offset(wobble, -reach * 0.2 * speed * lt);
      final popping = lt > 0.9;
      final swell = Curves.easeOut.transform((lt * 1.5).clamp(0.0, 1.0));
      final radius =
          (3.2 + _hash01(i * 23 + 5) * 5.8) *
          (popping ? 1.0 + (lt - 0.9) * 7.0 : 0.45 + 0.55 * swell);
      final opacity = ((1 - lt * lt) * s.intensity * (popping ? 0.44 : 0.8))
          .clamp(0.0, 1.0);
      final color = Color.lerp(
        s.palette.first,
        s.palette[i % s.palette.length],
        0.55,
      )!;

      if (!popping) {
        paint
          ..blendMode = BlendMode.srcOver
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: opacity * 0.10);
        canvas.drawCircle(pos, radius, paint);
      }
      paint
        ..blendMode = BlendMode.srcOver
        ..style = PaintingStyle.stroke
        ..strokeWidth = popping ? 0.9 : 1.5
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(pos, radius, paint);
      if (!popping) {
        paint
          ..style = PaintingStyle.fill
          ..color = s.palette.first.withValues(alpha: opacity * 0.55);
        canvas.drawCircle(
          pos + Offset(-radius * 0.34, -radius * 0.34),
          radius * 0.17,
          paint,
        );
      }
    }
  }

  void _paintEmbers(Canvas canvas, Size size, StageParticleSample s) {
    final center = _center(size, s.origin);
    final reach = size.height * s.reach;
    final paint = Paint()..blendMode = BlendMode.plus;
    final t = s.progress;

    for (var i = 0; i < s.count; i++) {
      final life = 0.6 + _hash01(i * 13 + 1) * 0.4;
      final lt = (t / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;
      final spread = (_hash01(i * 17 + 3) - 0.5) * 0.7;
      final angle = s.directionRadians + spread;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final speed = 0.38 + _hash01(i * 19 + 5) * 0.48;
      final wobble = math.sin(lt * math.pi * 5 + i) * reach * 0.07;
      final pos =
          center +
          dir * (reach * speed * Curves.easeOut.transform(lt)) +
          Offset(wobble, 0);
      final base = Color.lerp(
        s.palette[i % s.palette.length],
        s.palette.last,
        lt,
      )!;
      final opacity = ((1 - lt * lt) * s.intensity * 0.72).clamp(0.0, 1.0);
      final r = (1.8 + _hash01(i * 23 + 7) * 2.8) * (1 - 0.4 * lt);

      paint
        ..style = PaintingStyle.fill
        ..color = base.withValues(alpha: opacity * 0.22);
      canvas.drawCircle(pos, r * 3.2, paint);
      paint.color = base.withValues(alpha: opacity);
      canvas.drawCircle(pos, r, paint);
    }
  }

  Offset _center(Size size, Offset origin) =>
      Offset(origin.dx * size.width, origin.dy * size.height);

  @override
  bool shouldRepaint(StageEffectsPainter old) =>
      old.reducedMotion != reducedMotion || !listEquals(old.samples, samples);
}

double _hash01(int n) {
  final x = math.sin(n * 12.9898) * 43758.5453;
  return x - x.floorToDouble();
}
