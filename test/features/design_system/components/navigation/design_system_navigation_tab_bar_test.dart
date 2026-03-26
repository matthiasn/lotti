import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemNavigationTabBar', () {
    testWidgets('uses caption typography for tab labels', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemNavigationTabBar(
            items: [
              DesignSystemNavigationTabBarItem(
                label: 'Tasks',
                icon: Icons.check_circle_outline,
                active: true,
              ),
              DesignSystemNavigationTabBarItem(
                label: 'Projects',
                icon: Icons.folder_outlined,
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final activeLabel = tester.widget<Text>(find.text('Tasks'));
      final inactiveLabel = tester.widget<Text>(find.text('Projects'));

      expectTextStyle(
        activeLabel.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.interactive.enabled,
      );
      expectTextStyle(
        inactiveLabel.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.text.highEmphasis,
      );
    });

    testWidgets('minimized mode hides visible labels', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemNavigationTabBar(
            minimized: true,
            items: [
              DesignSystemNavigationTabBarItem(
                label: 'Tasks',
                icon: Icons.check_circle_outline,
                active: true,
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Tasks'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}
