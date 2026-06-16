import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// One entry in [DesignSystemNavigationTabBar]: a [label], an [icon] (with an
/// optional [activeIcon] swapped in when [active]), and a tap callback.
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

/// Content-hugging pill tab bar from the design handoff.
///
/// No longer the app's mobile bottom navigation — the shell uses
/// `DesignSystemFiveSlotNavBar` (fixed slot count, equal flex, docked)
/// instead, because this pill shrinks via `FittedBox` when too many tabs
/// are visible. It survives for the design-handoff showcase mockups and
/// the widgetbook artboards that depict the original handoff spec.
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

/// Reusable frosted-glass container behind navigation chrome.
///
/// Clips [child] to [borderRadius], applies a backdrop blur, a
/// brightness-aware translucent fill, a hairline border of [borderWidth], and
/// a soft drop shadow. Used by the pill tab bar and any surface that needs the
/// same blurred treatment.
class DesignSystemNavigationFrostedSurface extends StatelessWidget {
  const DesignSystemNavigationFrostedSurface({
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Width of the hairline border drawn around the surface.
  /// `Container` stacks it onto [padding] on every side,
  /// so height math that depends on this surface (e.g. the bottom nav's
  /// occupied height) must account for it through this constant rather
  /// than a magic number. [build] passes it to `Border.all` explicitly,
  /// so the rendered width and the height math cannot drift apart.
  static const double borderWidth = 1;

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
              // Deliberately explicit even though it matches the default:
              // [borderWidth] feeds the bottom nav's occupied-height math,
              // and relying on the framework default would let the two
              // silently drift apart.
              // ignore: avoid_redundant_argument_values
              width: borderWidth,
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
