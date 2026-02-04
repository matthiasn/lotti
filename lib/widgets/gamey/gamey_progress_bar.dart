import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';

/// An XP-style animated progress bar with gradient fill.
///
/// Features:
/// - Gradient fill (customizable)
/// - Animated progress changes
/// - Rounded ends
/// - Optional text overlay
/// - Glow effect on completion
class GameyProgressBar extends StatefulWidget {
  const GameyProgressBar({
    required this.progress,
    this.gradient,
    this.backgroundColor,
    this.height = 12.0,
    this.borderRadius,
    this.showText = false,
    this.textStyle,
    this.animateOnChange = true,
    this.animationDuration,
    this.animationCurve,
    this.showGlowOnComplete = true,
    this.glowColor,
    super.key,
  });

  /// Progress value from 0.0 to 1.0
  final double progress;

  /// Gradient for the filled portion (defaults to XP gradient)
  final Gradient? gradient;

  /// Background color for unfilled portion
  final Color? backgroundColor;

  /// Height of the progress bar (default: 12)
  final double height;

  /// Border radius (defaults to height / 2 for pill shape)
  final double? borderRadius;

  /// Whether to show progress text (e.g., "75%")
  final bool showText;

  /// Text style for progress text
  final TextStyle? textStyle;

  /// Whether to animate progress changes
  final bool animateOnChange;

  /// Animation duration
  final Duration? animationDuration;

  /// Animation curve
  final Curve? animationCurve;

  /// Whether to show glow effect when complete
  final bool showGlowOnComplete;

  /// Glow color (defaults to gradient's first color)
  final Color? glowColor;

  @override
  State<GameyProgressBar> createState() => _GameyProgressBarState();
}

class _GameyProgressBarState extends State<GameyProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.progress.clamp(0.0, 1.0);

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration ?? GameyAnimations.normal,
    );

    _progressAnimation = Tween<double>(
      begin: 0,
      end: _currentProgress,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve ?? GameyAnimations.smooth,
      ),
    );

    if (widget.animateOnChange) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(GameyProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newProgress = widget.progress.clamp(0.0, 1.0);
    if (newProgress != _currentProgress) {
      final oldProgress = _currentProgress;
      _currentProgress = newProgress;

      _progressAnimation = Tween<double>(
        begin: oldProgress,
        end: newProgress,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: widget.animationCurve ?? GameyAnimations.smooth,
        ),
      );

      if (widget.animateOnChange) {
        _controller
          ..reset()
          ..forward();
      } else {
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = widget.borderRadius ?? widget.height / 2;
    final effectiveGradient = widget.gradient ?? GameyGradients.xpProgress;
    final effectiveBackgroundColor = widget.backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08));
    final effectiveGlowColor =
        widget.glowColor ?? effectiveGradient.colors.first;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final progress = _progressAnimation.value;
        final isComplete = progress >= 1.0;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            borderRadius: BorderRadius.circular(effectiveRadius),
            boxShadow: (widget.showGlowOnComplete && isComplete)
                ? [GameyGlows.subtleGlow(effectiveGlowColor)]
                : null,
          ),
          child: Stack(
            children: [
              // Progress fill
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: effectiveGradient,
                    borderRadius: BorderRadius.circular(effectiveRadius),
                  ),
                ),
              ),

              // Text overlay
              if (widget.showText)
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: widget.textStyle ??
                        TextStyle(
                          color: Colors.white,
                          fontSize: widget.height * 0.65,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A labeled progress bar with title and optional value display
class GameyLabeledProgressBar extends StatelessWidget {
  const GameyLabeledProgressBar({
    required this.label,
    required this.progress,
    this.valueText,
    this.gradient,
    this.height = 10.0,
    this.labelStyle,
    this.valueStyle,
    this.spacing = 8.0,
    super.key,
  });

  final String label;
  final double progress;
  final String? valueText;
  final Gradient? gradient;
  final double height;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: labelStyle ??
                  theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (valueText != null)
              Text(
                valueText!,
                style: valueStyle ??
                    theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
        SizedBox(height: spacing),
        GameyProgressBar(
          progress: progress,
          gradient: gradient,
          height: height,
        ),
      ],
    );
  }
}

/// A circular progress indicator with gamey styling
class GameyCircularProgress extends StatefulWidget {
  const GameyCircularProgress({
    required this.progress,
    this.size = 64.0,
    this.strokeWidth = 6.0,
    this.gradient,
    this.backgroundColor,
    this.showText = true,
    this.textStyle,
    this.child,
    this.animateOnChange = true,
    super.key,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Gradient? gradient;
  final Color? backgroundColor;
  final bool showText;
  final TextStyle? textStyle;
  final Widget? child;
  final bool animateOnChange;

  @override
  State<GameyCircularProgress> createState() => _GameyCircularProgressState();
}

class _GameyCircularProgressState extends State<GameyCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.progress.clamp(0.0, 1.0);

    _controller = AnimationController(
      vsync: this,
      duration: GameyAnimations.normal,
    );

    _progressAnimation = Tween<double>(
      begin: 0,
      end: _currentProgress,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: GameyAnimations.smooth,
      ),
    );

    if (widget.animateOnChange) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(GameyCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newProgress = widget.progress.clamp(0.0, 1.0);
    if (newProgress != _currentProgress) {
      final oldProgress = _currentProgress;
      _currentProgress = newProgress;

      _progressAnimation = Tween<double>(
        begin: oldProgress,
        end: newProgress,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: GameyAnimations.smooth,
        ),
      );

      if (widget.animateOnChange) {
        _controller
          ..reset()
          ..forward();
      } else {
        // Skip animation, jump to completed state
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackgroundColor = widget.backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08));

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: widget.strokeWidth,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(effectiveBackgroundColor),
                ),
              ),
              // Progress circle
              ShaderMask(
                shaderCallback: (bounds) {
                  return (widget.gradient ?? GameyGradients.xpProgress)
                      .createShader(bounds);
                },
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: _progressAnimation.value,
                    strokeWidth: widget.strokeWidth,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              // Center content
              if (widget.child != null)
                widget.child!
              else if (widget.showText)
                Text(
                  '${(_progressAnimation.value * 100).round()}%',
                  style: widget.textStyle ??
                      TextStyle(
                        fontSize: widget.size * 0.22,
                        fontWeight: FontWeight.bold,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}
