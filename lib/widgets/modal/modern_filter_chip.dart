import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

class ModernFilterChip extends StatefulWidget {
  const ModernFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.description,
    this.selectedColor,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final String? description;
  final Color? selectedColor;

  @override
  State<ModernFilterChip> createState() => _ModernFilterChipState();
}

class _ModernFilterChipState extends State<ModernFilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveSelectedColor = widget.selectedColor ?? colorScheme.primary;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            onLongPress: widget.onLongPress != null
                ? () {
                    HapticFeedback.heavyImpact();
                    widget.onLongPress!();
                  }
                : null,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: ModernBaseCard(
                onTap: widget.onTap,
                padding: EdgeInsets.zero,
                backgroundColor: widget.isSelected
                    ? effectiveSelectedColor.withValues(alpha: 0.1)
                    : null,
                borderColor: widget.isSelected
                    ? effectiveSelectedColor
                    : colorScheme.outline.withValues(alpha: 0.3),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        widget.icon != null || widget.description != null
                            ? AppTheme.cardPadding
                            : AppTheme.spacingLarge,
                    vertical: widget.description != null
                        ? AppTheme.cardPadding
                        : AppTheme.spacingMedium,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 18,
                          color: widget.isSelected
                              ? effectiveSelectedColor
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppTheme.spacingSmall),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: widget.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: widget.isSelected
                                    ? effectiveSelectedColor
                                    : colorScheme.onSurface,
                              ),
                            ),
                            if (widget.description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.description!,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.isSelected) ...[
                        const SizedBox(width: AppTheme.spacingSmall),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: effectiveSelectedColor,
                        ),
                      ],
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
