import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/advanced/about_page.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockJournalDb = MockJournalDb();
  final mockUpdateNotifications = MockUpdateNotifications();

  group('SettingsPage Widget Tests - ', () {
    setUpAll(() {
      when(mockJournalDb.watchJournalCount)
          .thenAnswer((_) => Stream<int>.fromIterable([n]));

      when(mockJournalDb.watchCountImportFlagEntries)
          .thenAnswer((_) => Stream<int>.fromIterable([0]));

      when(
        () => mockJournalDb.sortedJournalEntities(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => <JournalEntity>[]);

      when(
        () => mockJournalDb.linksForEntryIds(any()),
      ).thenAnswer((_) async => <EntryLink>[]);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<JournalDb>(mockJournalDb);

      when(
        () => mockJournalDb.watchTaskCount(any()),
      ).thenAnswer(
        (_) => Stream<int>.fromIterable([10]),
      );
    });
    tearDown(getIt.reset);

    testWidgets('main page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const AboutPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('About Lotti'), findsOneWidget);
      expect(find.text('Entries: 111, '), findsOneWidget);
    });
  });
}
