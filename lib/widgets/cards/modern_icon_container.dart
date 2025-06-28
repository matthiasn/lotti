import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A modern icon container with gradient background
///
/// Used for displaying icons with a consistent gradient style across cards.
/// Supports both IconData and custom widget children.
class ModernIconContainer extends StatelessWidget {
  const ModernIconContainer({
    this.icon,
    this.child,
    this.isCompact = false,
    this.iconColor,
    this.gradient,
    this.borderColor,
    super.key,
  }) : assert(
          icon != null || child != null,
          'Either icon or child must be provided',
        );

  final IconData? icon;
  final Widget? child;
  final bool isCompact;
  final Color? iconColor;
  final LinearGradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final size = isCompact
        ? AppTheme.iconContainerSizeCompact
        : AppTheme.iconContainerSize;

    final iconSize = isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize;

    final effectiveGradient =
        gradient ?? GradientThemes.iconContainerGradient(context);

    final effectiveBorderColor = borderColor ??
        context.colorScheme.primaryContainer
            .withValues(alpha: AppTheme.alphaPrimaryBorder);

    final effectiveIconColor = iconColor ??
        context.colorScheme.primary
            .withValues(alpha: AppTheme.alphaPrimaryIcon);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(
          AppTheme.iconContainerBorderRadius,
        ),
        border: Border.all(
          color: effectiveBorderColor,
        ),
      ),
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                size: iconSize,
                color: effectiveIconColor,
              )
            : SizedBox(
                width: iconSize,
                height: iconSize,
                child: child,
              ),
      ),
    );
  }
}
