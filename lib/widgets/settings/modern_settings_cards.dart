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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
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
                  ? context.colorScheme.outline.withValues(alpha: 0.3)
                  : context.colorScheme.primaryContainer
                      .withValues(alpha: 0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? context.colorScheme.shadow.withValues(alpha: 0.08)
                : context.colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardElevationLight
                : AppTheme.cardElevationDark,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
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
                          letterSpacing: 0.1,
                          fontSize: isCompact ? 15 : 16,
                          color: context.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Subtitle
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(height: isCompact ? 2 : 4),
                        Text(
                          subtitle!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                            fontSize: isCompact ? 11 : 12,
                            height: 1.4,
                            letterSpacing: 0,
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
                        .withValues(alpha: 0.6),
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
            color: context.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(
          icon,
          size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
          color:
              iconColor ?? context.colorScheme.primary.withValues(alpha: 0.9),
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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isDestructive && Theme.of(context).brightness == Brightness.light
            ? destructiveContainerColor.withValues(alpha: 0.1)
            : (Theme.of(context).brightness == Brightness.light
                ? context.colorScheme.surface
                : null),
        gradient:
            isDestructive && Theme.of(context).brightness == Brightness.dark
                ? LinearGradient(
                    colors: [
                      destructiveContainerColor.withValues(alpha: 0.2),
                      destructiveContainerColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : GradientThemes.cardGradient(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: isDestructive
              ? destructiveColor.withValues(alpha: 0.3)
              : (Theme.of(context).brightness == Brightness.light
                  ? context.colorScheme.outline.withValues(alpha: 0.3)
                  : context.colorScheme.primaryContainer
                      .withValues(alpha: 0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isDestructive ? destructiveColor : context.colorScheme.shadow)
                    .withValues(
                        alpha: Theme.of(context).brightness == Brightness.light
                            ? 0.08
                            : 0.15),
            blurRadius: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardElevationLight
                : AppTheme.cardElevationDark,
            offset: const Offset(0, 2),
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
                  .withValues(alpha: 0.1),
          highlightColor:
              (isDestructive ? destructiveColor : context.colorScheme.primary)
                  .withValues(alpha: 0.05),
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
                                destructiveColor.withValues(alpha: 0.2),
                                destructiveColor.withValues(alpha: 0.1),
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
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: isCompact
                          ? AppTheme.iconSizeCompact
                          : AppTheme.iconSize,
                      color: isDestructive
                          ? destructiveColor.withValues(alpha: 0.9)
                          : context.colorScheme.primary.withValues(alpha: 0.9),
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
                          letterSpacing: 0.1,
                          fontSize: isCompact ? 15 : 16,
                          color: isDestructive
                              ? destructiveColor
                              : context.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Subtitle
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(height: isCompact ? 2 : 4),
                        Text(
                          subtitle!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: isDestructive
                                ? destructiveColor.withValues(alpha: 0.8)
                                : context.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                            fontSize: isCompact ? 11 : 12,
                            height: 1.4,
                            letterSpacing: 0,
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
                      .withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
