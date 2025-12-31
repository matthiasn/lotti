import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A subtle action chip for secondary actions like dates, labels, estimates.
///
/// Used for tappable items that should be less prominent than primary status chips.
/// Supports an urgent state with red border and tinted content.
///
/// Can display either:
/// - Default content: icon + label (when [label] is provided)
/// - Custom content: any widget (when [child] is provided)
class SubtleActionChip extends StatelessWidget {
  const SubtleActionChip({
    this.label,
    this.icon,
    this.child,
    this.isUrgent = false,
    this.urgentColor,
    super.key,
  }) : assert(
          label != null || child != null,
          'Either label or child must be provided',
        );

  final String? label;
  final IconData? icon;
  final Widget? child;
  final bool isUrgent;
  final Color? urgentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Subtle dark gray background
    final backgroundColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : colorScheme.surfaceContainerHighest;

    // Border color - red when urgent, subtle otherwise
    final effectiveUrgentColor = urgentColor ?? colorScheme.error;
    final borderColor = isUrgent
        ? effectiveUrgentColor.withValues(alpha: 0.8)
        : colorScheme.outline.withValues(alpha: 0.3);

    // Content color - red when urgent, muted grey otherwise
    final contentColor = isUrgent
        ? effectiveUrgentColor.withValues(alpha: 0.9)
        : colorScheme.outline;

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
        ),
      ),
      child: child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppTheme.statusIndicatorIconSize,
                  color: contentColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label!,
                style: TextStyle(
                  fontSize: AppTheme.statusIndicatorFontSize,
                  fontWeight: FontWeight.w500,
                  color: contentColor,
                ),
              ),
            ],
          ),
    );
  }
}
