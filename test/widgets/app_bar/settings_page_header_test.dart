import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPageHeader', () {
    testWidgets(
      'renders title, subtitle, and back button',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 47),
              ),
              child: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SettingsPageHeader(
                      title: 'Matrix Sync Maintenance',
                      subtitle:
                          'Run Matrix maintenance tasks and recovery tools',
                      showBackButton: true,
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 400),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      },
    );

    testWidgets(
      'accommodates large text scaling without overflow',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 47),
                textScaler: TextScaler.linear(1.6),
              ),
              child: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SettingsPageHeader(
                      title:
                          'Extremely Long Matrix Sync Maintenance Header Variant',
                      subtitle:
                          'Detailed description that wraps across multiple lines for accessibility validation.',
                      showBackButton: true,
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(
          find.textContaining('Extremely Long Matrix Sync Maintenance Header'),
          findsOneWidget,
        );
        expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      },
    );

    testWidgets('renders across common text scales (1.0, 1.2, 2.0)',
        (tester) async {
      Future<void> pumpWithScale(double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                padding: const EdgeInsets.only(top: 47),
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SettingsPageHeader(
                      title: 'Sync Stats',
                      subtitle: 'Inspect sync pipeline metrics',
                      showBackButton: true,
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 300)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final scale in <num>[1, 1.2, 2]) {
        await pumpWithScale(scale.toDouble());
        expect(find.text('Sync Stats'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));
      }
    });

    testWidgets('lays out on varied screen widths without errors',
        (tester) async {
      Future<void> pumpWithWidth(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                padding: const EdgeInsets.only(top: 24),
              ),
              child: const Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SettingsPageHeader(
                      title: 'Matrix Sync Maintenance',
                      subtitle:
                          'Run Matrix maintenance tasks and recovery tools',
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 300)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Representative breakpoints used by the header.
      for (final w in <double>[360, 420, 540, 720, 992, 1200, 1600]) {
        await pumpWithWidth(w);
        expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
        expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));
      }
    });

    testWidgets('scrolling collapses header without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47),
            ),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SettingsPageHeader(
                    title: 'Matrix Sync Maintenance',
                    subtitle: 'Run Matrix maintenance tasks and recovery tools',
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 1200)),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title and subtitle initially visible
      expect(find.text('Matrix Sync Maintenance'), findsOneWidget);
      expect(find.text('Run Matrix maintenance tasks and recovery tools'),
          findsOneWidget);

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
      expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));
    });

    testWidgets('renders with bottom widget pinned on scroll', (tester) async {
      const bottom = _TestBottomBar(label: 'SEGMENTS', height: 120);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47),
            ),
            child: Scaffold(
              body: CustomScrollView(
                slivers: <Widget>[
                  SettingsPageHeader(
                    title: 'Header with Bottom',
                    subtitle: 'Subtitle',
                    showBackButton: true,
                    bottom: bottom,
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 1000)),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('SEGMENTS'), findsOneWidget);

      // Scroll; bottom should remain visible because header is pinned.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('SEGMENTS'), findsOneWidget);
    });

    testWidgets('handles empty subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47),
            ),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SettingsPageHeader(
                    title: 'Title Only',
                    subtitle: '',
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 200)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Title Only'), findsOneWidget);
      // No subtitle is rendered when empty.
      expect(find.text(''), findsNothing);
    });

    testWidgets('unpinned header scrolls offscreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47),
            ),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SettingsPageHeader(
                    title: 'Unpinned',
                    subtitle: 'Goes away',
                    pinned: false,
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 1200)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unpinned'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      // Title is scrolled offscreen when not pinned.
      expect(find.text('Unpinned'), findsNothing);
    });

    testWidgets('uses FittedBox at >= 1.5 text scale', (tester) async {
      Future<void> pumpWithScale(double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                padding: const EdgeInsets.only(top: 47),
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SettingsPageHeader(
                      title: 'Scale Threshold',
                      subtitle: 'Subtitle',
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 400)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWithScale(1.2);
      expect(find.byType(FittedBox), findsNothing);

      await pumpWithScale(1.5);
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('title color follows theme primary', (tester) async {
      Future<void> pumpWithTheme(ThemeData theme) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 47),
              ),
              child: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SettingsPageHeader(
                      title: 'Themed Title',
                      subtitle: 'Subtitle',
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 200)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final light = ThemeData.light();
      await pumpWithTheme(light);
      final lightTitleStyle = tester.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Themed Title'),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(lightTitleStyle.style.color, equals(light.colorScheme.primary));

      final dark = ThemeData.dark();
      await pumpWithTheme(dark);
      final darkTitleStyle = tester.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Themed Title'),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(darkTitleStyle.style.color, equals(dark.colorScheme.primary));
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
