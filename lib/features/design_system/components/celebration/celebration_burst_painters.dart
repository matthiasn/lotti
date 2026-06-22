import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/themes/colors.dart';

/// The particle field painted for a celebration burst. One concrete subclass per
/// [CelebrationVariant]; the surrounding widget/overlay choreography is shared,
/// so a variant only swaps the painter.
///
/// All motion is **index-seeded** (a deterministic function of the spark index
/// and [progress], no `Random`) so the same frame renders identically every
/// time — required for golden / filmstrip capture and for the expert-panel
/// rating loop. [progress] runs `0 → 1` across the burst window; subclasses
/// should fade their particles out before `1` so nothing lingers in dead space.
abstract class CelebrationBurstPainter extends CustomPainter {
  CelebrationBurstPainter({
    required this.progress,
    required this.origin,
    required this.palette,
    required this.count,
    required this.sizeScale,
    required this.clearCenter,
    required this.reachFactor,
    required this.reachOverride,
  }) : assert(palette.isNotEmpty, 'palette must not be empty');

  /// `0` → particles tight on the origin, `1` → flown out and gone.
  final double progress;

  /// Burst centre in fractional coordinates within the paint area.
  final Alignment origin;

  /// The variant's colour set. Index 0 is the primary accent; particles cycle
  /// through the list via [paletteColor]. Never empty.
  final List<Color> palette;

  /// Particle count, head/trail size multiplier, the cleared centre ring as a
  /// fraction of reach, and how far particles travel ([reachFactor] × height, or
  /// the absolute [reachOverride] when painting in a roomy overlay box).
  final int count;
  final double sizeScale;
  final double clearCenter;
  final double reachFactor;
  final double? reachOverride;

  /// The burst centre in pixels for [size]. (Exposed for subclasses and tests.)
  Offset centerOf(Size size) => origin.alongSize(size);

  /// How far particles travel in pixels for [size].
  double reachOf(Size size) => reachOverride ?? (size.height * reachFactor);

  /// The colour for spark [i], cycling through [palette].
  Color paletteColor(int i) => palette[i % palette.length];

  @override
  bool shouldRepaint(covariant CelebrationBurstPainter old) =>
      old.runtimeType != runtimeType ||
      old.progress != progress ||
      old.origin != origin ||
      old.count != count ||
      old.sizeScale != sizeScale ||
      old.clearCenter != clearCenter ||
      old.reachFactor != reachFactor ||
      old.reachOverride != reachOverride ||
      !listEquals(old.palette, palette);
}

/// The colour set for [variant]. Sourced entirely from existing app colour
/// constants (the accent token plus the gold/status palette) — no new ad-hoc
/// hex — so the festive multi-colour variants stay on-brand. Index 0 is always
/// the primary/lead colour.
List<Color> celebrationPalette(CelebrationVariant variant, Color accent) =>
    switch (variant) {
      CelebrationVariant.sparks => [accent, starredGold],
      CelebrationVariant.fireworks || CelebrationVariant.confetti => [
        accent,
        starredGold,
        taskIconColorOrange,
        taskIconColorGreen,
        taskIconColorBlue,
        taskIconColorRed,
      ],
      CelebrationVariant.embers => [
        starredGold,
        taskIconColorOrange,
        taskIconColorRed,
        taskStatusDarkOrange,
      ],
      CelebrationVariant.bubbles => [accent, starredGold, taskIconColorBlue],
    };

/// Builds the painter for [variant]. The dispatch point the burst widget uses.
///
/// Takes the [accent] colour and derives the variant's [celebrationPalette]
/// internally, so the palette can never be mismatched to the variant.
CelebrationBurstPainter buildCelebrationBurstPainter({
  required CelebrationVariant variant,
  required double progress,
  required Alignment origin,
  required Color accent,
  required int count,
  required double sizeScale,
  required double clearCenter,
  required double reachFactor,
  required double? reachOverride,
}) {
  final palette = celebrationPalette(variant, accent);
  CelebrationBurstPainter make(
    CelebrationBurstPainter Function({
      required double progress,
      required Alignment origin,
      required List<Color> palette,
      required int count,
      required double sizeScale,
      required double clearCenter,
      required double reachFactor,
      required double? reachOverride,
    })
    ctor,
  ) => ctor(
    progress: progress,
    origin: origin,
    palette: palette,
    count: count,
    sizeScale: sizeScale,
    clearCenter: clearCenter,
    reachFactor: reachFactor,
    reachOverride: reachOverride,
  );

  return switch (variant) {
    CelebrationVariant.sparks => make(SparksBurstPainter.new),
    CelebrationVariant.fireworks => make(FireworksBurstPainter.new),
    CelebrationVariant.confetti => make(ConfettiBurstPainter.new),
    CelebrationVariant.embers => make(EmbersBurstPainter.new),
    CelebrationVariant.bubbles => make(BubblesBurstPainter.new),
  };
}

/// The original accent spark burst: fine comet motes flung radially, in two
/// depth tiers, withering with a faint gravity droop.
class SparksBurstPainter extends CelebrationBurstPainter {
  SparksBurstPainter({
    required super.progress,
    required super.origin,
    required super.palette,
    required super.count,
    required super.sizeScale,
    required super.clearCenter,
    required super.reachFactor,
    required super.reachOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerOf(size);
    final reach = reachOf(size);
    final clearRadius = reach * clearCenter;
    final paint = Paint();

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (((i * 13) % 7) - 3) * 0.05;
      final speed = 0.5 + ((i * 7) % 9) / 9 * 0.8;
      final life = 0.7 + ((i * 5) % 5) / 5 * 0.3;
      final lt = (progress / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      final ease = 0.5 * Curves.easeOutCubic.transform(lt) + 0.5 * lt;
      final dist = clearRadius + reach * speed * ease;
      final gravity = size.height * 0.16 * lt * lt;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final head = center + dir * dist + Offset(0, gravity);

      final isLead = i % 3 == 0;
      final tierScale = isLead ? 1.25 : 0.82;
      final tierAlpha = isLead ? 1.0 : 0.72;
      final opacity = ((1 - lt * lt) * tierAlpha).clamp(0.0, 1.0);
      final headR =
          (2.6 + ((i * 3) % 4) / 3 * 2.6) *
          (1 - 0.32 * lt) *
          sizeScale *
          tierScale;
      if (headR <= 0.3) continue;
      final base = i % 5 == 0 ? paletteColor(1) : paletteColor(0);

      final trailLen = reach * speed * 0.2 * (1 - ease);
      final tailDist = (dist - trailLen).clamp(clearRadius, dist);
      final tail = center + dir * tailDist + Offset(0, gravity);
      paint
        ..color = base.withValues(alpha: (opacity * 0.18).clamp(0.0, 1.0))
        ..strokeWidth = 0
        ..strokeCap = StrokeCap.butt;
      canvas.drawCircle(head, headR * 2.2, paint);

      paint
        ..color = base.withValues(alpha: (opacity * 0.4).clamp(0.0, 1.0))
        ..strokeWidth = headR * 0.9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, head, paint);

      paint
        ..color = base.withValues(alpha: (opacity * 0.95).clamp(0.0, 1.0))
        ..strokeWidth = 0
        ..strokeCap = StrokeCap.butt;
      canvas.drawCircle(head, headR, paint);
    }
  }
}

/// Energetic: a rocket streak that flies up, then a multi-colour shell that
/// bursts into a twinkling ring and rains glittering fallout.
class FireworksBurstPainter extends CelebrationBurstPainter {
  FireworksBurstPainter({
    required super.progress,
    required super.origin,
    required super.palette,
    required super.count,
    required super.sizeScale,
    required super.clearCenter,
    required super.reachFactor,
    required super.reachOverride,
  });

  /// The rocket has fully arrived (and the shell has fully bloomed) by here.
  static const _launchEnd = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerOf(size);
    final reach = reachOf(size);
    final clearRadius = reach * clearCenter;
    final paint = Paint();

    // Rocket: a bright streak rising from below the centre up to it.
    if (progress < _launchEnd) {
      final riseT = Curves.easeOut.transform(progress / _launchEnd);
      final headY = center.dy + reach * 0.9 * (1 - riseT);
      final head = Offset(center.dx, headY);
      final tail = Offset(center.dx, headY + reach * 0.22 * (1 - riseT));
      paint
        ..color = paletteColor(0).withValues(alpha: 0.9)
        ..strokeWidth = 2.4 * sizeScale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, head, paint);
    }

    // Shell: a radial spray that blooms once the rocket reaches the apex.
    if (progress < _launchEnd * 0.8) return;
    final burstT = ((progress - _launchEnd * 0.8) / (1 - _launchEnd * 0.8))
        .clamp(0.0, 1.0);

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (((i * 11) % 5) - 2) * 0.04;
      final speed = 0.55 + ((i * 7) % 9) / 9 * 0.7;
      final life = 0.72 + ((i * 5) % 5) / 5 * 0.28;
      final lt = (burstT / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      final ease = Curves.easeOutCubic.transform(lt);
      // A secondary inner ring (every other spark) for a layered shell.
      final ring = i.isEven ? 1.0 : 0.62;
      final dist = clearRadius + reach * speed * ease * ring;
      final gravity = size.height * 0.5 * lt * lt; // heavy fallout
      final dir = Offset(math.cos(angle), math.sin(angle));
      final head = center + dir * dist + Offset(0, gravity);

      // Twinkle: a fast brightness flicker so the ring sparkles as it falls.
      final twinkle = 0.55 + 0.45 * math.sin(lt * math.pi * 8 + i);
      final opacity = ((1 - lt * lt) * twinkle).clamp(0.0, 1.0);
      final headR =
          (2.2 + ((i * 3) % 4) / 3 * 1.8) * (1 - 0.3 * lt) * sizeScale;
      if (headR <= 0.3) continue;
      final base = paletteColor(i);

      paint
        ..color = base.withValues(alpha: (opacity * 0.2).clamp(0.0, 1.0))
        ..strokeWidth = 0
        ..strokeCap = StrokeCap.butt;
      canvas.drawCircle(head, headR * 2.4, paint);
      paint.color = base.withValues(alpha: opacity);
      canvas.drawCircle(head, headR, paint);
    }
  }
}

/// Playful: tumbling rectangular ribbons that pop up and outward, flutter with a
/// sideways sway, then drift down under gravity, spinning as they fall.
class ConfettiBurstPainter extends CelebrationBurstPainter {
  ConfettiBurstPainter({
    required super.progress,
    required super.origin,
    required super.palette,
    required super.count,
    required super.sizeScale,
    required super.clearCenter,
    required super.reachFactor,
    required super.reachOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerOf(size);
    final reach = reachOf(size);
    final paint = Paint()..style = PaintingStyle.fill;
    final t = progress;

    for (var i = 0; i < count; i++) {
      final life = 0.7 + ((i * 5) % 5) / 5 * 0.3;
      final lt = (t / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      // Spread mostly upward-and-out, then gravity pulls it back down.
      final spread = (((i * 7) % 11) / 11 - 0.5) * math.pi * 1.3;
      final outDir = Offset(math.sin(spread), -math.cos(spread).abs());
      final speed = 0.6 + ((i * 13) % 7) / 7 * 0.6;
      final rise = reach * speed * Curves.easeOut.transform(lt);
      final gravity = reach * 1.1 * lt * lt;
      final sway = math.sin(lt * math.pi * 4 + i) * reach * 0.08;
      final pos =
          center +
          outDir * rise +
          Offset(sway + reach * 0.18 * outDir.dx, gravity);

      final opacity = (lt < 0.65 ? 1.0 : (1 - (lt - 0.65) / 0.35)).clamp(
        0.0,
        1.0,
      );
      final w = (5.0 + ((i * 3) % 4)) * sizeScale;
      final h = w * 0.5;
      final spin = i * 0.7 + lt * math.pi * 6 * (i.isEven ? 1 : -1);

      paint.color = paletteColor(i).withValues(alpha: opacity);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(spin)
        // A thin sliver when seen edge-on (sin of the spin) → a fluttering feel.
        ..scale(1, 0.4 + 0.6 * math.sin(spin).abs())
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          paint,
        )
        ..restore();
    }
  }
}

/// Warm / organic: glowing embers that surge up, drift sideways with a flame
/// wobble, cool from gold through orange to red, and fade as they rise.
class EmbersBurstPainter extends CelebrationBurstPainter {
  EmbersBurstPainter({
    required super.progress,
    required super.origin,
    required super.palette,
    required super.count,
    required super.sizeScale,
    required super.clearCenter,
    required super.reachFactor,
    required super.reachOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerOf(size);
    final reach = reachOf(size);
    final clearRadius = reach * clearCenter;
    final paint = Paint();
    final red = palette.last;
    // Source colours are everything but the final (reddest) tone, so the lerp
    // has somewhere to cool *to*. Guard the length-1 case (the base only
    // promises a non-empty palette) so a future single-colour palette can't
    // divide by zero on the frame the burst fires.
    final sourceCount = palette.length > 1 ? palette.length - 1 : 1;

    for (var i = 0; i < count; i++) {
      final life = 0.6 + ((i * 5) % 5) / 5 * 0.4;
      final lt = (progress / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      final ease = Curves.easeOut.transform(lt);
      final spread = (((i * 7) % 9) / 9 - 0.5) * 1.4; // a narrow upward fan
      final rise = reach * (0.4 + 0.6 * (((i * 3) % 5) / 5)) * ease;
      final wobble = math.sin(lt * math.pi * 5 + i) * reach * 0.07;
      final pos = Offset(
        center.dx + math.sin(spread) * clearRadius + wobble,
        center.dy - rise,
      );

      // Cool from the lead colour toward red as the ember loses heat.
      final base = Color.lerp(paletteColor(i % sourceCount), red, lt)!;
      final isLead = i % 7 == 0;
      final opacity = ((1 - lt * lt) * (isLead ? 1.0 : 0.78)).clamp(0.0, 1.0);
      final r = (2.0 + ((i * 3) % 4) / 3 * 2.4) * (1 - 0.4 * lt) * sizeScale;
      if (r <= 0.3) continue;

      paint
        ..color = base.withValues(alpha: (opacity * 0.22).clamp(0.0, 1.0))
        ..strokeWidth = 0
        ..strokeCap = StrokeCap.butt;
      canvas.drawCircle(pos, r * 2.6, paint); // warm halo
      paint.color = base.withValues(alpha: opacity);
      canvas.drawCircle(pos, r, paint);
    }
  }
}

/// Warm / organic: soft iridescent bubbles that swell, rise with a gentle
/// wobble, and pop — a thin expanding ring at the end of each life.
class BubblesBurstPainter extends CelebrationBurstPainter {
  BubblesBurstPainter({
    required super.progress,
    required super.origin,
    required super.palette,
    required super.count,
    required super.sizeScale,
    required super.clearCenter,
    required super.reachFactor,
    required super.reachOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerOf(size);
    final reach = reachOf(size);
    final clearRadius = reach * clearCenter;
    final paint = Paint();

    for (var i = 0; i < count; i++) {
      final life = 0.7 + ((i * 5) % 5) / 5 * 0.3;
      final lt = (progress / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      final angle = (i / count) * math.pi * 2 + (((i * 13) % 7) - 3) * 0.05;
      final speed = 0.4 + ((i * 7) % 9) / 9 * 0.5;
      final wobble = math.sin(lt * math.pi * 3 + i) * reach * 0.06;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final pos =
          center +
          dir * (clearRadius + reach * speed * lt) +
          Offset(wobble, -reach * 0.35 * speed * lt);

      // Iridescent: shift the ring hue across the palette by direction.
      final base = Color.lerp(paletteColor(0), paletteColor(i), 0.5)!;
      // Swell quickly, hold, then pop in the last tenth of life.
      final popping = lt > 0.9;
      final swell = Curves.easeOut.transform((lt * 1.6).clamp(0.0, 1.0));
      final r =
          (3.0 + ((i * 3) % 4) / 3 * 3.0) *
          sizeScale *
          (popping ? 1.0 + (lt - 0.9) / 0.1 * 0.8 : 0.4 + 0.6 * swell);
      if (r <= 0.3) continue;
      final opacity = ((1 - lt * lt) * (popping ? 0.5 : 1.0)).clamp(0.0, 1.0);

      if (!popping) {
        // Faint fill so the bubble reads as a soft sphere, not a hole.
        paint
          ..style = PaintingStyle.fill
          ..color = base.withValues(alpha: (opacity * 0.12).clamp(0.0, 1.0));
        canvas.drawCircle(pos, r, paint);
      }
      // The membrane ring.
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = (popping ? 1.0 : 1.6) * sizeScale
        ..color = base.withValues(alpha: opacity);
      canvas.drawCircle(pos, r, paint);
      if (!popping) {
        // A small specular highlight up-and-left, drawn in the palette accent.
        paint
          ..style = PaintingStyle.fill
          ..color = paletteColor(0).withValues(
            alpha: (opacity * 0.6).clamp(0.0, 1.0),
          );
        canvas.drawCircle(pos + Offset(-r * 0.35, -r * 0.35), r * 0.18, paint);
      }
    }
  }
}
