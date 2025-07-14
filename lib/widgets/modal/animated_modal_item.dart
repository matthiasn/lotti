import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';

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
    this.controller,
    this.margin,
    this.disableShadow = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool isDisabled;
  final double hoverScale;
  final double tapScale;
  final double tapOpacity;
  final double hoverElevation;
  final AnimatedModalItemController? controller;
  final EdgeInsets? margin;
  final bool disableShadow;

  @override
  State<AnimatedModalItem> createState() => _AnimatedModalItemState();
}

class _AnimatedModalItemState extends State<AnimatedModalItem>
    with TickerProviderStateMixin {
  AnimatedModalItemController? _internalController;
  AnimatedModalItemController get _controller =>
      widget.controller ?? _internalController!;

  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _hoverElevationAnimation;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _tapOpacityAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = AnimatedModalItemController(vsync: this);
    }
    _initializeAnimations();
  }

  @override
  void didUpdateWidget(AnimatedModalItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle controller changes
    if (widget.controller == null && oldWidget.controller != null) {
      // Switched from external to internal controller
      _internalController = AnimatedModalItemController(vsync: this);
    } else if (widget.controller != null && oldWidget.controller == null) {
      // Switched from internal to external controller
      _internalController?.dispose();
      _internalController = null;
    }

    // Re-initialize animations if their parameters or the controller changes
    if (widget.hoverScale != oldWidget.hoverScale ||
        widget.tapScale != oldWidget.tapScale ||
        widget.tapOpacity != oldWidget.tapOpacity ||
        widget.hoverElevation != oldWidget.hoverElevation ||
        widget.controller != oldWidget.controller) {
      _initializeAnimations();
    }
  }

  void _initializeAnimations() {
    // Hover animations
    _hoverScaleAnimation = Tween<double>(
      begin: 1,
      end: widget.hoverScale,
    ).animate(CurvedAnimation(
      parent: _controller.hoverAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _hoverElevationAnimation = Tween<double>(
      begin: 0,
      end: widget.hoverElevation,
    ).animate(CurvedAnimation(
      parent: _controller.hoverAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Tap animations
    _tapScaleAnimation = Tween<double>(
      begin: 1,
      end: widget.tapScale,
    ).animate(CurvedAnimation(
      parent: _controller.tapAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _tapOpacityAnimation = Tween<double>(
      begin: 1,
      end: widget.tapOpacity,
    ).animate(CurvedAnimation(
      parent: _controller.tapAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _handleHoverChanged(bool isHovered) {
    if (isHovered && !widget.isDisabled) {
      _controller.startHover();
    } else {
      _controller.endHover();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled) {
      _controller.startTap();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled) {
      _controller.endTap();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled) {
      _controller.endTap();
    }
  }

  List<BoxShadow>? _buildBoxShadow(BuildContext context, bool isDark) {
    if (widget.disableShadow) return null;

    return [
      BoxShadow(
        color: context.colorScheme.shadow.withValues(
          alpha: isDark ? AppTheme.alphaShadowDark : AppTheme.alphaShadowLight,
        ),
        blurRadius: (isDark
                ? AppTheme.cardElevationDark
                : AppTheme.cardElevationLight) +
            _hoverElevationAnimation.value,
        offset: AppTheme.shadowOffset,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller.tapAnimationController,
        _controller.hoverAnimationController
      ]),
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
                  margin: widget.margin ??
                      const EdgeInsets.symmetric(
                        horizontal: AppTheme.cardPadding,
                        vertical: AppTheme.cardSpacing / 2,
                      ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardBorderRadius),
                      boxShadow: _buildBoxShadow(context, isDark),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardBorderRadius),
                      child: widget.child,
                    ),
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
