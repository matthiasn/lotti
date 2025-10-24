import 'dart:async';
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

class AudioProgressColors {
  const AudioProgressColors({
    required this.track,
    required this.buffered,
    required this.progress,
    required this.thumb,
    required this.glow,
  });

  final Color track;
  final Color buffered;
  final Color progress;
  final Color thumb;
  final Color glow;
}

AudioProgressColors resolveAudioProgressColors(ThemeData theme) {
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  final progressBase = scheme.primary;

  final track = scheme.onSurfaceVariant.withValues(
    alpha: isDark ? 0.32 : 0.24,
  );

  final buffered = progressBase.withValues(
    alpha: isDark ? 0.22 : 0.18,
  );

  final glow =
      isDark ? Colors.transparent : progressBase.withValues(alpha: 0.3);
  final thumb = _resolveThumbColor(scheme, isDark);

  return AudioProgressColors(
    track: track,
    buffered: buffered,
    progress: progressBase,
    thumb: thumb,
    glow: glow,
  );
}

Color _resolveThumbColor(ColorScheme scheme, bool isDark) {
  final base = scheme.primary;
  if (base.a == 0) {
    return base;
  }

  final luminance = base.computeLuminance();
  if (isDark) {
    return Color.lerp(base, Colors.white, 0.45)!;
  }

  if (luminance > 0.75) {
    return Color.lerp(base, Colors.black, 0.2)!;
  }

  return Color.lerp(base, Colors.white, 0.1)!;
}

/// Custom painted progress bar with buffered overlay and gesture-driven scrubbing.
class AudioProgressBar extends StatefulWidget {
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

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  static const Duration _seekThrottleDelay = Duration(milliseconds: 60);

  Timer? _throttleTimer;
  DateTime? _lastSeekInvocation;
  Duration? _pendingSeek;

  bool get _hasTotal => widget.total.inMilliseconds > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackHeight = widget.compact ? 6.0 : 8.0;
    final thumbRadius = widget.compact ? 6.0 : 7.5;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final progressRatio = _hasTotal
            ? (widget.progress.inMilliseconds / widget.total.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        final bufferedRatio = _hasTotal
            ? (widget.buffered.inMilliseconds / widget.total.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        final colors = resolveAudioProgressColors(theme);

        final Widget bar = SizedBox(
          width: double.infinity,
          height: widget.compact ? 32 : 36,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ProgressBarPainter(
                backgroundColor: colors.track,
                bufferedColor: colors.buffered,
                progressColor: colors.progress,
                glowColor: colors.glow,
                thumbColor: colors.thumb,
                progressRatio: progressRatio,
                bufferedRatio: bufferedRatio,
                trackHeight: trackHeight,
                thumbRadius: thumbRadius,
              ),
            ),
          ),
        );

        if (!widget.enabled || !_hasTotal) {
          return bar;
        }

        Duration durationForPosition(Offset position) {
          if (width <= 0) {
            return Duration.zero;
          }
          final ratio = (position.dx / width).clamp(0.0, 1.0);
          final targetMs = (widget.total.inMilliseconds * ratio).round();
          return Duration(milliseconds: targetMs);
        }

        void handleImmediate(Offset position) {
          final target = durationForPosition(position);
          if (!_hasTotal) {
            return;
          }
          _emitSeek(target);
        }

        void handleThrottled(Offset position) {
          final target = durationForPosition(position);
          if (!_hasTotal) {
            return;
          }
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

        return Semantics(
          label: widget.semanticLabel ?? 'Audio timeline',
          value: '${formatAudioDuration(widget.progress)} of '
              '${formatAudioDuration(widget.total)}',
          increasedValue: 'Seek forward',
          decreasedValue: 'Seek backward',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) => handleImmediate(details.localPosition),
            onHorizontalDragStart: (details) =>
                handleThrottled(details.localPosition),
            onHorizontalDragUpdate: (details) =>
                handleThrottled(details.localPosition),
            onHorizontalDragEnd: (_) => handleDragEnd(),
            onHorizontalDragCancel: handleDragEnd,
            child: bar,
          ),
        );
      },
    );
  }

  void _emitSeek(Duration target) {
    widget.onSeek(target);
    _lastSeekInvocation = DateTime.now();
  }

  void _scheduleSeek(Duration target) {
    final now = DateTime.now();
    final last = _lastSeekInvocation;
    if (last == null || now.difference(last) >= _seekThrottleDelay) {
      _emitSeek(target);
      _pendingSeek = null;
      _throttleTimer?.cancel();
      _throttleTimer = null;
      return;
    }

    _pendingSeek = target;
    _throttleTimer ??= Timer(
      _seekThrottleDelay - now.difference(last),
      () {
        if (_pendingSeek != null) {
          _emitSeek(_pendingSeek!);
          _pendingSeek = null;
        }
        _throttleTimer = null;
      },
    );
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
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

      if (glowColor.a > 0) {
        final glowPaint = Paint()
          ..color = glowColor
          ..maskFilter = const ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            6,
          );
        canvas.drawCircle(thumbCenter, thumbRadius + 3, glowPaint);
      }

      canvas.drawCircle(
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
        progressColor != oldDelegate.progressColor ||
        backgroundColor != oldDelegate.backgroundColor ||
        bufferedColor != oldDelegate.bufferedColor ||
        glowColor != oldDelegate.glowColor ||
        thumbColor != oldDelegate.thumbColor ||
        trackHeight != oldDelegate.trackHeight ||
        thumbRadius != oldDelegate.thumbRadius;
  }
}
