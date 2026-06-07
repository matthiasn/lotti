import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

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

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();

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

  group('AboutBody Daily OS personalization', () {
    late TestGetItMocks testMocks;

    setUp(() async {
      testMocks = await setUpTestGetIt();
      when(testMocks.journalDb.getJournalCount).thenAnswer((_) async => n);
      when(
        testMocks.journalDb.getCountImportFlagEntries,
      ).thenAnswer((_) async => 0);
      when(
        () => testMocks.journalDb.linksForEntryIds(any()),
      ).thenAnswer((_) async => <EntryLink>[]);
      when(
        () => testMocks.journalDb.getTasksCount(
          statuses: any(named: 'statuses'),
        ),
      ).thenAnswer((_) async => 10);
    });

    tearDown(tearDownTestGetIt);

    testWidgets('starts with an empty Daily OS greeting name', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const AboutBody(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('daily_os_user_name_field')),
      );

      expect(nameField.controller?.text, isEmpty);
      expect(nameField.decoration?.hintText, isNull);
    });

    testWidgets('persists the Daily OS greeting name', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const AboutBody(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('daily_os_user_name_field')),
        'Daily OS User',
      );

      verify(
        () => testMocks.settingsDb.saveSettingsItem(
          dailyOsUserNameSettingsKey,
          'Daily OS User',
        ),
      ).called(1);
    });
  });
}
