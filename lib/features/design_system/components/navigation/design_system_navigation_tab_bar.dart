import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemNavigationTabBarItem {
  const DesignSystemNavigationTabBarItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.active = false,
    this.onTap,
  });

  final String label;
  final Widget icon;
  final Widget? activeIcon;
  final bool active;
  final VoidCallback? onTap;
}

class DesignSystemNavigationTabBar extends StatelessWidget {
  const DesignSystemNavigationTabBar({
    required this.items,
    this.minimized = false,
    super.key,
  });

  static const double defaultItemMinHeight = 52;
  static const double defaultIconSize = 20;

  final List<DesignSystemNavigationTabBarItem> items;
  final bool minimized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DesignSystemNavigationFrostedSurface(
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      padding: EdgeInsets.all(tokens.spacing.step2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : tokens.spacing.step1,
              ),
              child: _DesignSystemNavigationTabBarItem(
                item: items[index],
                symbol: minimized,
              ),
            ),
        ],
      ),
    );
  }
}

class DesignSystemNavigationFrostedSurface extends StatelessWidget {
  const DesignSystemNavigationFrostedSurface({
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;
    final frostedFill = brightness == Brightness.dark
        ? tokens.colors.surface.hover
        : tokens.colors.background.level01.withValues(alpha: 0.72);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.spacing.step5,
          sigmaY: tokens.spacing.step5,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: frostedFill,
            borderRadius: borderRadius,
            border: Border.all(
              color: tokens.colors.decorative.level01.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: tokens.spacing.step5 + tokens.spacing.step2,
                offset: Offset(0, tokens.spacing.step1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DesignSystemNavigationTabBarItem extends StatelessWidget {
  const _DesignSystemNavigationTabBarItem({
    required this.item,
    required this.symbol,
  });

  final DesignSystemNavigationTabBarItem item;
  final bool symbol;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final iconColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final labelColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.highEmphasis;
    final icon = item.active ? item.activeIcon ?? item.icon : item.icon;

    return Semantics(
      button: true,
      selected: item.active,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          onTap: item.onTap,
          child: Container(
            constraints: BoxConstraints(
              minWidth: symbol ? 44 : 56,
              minHeight: symbol ? 44 : 52,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: symbol
                  ? tokens.spacing.step4 - tokens.spacing.step1
                  : tokens.spacing.step4,
              vertical: symbol
                  ? tokens.spacing.step4 - tokens.spacing.step1
                  : tokens.spacing.step3,
            ),
            decoration: BoxDecoration(
              color: item.active
                  ? tokens.colors.background.level01
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: DesignSystemNavigationTabBar.defaultIconSize,
                    color: iconColor,
                  ),
                  child: icon,
                ),
                if (!symbol) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: labelColor,
                    ),
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
