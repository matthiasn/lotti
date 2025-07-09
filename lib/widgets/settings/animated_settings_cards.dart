import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/animated_modal_item_with_icon.dart';

/// A modern settings card with icon wrapped with animations
class AnimatedModernSettingsCardWithIcon extends StatelessWidget {
  const AnimatedModernSettingsCardWithIcon({
    required this.title,
    required this.icon,
    this.onTap,
    this.subtitle,
    this.margin,
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
  final EdgeInsets? margin;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isCompact;
  final bool showChevron;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedModalItemWithIcon(
      onTap: onTap ?? () {},
      disableShadow: true, // ModernBaseCard already has its own shadow
      iconBuilder: (context, iconAnimation, {required isPressed}) {
        return Positioned(
          left: isCompact ? 12 : 16,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.scale(
              scale: iconAnimation.value,
              child: ModernIconContainer(
                icon: icon,
                isCompact: isCompact,
                iconColor: iconColor,
              ),
            ),
          ),
        );
      },
      child: ModernBaseCard(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        isCompact: isCompact,
        child: ModernCardContent(
          title: title,
          subtitle: subtitle,
          leading: ModernIconContainer(
            icon: icon,
            isCompact: isCompact,
            iconColor: iconColor,
          ),
          isCompact: isCompact,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) trailing!,
              if (showChevron) ...[
                if (trailing != null) SizedBox(width: isCompact ? 4 : 8),
                Icon(
                  Icons.chevron_right_rounded,
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
    );
  }
}

/// A modern maintenance card with animations
class AnimatedModernMaintenanceCard extends StatelessWidget {
  const AnimatedModernMaintenanceCard({
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

    return AnimatedModalItemWithIcon(
      onTap: onTap,
      disableShadow: true, // ModernBaseCard already has its own shadow
      iconBuilder: icon != null
          ? (context, iconAnimation, {required isPressed}) {
              return Positioned(
                left: isCompact ? 12 : 16,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.scale(
                    scale: iconAnimation.value,
                    child: Container(
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
                                      alpha: AppTheme
                                          .alphaDestructiveGradientStart),
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
                  ),
                ),
              );
            }
          : (context, animation, {required isPressed}) =>
              const SizedBox.shrink(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: AppTheme.animationDuration),
        curve: AppTheme.animationCurve,
        decoration: BoxDecoration(
          color:
              isDestructive && Theme.of(context).brightness == Brightness.light
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
              color: (isDestructive
                      ? destructiveColor
                      : context.colorScheme.shadow)
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
