import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';

/// Displays a tappable/dragable waveform visualization mirroring the progress
/// bar semantics.
class AudioWaveformScrubber extends StatefulWidget {
  const AudioWaveformScrubber({
    required this.amplitudes,
    required this.progress,
    required this.buffered,
    required this.total,
    required this.onSeek,
    required this.enabled,
    required this.compact,
    super.key,
  });

  final List<double> amplitudes;
  final Duration progress;
  final Duration buffered;
  final Duration total;
  final ValueChanged<Duration> onSeek;
  final bool enabled;
  final bool compact;

  @override
  State<AudioWaveformScrubber> createState() => _AudioWaveformScrubberState();
}

class _AudioWaveformScrubberState extends State<AudioWaveformScrubber> {
  static const Duration _seekThrottleDelay = Duration(milliseconds: 60);
  static const double _targetBarWidth = 1.5;
  static const double _targetBarSpacing = 1.5;

  Timer? _throttleTimer;
  DateTime? _lastSeekInvocation;
  Duration? _pendingSeek;

  bool get _hasTotal => widget.total.inMilliseconds > 0;

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = resolveAudioProgressColors(theme);
    final height = (widget.compact ? 40 : 48).toDouble();

    final progressRatio = _hasTotal
        ? (widget.progress.inMilliseconds / widget.total.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;
    final bufferedRatio = _hasTotal
        ? (widget.buffered.inMilliseconds / widget.total.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final waveform = SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WaveformPainter(
            amplitudes: widget.amplitudes,
            progressRatio: progressRatio,
            bufferedRatio: bufferedRatio,
            progressColor: colors.progress,
            bufferedColor: colors.buffered,
            trackColor: colors.track,
            glowColor: colors.glow,
            targetBarWidth: _targetBarWidth,
            targetSpacing: _targetBarSpacing,
            compact: widget.compact,
          ),
        ),
      ),
    );

    if (!widget.enabled || !_hasTotal) {
      return waveform;
    }

    Duration durationForPosition(Offset position, double width) {
      if (width <= 0) {
        return Duration.zero;
      }
      final ratio = (position.dx / width).clamp(0.0, 1.0);
      final targetMs = (widget.total.inMilliseconds * ratio).round();
      return Duration(milliseconds: targetMs);
    }

    void handleImmediate(Offset position, double width) {
      final target = durationForPosition(position, width);
      _emitSeek(target);
    }

    void handleThrottled(Offset position, double width) {
      final target = durationForPosition(position, width);
      _scheduleSeek(target);
    }

    void handleDragEnd() {
      if (_pendingSeek != null) {
        widget.onSeek(_pendingSeek!);
        _lastSeekInvocation = DateTime.now();
        _pendingSeek = null;
      }
      _throttleTimer?.cancel();
      _throttleTimer = null;
    }

    final valueLabel =
        '${formatAudioDuration(widget.progress)} of ${formatAudioDuration(widget.total)}';
    final hintLabel =
        widget.enabled ? 'Tap to seek, drag to scrub' : 'Playback disabled';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return Semantics(
          label: 'Audio waveform',
          value: valueLabel,
          hint: hintLabel,
          child: GestureDetector(
            onTapDown: (TapDownDetails details) =>
                handleImmediate(details.localPosition, width),
            onHorizontalDragStart: (_) => _cancelThrottle(),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                handleThrottled(details.localPosition, width),
            onHorizontalDragEnd: (_) => handleDragEnd(),
            onHorizontalDragCancel: handleDragEnd,
            child: waveform,
          ),
        );
      },
    );
  }

  void _scheduleSeek(Duration target) {
    final now = DateTime.now();
    if (_lastSeekInvocation == null ||
        now.difference(_lastSeekInvocation!) > _seekThrottleDelay) {
      _emitSeek(target);
      return;
    }

    _pendingSeek = target;

    _throttleTimer ??= Timer(_seekThrottleDelay, () {
      if (_pendingSeek != null) {
        widget.onSeek(_pendingSeek!);
        _lastSeekInvocation = DateTime.now();
        _pendingSeek = null;
      }
      _throttleTimer = null;
    });
  }

  void _emitSeek(Duration target) {
    _pendingSeek = null;
    _cancelThrottle();
    widget.onSeek(target);
    _lastSeekInvocation = DateTime.now();
  }

  void _cancelThrottle() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.progressRatio,
    required this.bufferedRatio,
    required this.progressColor,
    required this.bufferedColor,
    required this.trackColor,
    required this.glowColor,
    required this.targetBarWidth,
    required this.targetSpacing,
    required this.compact,
  });

  final List<double> amplitudes;
  final double progressRatio;
  final double bufferedRatio;
  final Color progressColor;
  final Color bufferedColor;
  final Color trackColor;
  final Color glowColor;
  final double targetBarWidth;
  final double targetSpacing;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final barCount = amplitudes.length;
    final barFullWidth = size.width / barCount;
    final desiredWidth = targetBarWidth;
    final spacingTarget = compact ? targetSpacing * 0.9 : targetSpacing;

    double barWidth = math.min(desiredWidth, barFullWidth);
    double spacing = math.max(0, barFullWidth - barWidth);

    if (spacing > spacingTarget && barFullWidth > spacingTarget) {
      barWidth = math.max(1, barFullWidth - spacingTarget);
      spacing = barFullWidth - barWidth;
    }

    if (barWidth > barFullWidth) {
      barWidth = barFullWidth;
      spacing = 0;
    }
    final maxHeight = size.height * 0.8;
    final minBarHeight = math.max(2, size.height * 0.08).toDouble();
    final baseline = size.height / 2;

    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final progressPaint = Paint()..color = progressColor;
    final bufferedPaint = Paint()..color = bufferedColor;
    final trackPaint = Paint()..color = trackColor;

    final barRadius = Radius.circular(compact ? 1.0 : 1.5);

    var x = 0.0;
    for (var index = 0; index < barCount; index++) {
      final amplitude = amplitudes[index].clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(amplitude);
      final barHeight = math.max(minBarHeight, eased * maxHeight);
      final progressThreshold = (index + 0.5) / barCount;

      final paint = progressThreshold <= progressRatio
          ? progressPaint
          : progressThreshold <= bufferedRatio
              ? bufferedPaint
              : trackPaint;

      if (x + barWidth > size.width) {
        break;
      }

      final rect = RRect.fromLTRBR(
        x,
        baseline - barHeight / 2,
        x + barWidth,
        baseline + barHeight / 2,
        barRadius,
      );

      if (paint == progressPaint && glowColor.a > 0) {
        canvas.drawRRect(rect, glowPaint);
      }
      canvas.drawRRect(rect, paint);
      x += barWidth + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.progressRatio != progressRatio ||
        oldDelegate.bufferedRatio != bufferedRatio ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.bufferedColor != bufferedColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.targetBarWidth != targetBarWidth ||
        oldDelegate.targetSpacing != targetSpacing ||
        oldDelegate.compact != compact;
  }
}
