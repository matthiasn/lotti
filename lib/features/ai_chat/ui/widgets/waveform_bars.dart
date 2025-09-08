import 'package:flutter/material.dart';

/// WhatsApp-style right-aligned waveform bars.
///
/// - Newest amplitude appears on the right and pushes leftward.
/// - Bars are centered around a horizontal baseline.
/// - Colors blend between primary and secondary based on amplitude.
class WaveformBars extends StatelessWidget {
  const WaveformBars({
    required this.amplitudesNormalized,
    super.key,
    this.height = 48,
    this.barWidth = 2,
    this.barSpacing = 3,
    this.minBarHeight = 2,
    this.borderRadius = 24,
  });

  final List<double> amplitudesNormalized; // 0..1, oldest -> newest
  final double height;
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerRight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, height / 2),
            painter: _WaveformBarsPainter(
              amplitudes: amplitudesNormalized,
              barWidth: barWidth,
              barSpacing: barSpacing,
              minBarHeight: minBarHeight,
              primary: cs.primary,
              secondary: cs.secondary,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformBarsPainter extends CustomPainter {
  _WaveformBarsPainter({
    required this.amplitudes,
    required this.barWidth,
    required this.barSpacing,
    required this.minBarHeight,
    required this.primary,
    required this.secondary,
  });

  final List<double> amplitudes; // normalized 0..1
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final baselineY = size.height / 2;
    final totalBarWidth = barWidth + barSpacing;
    final maxBars = (size.width / totalBarWidth).floor();

    final visible = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    var x = size.width - barWidth; // start from right
    for (var i = visible.length - 1; i >= 0; i--) {
      final amp = visible[i].clamp(0.0, 1.0);
      final eased = Curves.easeOut.transform(amp);
      final barHeight = (eased * (size.height - minBarHeight)) + minBarHeight;
      final halfHeight = barHeight / 2;

      final color = Color.lerp(primary, secondary, amp) ?? primary;
      final paint = Paint()..color = color.withValues(alpha: 0.95);

      final rect = Rect.fromLTWH(
        x,
        baselineY - halfHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );

      x -= totalBarWidth;
      if (x < 0) break;
    }

    // Baseline for polish
    final basePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, baselineY), Offset(size.width, baselineY), basePaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformBarsPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.barSpacing != barSpacing ||
        oldDelegate.minBarHeight != minBarHeight;
  }
}
