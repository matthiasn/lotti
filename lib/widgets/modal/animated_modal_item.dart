import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A wrapper widget that provides hover and tap animations for modal items
class AnimatedModalItem extends StatefulWidget {
  const AnimatedModalItem({
    required this.child,
    required this.onTap,
    this.isDisabled = false,
    this.hoverScale = 0.99,
    this.tapScale = 0.98,
    this.tapOpacity = 0.8,
    this.hoverElevation = 4,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool isDisabled;
  final double hoverScale;
  final double tapScale;
  final double tapOpacity;
  final double hoverElevation;

  @override
  State<AnimatedModalItem> createState() => _AnimatedModalItemState();
}

class _AnimatedModalItemState extends State<AnimatedModalItem>
    with TickerProviderStateMixin {
  late AnimationController _hoverAnimationController;
  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _hoverElevationAnimation;
  late AnimationController _tapAnimationController;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _tapOpacityAnimation;

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
      duration: const Duration(milliseconds: 150),
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
      _tapAnimationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled) {
      _tapAnimationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled) {
      _tapAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_tapAnimationController, _hoverAnimationController]),
      builder: (context, child) {
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
              child: AnimatedOpacity(
                opacity: widget.isDisabled ? 0.5 : _tapOpacityAnimation.value,
                duration: const Duration(milliseconds: 150),
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
                    child: widget.child,
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
