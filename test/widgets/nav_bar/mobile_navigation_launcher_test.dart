import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
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

  void onNavigate() {}
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

  // A large phone, comfortably wider than the two labels need at the real
  // font — the default for tests that are not about the fit threshold.
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
    VoidCallback? navigate,
    MediaQueryData? mediaQueryData,
    ThemeData? theme,
  }) => makeTestableWidgetWithScaffold(
    MobileNavigationLauncher(
      onNavigate: navigate ?? onNavigate,
      pageAction: pageAction,
    ),
    theme: theme ?? DesignSystemTheme.light(),
    mediaQueryData: mediaQueryData ?? roomy,
  );

  /// Pumps the launcher on a viewport whose chip row is [delta] pixels wider
  /// than the two labels actually need at [scaler].
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
    final context = tester.element(find.byType(MobileNavigationLauncher));
    final needed =
        DsGlassPill.intrinsicWidth(
          context,
          label: context.messages.navTabTitleNavigate,
        ) +
        MobileNavigationLauncher.chipGap(context) +
        DsGlassPill.intrinsicWidth(context, label: pageAction.label);
    // `availableRowWidth` takes the launcher's own gutters off the window.
    final gutters = context.designTokens.spacing.step3 * 2;

    await tester.pumpWidget(
      subject(
        pageAction: pageAction,
        mediaQueryData: sized(Size(needed + gutters + delta, 932), scaler),
      ),
    );
  }

  Rect chipRect(WidgetTester tester, int index) =>
      tester.getRect(find.byType(DsGlassPill).at(index));

  Rect launcherRect(WidgetTester tester) =>
      tester.getRect(find.byType(MobileNavigationLauncher));

  double chipGapOf(WidgetTester tester) => MobileNavigationLauncher.chipGap(
    tester.element(find.byType(MobileNavigationLauncher)),
  );

  group('mobileNavigationLauncherOwnsPageActions', () {
    Future<bool?> resolve(
      WidgetTester tester, {
      required Stream<bool> flag,
      required Size size,
    }) async {
      bool? owns;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Consumer(
            builder: (context, ref, _) {
              owns = mobileNavigationLauncherOwnsPageActions(context, ref);
              return const SizedBox.shrink();
            },
          ),
          theme: DesignSystemTheme.light(),
          mediaQueryData: MediaQueryData(size: size),
          overrides: [
            configFlagProvider(
              enableMobileNavigationLauncherFlag,
            ).overrideWith((_) => flag),
          ],
        ),
      );
      await tester.pump();
      return owns;
    }

    testWidgets('is false while the flag has not resolved yet', (tester) async {
      final pending = StreamController<bool>();
      addTearDown(pending.close);
      expect(
        await resolve(
          tester,
          flag: pending.stream,
          size: const Size(390, 844),
        ),
        isFalse,
      );
    });

    testWidgets('is false while the launcher flag is off', (tester) async {
      expect(
        await resolve(
          tester,
          flag: Stream.value(false),
          size: const Size(390, 844),
        ),
        isFalse,
      );
    });

    testWidgets('is true on a compact window with the flag on', (tester) async {
      expect(
        await resolve(
          tester,
          flag: Stream.value(true),
          size: const Size(390, 844),
        ),
        isTrue,
      );
    });

    testWidgets(
      'is false on a desktop window even with the flag on — the sidebar '
      'replaces the launcher there, so floating actions keep their corner',
      (tester) async {
        expect(
          await resolve(
            tester,
            flag: Stream.value(true),
            size: const Size(1280, 800),
          ),
          isFalse,
        );
      },
    );
  });

  group('Navigate alone', () {
    testWidgets('centers one labeled chip and dispatches its action', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(subject(navigate: () => taps++));

      final chip = chipRect(tester, 0);
      final container = launcherRect(tester);
      expect(find.byType(DsGlassPill), findsOneWidget);
      // The launcher spans its host and centres inside it; a shrink-wrapped
      // row would make every centring assertion below trivially true.
      expect(
        container.width,
        tester.getSize(find.byType(Scaffold)).width,
      );
      expect(chip.width, lessThan(container.width / 2));
      expect(chip.center.dx, closeTo(container.center.dx, 0.01));
      expect(chip.height, greaterThanOrEqualTo(TapTargets.minimum));

      await tester.tap(find.text('Navigate'));
      expect(taps, 1);
    });

    testWidgets('wears the glass treatment: blurred backdrop, translucent '
        'fill and the floating-surface shadow', (tester) async {
      await tester.pumpWidget(subject());

      final pill = tester.widget<DsGlassPill>(find.byType(DsGlassPill));
      // No fill of its own — the shared translucent glass-chip fill shows the
      // blurred page through it. A solid fill here is what made the previous
      // launcher read as a grey slab rather than glass.
      expect(pill.fillColor, isNull);
      expect(pill.icon, LottiIcons.menu);

      final filter = tester.widget<BackdropFilter>(
        find
            .ancestor(
              of: find.byType(DsGlassPill),
              matching: find.byType(BackdropFilter),
            )
            .first,
      );
      expect(
        filter.filter.toString(),
        contains('${DesignSystemGlassStrip.blurSigma}'),
      );

      expect(
        tester
            .widgetList<DecoratedBox>(
              find.ancestor(
                of: find.byType(DsGlassPill),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => (box.decoration as BoxDecoration).boxShadow),
        contains(DsShadows.floatingSurface),
      );
    });
  });

  group('docked page action', () {
    testWidgets('rides the same row and centers the pair, not either chip', (
      tester,
    ) async {
      await tester.pumpWidget(subject(pageAction: action()));

      final navigate = chipRect(tester, 0);
      final create = chipRect(tester, 1);
      final container = launcherRect(tester);

      // One row: same top, same height, in reading order.
      expect(create.top, closeTo(navigate.top, 0.01));
      expect(create.height, closeTo(navigate.height, 0.01));
      expect(create.left, greaterThan(navigate.right));

      // The pair is centered as a group — neither chip owns the centre.
      expect(
        (navigate.left + create.right) / 2,
        closeTo(container.center.dx, 0.01),
      );
      expect(navigate.center.dx, lessThan(container.center.dx));
      expect(create.center.dx, greaterThan(container.center.dx));
    });

    testWidgets('separates the chips by the shared glass-row gap', (
      tester,
    ) async {
      await tester.pumpWidget(subject(pageAction: action()));

      final tokens = tester
          .element(find.byType(MobileNavigationLauncher))
          .designTokens;
      expect(chipGapOf(tester), tokens.spacing.step4);
      expect(
        chipRect(tester, 1).left - chipRect(tester, 0).right,
        closeTo(tokens.spacing.step4, 0.01),
      );
    });

    testWidgets('is the accent-filled peer of the translucent Navigate chip', (
      tester,
    ) async {
      await tester.pumpWidget(subject(pageAction: action()));

      final tokens = tester
          .element(find.byType(MobileNavigationLauncher))
          .designTokens;
      final create = tester.widget<DsGlassPill>(
        find.byType(DsGlassPill).at(1),
      );
      expect(create.fillColor, tokens.colors.interactive.enabled);
      expect(create.foregroundColor, tokens.colors.text.onInteractiveAlert);
      expect(create.icon, LottiIcons.add);
      expect(create.label, 'Add a task');
    });

    testWidgets('an opaque accent chip skips the backdrop blur it cannot show '
        'through', (tester) async {
      await tester.pumpWidget(subject(pageAction: action()));

      expect(
        find.ancestor(
          of: find.byType(DsGlassPill).at(1),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byType(DsGlassPill).at(0),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dispatches its own action, not the launcher sheet', (
      tester,
    ) async {
      var navigateTaps = 0;
      var actionTaps = 0;
      await tester.pumpWidget(
        subject(
          navigate: () => navigateTaps++,
          pageAction: action(onPressed: () => actionTaps++),
        ),
      );

      await tester.tap(find.text('Add a task'));
      expect(actionTaps, 1);
      expect(navigateTaps, 0);

      await tester.tap(find.text('Navigate'));
      expect(navigateTaps, 1);
      expect(actionTaps, 1);
    });

    testWidgets('announces its semantic label override', (tester) async {
      await tester.pumpWidget(
        subject(
          pageAction: action(semanticLabel: 'Add a task to this list'),
        ),
      );

      expect(find.bySemanticsLabel('Add a task to this list'), findsOneWidget);
    });

    testWidgets('leaving the page re-centers Navigate on its own', (
      tester,
    ) async {
      await tester.pumpWidget(subject(pageAction: action()));
      expect(find.byType(DsGlassPill), findsNWidgets(2));
      final docked = chipRect(tester, 0);

      await tester.pumpWidget(subject());
      expect(find.byType(DsGlassPill), findsOneWidget);

      final alone = chipRect(tester, 0);
      final container = launcherRect(tester);
      expect(alone.center.dx, closeTo(container.center.dx, 0.01));
      expect(alone.center.dx, greaterThan(docked.center.dx));
      expect(alone.height, closeTo(docked.height, 0.01));
    });

    testWidgets('docking an action does not change the launcher clearance', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      final alone = tester.getSize(find.byType(MobileNavigationLauncher));

      await tester.pumpWidget(subject(pageAction: action()));
      expect(
        tester.getSize(find.byType(MobileNavigationLauncher)).height,
        alone.height,
      );
    });
  });

  group('labelsFit', () {
    testWidgets('keeps both words when the row has room for them', (
      tester,
    ) async {
      // One pixel on the other side of the same threshold, so the pair of
      // tests brackets it rather than describing two unrelated widths.
      await pumpAtFitThreshold(tester, pageAction: action(), delta: 0);

      expect(
        MobileNavigationLauncher.labelsFit(
          tester.element(find.byType(MobileNavigationLauncher)),
          action(),
        ),
        isTrue,
      );
      expect(find.text('Navigate'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
      expect(find.byType(DsGlassRoundButton), findsNothing);
    });

    testWidgets('drops the action to its glyph rather than ellipsising two '
        'stubs when the words no longer fit', (tester) async {
      await pumpAtFitThreshold(
        tester,
        pageAction: action(),
        delta: -1,
        scaler: const TextScaler.linear(2),
      );

      expect(find.text('Add a task'), findsNothing);
      // Navigate keeps its word; the page action keeps its name for
      // assistive tech and its place on the row.
      expect(find.text('Navigate'), findsOneWidget);
      expect(find.bySemanticsLabel('Add a task'), findsOneWidget);

      final round = tester.widget<DsGlassRoundButton>(
        find.byType(DsGlassRoundButton),
      );
      final tokens = tester
          .element(find.byType(MobileNavigationLauncher))
          .designTokens;
      expect(round.icon, LottiIcons.add);
      expect(round.backgroundColor, tokens.colors.interactive.enabled);
      expect(round.iconColor, tokens.colors.text.onInteractiveAlert);
    });

    testWidgets('the collapsed glyph keeps the row on one baseline', (
      tester,
    ) async {
      await pumpAtFitThreshold(
        tester,
        pageAction: action(),
        delta: -1,
        scaler: const TextScaler.linear(2),
      );

      final navigate = chipRect(tester, 0);
      final glyph = tester.getRect(find.byType(DsGlassRoundButton));
      expect(glyph.height, closeTo(navigate.height, 0.01));
      expect(glyph.center.dy, closeTo(navigate.center.dy, 0.01));
      expect(
        (navigate.left + glyph.right) / 2,
        closeTo(launcherRect(tester).center.dx, 0.01),
      );
    });

    testWidgets('a longer action label collapses the row sooner', (
      tester,
    ) async {
      await tester.pumpWidget(subject(pageAction: action()));
      final context = tester.element(find.byType(MobileNavigationLauncher));

      expect(
        MobileNavigationLauncher.labelsFit(context, action()),
        isTrue,
      );
      expect(
        MobileNavigationLauncher.labelsFit(
          context,
          action(label: 'Add a task to the currently filtered list'),
        ),
        isFalse,
      );
    });

    testWidgets('the collapsed glyph still dispatches the action', (
      tester,
    ) async {
      var taps = 0;
      await pumpAtFitThreshold(
        tester,
        pageAction: action(onPressed: () => taps++),
        delta: -1,
        scaler: const TextScaler.linear(2),
      );

      await tester.tap(find.byType(DsGlassRoundButton));
      expect(taps, 1);
    });
  });

  group('a glyph-only page action', () {
    testWidgets('is round at a width where a worded action still fits', (
      tester,
    ) async {
      // Same viewport that keeps the worded pair labeled, so the difference
      // is the page's own decision and not the fit rule.
      await tester.pumpWidget(subject(pageAction: action()));
      expect(find.byType(DsGlassPill), findsNWidgets(2));

      await tester.pumpWidget(subject(pageAction: glyphAction()));
      expect(find.byType(DsGlassPill), findsOneWidget);
      expect(find.byType(DsGlassRoundButton), findsOneWidget);
      expect(find.text('Add a habit'), findsNothing);
      expect(find.text('Navigate'), findsOneWidget);
    });

    testWidgets('keeps the row on one baseline and centres the pair', (
      tester,
    ) async {
      await tester.pumpWidget(subject(pageAction: glyphAction()));

      final navigate = chipRect(tester, 0);
      final glyph = tester.getRect(find.byType(DsGlassRoundButton));
      expect(glyph.height, closeTo(navigate.height, 0.01));
      expect(glyph.width, closeTo(navigate.height, 0.01));
      expect(glyph.center.dy, closeTo(navigate.center.dy, 0.01));
      expect(glyph.left - navigate.right, closeTo(chipGapOf(tester), 0.01));
      expect(
        (navigate.left + glyph.right) / 2,
        closeTo(launcherRect(tester).center.dx, 0.01),
      );
    });

    testWidgets('wears the accent and announces its name', (tester) async {
      await tester.pumpWidget(subject(pageAction: glyphAction()));

      final tokens = tester
          .element(find.byType(MobileNavigationLauncher))
          .designTokens;
      final round = tester.widget<DsGlassRoundButton>(
        find.byType(DsGlassRoundButton),
      );
      expect(round.backgroundColor, tokens.colors.interactive.enabled);
      expect(round.iconColor, tokens.colors.text.onInteractiveAlert);
      expect(round.semanticLabel, 'Add a habit');
      expect(find.bySemanticsLabel('Add a habit'), findsOneWidget);
    });

    testWidgets('dispatches its action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        subject(pageAction: glyphAction(onPressed: () => taps++)),
      );

      await tester.tap(find.byType(DsGlassRoundButton));
      expect(taps, 1);
    });

    testWidgets('does not change the launcher clearance either', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      final alone = tester.getSize(find.byType(MobileNavigationLauncher));

      await tester.pumpWidget(subject(pageAction: glyphAction()));
      expect(
        tester.getSize(find.byType(MobileNavigationLauncher)).height,
        alone.height,
      );
    });

    testWidgets('stays round however long its accessible name is — a glyph '
        'action never consults the fit rule', (tester) async {
      await tester.pumpWidget(
        subject(
          pageAction: glyphAction(
            label: 'Add an entry to the currently filtered logbook feed',
          ),
        ),
      );

      expect(find.byType(DsGlassRoundButton), findsOneWidget);
      expect(find.byType(DsGlassPill), findsOneWidget);
    });
  });

  group('clearance', () {
    for (final scaler in const [
      TextScaler.linear(1.3),
      TextScaler.linear(2),
      TextScaler.linear(3),
      _NonlinearTextScaler(),
    ]) {
      for (final docked in const [false, true]) {
        testWidgets(
          'launcher clearance matches large text at $scaler '
          '(docked action: $docked)',
          (tester) async {
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
          },
        );
      }
    }

    testWidgets('the safe-area inset only ever adds clearance', (tester) async {
      await tester.pumpWidget(
        subject(
          mediaQueryData: const MediaQueryData(size: Size(430, 932)),
        ),
      );
      final withoutInset = tester.getSize(
        find.byType(MobileNavigationLauncher),
      );
      final tokens = tester
          .element(find.byType(MobileNavigationLauncher))
          .designTokens;

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

  group('dark theme', () {
    testWidgets('resolves the accent and its ink from the dark token set', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(pageAction: action(), theme: DesignSystemTheme.dark()),
      );

      final tokens = tester
          .element(find.byType(MobileNavigationLauncher))
          .designTokens;
      final create = tester.widget<DsGlassPill>(
        find.byType(DsGlassPill).at(1),
      );
      expect(create.fillColor, tokens.colors.interactive.enabled);
      expect(create.foregroundColor, tokens.colors.text.onInteractiveAlert);
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
