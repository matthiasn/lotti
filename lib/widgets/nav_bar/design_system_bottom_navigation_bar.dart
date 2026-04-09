import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemBottomNavigationBar extends StatelessWidget {
  const DesignSystemBottomNavigationBar({
    required this.items,
    super.key,
  });

  final List<DesignSystemNavigationTabBarItem> items;

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
    final tokens = context.designTokens;
    final itemHeight = math.max(
      DesignSystemNavigationTabBar.defaultItemMinHeight,
      tokens.spacing.step3 * 2 +
          DesignSystemNavigationTabBar.defaultIconSize +
          tokens.spacing.step1 +
          tokens.typography.lineHeight.caption,
    );

    return padding(context).vertical + tokens.spacing.step2 * 2 + itemHeight;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding(context),
        child: Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: DesignSystemNavigationTabBar(items: items),
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
