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
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconScaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _iconScaleAnimation = Tween<double>(
      begin: 1,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = widget.iconColor ?? context.colorScheme.primary;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.isDisabled ? null : widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.cardPadding,
                vertical: AppTheme.cardSpacing / 2,
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
                                      effectiveIconColor.withValues(alpha: 0.4),
                                      effectiveIconColor.withValues(alpha: 0.3),
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
                            letterSpacing: AppTheme.letterSpacingTitle * 0.8,
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
        );
      },
    );
  }
}
