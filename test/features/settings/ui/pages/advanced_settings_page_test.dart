import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/settings/ui/pages/advanced_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockSyncDatabase = MockSyncDatabase();
  final mockJournalDb = MockJournalDb();

  setUp(() {
    when(() => mockJournalDb.watchConfigFlag(any()))
        .thenAnswer((_) => Stream.value(true));
    when(mockSyncDatabase.watchOutboxCount).thenAnswer((_) => Stream.value(n));

    getIt
      ..registerSingleton<SyncDatabase>(mockSyncDatabase)
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<JournalDb>(mockJournalDb);
  });

  tearDown(getIt.reset);

  group('AdvancedSettingsPage', () {
    testWidgets('renders advanced-only cards (no sync items here)',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AdvancedSettingsPage));

      // Verify advanced-only cards are present
      expect(find.text(context.messages.settingsLogsTitle), findsOneWidget);
      expect(
          find.text(context.messages.settingsMaintenanceTitle), findsOneWidget);
      expect(find.text(context.messages.settingsAboutTitle), findsOneWidget);

      // Verify sync-related items moved away from Advanced
      expect(find.text(context.messages.settingsMatrixTitle), findsNothing);
      expect(find.text(context.messages.settingsSyncOutboxTitle), findsNothing);
      expect(find.text(context.messages.settingsConflictsTitle), findsNothing);
    });

    testWidgets('shows health import card on mobile', (tester) async {
      platform.isMobile = true;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AdvancedSettingsPage));
      expect(find.text(context.messages.settingsHealthImportTitle),
          findsOneWidget);
    });

    testWidgets('hides health import card on desktop', (tester) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AdvancedSettingsPage));
      expect(
          find.text(context.messages.settingsHealthImportTitle), findsNothing);
    });
  });
}
