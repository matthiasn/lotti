import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';

/// Base card widget with modern gradient styling and Material 3 design
///
/// This provides the foundation for all modern card components with:
/// - Gradient background (dark mode) or solid color (light mode)
/// - Consistent border, shadow, and border radius
/// - Material inkwell effects for interactivity
/// - Flexible content area
/// - Optional custom shadow overrides for bespoke styling
class ModernBaseCard extends StatelessWidget {
  const ModernBaseCard({
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.gradient,
    this.margin,
    this.padding,
    this.isEnhanced = false,
    this.selected = false,
    this.customShadows,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final LinearGradient? gradient;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final bool isEnhanced;

  /// Whether this card is the active row of a desktop list/detail split.
  ///
  /// Opt-in and false everywhere else, so cards in single-pane lists (where
  /// nothing stays selected after a tap) are unaffected. When true the card
  /// takes the shared list activated fill and an accent border, matching the
  /// selected row treatment in the tasks and projects lists.
  final bool selected;

  final List<BoxShadow>? customShadows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Resolved lazily: only the selected treatment needs design tokens, and
    // unselected cards must keep rendering under themes without the DsTokens
    // extension (several consumers pump plain ThemeData in tests).
    final tokens = selected ? context.designTokens : null;

    // Accent for the ink feedback: the design-token interactive color when the
    // theme carries DsTokens, falling back to the Material primary for
    // token-less themes (several consumers pump plain ThemeData in tests). So a
    // tapped card flashes the same accent family as the selection treatment.
    final inkAccent =
        Theme.of(context).extension<DsTokens>()?.colors.interactive.enabled ??
        context.colorScheme.primary;

    // Determine background color or gradient. A selected card is drawn as a
    // flat activated fill rather than the usual gradient, so the accent reads
    // uniformly across the row.
    final effectiveGradient = tokens != null
        ? null
        : gradient ??
              (backgroundColor == null
                  ? GradientThemes.cardGradient(context)
                  : null);

    final baseBackgroundColor =
        backgroundColor ??
        (effectiveGradient == null ? context.colorScheme.surface : null);

    final effectiveBackgroundColor = tokens != null
        ? Color.alphaBlend(
            DesignSystemListPalette.activatedFill(tokens),
            // Selected always paints a solid base (no gradient), so fall back to
            // the surface when no explicit background is supplied.
            backgroundColor ?? context.colorScheme.surface,
          )
        : baseBackgroundColor;

    // Determine border color - very subtle in light mode, slightly visible in dark mode
    final effectiveBorderColor = tokens != null
        ? tokens.colors.interactive.enabled
        : borderColor ??
              (isDark
                  ? context.colorScheme.outlineVariant.withValues(
                      alpha: AppTheme.alphaCardBorderDark,
                    )
                  : context.colorScheme.outline.withValues(
                      alpha: AppTheme.alphaCardBorderLight,
                    ));

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: effectiveBorderColor),
        boxShadow:
            customShadows ??
            (isEnhanced
                ? [
                    BoxShadow(
                      color: context.colorScheme.shadow.withValues(
                        alpha: isDark ? 0.3 : 0.15,
                      ),
                      blurRadius: isDark ? 20 : 15,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: context.colorScheme.shadow.withValues(
                        alpha: isDark
                            ? GradientConstants.enhancedShadowSecondaryDarkAlpha
                            : GradientConstants
                                  .enhancedShadowSecondaryLightAlpha,
                      ),
                      blurRadius: isDark
                          ? GradientConstants.enhancedShadowSecondaryBlurDark
                          : GradientConstants.enhancedShadowSecondaryBlurLight,
                      offset: const Offset(
                        0,
                        GradientConstants.enhancedShadowSecondaryOffsetY,
                      ),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: context.colorScheme.shadow.withValues(
                        alpha: isDark
                            ? AppTheme.alphaShadowDark
                            : AppTheme.alphaShadowLight,
                      ),
                      blurRadius: isDark
                          ? AppTheme.cardElevationDark
                          : AppTheme.cardElevationLight,
                      offset: AppTheme.shadowOffset,
                    ),
                  ]),
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        color: Colors.transparent,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                splashColor: inkAccent.withValues(alpha: AppTheme.alphaPrimary),
                highlightColor: inkAccent.withValues(
                  alpha: AppTheme.alphaPrimaryHighlight,
                ),
                child: Container(
                  padding:
                      padding ?? const EdgeInsets.all(AppTheme.cardPadding),
                  child: child,
                ),
              )
            : Container(
                padding: padding ?? const EdgeInsets.all(AppTheme.cardPadding),
                child: child,
              ),
      ),
    );
  }
}

/// Enhanced modern card with sophisticated gradient and effects
class EnhancedModernCard extends StatelessWidget {
  const EnhancedModernCard({
    required this.child,
    this.onTap,
    this.gradient,
    this.margin,
    this.padding,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ModernBaseCard(
      onTap: onTap,
      gradient: gradient ?? GradientThemes.primaryGradient(context),
      margin: margin,
      padding: padding,
      isEnhanced: true,
      child: child,
    );
  }
}
