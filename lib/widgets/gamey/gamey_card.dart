import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';

/// A vibrant, gamified card widget with gradient backgrounds and glowing shadows.
///
/// Features:
/// - Gradient or solid color backgrounds
/// - Color-matched glow shadows
/// - Playful tap animations
/// - Optional shimmer effect for special items
/// - Customizable border radius and padding
class GameyCard extends StatefulWidget {
  const GameyCard({
    required this.child,
    this.gradient,
    this.backgroundColor,
    this.glowColor,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.isHighlighted = false,
    this.showGlow = true,
    this.animateOnTap = true,
    this.border,
    super.key,
  });

  final Widget child;

  /// Gradient background (takes precedence over backgroundColor)
  final Gradient? gradient;

  /// Solid background color (used if gradient is null)
  final Color? backgroundColor;

  /// Color for the glow shadow (defaults to gradient's first color or backgroundColor)
  final Color? glowColor;

  /// Tap callback
  final VoidCallback? onTap;

  /// Long press callback
  final VoidCallback? onLongPress;

  /// Border radius (default: 20)
  final double borderRadius;

  /// Internal padding (default: 16)
  final EdgeInsets padding;

  /// External margin
  final EdgeInsets? margin;

  /// Whether the card is in highlighted state (stronger glow)
  final bool isHighlighted;

  /// Whether to show glow shadow
  final bool showGlow;

  /// Whether to animate on tap
  final bool animateOnTap;

  /// Optional border
  final Border? border;

  @override
  State<GameyCard> createState() => _GameyCardState();
}

class _GameyCardState extends State<GameyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GameyAnimations.fast,
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: GameyAnimations.tapScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: GameyAnimations.smooth,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.animateOnTap && widget.onTap != null) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.animateOnTap && widget.onTap != null) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.animateOnTap && widget.onTap != null) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  Color _getGlowColor() {
    if (widget.glowColor != null) return widget.glowColor!;
    if (widget.gradient != null) return widget.gradient!.colors.first;
    return widget.backgroundColor ?? GameyColors.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final glowColor = _getGlowColor();

    // Determine shadows
    List<BoxShadow> shadows;
    if (!widget.showGlow) {
      shadows = [];
    } else if (widget.isHighlighted || _isPressed) {
      shadows = GameyGlows.cardGlowHighlighted(glowColor, isDark: isDark);
    } else {
      shadows = GameyGlows.cardGlow(glowColor, isDark: isDark);
    }

    // Determine background - use theme surface colors
    final surfaceColor = colorScheme.surfaceContainer;
    final defaultGradient = isDark
        ? GameyGradients.cardDark(glowColor, surfaceColor)
        : GameyGradients.cardLight(glowColor, surfaceColor);

    final effectiveGradient = widget.gradient ?? defaultGradient;

    Widget card = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        gradient: widget.backgroundColor == null ? effectiveGradient : null,
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.border ??
            Border.all(
              color: glowColor.withValues(alpha: isDark ? 0.12 : 0.15),
              width: isDark ? 1 : 1.5,
            ),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            splashColor: glowColor.withValues(alpha: 0.15),
            highlightColor: glowColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    // Wrap with scale animation if tap animation is enabled
    if (widget.animateOnTap && widget.onTap != null) {
      card = AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }
}

/// A feature-specific GameyCard with pre-configured gradient and glow
class GameyFeatureCard extends StatelessWidget {
  const GameyFeatureCard({
    required this.feature,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.isHighlighted = false,
    super.key,
  });

  /// Feature type: 'journal', 'task', 'habit', 'mood', 'health', 'ai'
  final String feature;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return GameyCard(
      gradient: GameyGradients.forFeature(feature),
      glowColor: GameyColors.featureColor(feature),
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      isHighlighted: isHighlighted,
      child: child,
    );
  }
}

/// A subtle GameyCard that uses theme surface background with colored glow
class GameySubtleCard extends StatelessWidget {
  const GameySubtleCard({
    required this.child,
    this.accentColor,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.isHighlighted = false,
    super.key,
  });

  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? colorScheme.primary;
    final surfaceColor = colorScheme.surfaceContainer;

    return GameyCard(
      gradient: isDark
          ? GameyGradients.cardDark(effectiveAccent, surfaceColor)
          : GameyGradients.cardLight(effectiveAccent, surfaceColor),
      glowColor: effectiveAccent,
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      isHighlighted: isHighlighted,
      child: child,
    );
  }
}
