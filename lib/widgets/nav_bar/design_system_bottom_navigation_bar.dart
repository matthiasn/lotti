import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemBottomNavigationBar extends StatelessWidget {
  const DesignSystemBottomNavigationBar({
    required this.items,
    this.overlay,
    super.key,
  });

  final List<DesignSystemNavigationTabBarItem> items;

  /// Optional widget rendered immediately above the pill, sized to the same
  /// width as the pill. The overlay scales with the pill via the same
  /// `FittedBox`, so its position stays tied to the rendered nav bar
  /// regardless of how many tabs are visible.
  final Widget? overlay;

  static EdgeInsets padding(BuildContext context) {
    final tokens = context.designTokens;
    return EdgeInsets.fromLTRB(
      tokens.spacing.step5,
      tokens.spacing.step3,
      tokens.spacing.step5,
      tokens.spacing.step4,
    );
  }

  static double occupiedHeight(BuildContext context) {
    // In desktop layout the bottom navigation bar is not shown;
    // the sidebar replaces it, so no bottom inset is needed.
    if (isDesktopLayout(context)) return 0;

    final tokens = context.designTokens;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final itemHeight = math.max(
      DesignSystemNavigationTabBar.defaultItemMinHeight,
      tokens.spacing.step3 * 2 +
          DesignSystemNavigationTabBar.defaultIconSize +
          tokens.spacing.step1 +
          tokens.typography.lineHeight.caption,
    );

    return bottomSafeInset +
        padding(context).vertical +
        tokens.spacing.step2 * 2 +
        itemHeight;
  }

  /// Distance from the top of the system bottom safe-area inset to the visual
  /// top of the nav-bar pill. Overlays (e.g. recording indicators) that wrap
  /// themselves in `SafeArea(top: false)` should add this offset to dock flush
  /// against the pill. Excludes `MediaQuery.paddingOf(context).bottom` so the
  /// SafeArea at the overlay site is the single source of truth for the
  /// home-indicator inset on iOS.
  static double pillTopFromNavBarBottom(BuildContext context) {
    if (isDesktopLayout(context)) return 0;
    final tokens = context.designTokens;
    final itemHeight = math.max(
      DesignSystemNavigationTabBar.defaultItemMinHeight,
      tokens.spacing.step3 * 2 +
          DesignSystemNavigationTabBar.defaultIconSize +
          tokens.spacing.step1 +
          tokens.typography.lineHeight.caption,
    );
    return padding(context).bottom + tokens.spacing.step2 * 2 + itemHeight;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding(context),
        child: Align(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            // IntrinsicWidth bounds the inner Column so the overlay row can
            // stretch to the pill's natural width.
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?overlay,
                  DesignSystemNavigationTabBar(items: items),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DesignSystemBottomNavigationFabPadding extends StatelessWidget {
  const DesignSystemBottomNavigationFabPadding({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: DesignSystemBottomNavigationBar.occupiedHeight(context),
      ),
      child: child,
    );
  }
}
