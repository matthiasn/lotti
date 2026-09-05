import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

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
                icon: Icon(LottiIcons.confirmCircled),
                active: true,
              ),
              DesignSystemNavigationTabBarItem(
                label: 'Projects',
                icon: Icon(LottiIcons.folder),
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

    testWidgets('tapping a tab invokes only its own onTap callback', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemNavigationTabBar(
            items: [
              DesignSystemNavigationTabBarItem(
                label: 'Tasks',
                icon: const Icon(LottiIcons.confirmCircled),
                active: true,
                onTap: () => taps.add('tasks'),
              ),
              DesignSystemNavigationTabBarItem(
                label: 'Projects',
                icon: const Icon(LottiIcons.folder),
                onTap: () => taps.add('projects'),
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.tap(find.text('Projects'));
      await tester.pump();
      expect(taps, ['projects']);

      await tester.tap(find.text('Tasks'));
      await tester.pump();
      expect(taps, ['projects', 'tasks']);
    });

    testWidgets('a tab without onTap absorbs the tap without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemNavigationTabBar(
            items: [
              DesignSystemNavigationTabBarItem(
                label: 'Tasks',
                icon: Icon(LottiIcons.confirmCircled),
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.tap(find.text('Tasks'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('active tab swaps to activeIcon when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemNavigationTabBar(
            items: [
              DesignSystemNavigationTabBarItem(
                label: 'Tasks',
                icon: Icon(LottiIcons.star),
                activeIcon: Icon(LottiIconsFilled.star),
                active: true,
              ),
              DesignSystemNavigationTabBarItem(
                label: 'Projects',
                icon: Icon(LottiIcons.folder),
                activeIcon: Icon(LottiIconsFilled.folder),
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Active item renders its activeIcon; inactive keeps the base icon.
      expect(find.byIcon(LottiIconsFilled.star), findsOneWidget);
      expect(find.byIcon(LottiIcons.star), findsNothing);
      expect(find.byIcon(LottiIcons.folder), findsOneWidget);
      expect(find.byIcon(LottiIconsFilled.folder), findsNothing);
    });

    testWidgets('minimized mode hides visible labels', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemNavigationTabBar(
            minimized: true,
            items: [
              DesignSystemNavigationTabBarItem(
                label: 'Tasks',
                icon: Icon(LottiIcons.confirmCircled),
                active: true,
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Tasks'), findsNothing);
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
    });
  });
}
