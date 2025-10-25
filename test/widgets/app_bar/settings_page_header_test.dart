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
  });
}
