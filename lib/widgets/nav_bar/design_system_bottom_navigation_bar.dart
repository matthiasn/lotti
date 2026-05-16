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

  /// Intrinsic height of a single nav-bar item row (icon + caption with the
  /// design-system minimum), shared by the height calculations below so the
  /// numbers can't drift apart.
  static double _itemHeight(BuildContext context) {
    final tokens = context.designTokens;
    return math.max(
      DesignSystemNavigationTabBar.defaultItemMinHeight,
      tokens.spacing.step3 * 2 +
          DesignSystemNavigationTabBar.defaultIconSize +
          tokens.spacing.step1 +
          tokens.typography.lineHeight.caption,
    );
  }

  static double occupiedHeight(BuildContext context) {
    // In desktop layout the bottom navigation bar is not shown;
    // the sidebar replaces it, so no bottom inset is needed.
    if (isDesktopLayout(context)) return 0;

    final tokens = context.designTokens;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;

    return bottomSafeInset +
        padding(context).vertical +
        tokens.spacing.step2 * 2 +
        _itemHeight(context);
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
