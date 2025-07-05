import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/themes/theme.dart';

/// A compact, uniform filter chip designed for grid layouts
class CompactFilterChip extends StatelessWidget {
  const CompactFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.selectedColor,
    this.showIcon = true,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final Color? selectedColor;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveSelectedColor = selectedColor ?? colorScheme.primary;
    
    final backgroundColor = isSelected 
        ? effectiveSelectedColor
        : colorScheme.surface;
    
    final borderColor = isSelected
        ? effectiveSelectedColor
        : colorScheme.outlineVariant;
    
    final textColor = isSelected
        ? effectiveSelectedColor.computeLuminance() > 0.5 
            ? Colors.black 
            : Colors.white
        : colorScheme.onSurface;

    final iconColor = isSelected
        ? textColor
        : colorScheme.onSurfaceVariant;

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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (icon != null && showIcon) ...[
                Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple icon-only filter chip
class CompactIconChip extends StatelessWidget {
  const CompactIconChip({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveSelectedColor = selectedColor ?? colorScheme.primary;
    
    final backgroundColor = isSelected 
        ? effectiveSelectedColor
        : colorScheme.surface;
    
    final borderColor = isSelected
        ? effectiveSelectedColor
        : colorScheme.outlineVariant;
    
    final iconColor = isSelected
        ? effectiveSelectedColor.computeLuminance() > 0.5 
            ? Colors.black 
            : Colors.white
        : colorScheme.onSurface;

    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: chip,
      );
    }
    return chip;
  }
}
