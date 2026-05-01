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

    testWidgets('occupiedHeight returns 0 in desktop layout', (tester) async {
      const desktop = MediaQueryData(size: Size(1280, 800));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
          mediaQueryData: desktop,
        ),
      );

      expect(
        DesignSystemBottomNavigationBar.occupiedHeight(
          tester.element(find.byType(Scaffold)),
        ),
        0,
      );
    });

    testWidgets('pillTopFromNavBarBottom returns 0 in desktop layout', (
      tester,
    ) async {
      const desktop = MediaQueryData(size: Size(1280, 800));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
          mediaQueryData: desktop,
        ),
      );

      expect(
        DesignSystemBottomNavigationBar.pillTopFromNavBarBottom(
          tester.element(find.byType(Scaffold)),
        ),
        0,
      );
    });

    testWidgets(
      'pillTopFromNavBarBottom equals occupiedHeight minus the bottom inset '
      'and the top outer padding',
      (tester) async {
        const withInset = MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 34),
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SizedBox.shrink(),
            theme: DesignSystemTheme.light(),
            mediaQueryData: withInset,
          ),
        );

        final context = tester.element(find.byType(Scaffold));
        final occupied = DesignSystemBottomNavigationBar.occupiedHeight(
          context,
        );
        final pillTop = DesignSystemBottomNavigationBar.pillTopFromNavBarBottom(
          context,
        );
        final outerPadding = DesignSystemBottomNavigationBar.padding(context);

        // pillTopFromNavBarBottom intentionally drops both the bottom safe
        // inset (consumed by SafeArea at the overlay site) and the top half
        // of the outer padding (above the pill).
        expect(
          pillTop,
          occupied - withInset.padding.bottom - outerPadding.top,
        );
      },
    );

    testWidgets(
      'renders the overlay above the pill in the same Column when provided',
      (tester) async {
        const overlayKey = ValueKey('overlay');

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
                overlay: SizedBox(key: overlayKey, height: 24),
              ),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        // Overlay is mounted.
        expect(find.byKey(overlayKey), findsOneWidget);

        // It shares the same Column as the pill (so it scales/centers
        // with the pill via the FittedBox + IntrinsicWidth above it).
        final column = tester.widget<Column>(
          find
              .ancestor(
                of: find.byKey(overlayKey),
                matching: find.byType(Column),
              )
              .first,
        );
        expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);
        expect(column.mainAxisSize, MainAxisSize.min);
        expect(
          column.children.whereType<DesignSystemNavigationTabBar>(),
          hasLength(1),
        );

        // Overlay is the first child, pill is the second — overlay is
        // visually above the pill.
        final overlayCenter = tester.getCenter(find.byKey(overlayKey));
        final pillCenter = tester.getCenter(
          find.byType(DesignSystemNavigationTabBar),
        );
        expect(overlayCenter.dy, lessThan(pillCenter.dy));
      },
    );

    testWidgets('omits the overlay slot when none is provided', (
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
              ],
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // The outermost Column inside the nav bar is the one that hosts the
      // pill (and would host the overlay if provided). Inner Columns belong
      // to each tab item.
      final column = tester
          .widgetList<Column>(
            find.descendant(
              of: find.byType(DesignSystemBottomNavigationBar),
              matching: find.byType(Column),
            ),
          )
          .first;
      // Only the pill — no overlay child contributes to the Column.
      expect(column.children, hasLength(1));
      expect(column.children.first, isA<DesignSystemNavigationTabBar>());
    });
  });
}
