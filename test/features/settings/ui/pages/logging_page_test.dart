import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockJournalDb = MockJournalDb();

  group('LoggingPage Tests - ', () {
    late MockLoggingDb mockLoggingDb;

    setUp(() {
      mockLoggingDb = MockLoggingDb();
      getIt
        ..registerSingleton<LoggingDb>(mockLoggingDb)
        ..registerSingleton<JournalDb>(mockJournalDb);
    });

    setUpAll(() {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });

    tearDown(getIt.reset);

    testWidgets('search triggers paginated search methods', (tester) async {
      final testLogEntries = List.generate(
        10,
        (index) => LogEntry(
          id: uuid.v1(),
          createdAt: DateTime.now().toIso8601String(),
          domain: 'domain$index',
          type: 'type',
          level: 'INFO',
          message: 'message$index',
        ),
      );

      // Mock initial logs
      when(
        () => mockLoggingDb.watchLogEntries(),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          testLogEntries.take(5).toList(),
        ]),
      );

      // Mock search count
      when(
        () => mockLoggingDb.getSearchLogEntriesCount(any()),
      ).thenAnswer((_) async => 10);

      // Mock paginated search results
      when(
        () => mockLoggingDb.watchSearchLogEntriesPaginated(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          testLogEntries.take(5).toList(),
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const LoggingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'test');
      await tester.pumpAndSettle();

      // Verify the paginated search methods were called
      verify(() => mockLoggingDb.getSearchLogEntriesCount(any())).called(1);
      verify(() => mockLoggingDb.watchSearchLogEntriesPaginated(
            any(),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).called(1);
    });

    testWidgets('pagination loads different pages correctly', (tester) async {
      // Create 100 test entries to simulate large dataset
      final testLogEntries = List.generate(
        100,
        (index) => LogEntry(
          id: 'test_$index',
          createdAt:
              DateTime.now().add(Duration(seconds: index)).toIso8601String(),
          domain: 'domain$index',
          type: 'type',
          level: 'INFO',
          message: 'message$index',
        ),
      );

      // Mock initial logs
      when(
        () => mockLoggingDb.watchLogEntries(),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          testLogEntries.take(50).toList(),
        ]),
      );

      // Mock search count for large dataset
      when(
        () => mockLoggingDb.getSearchLogEntriesCount(any()),
      ).thenAnswer((_) async => 100);

      // Mock first page (50 items)
      when(
        () => mockLoggingDb.watchSearchLogEntriesPaginated(
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          testLogEntries.take(50).toList(),
        ]),
      );

      // Mock second page (50 items)
      when(
        () => mockLoggingDb.watchSearchLogEntriesPaginated(
          any(),
          offset: 50,
        ),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          testLogEntries.skip(50).take(50).toList(),
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const LoggingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'test');
      await tester.pumpAndSettle();

      // Verify first page is loaded
      verify(() => mockLoggingDb.watchSearchLogEntriesPaginated(
            any(),
          )).called(1);

      // Verify total count is correct
      verify(() => mockLoggingDb.getSearchLogEntriesCount(any())).called(1);
    });

    testWidgets('pagination controls memory usage by limiting results',
        (tester) async {
      // Create large dataset to test memory control
      final testLogEntries = List.generate(
        1000,
        (index) => LogEntry(
          id: 'large_test_$index',
          createdAt:
              DateTime.now().add(Duration(seconds: index)).toIso8601String(),
          domain: 'domain$index',
          type: 'type',
          level: 'INFO',
          message: 'large_message_$index',
        ),
      );

      // Mock initial logs
      when(
        () => mockLoggingDb.watchLogEntries(),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          testLogEntries.take(50).toList(),
        ]),
      );

      // Mock search count for large dataset
      when(
        () => mockLoggingDb.getSearchLogEntriesCount(any()),
      ).thenAnswer((_) async => 1000);

      // Mock paginated search - only return 50 items at a time
      when(
        () => mockLoggingDb.watchSearchLogEntriesPaginated(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (invocation) {
          final limit = invocation.namedArguments[const Symbol('limit')] as int;
          final offset =
              invocation.namedArguments[const Symbol('offset')] as int;

          // Ensure only limited results are returned (memory control)
          expect(limit, lessThanOrEqualTo(50));

          return Stream<List<LogEntry>>.fromIterable([
            testLogEntries.skip(offset).take(limit).toList(),
          ]);
        },
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const LoggingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'large');
      await tester.pumpAndSettle();

      // Verify pagination is used (not loading all 1000 items at once)
      verify(() => mockLoggingDb.watchSearchLogEntriesPaginated(
            any(),
          )).called(1);

      // Verify total count is retrieved separately (for pagination info)
      verify(() => mockLoggingDb.getSearchLogEntriesCount(any())).called(1);
    });

    testWidgets('search handles errors gracefully', (tester) async {
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};

      try {
        // Mock initial logs
        when(
          () => mockLoggingDb.watchLogEntries(),
        ).thenAnswer(
          (_) => Stream<List<LogEntry>>.fromIterable([[]]),
        );

        // Mock search count throwing error
        when(
          () => mockLoggingDb.getSearchLogEntriesCount(any()),
        ).thenThrow(Exception('Database error'));

        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const LoggingPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter search query
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'test');
        await tester.pumpAndSettle();

        // Verify error handling - should not crash and should show error message
        expect(find.text('Search failed. Please try again.'), findsOneWidget);
      } finally {
        debugPrint = previousDebugPrint;
      }
    });

    group('SettingsPageHeader Integration', () {
      testWidgets('displays SettingsPageHeader with correct title',
          (tester) async {
        // Mock initial logs
        when(() => mockLoggingDb.watchLogEntries()).thenAnswer(
          (_) => Stream<List<LogEntry>>.fromIterable([[]]),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const LoggingPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should have SettingsPageHeader
        expect(find.byType(SettingsPageHeader), findsOneWidget);
      });

      testWidgets('shows back button in SettingsPageHeader', (tester) async {
        // Mock initial logs
        when(() => mockLoggingDb.watchLogEntries()).thenAnswer(
          (_) => Stream<List<LogEntry>>.fromIterable([[]]),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const LoggingPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should have back button (chevron_left icon)
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      });

      testWidgets('uses CustomScrollView with slivers', (tester) async {
        // Mock initial logs
        when(() => mockLoggingDb.watchLogEntries()).thenAnswer(
          (_) => Stream<List<LogEntry>>.fromIterable([[]]),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const LoggingPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should use CustomScrollView for sliver structure
        expect(find.byType(CustomScrollView), findsOneWidget);

        // Should have SettingsPageHeader as a sliver
        expect(find.byType(SettingsPageHeader), findsOneWidget);
      });
    });
  });
}
