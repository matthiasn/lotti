import 'dart:math' as math;

import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The live voice of a take — the app's one level meter, on the recorder
/// and in every field that takes dictation: thin accent bars travelling
/// from *now*, at the right, towards the past, over a hairline that is what
/// silence looks like.
///
/// The bars move at one pace wherever they are drawn: each stands for
/// [barDuration] of the take, and as many are drawn as fit the width given.
/// So a phone's sheet and the widest desktop row read alike, and a wider row
/// simply reaches further back. Nothing is drawn for the time before the
/// take: the hairline grows in from the right with it, and the oldest end
/// fades out so the eye rests on the newest bars.
///
/// Under reduced motion the bars are left out and the hairline lies still
/// across the whole width; the surface's own clock and controls still say a
/// take is running.
class DesignSystemVoiceWaveform extends StatelessWidget {
  const DesignSystemVoiceWaveform({
    required this.levels,
    this.sampleInterval = defaultSampleInterval,
    this.color,
    super.key,
  });

  /// The stretch of a take one bar stands for.
  static const Duration barDuration = Duration(milliseconds: 40);

  /// How often a level is taken, unless the host says otherwise.
  static const Duration defaultSampleInterval = Duration(milliseconds: 100);

  /// Loudness in `0..1`, oldest first, one per [sampleInterval].
  final List<double> levels;
  final Duration sampleInterval;

  /// The bars' ink; the accent when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final height = tokens.spacing.step6;
    final fade = LinearGradient(
      colors: [
        tokens.colors.text.highEmphasis.withValues(alpha: 0),
        tokens.colors.text.highEmphasis,
      ],
      stops: const [0, 0.18],
    );
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) => ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: fade.createShader,
              child: CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: DesignSystemVoiceWaveformPainter(
                  levels: levels,
                  samplesPerBar:
                      barDuration.inMicroseconds /
                      sampleInterval.inMicroseconds,
                  barWidth: tokens.spacing.step1,
                  barSpacing: tokens.spacing.step2,
                  color: color ?? tokens.colors.interactive.enabled,
                  baselineColor: tokens.colors.decorative.level02,
                  // The hairline weight of the recorder's control rings.
                  baselineWidth: tokens.spacing.step1 / 2,
                  reducedMotion: MediaQuery.disableAnimationsOf(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [DesignSystemVoiceWaveform]. Public so its geometry can be tested.
@visibleForTesting
class DesignSystemVoiceWaveformPainter extends CustomPainter {
  DesignSystemVoiceWaveformPainter({
    required this.levels,
    required this.samplesPerBar,
    required this.barWidth,
    required this.barSpacing,
    required this.color,
    required this.baselineColor,
    required this.baselineWidth,
    this.reducedMotion = false,
  });

  final List<double> levels;

  /// How many samples one bar stands for: above one, a bar is the loudest
  /// of its samples; below one, it reads between the two around it.
  final double samplesPerBar;
  final double barWidth;
  final double barSpacing;
  final Color color;
  final Color baselineColor;
  final double baselineWidth;
  final bool reducedMotion;

  /// How many bars fit [width].
  int capacity(double width) =>
      ((width + barSpacing) / (barWidth + barSpacing)).floor();

  /// The level at fractional sample [at], read between its two neighbours;
  /// null before the take.
  double? levelAt(double at) {
    if (levels.isEmpty || at < 0) return null;
    final last = levels.length - 1;
    if (at >= last) return levels[last];
    final low = at.floor();
    final t = at - low;
    return levels[low] * (1 - t) + levels[low + 1] * t;
  }

  /// The level of the bar whose newest sample is at fractional index [at]:
  /// the loudest of the [samplesPerBar] samples it stands for, so a fast
  /// recorder's samples move the bars smoothly rather than each one jolting
  /// them; null before the take.
  double? barLevelAt(double at) {
    if (samplesPerBar <= 1) return levelAt(at);
    if (levels.isEmpty || at < 0) return null;
    final last = math.min(at.floor(), levels.length - 1);
    final first = math.max((at - samplesPerBar).floor() + 1, 0);
    var loudest = levels[last];
    for (var i = first; i < last; i++) {
      loudest = math.max(loudest, levels[i]);
    }
    return loudest;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final slots = capacity(size.width);
    if (slots <= 0) return;
    final centreY = size.height / 2;
    final step = barWidth + barSpacing;
    // Right-aligned: the last slot is the newest sample.
    final offset = size.width - (slots * step - barSpacing);
    final newest = (levels.length - 1).toDouble();
    // The slots the take has reached so far.
    final reached = reducedMotion
        ? slots
        : math.min(slots, (newest / samplesPerBar).floor() + 1);
    if (!reducedMotion && levels.isEmpty) return;

    final start = offset + (slots - reached) * step;
    canvas.drawLine(
      Offset(reducedMotion ? 0 : start, centreY),
      Offset(size.width, centreY),
      Paint()
        ..color = baselineColor
        ..strokeWidth = baselineWidth,
    );
    if (reducedMotion) return;

    final paint = Paint()..color = color;
    final radius = Radius.circular(barWidth / 2);
    for (var slot = slots - reached; slot < slots; slot++) {
      final level = barLevelAt(newest - (slots - 1 - slot) * samplesPerBar);
      if (level == null) continue;
      final height = level.clamp(0.0, 1.0) * size.height;
      // Silence is the hairline alone.
      if (height <= baselineWidth) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offset + slot * step,
            centreY - height / 2,
            barWidth,
            height,
          ),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DesignSystemVoiceWaveformPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.samplesPerBar != samplesPerBar ||
      oldDelegate.color != color ||
      oldDelegate.baselineColor != baselineColor ||
      oldDelegate.baselineWidth != baselineWidth ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.barWidth != barWidth ||
      oldDelegate.barSpacing != barSpacing;
}
