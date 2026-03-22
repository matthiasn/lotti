import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

const _kTrackAlpha = 0.3;
const _kSkeletonBaseAlpha = 0.08;
const _kSkeletonShimmerAlpha = 0.16;

enum DesignSystemSpinnerStyle {
  plain,
  track,
}

class DesignSystemSpinner extends StatefulWidget {
  const DesignSystemSpinner({
    this.style = DesignSystemSpinnerStyle.track,
    this.size = 48,
    this.strokeWidth = 8,
    this.semanticsLabel,
    super.key,
  });

  final DesignSystemSpinnerStyle style;
  final double size;
  final double strokeWidth;
  final String? semanticsLabel;

  @override
  State<DesignSystemSpinner> createState() => _DesignSystemSpinnerState();
}

class _DesignSystemSpinnerState extends State<DesignSystemSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tokens.colors.interactive.enabled;

    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _SpinnerPainter(
                color: color,
                style: widget.style,
                strokeWidth: widget.strokeWidth,
                rotationValue: _controller.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.color,
    required this.style,
    required this.strokeWidth,
    required this.rotationValue,
  });

  final Color color;
  final DesignSystemSpinnerStyle style;
  final double strokeWidth;
  final double rotationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (style == DesignSystemSpinnerStyle.track) {
      final trackPaint = Paint()
        ..color = color.withValues(alpha: _kTrackAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, trackPaint);
    }

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const sweepAngle = math.pi * 0.5;
    final startAngle = rotationValue * math.pi * 2 - math.pi / 2;

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) {
    return oldDelegate.rotationValue != rotationValue ||
        oldDelegate.color != color ||
        oldDelegate.style != style ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

enum DesignSystemSkeletonAnimation {
  wave,
  pulse,
}

class DesignSystemSkeleton extends StatefulWidget {
  const DesignSystemSkeleton({
    this.width = double.infinity,
    this.height = 40,
    this.borderRadius,
    this.animation = DesignSystemSkeletonAnimation.wave,
    this.semanticsLabel,
    super.key,
  });

  final double width;
  final double height;
  final double? borderRadius;
  final DesignSystemSkeletonAnimation animation;
  final String? semanticsLabel;

  @override
  State<DesignSystemSkeleton> createState() => _DesignSystemSkeletonState();
}

class _DesignSystemSkeletonState extends State<DesignSystemSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = widget.borderRadius ?? tokens.radii.xs;

    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: CustomPaint(
                painter: _SkeletonPainter(
                  animation: widget.animation,
                  progress: _controller.value,
                  baseColor: tokens.colors.text.highEmphasis.withValues(
                    alpha: _kSkeletonBaseAlpha,
                  ),
                  shimmerColor: tokens.colors.text.highEmphasis.withValues(
                    alpha: _kSkeletonShimmerAlpha,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.animation,
    required this.progress,
    required this.baseColor,
    required this.shimmerColor,
  });

  final DesignSystemSkeletonAnimation animation;
  final double progress;
  final Color baseColor;
  final Color shimmerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = baseColor;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    switch (animation) {
      case DesignSystemSkeletonAnimation.wave:
        _paintWave(canvas, size);
      case DesignSystemSkeletonAnimation.pulse:
        _paintPulse(canvas, size);
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    final shimmerWidth = size.width * 0.5;
    final dx = -shimmerWidth + (size.width + shimmerWidth) * progress;

    final gradient = LinearGradient(
      colors: [baseColor, shimmerColor, baseColor],
    );

    final shimmerPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(dx, 0, shimmerWidth, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(dx, 0, shimmerWidth, size.height),
      shimmerPaint,
    );
  }

  void _paintPulse(Canvas canvas, Size size) {
    final pulseAlpha = (math.sin(progress * math.pi * 2) + 1) / 2;
    final pulsePaint = Paint()
      ..color = shimmerColor.withValues(alpha: shimmerColor.a * pulseAlpha);
    canvas.drawRect(Offset.zero & size, pulsePaint);
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animation != animation ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.shimmerColor != shimmerColor;
  }
}
