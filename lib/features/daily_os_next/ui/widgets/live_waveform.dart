import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Live-waveform strip rendered below the voice button while listening.
///
/// Renders [amplitudes] as a row of thin teal bars. Values are
/// expected to be normalised to `0.0..1.0` (see
/// `CaptureController._normaliseDbfs`); the widget itself does no
/// audio analysis.
///
/// When [amplitudes] is empty (or shorter than [barCount]), the
/// missing trailing slots render as a small idle baseline so the
/// strip never collapses to nothing while we wait for the first
/// amplitude sample to land.
class LiveWaveform extends StatelessWidget {
  const LiveWaveform({
    required this.amplitudes,
    this.barCount = 28,
    this.width = 240,
    this.height = 28,
    this.color,
    super.key,
  });

  /// Normalised amplitude samples in chronological order. Only the
  /// most recent [barCount] entries are rendered.
  final List<double> amplitudes;

  final int barCount;
  final double width;
  final double height;

  /// Bar colour. Defaults to the brand interactive (teal) when null, so
  /// existing callers are unchanged; the recording-style picker passes a
  /// per-style tint.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final teal = color ?? context.designTokens.colors.interactive.enabled;
    // Reduced motion: the strip stops dancing with the live signal and rests on
    // a calm static baseline. The orb and the "Listening…" caption still carry
    // the recording state, so no information is lost — only the motion.
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: LiveWaveformPainter(
          barCount: barCount,
          color: teal,
          amplitudes: amplitudes,
          reducedMotion: reducedMotion,
        ),
      ),
    );
  }
}

/// Paints the [LiveWaveform] bars. When [reducedMotion] is set it ignores the
/// live [amplitudes] entirely and draws a flat resting baseline, so the strip
/// never animates for a reduced-motion user.
class LiveWaveformPainter extends CustomPainter {
  LiveWaveformPainter({
    required this.barCount,
    required this.color,
    required this.amplitudes,
    this.reducedMotion = false,
  });

  /// Minimum bar height fraction. Keeps every slot visibly present
  /// even when the source amplitude is near zero.
  static const _idleFraction = 0.12;

  final int barCount;
  final Color color;
  final List<double> amplitudes;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final spacing = size.width / barCount;
    final barWidth = math.max(spacing * 0.45, 1.5);
    // Under reduced motion the live signal is ignored, so the slice is unused.
    final slice = reducedMotion
        ? const <double>[]
        : amplitudes.sublist(math.max(0, amplitudes.length - barCount));

    for (var i = 0; i < barCount; i++) {
      final double fraction;
      if (reducedMotion) {
        // Static resting baseline — every bar at the idle minimum.
        fraction = _idleFraction;
      } else {
        // Right-align the live samples so newer values stay on the right
        // (matches how voice waveforms read in iOS / standard recorders).
        final ageFromRight = barCount - 1 - i;
        final sampleIndex = slice.length - 1 - ageFromRight;
        final value = (sampleIndex >= 0 && sampleIndex < slice.length)
            ? slice[sampleIndex].clamp(0.0, 1.0)
            : 0.0;
        fraction = math.max(_idleFraction, value);
      }
      final h = size.height * fraction;
      final x = i * spacing + (spacing - barWidth) / 2;
      final y = (size.height - h) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LiveWaveformPainter old) {
    if (old.reducedMotion != reducedMotion) return true;
    // The static baseline ignores the live signal, so amplitude churn must not
    // force a repaint for a reduced-motion user.
    if (reducedMotion) {
      return old.color != color || old.barCount != barCount;
    }
    return old.color != color ||
        old.barCount != barCount ||
        !identical(old.amplitudes, amplitudes);
  }
}
