import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_utils/settings_header_harness.dart';
import '../../widget_test_utils.dart';

/// Pumps a [SettingsPageHeader] inside the standard scroll-view scaffolding,
/// parameterised over the knobs the individual tests vary.
Future<void> _pumpHeader(
  WidgetTester tester, {
  String title = 'Matrix Sync Maintenance',
  String subtitle = 'Run Matrix maintenance tasks and recovery tools',
  bool showBackButton = false,
  bool pinned = true,
  PreferredSizeWidget? bottom,
  double scale = 1,
  double width = 390,
  double height = 844,
  double topPadding = 47,
  double contentHeight = 400,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: LegacyMaterialBridge.builder,
      // The header reads context.designTokens (for its surface and title
      // colours); the central helper attaches the brightness-matched
      // DsTokens extension to whatever theme the test supplies.
      theme: resolveTestTheme(theme ?? ThemeData.light()),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          padding: EdgeInsets.only(top: topPadding),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SettingsPageHeader(
                title: title,
                subtitle: subtitle,
                showBackButton: showBackButton,
                pinned: pinned,
                bottom: bottom,
              ),
              SliverToBoxAdapter(child: SizedBox(height: contentHeight)),
            ],
          ),
        ),
      ),
    ),
  );
  // First frame plus one bounded second to elapse the BackWidget's 1s
  // flutter_animate fade-in (which would otherwise leave a pending timer);
  // scroll-gesture tests settle explicitly after dragging.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Pumps the header under a `MaterialApp` whose theme mode follows [mode],
/// beneath an ancestor that reads the tokens for its own colour — the shape
/// of `SliverBoxAdapterPage`, whose scaffold colour makes it rebuild in the
/// very frame the theme changes and hand the sliver a fresh delegate.
///
/// [title] is a parameter so the header cannot be const-canonicalised: a
/// const `SettingsPageHeader` would be reused across the ancestor's rebuilds
/// and the sliver would never receive a new delegate, which is the half of
/// the trap this host exists to reproduce.
Future<void> _pumpThemeSwitchingHeader(
  WidgetTester tester, {
  required ValueNotifier<ThemeMode> mode,
  required String title,
}) async {
  await tester.pumpWidget(
    ValueListenableBuilder<ThemeMode>(
      valueListenable: mode,
      builder: (context, themeMode, _) => MaterialApp(
        builder: LegacyMaterialBridge.builder,
        theme: resolveTestTheme(ThemeData.light()),
        darkTheme: resolveTestTheme(ThemeData.dark()),
        themeMode: themeMode,
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.designTokens.colors.background.level01,
            body: CustomScrollView(
              slivers: [
                SettingsPageHeader(title: title),
                const SliverToBoxAdapter(child: SizedBox(height: 400)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPageHeader', () {
    testWidgets('renders title, subtitle, and back button', (tester) async {
      await _pumpHeader(tester, showBackButton: true);

      expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
      expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
    });

    testWidgets('accommodates large text scaling without overflow', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        title: 'Extremely Long Matrix Sync Maintenance Header Variant',
        subtitle:
            'Detailed description that wraps across multiple lines for accessibility validation.',
        showBackButton: true,
        scale: 1.6,
        contentHeight: 800,
      );

      expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
      expect(
        find.textContaining('Extremely Long Matrix Sync Maintenance Header'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
    });

    testWidgets('renders across common text scales (1.0, 1.2, 2.0)', (
      tester,
    ) async {
      for (final scale in <double>[1, 1.2, 2]) {
        await _pumpHeader(
          tester,
          title: 'Sync Stats',
          subtitle: 'Inspect sync pipeline metrics',
          showBackButton: true,
          scale: scale,
          contentHeight: 300,
        );
        expect(find.text('Sync Stats'), findsOneWidget);
        expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('lays out on varied screen widths without errors', (
      tester,
    ) async {
      // Representative breakpoints used by the header.
      for (final w in <double>[360, 420, 540, 720, 992, 1200, 1600]) {
        await _pumpHeader(
          tester,
          width: w,
          height: 900,
          topPadding: 24,
          contentHeight: 300,
        );
        expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('pinned header stays fixed (title never scrolls away)', (
      tester,
    ) async {
      await _pumpHeader(tester, contentHeight: 1200);

      expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
      expect(
        find.text('Run Matrix maintenance tasks and recovery tools'),
        findsOneWidget,
      );

      // The header is fixed (no collapse): repeated scrolling keeps the
      // title pinned and unchanged.
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with bottom widget pinned on scroll', (tester) async {
      const bottom = _TestBottomBar(label: 'SEGMENTS', height: 120);

      await _pumpHeader(
        tester,
        title: 'Header with Bottom',
        subtitle: 'Subtitle',
        showBackButton: true,
        bottom: bottom,
        contentHeight: 1000,
      );
      expect(find.text('SEGMENTS'), findsOneWidget);

      // Scroll; bottom should remain visible because header is pinned.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('SEGMENTS'), findsOneWidget);
    });

    testWidgets('handles empty subtitle', (tester) async {
      await _pumpHeader(
        tester,
        title: 'Title Only',
        subtitle: '',
        contentHeight: 200,
      );
      expect(find.text('Title Only'), findsOneWidget);
      // No subtitle is rendered when empty.
      expect(find.text(''), findsNothing);
    });

    testWidgets('unpinned header scrolls offscreen', (tester) async {
      await _pumpHeader(
        tester,
        title: 'Unpinned',
        subtitle: 'Goes away',
        pinned: false,
        contentHeight: 1200,
      );
      expect(find.text('Unpinned'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      // Title is scrolled offscreen when not pinned.
      expect(find.text('Unpinned'), findsNothing);
    });

    testWidgets('never wraps the title in a FittedBox (it grows instead)', (
      tester,
    ) async {
      for (final scale in <double>[1, 1.5, 2]) {
        await _pumpHeader(
          tester,
          title: 'Scale Threshold',
          subtitle: 'Subtitle',
          scale: scale,
        );
        // The fixed header grows its extent for large text rather than
        // squashing the title with a FittedBox.
        expect(find.byType(FittedBox), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('title uses the high-emphasis token colour, not the accent', (
      tester,
    ) async {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await _pumpHeader(
          tester,
          title: 'Themed Title',
          subtitle: 'Subtitle',
          theme: theme,
          contentHeight: 200,
        );
        final tokens = tester.element(find.text('Themed Title')).designTokens;
        final titleText = tester.widget<Text>(find.text('Themed Title'));
        expect(titleText.style?.color, tokens.colors.text.highEmphasis);
        expect(
          titleText.style?.color,
          isNot(tokens.colors.interactive.enabled),
        );
      }
    });

    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      testWidgets(
        'paints the level-01 background under a decorative hairline '
        '(${theme.brightness.name})',
        (tester) async {
          await _pumpHeader(tester, theme: theme, contentHeight: 200);

          final tokens = tester
              .element(find.byType(SettingsPageHeader))
              .designTokens;
          final surface = settingsHeaderSurface(tester);
          expect(surface.color, tokens.colors.background.level01);
          expect(
            surface.border?.bottom.color,
            tokens.colors.decorative.level01,
          );
        },
      );
    }

    for (final (from, to) in [
      (ThemeMode.light, ThemeMode.dark),
      (ThemeMode.dark, ThemeMode.light),
    ]) {
      testWidgets(
        'surface follows a theme switch while a token-reading ancestor '
        'rebuilds in the same frame (${from.name} to ${to.name})',
        (tester) async {
          final mode = ValueNotifier<ThemeMode>(from);
          addTearDown(mode.dispose);
          await _pumpThemeSwitchingHeader(
            tester,
            mode: mode,
            title: 'Theming',
          );

          mode.value = to;
          await tester.pumpAndSettle();

          final dark = to == ThemeMode.dark;
          final expected = dark ? dsTokensDark : dsTokensLight;
          expect(
            Theme.of(
              tester.element(find.byType(SettingsPageHeader)),
            ).brightness,
            dark ? Brightness.dark : Brightness.light,
            reason:
                'the switch itself must have landed before the surface '
                'is judged',
          );
          final surface = settingsHeaderSurface(tester);
          expect(surface.color, expected.colors.background.level01);
          expect(
            surface.border?.bottom.color,
            expected.colors.decorative.level01,
          );
        },
      );
    }
  });
}

class _TestBottomBar extends StatelessWidget implements PreferredSizeWidget {
  const _TestBottomBar({required this.label, this.height = 100});

  final String label;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(label),
    );
  }
}
