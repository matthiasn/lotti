import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/main.dart' as app;

void main() {
  app.main();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group(
    'end-to-end test',
    () {
      testWidgets(
        'tap settings bottom nav icon, verify settings elements',
        (WidgetTester tester) async {
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1), () {});

          expect(find.text('Search...'), findsWidgets);

          final Finder settings = find.byIcon(Icons.settings_outlined);
          await tester.tap(settings);
          await tester.pumpAndSettle();

          expect(find.text('Tags'), findsOneWidget);
          expect(find.text('Health Import'), findsOneWidget);
          expect(find.text('Synchronization'), findsOneWidget);
          expect(find.text('Measurables'), findsOneWidget);
          expect(find.text('Sync Outbox'), findsOneWidget);
          expect(find.text('Logs'), findsOneWidget);
          expect(find.text('Conflicts'), findsOneWidget);
          expect(find.text('Flags'), findsOneWidget);
          expect(find.text('Maintenance'), findsOneWidget);

          await Future.delayed(const Duration(seconds: 1), () {});
        },
      );
    },
  );
}
