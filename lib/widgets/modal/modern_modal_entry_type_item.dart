import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// A modern modal entry type item for creating different entry types
///
/// This widget provides a clean, production-quality design for entry type selection
/// with subtle animations and visual feedback optimized for the create entry flow.
class ModernModalEntryTypeItem extends StatefulWidget {
  const ModernModalEntryTypeItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.isDisabled = false,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isDisabled;
  final Widget? badge;

  @override
  State<ModernModalEntryTypeItem> createState() =>
      _ModernModalEntryTypeItemState();
}

class _ModernModalEntryTypeItemState extends State<ModernModalEntryTypeItem>
    with TickerProviderStateMixin {
  late AnimationController _hoverAnimationController;
  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _hoverElevationAnimation;
  late AnimationController _tapAnimationController;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _iconScaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // Create controllers only once in initState
    _hoverAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _tapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _initializeAnimations();
  }

  @override
  void didUpdateWidget(ModernModalEntryTypeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When widget properties change, re-initialize the animations.
    if (widget.isDisabled != oldWidget.isDisabled) {
      _initializeAnimations();
    }
  }

  void _initializeAnimations() {
    // Only create Tween animations, not controllers
    _hoverScaleAnimation = Tween<double>(
      begin: 1,
      end: 0.99,
    ).animate(CurvedAnimation(
      parent: _hoverAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _hoverElevationAnimation = Tween<double>(
      begin: 0,
      end: 4,
    ).animate(CurvedAnimation(
      parent: _hoverAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _tapScaleAnimation = Tween<double>(
      begin: 1,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _tapAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _iconScaleAnimation = Tween<double>(
      begin: 1,
      end: 0.9,
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
    final effectiveIconColor = widget.iconColor ?? context.colorScheme.primary;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_tapAnimationController, _hoverAnimationController]),
      builder: (context, child) {
        final combinedScale =
            _hoverScaleAnimation.value * _tapScaleAnimation.value;

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
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.alphaShadowDark
                              : AppTheme.alphaShadowLight,
                        ),
                        blurRadius:
                            (Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.cardElevationDark
                                    : AppTheme.cardElevationLight) +
                                _hoverElevationAnimation.value,
                        offset: AppTheme.shadowOffset,
                      ),
                    ],
                  ),
                  child: AnimatedOpacity(
                    opacity: widget.isDisabled ? 0.5 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: ModernBaseCard(
                      onTap: widget.isDisabled ? null : widget.onTap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.cardPadding,
                        vertical: AppTheme.cardPadding * 0.85,
                      ),
                      child: Row(
                        children: [
                          // Animated icon container
                          Transform.scale(
                            scale: _iconScaleAnimation.value,
                            child: Container(
                              width: AppTheme.iconContainerSize * 1.1,
                              height: AppTheme.iconContainerSize * 1.1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isPressed
                                      ? [
                                          effectiveIconColor.withValues(
                                              alpha: 0.4),
                                          effectiveIconColor.withValues(
                                              alpha: 0.3),
                                        ]
                                      : [
                                          effectiveIconColor.withValues(
                                              alpha: 0.25),
                                          effectiveIconColor.withValues(
                                              alpha: 0.15),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.iconContainerBorderRadius,
                                ),
                                border: Border.all(
                                  color: effectiveIconColor.withValues(
                                      alpha: _isPressed ? 0.3 : 0.2),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  widget.icon,
                                  size: AppTheme.iconSize * 1.1,
                                  color: effectiveIconColor.withValues(
                                    alpha: _isPressed ? 1.0 : 0.9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingLarge),

                          // Title
                          Expanded(
                            child: Text(
                              widget.title,
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: AppTheme.titleFontSize,
                                color: context.colorScheme.onSurface,
                                letterSpacing:
                                    AppTheme.letterSpacingTitle * 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Badge if present
                          if (widget.badge != null) ...[
                            const SizedBox(width: AppTheme.spacingMedium),
                            widget.badge!,
                          ],

                          // Subtle chevron
                          const SizedBox(width: AppTheme.spacingSmall),
                          AnimatedOpacity(
                            opacity: _isPressed ? 1.0 : 0.4,
                            duration: const Duration(milliseconds: 100),
                            child: Icon(
                              Icons.add_circle_outline_rounded,
                              size: AppTheme.chevronSize,
                              color: effectiveIconColor,
                            ),
                          ),
                        ],
                      ),
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
