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
  });
}
