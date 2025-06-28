import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// Base card widget with modern gradient styling and Material 3 design
///
/// This provides the foundation for all modern card components with:
/// - Gradient background (dark mode) or solid color (light mode)
/// - Consistent border, shadow, and border radius
/// - Material inkwell effects for interactivity
/// - Flexible content area
class ModernBaseCard extends StatelessWidget {
  const ModernBaseCard({
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.gradient,
    this.margin,
    this.padding,
    this.isCompact = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final LinearGradient? gradient;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine background color or gradient
    final effectiveGradient = gradient ??
        (backgroundColor == null && isDark
            ? GradientThemes.cardGradient(context)
            : null);

    final effectiveBackgroundColor =
        backgroundColor ?? (!isDark ? context.colorScheme.surface : null);

    // Determine border color
    final effectiveBorderColor = borderColor ??
        (isDark
            ? context.colorScheme.primaryContainer
                .withValues(alpha: AppTheme.alphaPrimaryContainer)
            : context.colorScheme.outline
                .withValues(alpha: AppTheme.alphaOutline));

    return AnimatedContainer(
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      curve: AppTheme.animationCurve,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: effectiveBorderColor),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(
              alpha:
                  isDark ? AppTheme.alphaShadowDark : AppTheme.alphaShadowLight,
            ),
            blurRadius: isDark
                ? AppTheme.cardElevationDark
                : AppTheme.cardElevationLight,
            offset: AppTheme.shadowOffset,
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        color: Colors.transparent,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                splashColor: context.colorScheme.primary
                    .withValues(alpha: AppTheme.alphaPrimary),
                highlightColor: context.colorScheme.primary
                    .withValues(alpha: AppTheme.alphaPrimaryHighlight),
                child: Container(
                  padding: padding ??
                      EdgeInsets.all(
                        isCompact
                            ? AppTheme.cardPaddingCompact
                            : AppTheme.cardPadding,
                      ),
                  child: child,
                ),
              )
            : Container(
                padding: padding ??
                    EdgeInsets.all(
                      isCompact
                          ? AppTheme.cardPaddingCompact
                          : AppTheme.cardPadding,
                    ),
                child: child,
              ),
      ),
    );
  }
}
