import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/pages/settings/advanced_settings_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';

class MockMessages extends Mock implements AppLocalizations {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockSyncDatabase = MockSyncDatabase();
  final mockJournalDb = mockJournalDbWithSyncFlag(enabled: true);

  group('SettingsPage Widget Tests - ', () {
    setUp(() {
      when(mockSyncDatabase.watchOutboxCount)
          .thenAnswer((_) => Stream<int>.fromIterable([n]));

      getIt
        ..registerSingleton<SyncDatabase>(mockSyncDatabase)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<JournalDb>(mockJournalDb);
    });
    tearDown(getIt.reset);

    testWidgets('main page is displayed', (tester) async {
      final mockMessages = MockMessages();
      when(() => mockMessages.settingsAdvancedTitle)
          .thenReturn('Advanced Settings');
      when(() => mockMessages.settingsSyncOutboxTitle)
          .thenReturn('Sync Outbox');
      when(() => mockMessages.settingsConflictsTitle)
          .thenReturn('Sync Conflicts');
      when(() => mockMessages.settingsLogsTitle).thenReturn('Logs');
      when(() => mockMessages.settingsMaintenanceTitle)
          .thenReturn('Maintenance');

      getIt.registerSingleton<AppLocalizations>(mockMessages);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1200,
                maxWidth: 1000,
              ),
              child: const AdvancedSettingsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sync Outbox'), findsOneWidget);
      expect(find.text('Sync Conflicts'), findsOneWidget);
      expect(find.text('Logs'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);

      expect(find.byIcon(MdiIcons.mailboxOutline), findsOneWidget);

      // Check outbox badge count
      expect(find.text('$n'), findsOneWidget);

      verify(mockSyncDatabase.watchOutboxCount).called(1);
    });
  });
}
