import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Decorative live-waveform strip rendered below the voice button
/// while listening.
///
/// 28 thin teal bars whose heights are derived from a layered-sine
/// function over time so the strip "breathes" without ever spiking
/// dramatically. The waveform is **not** a real audio analyzer — the
/// real-time STT path is mocked for now; this widget exists purely to
/// signal "we're listening" to the user.
///
/// When the real STT pipeline lands, swap the height generator for
/// the `AudioRecorderState.vu` / `dBFS` stream.
class LiveWaveform extends StatefulWidget {
  const LiveWaveform({
    this.barCount = 28,
    this.width = 240,
    this.height = 28,
    super.key,
  });

  final int barCount;
  final double width;
  final double height;

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration t) {
    setState(() => _elapsed = t);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teal = context.designTokens.colors.interactive.enabled;
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _WaveformPainter(
        barCount: widget.barCount,
        color: teal,
        elapsedMs: _elapsed.inMilliseconds,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.barCount,
    required this.color,
    required this.elapsedMs,
  });

  final int barCount;
  final Color color;
  final int elapsedMs;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final spacing = size.width / barCount;
    final barWidth = math.max(spacing * 0.45, 1.5);
    final t = elapsedMs / 1000.0;

    for (var i = 0; i < barCount; i++) {
      // Layered sines staggered by bar index produce a per-bar height
      // that drifts independently. Range is normalized to [0.18..1.0]
      // so even the quietest bar stays visibly present.
      final a = math.sin(t * 2.3 + i * 0.42);
      final b = math.sin(t * 1.1 + i * 0.18 + 1.7);
      final mixed = 0.5 + (a * 0.35) + (b * 0.15);
      final h = size.height * mixed.clamp(0.18, 1.0);
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
    return old.elapsedMs != elapsedMs ||
        old.color != color ||
        old.barCount != barCount;
  }
}
