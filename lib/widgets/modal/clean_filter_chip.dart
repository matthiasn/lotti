import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/themes/theme.dart';

/// A clean, minimal filter chip with subtle styling
class CleanFilterChip extends StatelessWidget {
  const CleanFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.selectedColor,
    this.compact = false,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final Color? selectedColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveSelectedColor = selectedColor ?? colorScheme.primary;
    
    final backgroundColor = isSelected 
        ? effectiveSelectedColor.withValues(alpha: 0.2)
        : Colors.transparent;
    
    final borderColor = isSelected
        ? effectiveSelectedColor
        : colorScheme.outline.withValues(alpha: 0.2);
    
    final textColor = isSelected
        ? effectiveSelectedColor
        : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: onLongPress != null
            ? () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              }
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: compact ? 16 : 18,
                  color: textColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: (compact 
                    ? context.textTheme.bodySmall 
                    : context.textTheme.bodyMedium)?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
