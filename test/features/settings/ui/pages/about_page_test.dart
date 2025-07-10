import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../logic/health_import_test.dart';
import '../../../../mocks/mocks.dart' hide MockJournalDb;
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockJournalDb = MockJournalDb();
  final mockUpdateNotifications = MockUpdateNotifications();

  group('SettingsPage Widget Tests - ', () {
    setUpAll(() {
      when(mockJournalDb.getJournalCount).thenAnswer((_) async => n);

      when(mockJournalDb.getCountImportFlagEntries).thenAnswer((_) async => 0);

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
        () => mockJournalDb.getTasksCount(statuses: any(named: 'statuses')),
      ).thenAnswer((_) async => 10);
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
      expect(find.text('111'), findsOneWidget);
    });
  });
}
