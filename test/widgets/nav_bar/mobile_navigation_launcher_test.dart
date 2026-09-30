import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/navigation/ds_menu_glyph.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_utils/screenshot_harness.dart';
import '../../widget_test_utils.dart';

void main() {
  // Width-driven layout assertions pin the fonts themselves. `FontLoader`
  // registers process-wide with no unload, so under the single-isolate
  // optimizer a file that loaded Inter earlier in the shard silently changes
  // every later file's text metrics. Tuned against whichever font the bundle
  // order happened to leave behind, the break points below describe a layout
  // that does not ship — see test/README.md, "Committed per-feature
  // harnesses".
  setUpAll(loadAppFonts);

  void onOpenMenu() {}
  void onAction() {}

  MobileNavDockAction action({
    VoidCallback? onPressed,
    String label = 'Add a task',
    String? semanticLabel,
  }) => MobileNavDockAction.worded(
    label: label,
    icon: LottiIcons.add,
    onPressed: onPressed ?? onAction,
    semanticLabel: semanticLabel,
  );

  MobileNavDockAction glyphAction({
    VoidCallback? onPressed,
    String label = 'Add a habit',
  }) => MobileNavDockAction.glyph(
    label: label,
    icon: LottiIcons.add,
    onPressed: onPressed ?? onAction,
  );

  // A large phone, comfortably wider than the row needs at the real font —
  // the default for tests that are not about the fit threshold.
  const roomy = MediaQueryData(
    size: Size(430, 932),
    padding: EdgeInsets.only(top: 47, bottom: 34),
  );

  MediaQueryData sized(Size size, [TextScaler scaler = TextScaler.noScaling]) =>
      MediaQueryData(
        size: size,
        padding: roomy.padding,
        textScaler: scaler,
      );

  MediaQueryData scaled(TextScaler scaler) => sized(roomy.size, scaler);

  Widget subject({
    MobileNavDockAction? pageAction,
    VoidCallback? openMenu,
    MediaQueryData? mediaQueryData,
    ThemeData? theme,
    TextDirection textDirection = TextDirection.ltr,
  }) => makeTestableWidgetWithScaffold(
    Directionality(
      textDirection: textDirection,
      child: MobileNavigationLauncher(
        onOpenMenu: openMenu ?? onOpenMenu,
        pageAction: pageAction,
      ),
    ),
    theme: theme ?? DesignSystemTheme.light(),
    mediaQueryData: mediaQueryData ?? roomy,
  );

  final menuButton = find.byKey(MobileNavigationLauncherKeys.menuButton);

  BuildContext launcherContext(WidgetTester tester) =>
      tester.element(find.byType(MobileNavigationLauncher));

  Rect launcherRect(WidgetTester tester) =>
      tester.getRect(find.byType(MobileNavigationLauncher));

  Rect menuRect(WidgetTester tester) => tester.getRect(menuButton);

  Rect pillRect(WidgetTester tester) =>
      tester.getRect(find.byType(DsGlassPill));

  double chipHeightOf(WidgetTester tester) =>
      MobileNavigationLauncher.chipHeight(launcherContext(tester));

  double leadingGutterOf(WidgetTester tester) =>
      MobileNavigationLauncher.leadingGutter(launcherContext(tester));

  double trailingGutterOf(WidgetTester tester) =>
      MobileNavigationLauncher.trailingGutter(launcherContext(tester));

  final glyphActionButton = find.byWidgetPredicate(
    (w) => w is DsGlassRoundButton && w.icon == LottiIcons.add,
  );

  /// Pumps the launcher so its row is [delta] pixels wider than the menu
  /// button, the gap and the worded action need at [scaler].
  ///
  /// Calibrated rather than guessed: a hard-coded width pins the threshold to
  /// one font's metrics, and the assertion then passes or fails for reasons
  /// that have nothing to do with the branch under test. Measuring first puts
  /// the row a single pixel on the intended side of
  /// [MobileNavigationLauncher.labelsFit].
  Future<void> pumpAtFitThreshold(
    WidgetTester tester, {
    required MobileNavDockAction pageAction,
    required double delta,
    TextScaler scaler = TextScaler.noScaling,
  }) async {
    // A generous first pass, only to get a context to measure through; the
    // intrinsic widths depend on the text scale, not the viewport.
    await tester.pumpWidget(
      subject(
        pageAction: pageAction,
        mediaQueryData: sized(const Size(2000, 932), scaler),
      ),
    );
    final context = launcherContext(tester);
    final needed =
        MobileNavigationLauncher.chipHeight(context) +
        MobileNavigationLauncher.chipGap(context) +
        DsGlassPill.intrinsicWidth(context, label: pageAction.label);
    final gutters =
        MobileNavigationLauncher.leadingGutter(context) +
        MobileNavigationLauncher.trailingGutter(context);

    await tester.pumpWidget(
      subject(
        pageAction: pageAction,
        mediaQueryData: sized(Size(needed + gutters + delta, 932), scaler),
      ),
    );
  }

  group('mobileNavigationLauncherOwnsPageActions', () {
    Future<bool?> resolve(
      WidgetTester tester, {
      required Size size,
      bool? barDocked,
    }) async {
      bool? owns;
      final probe = Builder(
        builder: (context) {
          owns = mobileNavigationLauncherOwnsPageActions(context);
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          barDocked == null
              ? probe
              : DesignSystemBottomNavigationOverlayHeight(
                  height: 0,
                  barDocked: barDocked,
                  child: probe,
                ),
          theme: DesignSystemTheme.light(),
          mediaQueryData: MediaQueryData(size: size),
        ),
      );
      await tester.pump();
      return owns;
    }

    testWidgets('is true on a compact window', (tester) async {
      expect(await resolve(tester, size: const Size(390, 844)), isTrue);
    });

    testWidgets('ignores whether the launcher is docked or slid away', (
      tester,
    ) async {
      expect(
        await resolve(tester, size: const Size(390, 844), barDocked: false),
        isTrue,
      );
      expect(
        await resolve(tester, size: const Size(390, 844), barDocked: true),
        isTrue,
      );
    });

    testWidgets('is true right up to the desktop breakpoint', (tester) async {
      expect(
        await resolve(tester, size: const Size(kDesktopBreakpoint - 1, 844)),
        isTrue,
      );
    });

    testWidgets('is false from the desktop breakpoint on — the sidebar '
        'replaces the launcher there', (tester) async {
      expect(
        await resolve(tester, size: const Size(kDesktopBreakpoint, 844)),
        isFalse,
      );
      expect(await resolve(tester, size: const Size(1280, 800)), isFalse);
    });
  });

  group('gutters', () {
    testWidgets('the leading gutter is wider than the trailing one', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      final tokens = launcherContext(tester).designTokens;

      expect(leadingGutterOf(tester), tokens.spacing.step5);
      expect(trailingGutterOf(tester), tokens.spacing.step3);
      expect(leadingGutterOf(tester), greaterThan(trailingGutterOf(tester)));
    });

    testWidgets('availableRowWidth takes both gutters and both side insets '
        'off the window', (tester) async {
      const insets = EdgeInsets.only(left: 30, right: 20, bottom: 21);
      await tester.pumpWidget(
        subject(
          mediaQueryData: const MediaQueryData(
            size: Size(932, 430),
            padding: insets,
          ),
        ),
      );

      expect(
        MobileNavigationLauncher.availableRowWidth(launcherContext(tester)),
        932 -
            insets.left -
            insets.right -
            leadingGutterOf(tester) -
            trailingGutterOf(tester),
      );
    });
  });

  group('the menu button', () {
    testWidgets('stands alone in the bottom-leading corner, the leading '
        'gutter in from the edge', (tester) async {
      await tester.pumpWidget(subject());

      final launcher = launcherRect(tester);
      expect(launcher.width, tester.getSize(find.byType(Scaffold)).width);
      expect(menuRect(tester).left, launcher.left + leadingGutterOf(tester));
      expect(find.byType(DsGlassPill), findsNothing);
    });

    testWidgets('opens the menu when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(subject(openMenu: () => taps++));

      await tester.tap(menuButton);
      expect(taps, 1);
    });

    testWidgets('is a round glyph button the height of a chip, wearing the '
        'two-stroke menu mark', (tester) async {
      await tester.pumpWidget(subject());

      final button = tester.widget<DsGlassRoundButton>(menuButton);
      expect(button.glyph, isA<DsMenuGlyph>());
      expect(button.icon, isNull);
      expect(button.diameter, chipHeightOf(tester));
      expect(button.iconSize, IconSizes.l);
      expect(menuRect(tester).width, closeTo(chipHeightOf(tester), 0.01));
      expect(menuRect(tester).height, closeTo(chipHeightOf(tester), 0.01));
      expect(menuRect(tester).height, greaterThanOrEqualTo(TapTargets.minimum));
    });

    for (final (name, theme) in [
      ('light', DesignSystemTheme.light()),
      ('dark', DesignSystemTheme.dark()),
    ]) {
      testWidgets('wears the accent as a ring and as the glyph ink over '
          'translucent glass ($name)', (tester) async {
        await tester.pumpWidget(subject(theme: theme));

        final accent = launcherContext(
          tester,
        ).designTokens.colors.interactive.enabled;
        final button = tester.widget<DsGlassRoundButton>(menuButton);
        expect(button.outlineColor, accent);
        expect(button.iconColor, accent);
        // Translucent, so the ring is drawn and the page shows through.
        expect(button.backgroundColor, isNull);
        expect(
          IconTheme.of(tester.element(find.byType(DsMenuGlyph))).color,
          accent,
        );
      });
    }

    testWidgets('blurs the page behind it and floats on the glass shadow', (
      tester,
    ) async {
      await tester.pumpWidget(subject());

      final filter = tester.widget<BackdropFilter>(
        find.ancestor(of: menuButton, matching: find.byType(BackdropFilter)),
      );
      expect(
        filter.filter.toString(),
        contains('${DesignSystemGlassStrip.blurSigma}'),
      );
      expect(
        tester
            .widgetList<DecoratedBox>(
              find.ancestor(
                of: menuButton,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => (box.decoration as BoxDecoration).boxShadow),
        contains(DsShadows.floatingSurface),
      );
    });

    testWidgets('announces that it opens the navigation', (tester) async {
      await tester.pumpWidget(subject());

      final label = launcherContext(tester).messages.navSidebarOpenLabel;
      expect(
        tester.widget<DsGlassRoundButton>(menuButton).semanticLabel,
        label,
      );
      expect(find.bySemanticsLabel(label), findsOneWidget);
    });

    testWidgets('stays exactly where it is whether or not the page docks an '
        'action', (tester) async {
      await tester.pumpWidget(subject());
      final alone = menuRect(tester);

      await tester.pumpWidget(subject(pageAction: action()));
      expect(menuRect(tester), alone);

      await tester.pumpWidget(subject(pageAction: glyphAction()));
      expect(menuRect(tester), alone);
    });

    testWidgets('clears the leading safe-area inset of a landscape phone', (
      tester,
    ) async {
      const inset = 48.0;
      await tester.pumpWidget(
        subject(
          mediaQueryData: const MediaQueryData(
            size: Size(932, 430),
            padding: EdgeInsets.only(left: inset, bottom: 21),
          ),
        ),
      );

      expect(
        menuRect(tester).left,
        launcherRect(tester).left + inset + leadingGutterOf(tester),
      );
    });
  });

  group('the docked page action', () {
    testWidgets('is pinned to the bottom-trailing corner, on the menu '
        "button's row and baseline", (tester) async {
      await tester.pumpWidget(subject(pageAction: action()));

      final create = pillRect(tester);
      final launcher = launcherRect(tester);
      expect(
        create.right,
        closeTo(launcher.right - trailingGutterOf(tester), 0.01),
      );
      expect(create.height, closeTo(menuRect(tester).height, 0.01));
      expect(create.center.dy, closeTo(menuRect(tester).center.dy, 0.01));
      // The two sit at opposite ends, not as a centred pair.
      expect(
        create.left - menuRect(tester).right,
        greaterThan(MobileNavigationLauncher.chipGap(launcherContext(tester))),
      );
    });

    testWidgets('clears the trailing safe-area inset', (tester) async {
      const inset = 48.0;
      await tester.pumpWidget(
        subject(
          pageAction: action(),
          mediaQueryData: const MediaQueryData(
            size: Size(932, 430),
            padding: EdgeInsets.only(right: inset, bottom: 21),
          ),
        ),
      );

      expect(
        pillRect(tester).right,
        closeTo(
          launcherRect(tester).right - inset - trailingGutterOf(tester),
          0.01,
        ),
      );
    });

    for (final (name, theme) in [
      ('light', DesignSystemTheme.light()),
      ('dark', DesignSystemTheme.dark()),
    ]) {
      testWidgets('is filled with the accent and its ink, carrying its label '
          '($name)', (tester) async {
        await tester.pumpWidget(subject(pageAction: action(), theme: theme));

        final tokens = launcherContext(tester).designTokens;
        final create = tester.widget<DsGlassPill>(find.byType(DsGlassPill));
        expect(create.fillColor, tokens.colors.interactive.enabled);
        expect(create.foregroundColor, tokens.colors.text.onInteractiveAlert);
        expect(create.label, 'Add a task');
        expect(create.icon, LottiIcons.add);
      });
    }

    testWidgets('an opaque action skips the backdrop blur it cannot show', (
      tester,
    ) async {
      await tester.pumpWidget(subject(pageAction: action()));

      expect(
        find.ancestor(
          of: find.byType(DsGlassPill),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });

    testWidgets('dispatches its own action, and the menu button its own', (
      tester,
    ) async {
      var menuTaps = 0;
      var actionTaps = 0;
      await tester.pumpWidget(
        subject(
          openMenu: () => menuTaps++,
          pageAction: action(onPressed: () => actionTaps++),
        ),
      );

      await tester.tap(find.text('Add a task'));
      expect((menuTaps, actionTaps), (0, 1));

      await tester.tap(menuButton);
      expect((menuTaps, actionTaps), (1, 1));
    });

    testWidgets('announces its semantic label override', (tester) async {
      await tester.pumpWidget(
        subject(pageAction: action(semanticLabel: 'Create a new task')),
      );

      expect(
        tester.widget<DsGlassPill>(find.byType(DsGlassPill)).semanticLabel,
        'Create a new task',
      );
    });
  });

  group('a glyph-only page action', () {
    testWidgets('is a round accent button in the trailing corner that '
        'announces its name and never renders it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        subject(pageAction: glyphAction(onPressed: () => taps++)),
      );

      final rect = tester.getRect(glyphActionButton);
      expect(
        rect.right,
        closeTo(launcherRect(tester).right - trailingGutterOf(tester), 0.01),
      );
      expect(rect.width, closeTo(chipHeightOf(tester), 0.01));
      expect(find.text('Add a habit'), findsNothing);
      expect(find.bySemanticsLabel('Add a habit'), findsOneWidget);

      final tokens = launcherContext(tester).designTokens;
      final button = tester.widget<DsGlassRoundButton>(glyphActionButton);
      expect(button.backgroundColor, tokens.colors.interactive.enabled);
      expect(button.iconColor, tokens.colors.text.onInteractiveAlert);

      await tester.tap(glyphActionButton);
      expect(taps, 1);
    });

    testWidgets('stays round however long its accessible name is', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          pageAction: glyphAction(
            label: 'Add a habit to the list of things you do every day',
          ),
        ),
      );

      expect(find.byType(DsGlassPill), findsNothing);
      expect(
        tester.getSize(glyphActionButton).width,
        closeTo(chipHeightOf(tester), 0.01),
      );
    });
  });

  group('labelsFit', () {
    testWidgets('keeps the word when the row has exactly room for the disc, '
        'the gap and the label', (tester) async {
      await pumpAtFitThreshold(tester, pageAction: action(), delta: 0);

      expect(
        MobileNavigationLauncher.labelsFit(launcherContext(tester), action()),
        isTrue,
      );
      expect(find.text('Add a task'), findsOneWidget);
    });

    testWidgets('drops the action to its glyph one pixel short of that, '
        'still announcing its name', (tester) async {
      await pumpAtFitThreshold(
        tester,
        pageAction: action(),
        delta: -1,
        scaler: const TextScaler.linear(2),
      );

      expect(
        MobileNavigationLauncher.labelsFit(launcherContext(tester), action()),
        isFalse,
      );
      expect(find.text('Add a task'), findsNothing);
      expect(find.bySemanticsLabel('Add a task'), findsOneWidget);
      expect(glyphActionButton, findsOneWidget);
    });

    testWidgets('a longer label collapses the row sooner', (tester) async {
      await pumpAtFitThreshold(tester, pageAction: action(), delta: 0);

      expect(
        MobileNavigationLauncher.labelsFit(
          launcherContext(tester),
          action(label: 'Add a task to this project'),
        ),
        isFalse,
      );
    });

    testWidgets('the collapsed glyph keeps the row on one baseline', (
      tester,
    ) async {
      await pumpAtFitThreshold(tester, pageAction: action(), delta: -1);

      expect(
        tester.getRect(glyphActionButton).center.dy,
        closeTo(menuRect(tester).center.dy, 0.01),
      );
    });
  });

  group('right-to-left', () {
    testWidgets('mirrors the corners and the gutters: menu button on the '
        'right, action on the left', (tester) async {
      await tester.pumpWidget(
        subject(pageAction: action(), textDirection: TextDirection.rtl),
      );

      final launcher = launcherRect(tester);
      expect(
        menuRect(tester).right,
        closeTo(launcher.right - leadingGutterOf(tester), 0.01),
      );
      expect(
        pillRect(tester).left,
        closeTo(launcher.left + trailingGutterOf(tester), 0.01),
      );
    });

    testWidgets('pairs the leading gutter with the right-hand safe-area '
        'inset', (tester) async {
      const inset = 48.0;
      await tester.pumpWidget(
        subject(
          pageAction: action(),
          textDirection: TextDirection.rtl,
          mediaQueryData: const MediaQueryData(
            size: Size(932, 430),
            padding: EdgeInsets.only(right: inset, left: 12, bottom: 21),
          ),
        ),
      );

      final launcher = launcherRect(tester);
      expect(
        menuRect(tester).right,
        closeTo(launcher.right - inset - leadingGutterOf(tester), 0.01),
      );
      expect(
        pillRect(tester).left,
        closeTo(launcher.left + 12 + trailingGutterOf(tester), 0.01),
      );
    });
  });

  group('chipHeight', () {
    testWidgets('is the tap-target floor at the default text size', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      final tokens = launcherContext(tester).designTokens;

      expect(
        chipHeightOf(tester),
        tokens.typography.lineHeight.subtitle1 + tokens.spacing.step4 * 2,
      );
      expect(chipHeightOf(tester), greaterThanOrEqualTo(TapTargets.minimum));
    });

    for (final scaler in const [
      TextScaler.linear(2),
      _NonlinearTextScaler(),
    ]) {
      testWidgets('grows with the scaled label line at $scaler', (
        tester,
      ) async {
        await tester.pumpWidget(subject(mediaQueryData: scaled(scaler)));
        final tokens = launcherContext(tester).designTokens;
        final style = tokens.typography.styles.subtitle.subtitle1;

        expect(
          chipHeightOf(tester),
          scaler.scale(style.fontSize!) * style.height! +
              tokens.spacing.step4 * 2,
        );
      });
    }
  });

  group('clearance', () {
    for (final scaler in const [
      TextScaler.noScaling,
      TextScaler.linear(1.3),
      TextScaler.linear(2),
      TextScaler.linear(3),
      _NonlinearTextScaler(),
    ]) {
      for (final docked in const [false, true]) {
        testWidgets('occupies exactly barHeight at $scaler '
            '(docked action: $docked)', (tester) async {
          await tester.pumpWidget(
            subject(
              pageAction: docked ? action() : null,
              mediaQueryData: scaled(scaler),
            ),
          );
          final finder = find.byType(MobileNavigationLauncher);
          expect(
            tester.getSize(finder).height,
            MobileNavigationLauncher.barHeight(tester.element(finder)),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the safe-area inset only ever adds clearance', (tester) async {
      await tester.pumpWidget(
        subject(mediaQueryData: const MediaQueryData(size: Size(430, 932))),
      );
      final withoutInset = tester.getSize(
        find.byType(MobileNavigationLauncher),
      );
      final tokens = launcherContext(tester).designTokens;

      await tester.pumpWidget(
        subject(
          mediaQueryData: MediaQueryData(
            size: const Size(430, 932),
            padding: EdgeInsets.only(bottom: tokens.spacing.step6 * 2),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(MobileNavigationLauncher)).height,
        withoutInset.height + tokens.spacing.step6,
      );
    });
  });
}

/// Smaller fonts grow proportionally more, as in accessibility text scaling.
class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize * 2 : fontSize * 1.5 + 8;

  @override
  double get textScaleFactor => 2;
}
