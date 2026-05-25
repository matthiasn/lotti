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
    super.key,
  });

  /// Normalised amplitude samples in chronological order. Only the
  /// most recent [barCount] entries are rendered.
  final List<double> amplitudes;

  final int barCount;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final teal = context.designTokens.colors.interactive.enabled;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: _WaveformPainter(
          barCount: barCount,
          color: teal,
          amplitudes: amplitudes,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.barCount,
    required this.color,
    required this.amplitudes,
  });

  /// Minimum bar height fraction. Keeps every slot visibly present
  /// even when the source amplitude is near zero.
  static const _idleFraction = 0.12;

  final int barCount;
  final Color color;
  final List<double> amplitudes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final spacing = size.width / barCount;
    final barWidth = math.max(spacing * 0.45, 1.5);
    final sliceStart = math.max(0, amplitudes.length - barCount);
    final slice = amplitudes.sublist(sliceStart);

    for (var i = 0; i < barCount; i++) {
      // Right-align the live samples so newer values stay on the right
      // (matches how voice waveforms read in iOS / standard recorders).
      final ageFromRight = barCount - 1 - i;
      final sampleIndex = slice.length - 1 - ageFromRight;
      final value = (sampleIndex >= 0 && sampleIndex < slice.length)
          ? slice[sampleIndex].clamp(0.0, 1.0)
          : 0.0;
      final fraction = math.max(_idleFraction, value);
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
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.color != color ||
        old.barCount != barCount ||
        !identical(old.amplitudes, amplitudes);
  }
}
