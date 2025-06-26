import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A modern, card-based settings item with gradient styling
///
/// This widget provides a consistent, polished design for settings items
/// with subtle gradients, proper spacing, and Material 3 design principles.
class ModernSettingsCard extends StatelessWidget {
  const ModernSettingsCard({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isCompact = false,
    this.showChevron = true,
    this.backgroundColor,
    this.borderColor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isCompact;
  final bool showChevron;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      curve: AppTheme.animationCurve,
      decoration: BoxDecoration(
        color: backgroundColor ??
            (Theme.of(context).brightness == Brightness.light
                ? context.colorScheme.surface
                : null),
        gradient: backgroundColor == null
            ? GradientThemes.cardGradient(context)
            : null,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: borderColor ??
              (Theme.of(context).brightness == Brightness.light
                  ? context.colorScheme.outline
                      .withValues(alpha: AppTheme.alphaOutline)
                  : context.colorScheme.primaryContainer
                      .withValues(alpha: AppTheme.alphaPrimaryContainer)),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowLight)
                : context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowDark),
            blurRadius: Theme.of(context).brightness == Brightness.light
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
          child: Container(
            padding: EdgeInsets.all(
                isCompact ? AppTheme.cardPaddingCompact : AppTheme.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            ),
            child: Row(
              children: [
                // Leading widget (icon or custom widget)
                if (leading != null) ...[
                  leading!,
                  SizedBox(
                      width: isCompact
                          ? AppTheme.spacingMedium
                          : AppTheme.spacingLarge),
                ],

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        title,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: AppTheme.letterSpacingTitle,
                          fontSize: isCompact
                              ? AppTheme.titleFontSizeCompact
                              : AppTheme.titleFontSize,
                          color: context.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Subtitle
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(
                            height: isCompact
                                ? AppTheme.spacingBetweenTitleAndSubtitleCompact
                                : AppTheme.spacingBetweenTitleAndSubtitle),
                        Text(
                          subtitle!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(
                                    alpha: AppTheme.alphaSurfaceVariant),
                            fontSize: isCompact
                                ? AppTheme.subtitleFontSizeCompact
                                : AppTheme.subtitleFontSize,
                            height: AppTheme.lineHeightSubtitle,
                            letterSpacing: AppTheme.letterSpacingSubtitle,
                          ),
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing widget
                if (trailing != null) ...[
                  SizedBox(
                      width: isCompact
                          ? AppTheme.spacingSmall
                          : AppTheme.spacingMedium),
                  trailing!,
                ],

                // Chevron
                if (showChevron) ...[
                  SizedBox(
                      width: isCompact
                          ? AppTheme.spacingSmall
                          : AppTheme.spacingMedium),
                  Icon(
                    Icons.chevron_right,
                    size: isCompact
                        ? AppTheme.chevronSizeCompact
                        : AppTheme.chevronSize,
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: AppTheme.alphaSurfaceVariantChevron),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A modern settings card with an icon container that has gradient styling
class ModernSettingsCardWithIcon extends StatelessWidget {
  const ModernSettingsCardWithIcon({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.isCompact = false,
    this.showChevron = true,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isCompact;
  final bool showChevron;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ModernSettingsCard(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      isCompact: isCompact,
      showChevron: showChevron,
      trailing: trailing,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      leading: Container(
        width: isCompact
            ? AppTheme.iconContainerSizeCompact
            : AppTheme.iconContainerSize,
        height: isCompact
            ? AppTheme.iconContainerSizeCompact
            : AppTheme.iconContainerSize,
        decoration: BoxDecoration(
          gradient: GradientThemes.iconContainerGradient(context),
          borderRadius:
              BorderRadius.circular(AppTheme.iconContainerBorderRadius),
          border: Border.all(
            color: context.colorScheme.primary
                .withValues(alpha: AppTheme.alphaPrimaryBorder),
          ),
        ),
        child: Icon(
          icon,
          size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
          color: iconColor ??
              context.colorScheme.primary
                  .withValues(alpha: AppTheme.alphaPrimaryIcon),
        ),
      ),
    );
  }
}

/// A modern maintenance card with destructive styling and gradient
class ModernMaintenanceCard extends StatelessWidget {
  const ModernMaintenanceCard({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.isCompact = false,
    this.isDestructive = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isCompact;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final destructiveColor = context.colorScheme.error;
    final destructiveContainerColor = context.colorScheme.errorContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      curve: AppTheme.animationCurve,
      decoration: BoxDecoration(
        color: isDestructive && Theme.of(context).brightness == Brightness.light
            ? destructiveContainerColor.withValues(
                alpha: AppTheme.alphaDestructiveContainer)
            : (Theme.of(context).brightness == Brightness.light
                ? context.colorScheme.surface
                : null),
        gradient:
            isDestructive && Theme.of(context).brightness == Brightness.dark
                ? LinearGradient(
                    colors: [
                      destructiveContainerColor.withValues(
                          alpha: AppTheme.alphaDestructiveGradientStart),
                      destructiveContainerColor.withValues(
                          alpha: AppTheme.alphaDestructiveGradientEnd),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : GradientThemes.cardGradient(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: isDestructive
              ? destructiveColor.withValues(alpha: AppTheme.alphaDestructive)
              : (Theme.of(context).brightness == Brightness.light
                  ? context.colorScheme.outline
                      .withValues(alpha: AppTheme.alphaOutline)
                  : context.colorScheme.primaryContainer
                      .withValues(alpha: AppTheme.alphaPrimaryContainer)),
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isDestructive ? destructiveColor : context.colorScheme.shadow)
                    .withValues(
                        alpha: Theme.of(context).brightness == Brightness.light
                            ? AppTheme.alphaShadowLight
                            : AppTheme.alphaShadowDark),
            blurRadius: Theme.of(context).brightness == Brightness.light
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
          splashColor:
              (isDestructive ? destructiveColor : context.colorScheme.primary)
                  .withValues(alpha: AppTheme.alphaPrimary),
          highlightColor:
              (isDestructive ? destructiveColor : context.colorScheme.primary)
                  .withValues(alpha: AppTheme.alphaPrimaryHighlight),
          child: Container(
            padding: EdgeInsets.all(
                isCompact ? AppTheme.cardPaddingCompact : AppTheme.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            ),
            child: Row(
              children: [
                // Icon with gradient container
                if (icon != null) ...[
                  Container(
                    width: isCompact
                        ? AppTheme.iconContainerSizeCompact
                        : AppTheme.iconContainerSize,
                    height: isCompact
                        ? AppTheme.iconContainerSizeCompact
                        : AppTheme.iconContainerSize,
                    decoration: BoxDecoration(
                      gradient: isDestructive
                          ? LinearGradient(
                              colors: [
                                destructiveColor.withValues(
                                    alpha:
                                        AppTheme.alphaDestructiveGradientStart),
                                destructiveColor.withValues(
                                    alpha:
                                        AppTheme.alphaDestructiveGradientEnd),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : GradientThemes.iconContainerGradient(context),
                      borderRadius: BorderRadius.circular(
                          AppTheme.iconContainerBorderRadius),
                      border: Border.all(
                        color: (isDestructive
                                ? destructiveColor
                                : context.colorScheme.primary)
                            .withValues(alpha: AppTheme.alphaPrimaryBorder),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: isCompact
                          ? AppTheme.iconSizeCompact
                          : AppTheme.iconSize,
                      color: isDestructive
                          ? destructiveColor.withValues(
                              alpha: AppTheme.alphaDestructiveIcon)
                          : context.colorScheme.primary
                              .withValues(alpha: AppTheme.alphaPrimaryIcon),
                    ),
                  ),
                  SizedBox(
                      width: isCompact
                          ? AppTheme.spacingMedium
                          : AppTheme.spacingLarge),
                ],

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        title,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: AppTheme.letterSpacingTitle,
                          fontSize: isCompact
                              ? AppTheme.titleFontSizeCompact
                              : AppTheme.titleFontSize,
                          color: isDestructive
                              ? destructiveColor
                              : context.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Subtitle
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(
                            height: isCompact
                                ? AppTheme.spacingBetweenTitleAndSubtitleCompact
                                : AppTheme.spacingBetweenTitleAndSubtitle),
                        Text(
                          subtitle!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: isDestructive
                                ? destructiveColor.withValues(
                                    alpha: AppTheme.alphaDestructiveText)
                                : context.colorScheme.onSurfaceVariant
                                    .withValues(
                                        alpha: AppTheme.alphaSurfaceVariant),
                            fontSize: isCompact
                                ? AppTheme.subtitleFontSizeCompact
                                : AppTheme.subtitleFontSize,
                            height: AppTheme.lineHeightSubtitle,
                            letterSpacing: AppTheme.letterSpacingSubtitle,
                          ),
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  size: isCompact
                      ? AppTheme.chevronSizeCompact
                      : AppTheme.chevronSize,
                  color: (isDestructive
                          ? destructiveColor
                          : context.colorScheme.onSurfaceVariant)
                      .withValues(alpha: AppTheme.alphaSurfaceVariantChevron),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
