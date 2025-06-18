import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/advanced/logging_page.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockJournalDb = MockJournalDb();

  group('LoggingPage Tests - ', () {
    setUp(() {
      getIt
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<JournalDb>(mockJournalDb);
    });

    setUpAll(() {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });

    tearDown(getIt.reset);

    testWidgets('empty logging page is displayed', (tester) async {
      when(
        () => getIt<LoggingDb>().watchLogEntries(),
      ).thenAnswer(
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

      expect(find.text('Logs'), findsOneWidget);
    });

    testWidgets('log line is displayed', (tester) async {
      final testLogEntry = LogEntry(
        id: uuid.v1(),
        createdAt: DateTime.now().toIso8601String(),
        domain: 'domain',
        type: 'type',
        level: 'level',
        message: 'message',
      );

      when(
        () => getIt<LoggingDb>().watchLogEntries(),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          [testLogEntry],
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

      // finds appbar header
      expect(find.text('Logs'), findsOneWidget);

      // finds log line elements
      expect(
          find.text(testLogEntry.createdAt.substring(0, 23)), findsOneWidget);
      expect(find.text('${testLogEntry.domain} ${testLogEntry.subDomain}'),
          findsOneWidget);
      expect(find.text(testLogEntry.message), findsOneWidget);
    });

    testWidgets('log details page is displayed', (tester) async {
      final testLogEntry = LogEntry(
        id: uuid.v1(),
        createdAt: DateTime.now().toIso8601String(),
        domain: 'domain',
        subDomain: 'subDomain',
        type: 'type',
        level: 'INFO',
        message: 'message',
      );

      when(
        () => getIt<LoggingDb>().watchLogEntryById(testLogEntry.id),
      ).thenAnswer(
        (_) => Stream<List<LogEntry>>.fromIterable([
          [testLogEntry],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: LogDetailPage(
              logEntryId: testLogEntry.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // finds appbar header
      expect(find.text('Logs'), findsOneWidget);

      // finds log elements
      expect(
        find.text(testLogEntry.createdAt.substring(0, 23)),
        findsOneWidget,
      );
      expect(find.text(testLogEntry.level), findsOneWidget);
      expect(find.text(testLogEntry.domain), findsOneWidget);
      expect(find.text('${testLogEntry.subDomain}'), findsOneWidget);
      expect(find.text('Message:'), findsOneWidget);
    });
  });
}
