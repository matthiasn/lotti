import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';

/// A vibrant icon badge with gradient background and glow effect.
///
/// Used for feature icons, action buttons, and visual indicators.
/// Larger and more prominent than standard icon containers.
class GameyIconBadge extends StatefulWidget {
  const GameyIconBadge({
    required this.icon,
    this.gradient,
    this.backgroundColor,
    this.iconColor,
    this.size = 56.0,
    this.iconSize,
    this.onTap,
    this.showGlow = true,
    this.isPulsing = false,
    this.isActive = false,
    this.borderRadius,
    super.key,
  });

  /// The icon to display
  final IconData icon;

  /// Gradient background (takes precedence over backgroundColor)
  final Gradient? gradient;

  /// Solid background color
  final Color? backgroundColor;

  /// Icon color (auto-calculated from background if null)
  final Color? iconColor;

  /// Overall size of the badge (default: 56)
  final double size;

  /// Icon size (defaults to size * 0.45)
  final double? iconSize;

  /// Tap callback
  final VoidCallback? onTap;

  /// Whether to show glow shadow
  final bool showGlow;

  /// Whether to animate with pulse effect
  final bool isPulsing;

  /// Whether the badge is in active state (stronger glow)
  final bool isActive;

  /// Border radius (defaults to size / 3.5 for rounded square)
  final double? borderRadius;

  @override
  State<GameyIconBadge> createState() => _GameyIconBadgeState();
}

class _GameyIconBadgeState extends State<GameyIconBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: GameyAnimations.pulse,
    );

    _pulseAnimation = Tween<double>(
      begin: 1,
      end: GameyAnimations.pulseScaleMax,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: GameyAnimations.symmetrical,
      ),
    );

    if (widget.isPulsing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GameyIconBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !oldWidget.isPulsing) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isPulsing && oldWidget.isPulsing) {
      _pulseController..stop()
      ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getPrimaryColor() {
    if (widget.gradient != null) return widget.gradient!.colors.first;
    return widget.backgroundColor ?? GameyColors.primaryBlue;
  }

  /// Calculate icon color based on background luminance
  Color _getIconColor(Color backgroundColor) {
    if (widget.iconColor != null) return widget.iconColor!;
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = widget.iconSize ?? widget.size * 0.45;
    final effectiveRadius = widget.borderRadius ?? widget.size / 3.5;
    final primaryColor = _getPrimaryColor();
    final iconColor = _getIconColor(primaryColor);

    // Default gradient if none provided
    final effectiveGradient = widget.gradient ??
        LinearGradient(
          colors: [
            widget.backgroundColor ?? GameyColors.primaryBlue,
            (widget.backgroundColor ?? GameyColors.primaryBlue)
                .withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final Widget badge = AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.isPulsing
            ? _pulseAnimation.value
            : (_isPressed ? GameyAnimations.iconTapScale : 1.0);

        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          gradient: widget.backgroundColor == null ? effectiveGradient : null,
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(effectiveRadius),
          boxShadow: widget.showGlow
              ? GameyGlows.iconGlow(primaryColor, isActive: widget.isActive)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: widget.onTap != null
                ? (_) => setState(() => _isPressed = true)
                : null,
            onTapUp: widget.onTap != null
                ? (_) => setState(() => _isPressed = false)
                : null,
            onTapCancel: widget.onTap != null
                ? () => setState(() => _isPressed = false)
                : null,
            borderRadius: BorderRadius.circular(effectiveRadius),
            splashColor: iconColor.withValues(alpha: 0.2),
            highlightColor: iconColor.withValues(alpha: 0.1),
            child: Center(
              child: Icon(
                widget.icon,
                size: effectiveIconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );

    return badge;
  }
}

/// A feature-specific icon badge with pre-configured gradient and glow
class GameyFeatureIconBadge extends StatelessWidget {
  const GameyFeatureIconBadge({
    required this.feature,
    required this.icon,
    this.size = 56.0,
    this.iconSize,
    this.onTap,
    this.showGlow = true,
    this.isPulsing = false,
    this.isActive = false,
    super.key,
  });

  /// Feature type: 'journal', 'task', 'habit', 'mood', 'health', 'ai'
  final String feature;
  final IconData icon;
  final double size;
  final double? iconSize;
  final VoidCallback? onTap;
  final bool showGlow;
  final bool isPulsing;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GameyIconBadge(
      icon: icon,
      gradient: GameyGradients.forFeature(feature),
      size: size,
      iconSize: iconSize,
      onTap: onTap,
      showGlow: showGlow,
      isPulsing: isPulsing,
      isActive: isActive,
    );
  }
}

/// A circular icon badge (perfect circle)
class GameyCircleIconBadge extends StatelessWidget {
  const GameyCircleIconBadge({
    required this.icon,
    this.gradient,
    this.backgroundColor,
    this.iconColor,
    this.size = 48.0,
    this.iconSize,
    this.onTap,
    this.showGlow = true,
    this.isPulsing = false,
    this.isActive = false,
    super.key,
  });

  final IconData icon;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double? iconSize;
  final VoidCallback? onTap;
  final bool showGlow;
  final bool isPulsing;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GameyIconBadge(
      icon: icon,
      gradient: gradient,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      size: size,
      iconSize: iconSize,
      onTap: onTap,
      showGlow: showGlow,
      isPulsing: isPulsing,
      isActive: isActive,
      borderRadius: size / 2, // Perfect circle
    );
  }
}
