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

class DesignSystemNavigationFrostedSurface extends StatelessWidget {
  const DesignSystemNavigationFrostedSurface({
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.includeBottomBorder = true,
    super.key,
  });

  /// Width of the hairline border drawn around the surface.
  /// `Container` stacks it onto [padding] on each bordered side,
  /// so height math that depends on this surface (e.g. the bottom nav's
  /// occupied height) must account for it through this constant rather
  /// than a magic number. [build] passes it to the border explicitly,
  /// so the rendered width and the height math cannot drift apart.
  static const double borderWidth = 1;

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  /// Whether the hairline border is drawn along the bottom edge. The docked
  /// bottom navigation bar sits flush against the screen edge, so a bottom
  /// hairline renders as a stray light line below the bar — it sets this to
  /// `false` to drop the bottom side (the rounded top and the two sides keep
  /// theirs). Callers that omit it shed one [borderWidth] from their height
  /// math accordingly.
  final bool includeBottomBorder;

  static BorderSide _hairline(DsTokens tokens) => BorderSide(
    color: tokens.colors.decorative.level01.withValues(alpha: 0.4),
    // Deliberately explicit even though it matches the default: [borderWidth]
    // feeds the bottom nav's occupied-height math, and relying on the
    // framework default would let the two silently drift apart.
    // ignore: avoid_redundant_argument_values
    width: borderWidth,
  );

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
            // BoxDecoration asserts a borderRadius is only valid with a
            // uniform border; the docked bar's bottom-less border is
            // non-uniform, so the radius is dropped here and the rounded
            // corners come from the enclosing ClipRRect (which clips the
            // fill and the hairline together) instead.
            borderRadius: includeBottomBorder ? borderRadius : null,
            // Deliberately explicit even though [borderWidth] matches the
            // framework default: it feeds the bottom nav's occupied-height
            // math, and relying on the default would let the two silently
            // drift apart. The docked bottom bar drops the bottom side
            // (includeBottomBorder == false) so no stray hairline shows
            // below it.
            border: Border(
              top: _hairline(tokens),
              left: _hairline(tokens),
              right: _hairline(tokens),
              bottom: includeBottomBorder ? _hairline(tokens) : BorderSide.none,
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
