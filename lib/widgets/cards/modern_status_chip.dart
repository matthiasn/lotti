import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A modern status indicator chip with icon and label
///
/// Used for displaying status information with consistent styling.
/// Supports custom colors, icons, and labels.
class ModernStatusChip extends StatelessWidget {
  const ModernStatusChip({
    required this.label,
    required this.color,
    this.icon,
    this.isDark,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark =
        isDark ?? Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = color.withValues(
      alpha: effectiveIsDark
          ? AppTheme.alphaPrimaryContainerDark
          : AppTheme.alphaPrimaryContainerLight,
    );

    final borderColor = color.withValues(
      alpha: AppTheme.alphaStatusIndicatorBorder,
    );

    final contentColor = color.withValues(
      alpha: effectiveIsDark ? 0.9 : 0.8,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.statusIndicatorPaddingHorizontal,
        vertical: AppTheme.statusIndicatorPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          AppTheme.statusIndicatorBorderRadius,
        ),
        border: Border.all(
          color: borderColor,
          width: AppTheme.statusIndicatorBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppTheme.statusIndicatorIconSize,
              color: color.withValues(alpha: AppTheme.alphaPrimaryIcon),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.statusIndicatorFontSize,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }
}
