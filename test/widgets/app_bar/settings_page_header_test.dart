import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

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
  // The header reads context.designTokens (for the bottom corner radius),
  // so whatever theme the test supplies must carry the DsTokens extension.
  final baseTheme = theme ?? ThemeData.light();
  final themedWithTokens = baseTheme.copyWith(
    extensions: [
      ...baseTheme.extensions.values,
      if (baseTheme.brightness == Brightness.dark)
        dsTokensDark
      else
        dsTokensLight,
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: themedWithTokens,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPageHeader', () {
    testWidgets('renders title, subtitle, and back button', (tester) async {
      await _pumpHeader(tester, showBackButton: true);

      expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
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

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(
        find.textContaining('Extremely Long Matrix Sync Maintenance Header'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
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
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
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

    testWidgets('scrolling collapses header without errors', (tester) async {
      await _pumpHeader(tester, contentHeight: 1200);

      // Title and subtitle initially visible
      expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
      expect(
        find.text('Run Matrix maintenance tasks and recovery tools'),
        findsOneWidget,
      );

      // Scroll repeatedly to ensure full collapse
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
      }

      // Still renders without throwing and keeps title visible.
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

    testWidgets('uses FittedBox at >= 1.5 text scale', (tester) async {
      await _pumpHeader(
        tester,
        title: 'Scale Threshold',
        subtitle: 'Subtitle',
        scale: 1.2,
      );
      expect(find.byType(FittedBox), findsNothing);

      await _pumpHeader(
        tester,
        title: 'Scale Threshold',
        subtitle: 'Subtitle',
        scale: 1.5,
      );
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('title color follows theme primary', (tester) async {
      AnimatedDefaultTextStyle titleStyle() =>
          tester.widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: find.text('Themed Title'),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          );

      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await _pumpHeader(
          tester,
          title: 'Themed Title',
          subtitle: 'Subtitle',
          theme: theme,
          contentHeight: 200,
        );
        await tester.pumpAndSettle(); // let the text style animation finish
        expect(titleStyle().style.color, equals(theme.colorScheme.primary));
      }
    });
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
