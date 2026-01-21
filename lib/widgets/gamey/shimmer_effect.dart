import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';

/// A shimmer effect widget that creates a sweeping highlight animation.
///
/// Perfect for premium/special items, loading states, or attention-grabbing elements.
class ShimmerEffect extends StatefulWidget {
  const ShimmerEffect({
    required this.child,
    this.isActive = true,
    this.duration = const Duration(milliseconds: 2000),
    this.shimmerColor,
    this.shimmerOpacity = 0.15,
    this.delay = Duration.zero,
    super.key,
  });

  /// The widget to apply shimmer effect to
  final Widget child;

  /// Whether the shimmer is active
  final bool isActive;

  /// Duration of one shimmer cycle
  final Duration duration;

  /// Color of the shimmer highlight
  final Color? shimmerColor;

  /// Opacity of the shimmer highlight
  final double shimmerOpacity;

  /// Delay before starting the animation
  final Duration delay;

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _delayComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      if (widget.delay > Duration.zero) {
        Future.delayed(widget.delay, () {
          if (mounted) {
            setState(() => _delayComplete = true);
            _controller.repeat();
          }
        });
      } else {
        _delayComplete = true;
        _controller.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(ShimmerEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || !_delayComplete) {
      return widget.child;
    }

    final shimmerColor = widget.shimmerColor ?? Colors.white;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.transparent,
                shimmerColor.withValues(alpha: widget.shimmerOpacity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(_animation.value - 0.5, -0.5),
              end: Alignment(_animation.value + 0.5, 0.5),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A shimmer loading placeholder widget.
///
/// Use as a skeleton loader while content is loading.
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
    super.key,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GameyAnimations.shimmer,
    )..repeat();

    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        widget.baseColor ?? (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.grey.shade700 : Colors.grey.shade100);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
            ),
          ),
        );
      },
    );
  }
}

/// A card-shaped shimmer placeholder
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    this.height = 100,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.showIcon = true,
    this.showTitle = true,
    this.showSubtitle = true,
    super.key,
  });

  final double height;
  final double borderRadius;
  final EdgeInsets padding;
  final bool showIcon;
  final bool showTitle;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            const ShimmerPlaceholder(
              width: 56,
              height: 56,
              borderRadius: 16,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTitle)
                  const ShimmerPlaceholder(
                    width: 150,
                    height: 18,
                  ),
                if (showTitle && showSubtitle) const SizedBox(height: 8),
                if (showSubtitle)
                  const ShimmerPlaceholder(
                    height: 14,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of shimmer card placeholders
class ShimmerCardList extends StatelessWidget {
  const ShimmerCardList({
    this.itemCount = 3,
    this.cardHeight = 100,
    this.spacing = 12,
    this.staggerDelay = const Duration(milliseconds: 100),
    super.key,
  });

  final int itemCount;
  final double cardHeight;
  final double spacing;
  final Duration staggerDelay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < itemCount - 1 ? spacing : 0),
          child: ShimmerCard(height: cardHeight),
        );
      }),
    );
  }
}

/// A pulse animation widget for subtle attention-grabbing
class PulseEffect extends StatefulWidget {
  const PulseEffect({
    required this.child,
    this.isActive = true,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.98,
    this.maxScale = 1.02,
    super.key,
  });

  final Widget child;
  final bool isActive;
  final Duration duration;
  final double minScale;
  final double maxScale;

  @override
  State<PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<PulseEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: GameyAnimations.symmetrical,
      ),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller..stop()
      ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A glow pulse animation that makes the shadow breathe
class GlowPulse extends StatefulWidget {
  const GlowPulse({
    required this.child,
    required this.glowColor,
    this.isActive = true,
    this.duration = const Duration(milliseconds: 1500),
    this.minOpacity = 0.15,
    this.maxOpacity = 0.35,
    this.blurRadius = 16,
    super.key,
  });

  final Widget child;
  final Color glowColor;
  final bool isActive;
  final Duration duration;
  final double minOpacity;
  final double maxOpacity;
  final double blurRadius;

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: GameyAnimations.symmetrical,
      ),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GlowPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: _animation.value),
                blurRadius: widget.blurRadius,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
