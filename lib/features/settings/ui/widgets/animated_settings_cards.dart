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
