import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

import '../../widget_test_utils.dart';

void main() {
  group('DesignSystemBottomNavigationBar', () {
    testWidgets('centers the tab bar within the bottom nav row', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 402,
            child: DesignSystemBottomNavigationBar(
              items: [
                DesignSystemNavigationTabBarItem(
                  label: 'Tasks',
                  icon: Icon(Icons.check_circle_outline),
                  active: true,
                ),
                DesignSystemNavigationTabBarItem(
                  label: 'Projects',
                  icon: Icon(Icons.folder_outlined),
                ),
              ],
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final align = tester.widget<Align>(
        find.descendant(
          of: find.byType(DesignSystemBottomNavigationBar),
          matching: find.byType(Align),
        ),
      );

      expect(align.alignment, Alignment.center);
      expect(find.byType(DesignSystemNavigationTabBar), findsOneWidget);
    });

    testWidgets('includes the bottom safe-area inset in occupied height', (
      tester,
    ) async {
      const withInset = MediaQueryData(
        size: Size(390, 844),
        padding: EdgeInsets.only(bottom: 34),
      );
      const withoutInset = MediaQueryData(
        size: Size(390, 844),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
          mediaQueryData: withInset,
        ),
      );

      final withInsetHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        tester.element(find.byType(Scaffold)),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
          mediaQueryData: withoutInset,
        ),
      );

      final withoutInsetHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        tester.element(find.byType(Scaffold)),
      );

      expect(withInsetHeight - withoutInsetHeight, withInset.padding.bottom);
    });

    testWidgets(
      'provides enough bottom padding to lift the FAB above the bar',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const DesignSystemBottomNavigationFabPadding(
              child: SizedBox.square(dimension: 56),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        final context = tester.element(
          find.byType(DesignSystemBottomNavigationFabPadding),
        );
        final padding = tester.widget<Padding>(
          find.descendant(
            of: find.byType(DesignSystemBottomNavigationFabPadding),
            matching: find.byType(Padding),
          ),
        );

        expect(
          padding.padding,
          EdgeInsets.only(
            bottom: DesignSystemBottomNavigationBar.occupiedHeight(context),
          ),
        );
      },
    );
  });
}
