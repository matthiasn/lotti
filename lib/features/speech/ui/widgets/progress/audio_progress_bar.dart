import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Formats a [Duration] into `hh:mm:ss` or `mm:ss` for audio playback UI.
String formatAudioDuration(Duration duration) {
  final clampedSeconds = duration.inSeconds.clamp(0, 359999);
  final hours = clampedSeconds ~/ 3600;
  final minutes = (clampedSeconds % 3600) ~/ 60;
  final seconds = clampedSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class AudioProgressBar extends StatelessWidget {
  const AudioProgressBar({
    required this.progress,
    required this.buffered,
    required this.total,
    required this.onSeek,
    required this.enabled,
    required this.compact,
    this.semanticLabel,
    super.key,
  });

  final Duration progress;
  final Duration buffered;
  final Duration total;
  final ValueChanged<Duration> onSeek;
  final bool enabled;
  final bool compact;
  final String? semanticLabel;

  bool get _hasTotal => total.inMilliseconds > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackHeight = compact ? 6.0 : 8.0;
    final thumbRadius = compact ? 6.0 : 7.5;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final progressRatio = _hasTotal
            ? (progress.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        final bufferedRatio = _hasTotal
            ? (buffered.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        final Widget bar = SizedBox(
          width: double.infinity,
          height: compact ? 32 : 36,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ProgressBarPainter(
                backgroundColor:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.24),
                bufferedColor:
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                progressColor: theme.colorScheme.primary,
                glowColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                thumbColor: theme.colorScheme.onPrimary,
                progressRatio: progressRatio,
                bufferedRatio: bufferedRatio,
                trackHeight: trackHeight,
                thumbRadius: thumbRadius,
              ),
            ),
          ),
        );

        if (!enabled || !_hasTotal) {
          return bar;
        }

        void handle(Offset position) {
          if (width <= 0) {
            return;
          }
          final ratio = (position.dx / width).clamp(0.0, 1.0);
          final targetMs = (total.inMilliseconds * ratio).round();
          onSeek(Duration(milliseconds: targetMs));
        }

        return Semantics(
          label: semanticLabel ?? 'Audio timeline',
          value: '${formatAudioDuration(progress)} of '
              '${formatAudioDuration(total)}',
          increasedValue: 'Seek forward',
          decreasedValue: 'Seek backward',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) => handle(details.localPosition),
            onHorizontalDragStart: (details) => handle(details.localPosition),
            onHorizontalDragUpdate: (details) => handle(details.localPosition),
            child: bar,
          ),
        );
      },
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter({
    required this.backgroundColor,
    required this.bufferedColor,
    required this.progressColor,
    required this.glowColor,
    required this.thumbColor,
    required this.progressRatio,
    required this.bufferedRatio,
    required this.trackHeight,
    required this.thumbRadius,
  });

  final Color backgroundColor;
  final Color bufferedColor;
  final Color progressColor;
  final Color glowColor;
  final Color thumbColor;
  final double progressRatio;
  final double bufferedRatio;
  final double trackHeight;
  final double thumbRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final trackTop = (size.height - trackHeight) / 2;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, size.width, trackHeight),
      Radius.circular(trackHeight / 2),
    );

    final paint = Paint()..color = backgroundColor;
    canvas.drawRRect(trackRect, paint);

    if (bufferedRatio > 0) {
      final bufferedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          trackTop,
          size.width * bufferedRatio,
          trackHeight,
        ),
        Radius.circular(trackHeight / 2),
      );
      canvas.drawRRect(
        bufferedRect,
        Paint()..color = bufferedColor,
      );
    }

    if (progressRatio > 0) {
      final progressRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          trackTop,
          size.width * progressRatio,
          trackHeight,
        ),
        Radius.circular(trackHeight / 2),
      );

      final gradient = LinearGradient(
        colors: <Color>[
          Color.lerp(progressColor, Colors.white, 0.25)!,
          progressColor,
        ],
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(progressRect.outerRect);
      canvas.drawRRect(progressRect, progressPaint);

      final thumbCenter = Offset(
        progressRect.outerRect.right,
        trackRect.center.dy,
      );

      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          6,
        );
      canvas
        ..drawCircle(thumbCenter, thumbRadius + 3, glowPaint)
        ..drawCircle(
          thumbCenter,
          thumbRadius,
          Paint()..color = thumbColor,
        );
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) {
    return progressRatio != oldDelegate.progressRatio ||
        bufferedRatio != oldDelegate.bufferedRatio ||
        progressColor != oldDelegate.progressColor;
  }
}
