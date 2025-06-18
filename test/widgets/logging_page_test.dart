import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/pages/settings/advanced/logging_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MockLoggingDb extends Mock implements LoggingDb {}

class MockVisibilityDetector extends StatelessWidget {
  const MockVisibilityDetector({
    required this.child,
    required Key key,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

void main() {
  late MockLoggingDb mockLoggingDb;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    mockLoggingDb = MockLoggingDb();
    getIt.registerSingleton<LoggingDb>(mockLoggingDb);
    when(() => mockLoggingDb.watchLogEntries()).thenAnswer(
      (_) => Stream.value([
        LogEntry(
          id: '1',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'test',
          subDomain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Test log message',
          data: '{"key": "value"}',
        ),
      ]),
    );
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(getIt.reset);

  testWidgets('LoggingPage displays logs correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoggingPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify search bar is present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    // Verify log entry is displayed
    expect(find.text('Test log message'), findsOneWidget);
    expect(find.text('test test'), findsOneWidget);
  });

  testWidgets('LoggingPage search functionality works',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoggingPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Enter search text
    await tester.enterText(find.byType(TextField), 'Test');
    await tester.pump();

    // Verify filtered results
    expect(find.text('Test log message'), findsOneWidget);

    // Enter non-matching search text
    await tester.enterText(find.byType(TextField), 'NonMatching');
    await tester.pump();

    // Verify no results found
    expect(find.text('No logs match your search criteria.'), findsOneWidget);
  });

  testWidgets('LoggingPage handles empty logs', (WidgetTester tester) async {
    when(() => mockLoggingDb.watchLogEntries()).thenAnswer(
      (_) => Stream.value([]),
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoggingPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty state message
    expect(find.text('No logs match your search criteria.'), findsOneWidget);
  });

  testWidgets('LoggingPage handles null values gracefully',
      (WidgetTester tester) async {
    when(() => mockLoggingDb.watchLogEntries()).thenAnswer(
      (_) => Stream.value([
        LogEntry(
          id: '1',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Test log message',
        ),
      ]),
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoggingPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the widget doesn't crash with null values
    expect(find.byType(LoggingPage), findsOneWidget);
    expect(find.text('Test log message'), findsOneWidget);
  });
}
