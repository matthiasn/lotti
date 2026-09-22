import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

void main() {
  const phone = MediaQueryData(size: Size(390, 844));
  const scopedChildKey = ValueKey('scoped-child');

  Future<BuildContext> pumpScoped(
    WidgetTester tester, {
    double height = 0,
    bool barDocked = true,
    MediaQueryData mediaQueryData = phone,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemBottomNavigationOverlayHeight(
          height: height,
          barDocked: barDocked,
          child: const SizedBox.shrink(key: scopedChildKey),
        ),
        theme: DesignSystemTheme.light(),
        mediaQueryData: mediaQueryData,
      ),
    );
    return tester.element(find.byKey(scopedChildKey));
  }

  double fabBottomPadding(WidgetTester tester) {
    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(DesignSystemBottomNavigationFabPadding),
        matching: find.byType(Padding),
      ),
    );
    return padding.padding.resolve(TextDirection.ltr).bottom;
  }

  group('DesignSystemBottomNavigationBar.occupiedHeight', () {
    testWidgets("is the launcher's rendered height on a compact window", (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MobileNavigationLauncher(onNavigate: () {}),
          theme: DesignSystemTheme.light(),
          mediaQueryData: phone,
        ),
      );

      final rendered = tester
          .getSize(find.byType(MobileNavigationLauncher))
          .height;
      final context = tester.element(find.byType(MobileNavigationLauncher));
      // Guards the equality below from passing on a zero-height row.
      expect(rendered, greaterThan(0));
      expect(
        DesignSystemBottomNavigationBar.occupiedHeight(context),
        rendered,
      );
    });

    testWidgets('includes the bottom safe-area inset the launcher absorbs', (
      tester,
    ) async {
      const inset = 34.0;
      final withInset = await pumpScoped(
        tester,
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: inset),
        ),
      );
      final withInsetHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        withInset,
      );
      final without = await pumpScoped(tester);
      final withoutInsetHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        without,
      );

      // The launcher pads its bottom by the inset or its own step6 floor,
      // whichever is larger — never both — so the inset displaces the floor
      // rather than stacking onto it.
      final floor = dsTokensLight.spacing.step6;
      expect(
        withInsetHeight - withoutInsetHeight,
        moreOrLessEquals(math.max(inset, floor) - floor),
      );
    });

    testWidgets('is 0 in desktop layout, where the sidebar replaces it', (
      tester,
    ) async {
      final context = await pumpScoped(
        tester,
        height: 24,
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
      );
      expect(DesignSystemBottomNavigationBar.occupiedHeight(context), 0);
    });

    testWidgets('adds the published overlay height', (tester) async {
      final context = await pumpScoped(tester, height: 24);
      // The Scaffold sits above the scope, the keyed child below it — the
      // difference is exactly the published overlay height.
      final outsideScope = DesignSystemBottomNavigationBar.occupiedHeight(
        tester.element(find.byType(Scaffold)),
      );
      final insideScope = DesignSystemBottomNavigationBar.occupiedHeight(
        context,
      );
      expect(insideScope - outsideScope, 24);
    });

    testWidgets('counts the launcher only while it is docked', (tester) async {
      final docked = await pumpScoped(tester, height: 24);
      final launcherHeight = MobileNavigationLauncher.barHeight(docked);
      expect(launcherHeight, greaterThan(0));
      expect(
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(docked),
        isTrue,
      );
      expect(
        DesignSystemBottomNavigationBar.occupiedHeight(docked),
        launcherHeight + 24,
      );

      // The launcher has slid off-screen: it occupies nothing, so only the
      // island riding above it still counts. A page padding by this number
      // must be left with no launcher-sized gutter where its own pinned
      // surface docks.
      final slidAway = await pumpScoped(tester, height: 24, barDocked: false);
      expect(
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(slidAway),
        isFalse,
      );
      expect(DesignSystemBottomNavigationBar.occupiedHeight(slidAway), 24);
    });

    testWidgets('reserves the launcher where no scope publishes a docked '
        'state', (tester) async {
      // Previews and widget tests render pages without the app shell, so
      // `barDockedOf` defaults to docked and they reserve room for the
      // launcher exactly as the shell's pages do.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
          mediaQueryData: phone,
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      expect(
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(context),
        isTrue,
      );
      expect(DesignSystemBottomNavigationOverlayHeight.of(context), 0);
      expect(
        DesignSystemBottomNavigationBar.occupiedHeight(context),
        MobileNavigationLauncher.barHeight(context),
      );
    });
  });

  group('DesignSystemBottomNavigationFabPadding', () {
    Future<void> pump(
      WidgetTester tester, {
      double height = 0,
      bool barDocked = true,
    }) {
      return tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemBottomNavigationOverlayHeight(
            height: height,
            barDocked: barDocked,
            child: const DesignSystemBottomNavigationFabPadding(
              child: SizedBox.square(dimension: 56),
            ),
          ),
          theme: DesignSystemTheme.light(),
          mediaQueryData: phone,
        ),
      );
    }

    testWidgets('lifts its child by occupiedHeight', (tester) async {
      await pump(tester, height: 24);
      final context = tester.element(
        find.byType(DesignSystemBottomNavigationFabPadding),
      );
      final occupied = DesignSystemBottomNavigationBar.occupiedHeight(context);
      expect(occupied, greaterThan(24));
      expect(fabBottomPadding(tester), occupied);
    });

    testWidgets('tracks published overlay height changes', (tester) async {
      await pump(tester);
      final launcherOnly = fabBottomPadding(tester);

      // An island appears above the launcher: the padding grows by exactly
      // its height so the island never covers the lifted child.
      await pump(tester, height: 24);
      expect(fabBottomPadding(tester) - launcherOnly, 24);

      // Island gone again: padding shrinks back to the launcher alone.
      await pump(tester);
      expect(fabBottomPadding(tester), launcherOnly);
    });

    testWidgets('drops the launcher gutter when it slides away', (
      tester,
    ) async {
      await pump(tester, height: 24);
      final launcherHeight = MobileNavigationLauncher.barHeight(
        tester.element(find.byType(DesignSystemBottomNavigationFabPadding)),
      );
      final docked = fabBottomPadding(tester);
      expect(docked, launcherHeight + 24);

      // Flipping only the docked flag must reach dependents (it is the
      // second half of updateShouldNotify) and shed exactly the launcher.
      await pump(tester, height: 24, barDocked: false);
      expect(fabBottomPadding(tester), 24);
      expect(docked - fabBottomPadding(tester), launcherHeight);
    });
  });

  group('DesignSystemBottomNavigationOverlayHeight.launcherPresentOf', () {
    Future<bool?> resolve(
      WidgetTester tester, {
      required Widget Function(Widget child) scope,
    }) async {
      bool? present;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          scope(
            Builder(
              builder: (context) {
                present =
                    DesignSystemBottomNavigationOverlayHeight.launcherPresentOf(
                      context,
                    );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return present;
    }

    testWidgets('is true where no scope exists, so a page rendered outside '
        'the shell behaves as it always has', (tester) async {
      expect(await resolve(tester, scope: (child) => child), isTrue);
    });

    testWidgets('reports what the enclosing scope publishes', (tester) async {
      expect(
        await resolve(
          tester,
          scope: (child) => DesignSystemBottomNavigationOverlayHeight(
            height: 0,
            launcherPresent: false,
            child: child,
          ),
        ),
        isFalse,
      );
      expect(
        await resolve(
          tester,
          scope: (child) => DesignSystemBottomNavigationOverlayHeight(
            height: 0,
            child: child,
          ),
        ),
        isTrue,
      );
    });
  });

  group('DesignSystemBottomNavigationOverlayHeight.updateShouldNotify', () {
    const child = SizedBox.shrink();
    const docked = DesignSystemBottomNavigationOverlayHeight(
      height: 24,
      child: child,
    );

    test('fires when only the docked flag flips', () {
      const slidAway = DesignSystemBottomNavigationOverlayHeight(
        height: 24,
        barDocked: false,
        child: child,
      );
      expect(slidAway.updateShouldNotify(docked), isTrue);
      expect(docked.updateShouldNotify(slidAway), isTrue);
    });

    test('fires when only the launcher comes or goes', () {
      const noLauncher = DesignSystemBottomNavigationOverlayHeight(
        height: 24,
        launcherPresent: false,
        child: child,
      );
      expect(noLauncher.updateShouldNotify(docked), isTrue);
      expect(docked.updateShouldNotify(noLauncher), isTrue);
    });

    test('fires when only the height moves', () {
      const taller = DesignSystemBottomNavigationOverlayHeight(
        height: 40,
        child: child,
      );
      expect(taller.updateShouldNotify(docked), isTrue);
    });

    test('stays quiet when neither field moved', () {
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
