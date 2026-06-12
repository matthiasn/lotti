import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

import '../../widget_test_utils.dart';

void main() {
  const items = [
    DesignSystemFiveSlotNavBarItem(
      label: 'Tasks',
      icon: Icon(Icons.check_circle_outline),
      active: true,
    ),
    DesignSystemFiveSlotNavBarItem(
      label: 'Journal',
      icon: Icon(Icons.book_outlined),
    ),
    DesignSystemFiveSlotNavBarItem(
      label: 'Settings',
      icon: Icon(Icons.settings_outlined),
    ),
    DesignSystemFiveSlotNavBarItem(
      label: 'More',
      icon: Icon(Icons.more_horiz_rounded),
    ),
  ];

  group('DesignSystemBottomNavigationBar', () {
    testWidgets('adds no gap or inset of its own around the bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 390,
            child: DesignSystemBottomNavigationBar(items: items),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final containerRect = tester.getRect(
        find.byType(DesignSystemBottomNavigationBar),
      );
      final barRect = tester.getRect(find.byType(DesignSystemFiveSlotNavBar));

      // The container contributes zero padding: when the shell pins it to
      // the screen's bottom edge the bar surface is flush with that edge
      // and spans the full width.
      expect(barRect.bottom, containerRect.bottom);
      expect(barRect.left, containerRect.left);
      expect(barRect.right, containerRect.right);
    });

    testWidgets('occupiedHeight matches the rendered bar extent', (
      tester,
    ) async {
      const noInset = MediaQueryData(size: Size(390, 844));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemBottomNavigationBar(items: items),
          theme: DesignSystemTheme.light(),
          mediaQueryData: noInset,
        ),
      );

      final renderedHeight = tester
          .getSize(find.byType(DesignSystemBottomNavigationBar))
          .height;
      final occupiedHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        tester.element(find.byType(DesignSystemBottomNavigationBar)),
      );

      expect(occupiedHeight, renderedHeight);
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

      // The bar absorbs bottomInsetFraction of the inset, which replaces
      // (not stacks onto) its internal step2 bottom padding — so occupied
      // height grows by the trimmed inset minus the padding it displaced.
      expect(
        withInsetHeight - withoutInsetHeight,
        moreOrLessEquals(
          withInset.padding.bottom *
                  DesignSystemFiveSlotNavBar.bottomInsetFraction -
              dsTokensLight.spacing.step2,
        ),
      );
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

    testWidgets('occupiedHeight adds the published overlay height', (
      tester,
    ) async {
      const noInset = MediaQueryData(size: Size(390, 844));
      const scopedChildKey = ValueKey('scoped-child');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemBottomNavigationOverlayHeight(
            height: 24,
            child: SizedBox.shrink(key: scopedChildKey),
          ),
          theme: DesignSystemTheme.light(),
          mediaQueryData: noInset,
        ),
      );

      // The Scaffold sits above the scope, the keyed child below it — the
      // difference is exactly the published overlay height.
      final outsideScope = DesignSystemBottomNavigationBar.occupiedHeight(
        tester.element(find.byType(Scaffold)),
      );
      final insideScope = DesignSystemBottomNavigationBar.occupiedHeight(
        tester.element(find.byKey(scopedChildKey)),
      );

      expect(insideScope - outsideScope, 24);
    });

    testWidgets('FabPadding tracks published overlay height changes', (
      tester,
    ) async {
      Future<void> pump(double height) {
        return tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DesignSystemBottomNavigationOverlayHeight(
              height: height,
              child: const DesignSystemBottomNavigationFabPadding(
                child: SizedBox.square(dimension: 56),
              ),
            ),
            theme: DesignSystemTheme.light(),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          ),
        );
      }

      double bottomPadding() {
        final padding = tester.widget<Padding>(
          find.descendant(
            of: find.byType(DesignSystemBottomNavigationFabPadding),
            matching: find.byType(Padding),
          ),
        );
        return (padding.padding as EdgeInsets).bottom;
      }

      await pump(0);
      final barOnly = bottomPadding();

      // An indicator appears above the bar: the padding grows by exactly
      // its height so the indicator row never covers the lifted child.
      await pump(24);
      expect(bottomPadding() - barOnly, 24);

      // Indicator gone again: padding shrinks back to the bar alone.
      await pump(0);
      expect(bottomPadding(), barOnly);
    });
  });
}
