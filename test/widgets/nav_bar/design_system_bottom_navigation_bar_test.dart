import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

void main() {
  void onNavigate() {}

  group('DesignSystemBottomNavigationBar', () {
    testWidgets('centers one labeled launcher and dispatches its action', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemBottomNavigationBar(onNavigate: () => taps++),
          theme: DesignSystemTheme.light(),
        ),
      );
      final button = tester.getRect(find.byType(DesignSystemButton));
      final container = tester.getRect(
        find.byType(DesignSystemBottomNavigationBar),
      );
      expect(button.width, lessThan(container.width));
      expect(button.center.dx, container.center.dx);
      expect(button.height, greaterThanOrEqualTo(TapTargets.minimum));
      await tester.tap(find.text('Navigate'));
      expect(taps, 1);
    });

    for (final scale in [1.3, 2.0, 3.0]) {
      testWidgets('launcher clearance matches large text at $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DesignSystemBottomNavigationBar(onNavigate: onNavigate),
            theme: DesignSystemTheme.light(),
            mediaQueryData: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(bottom: 34),
            ),
          ),
        );
        final finder = find.byType(DesignSystemBottomNavigationBar);
        expect(
          tester.getSize(finder).height,
          DesignSystemBottomNavigationBar.occupiedHeight(
            tester.element(finder),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('occupiedHeight matches the rendered bar extent', (
      tester,
    ) async {
      const noInset = MediaQueryData(size: Size(390, 844));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemBottomNavigationBar(onNavigate: onNavigate),
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

    testWidgets(
      'includes the bottom safe-area inset in occupied height',
      (
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

        final withoutInsetHeight =
            DesignSystemBottomNavigationBar.occupiedHeight(
              tester.element(find.byType(Scaffold)),
            );

        // The launcher clears the full system safe area on every platform.
        final expectedAbsorbed = withInset.padding.bottom;
        expect(
          withInsetHeight - withoutInsetHeight,
          moreOrLessEquals(expectedAbsorbed - dsTokensLight.spacing.step6),
        );
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

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

    testWidgets('occupiedHeight counts the bar only while it is docked', (
      tester,
    ) async {
      const noInset = MediaQueryData(size: Size(390, 844));
      const scopedChildKey = ValueKey('scoped-child');

      Future<void> pump({required bool barDocked}) {
        return tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DesignSystemBottomNavigationOverlayHeight(
              height: 24,
              barDocked: barDocked,
              child: const SizedBox.shrink(key: scopedChildKey),
            ),
            theme: DesignSystemTheme.light(),
            mediaQueryData: noInset,
          ),
        );
      }

      double occupied() => DesignSystemBottomNavigationBar.occupiedHeight(
        tester.element(find.byKey(scopedChildKey)),
      );

      await pump(barDocked: true);
      final barHeight = DesignSystemBottomNavigationBar.barHeight(
        tester.element(find.byKey(scopedChildKey)),
      );
      // Guards the arithmetic below from passing on a zero-height bar.
      expect(barHeight, greaterThan(0));
      expect(
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(
          tester.element(find.byKey(scopedChildKey)),
        ),
        isTrue,
      );
      final docked = occupied();
      expect(docked, barHeight + 24);

      // The bar has slid off-screen: it occupies nothing, so only the
      // indicator row riding above it still counts. A page padding by this
      // number must be left with no bar-sized gutter where its own pinned
      // surface docks.
      await pump(barDocked: false);
      expect(
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(
          tester.element(find.byKey(scopedChildKey)),
        ),
        isFalse,
      );
      final slidAway = occupied();
      expect(slidAway, 24);
      expect(docked - slidAway, barHeight);
    });

    testWidgets('reserves the bar where no scope publishes a docked state', (
      tester,
    ) async {
      // Previews and widget tests render pages without the app shell, so
      // `barDockedOf` defaults to docked and they reserve room exactly as
      // they did before the flag existed.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      expect(
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(context),
        isTrue,
      );
      expect(
        DesignSystemBottomNavigationBar.occupiedHeight(context),
        DesignSystemBottomNavigationBar.barHeight(context),
      );
    });

    testWidgets('FabPadding drops the bar gutter when the bar slides away', (
      tester,
    ) async {
      Future<void> pump({required bool barDocked}) {
        return tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DesignSystemBottomNavigationOverlayHeight(
              height: 24,
              barDocked: barDocked,
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

      await pump(barDocked: true);
      final barHeight = DesignSystemBottomNavigationBar.barHeight(
        tester.element(find.byType(DesignSystemBottomNavigationFabPadding)),
      );
      final docked = bottomPadding();
      expect(docked, barHeight + 24);

      // Flipping only the docked flag must reach dependents (it is the
      // second half of updateShouldNotify) and shed exactly the bar.
      await pump(barDocked: false);
      expect(bottomPadding(), 24);
      expect(docked - bottomPadding(), barHeight);
    });

    test('updateShouldNotify fires when only the docked flag flips', () {
      const child = SizedBox.shrink();
      const docked = DesignSystemBottomNavigationOverlayHeight(
        height: 24,
        child: child,
      );
      const slidAway = DesignSystemBottomNavigationOverlayHeight(
        height: 24,
        barDocked: false,
        child: child,
      );

      expect(slidAway.updateShouldNotify(docked), isTrue);
      expect(docked.updateShouldNotify(slidAway), isTrue);
      // Neither field moved: dependents must not be rebuilt.
      expect(
        docked.updateShouldNotify(
          const DesignSystemBottomNavigationOverlayHeight(
            height: 24,
            child: child,
          ),
        ),
        isFalse,
      );
    });
  });
}
