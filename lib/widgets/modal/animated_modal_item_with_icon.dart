import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A specialized version of AnimatedModalItem that also animates an icon
class AnimatedModalItemWithIcon extends StatefulWidget {
  const AnimatedModalItemWithIcon({
    required this.child,
    required this.onTap,
    required this.iconBuilder,
    this.isDisabled = false,
    this.hoverScale = 0.99,
    this.tapScale = 0.97,
    this.tapOpacity = 1.0,
    this.hoverElevation = 4,
    this.iconScaleOnTap = 0.9,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, Animation<double> iconAnimation,
      {required bool isPressed}) iconBuilder;
  final bool isDisabled;
  final double hoverScale;
  final double tapScale;
  final double tapOpacity;
  final double hoverElevation;
  final double iconScaleOnTap;

  @override
  State<AnimatedModalItemWithIcon> createState() =>
      _AnimatedModalItemWithIconState();
}

class _AnimatedModalItemWithIconState extends State<AnimatedModalItemWithIcon>
    with TickerProviderStateMixin {
  late AnimationController _hoverAnimationController;
  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _hoverElevationAnimation;
  late AnimationController _tapAnimationController;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _tapOpacityAnimation;
  late Animation<double> _iconScaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Hover animations
    _hoverAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverScaleAnimation = Tween<double>(
      begin: 1,
      end: widget.hoverScale,
    ).animate(CurvedAnimation(
      parent: _hoverAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _hoverElevationAnimation = Tween<double>(
      begin: 0,
      end: widget.hoverElevation,
    ).animate(CurvedAnimation(
      parent: _hoverAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Tap animations
    _tapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _tapScaleAnimation = Tween<double>(
      begin: 1,
      end: widget.tapScale,
    ).animate(CurvedAnimation(
      parent: _tapAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _tapOpacityAnimation = Tween<double>(
      begin: 1,
      end: widget.tapOpacity,
    ).animate(CurvedAnimation(
      parent: _tapAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _iconScaleAnimation = Tween<double>(
      begin: 1,
      end: widget.iconScaleOnTap,
    ).animate(CurvedAnimation(
      parent: _tapAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _hoverAnimationController.dispose();
    _tapAnimationController.dispose();
    super.dispose();
  }

  void _handleHoverChanged(bool isHovered) {
    if (isHovered && !widget.isDisabled) {
      _hoverAnimationController.forward();
    } else {
      _hoverAnimationController.reverse();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled) {
      setState(() => _isPressed = true);
      _tapAnimationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled) {
      setState(() => _isPressed = false);
      _tapAnimationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled) {
      setState(() => _isPressed = false);
      _tapAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_tapAnimationController, _hoverAnimationController]),
      builder: (context, _) {
        final combinedScale =
            _hoverScaleAnimation.value * _tapScaleAnimation.value;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.isDisabled ? null : widget.onTap,
          child: MouseRegion(
            onEnter: (_) => _handleHoverChanged(true),
            onExit: (_) => _handleHoverChanged(false),
            child: Transform.scale(
              scale: combinedScale,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.cardPadding,
                  vertical: AppTheme.cardSpacing / 2,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.cardBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: context.colorScheme.shadow.withValues(
                          alpha: isDark
                              ? AppTheme.alphaShadowDark
                              : AppTheme.alphaShadowLight,
                        ),
                        blurRadius: (isDark
                                ? AppTheme.cardElevationDark
                                : AppTheme.cardElevationLight) +
                            _hoverElevationAnimation.value,
                        offset: AppTheme.shadowOffset,
                      ),
                    ],
                  ),
                  child: AnimatedOpacity(
                    opacity:
                        widget.isDisabled ? 0.5 : _tapOpacityAnimation.value,
                    duration: const Duration(milliseconds: 150),
                    child: widget.iconBuilder(context, _iconScaleAnimation,
                        isPressed: _isPressed),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
