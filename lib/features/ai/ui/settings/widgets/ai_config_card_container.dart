import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A reusable container widget that provides consistent card styling
/// for AI configuration cards.
///
/// This widget encapsulates the common decoration logic (gradient, border,
/// shadow) used across different card contexts (normal, selection mode).
///
/// Use this widget to avoid duplicating BoxDecoration code when building
/// card-like UI elements in the AI settings section.
class AiConfigCardContainer extends StatelessWidget {
  const AiConfigCardContainer({
    required this.child,
    required this.onTap,
    this.isSelected = false,
    super.key,
  });

  /// The content to display inside the card
  final Widget child;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  /// Whether the card is in a selected state (changes visual styling)
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _getBackgroundColor(context, isLight),
        gradient: _getGradient(context, isLight),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: _getBorderColor(context, isLight),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowLight)
                : context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowDark),
            blurRadius: isLight
                ? AppTheme.cardElevationLight
                : AppTheme.cardElevationDark,
            offset: AppTheme.shadowOffset,
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          splashColor: context.colorScheme.primary
              .withValues(alpha: AppTheme.alphaPrimary),
          highlightColor: context.colorScheme.primary
              .withValues(alpha: AppTheme.alphaPrimaryHighlight),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }

  Color? _getBackgroundColor(BuildContext context, bool isLight) {
    if (isSelected) {
      return context.colorScheme.primaryContainer.withValues(alpha: 0.3);
    }
    return isLight ? context.colorScheme.surface : null;
  }

  Gradient? _getGradient(BuildContext context, bool isLight) {
    if (isSelected || isLight) {
      return null;
    }
    return LinearGradient(
      colors: [
        Color.lerp(
          context.colorScheme.surfaceContainer,
          context.colorScheme.surfaceContainerHigh,
          0.3,
        )!,
        Color.lerp(
          context.colorScheme.surface,
          context.colorScheme.surfaceContainerLow,
          0.5,
        )!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _getBorderColor(BuildContext context, bool isLight) {
    if (isSelected) {
      return context.colorScheme.primary.withValues(alpha: 0.5);
    }
    return isLight
        ? context.colorScheme.outline.withValues(alpha: AppTheme.alphaOutline)
        : context.colorScheme.primaryContainer
            .withValues(alpha: AppTheme.alphaPrimaryContainer);
  }
}
