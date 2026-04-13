import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/advanced_settings_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
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
    when(
      () => mockJournalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(true));
    when(mockSyncDatabase.watchOutboxCount).thenAnswer((_) => Stream.value(n));

    getIt
      ..registerSingleton<SyncDatabase>(mockSyncDatabase)
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<JournalDb>(mockJournalDb);

    ensureThemingServicesRegistered();
  });

  tearDown(getIt.reset);

  group('AdvancedSettingsPage', () {
    testWidgets('renders DesignSystemListItem for each setting', (
      tester,
    ) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop: Logging Domains, Maintenance, About (3 items, no health)
      expect(find.byType(DesignSystemListItem), findsNWidgets(3));
    });

    testWidgets('uses SettingsIcon as leading widget', (tester) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsIcon), findsNWidgets(3));
    });

    testWidgets('shows correct titles and subtitles', (tester) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AdvancedSettingsPage));

      expect(
        find.text(context.messages.settingsLoggingDomainsTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingDomainsSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsMaintenanceTitle),
        findsOneWidget,
      );
      expect(find.text(context.messages.settingsAboutTitle), findsOneWidget);
    });

    testWidgets('shows chevron trailing icon for each item', (tester) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.chevron_right_rounded),
        findsNWidgets(3),
      );
    });

    testWidgets('does not show sync-related items', (tester) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AdvancedSettingsPage));
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
      expect(
        find.text(context.messages.settingsHealthImportTitle),
        findsOneWidget,
      );
      // Mobile: 4 items (logging, health, maintenance, about)
      expect(find.byType(DesignSystemListItem), findsNWidgets(4));
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
        find.text(context.messages.settingsHealthImportTitle),
        findsNothing,
      );
    });

    testWidgets('wraps items in decorated box with border', (tester) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));
      expect(find.byType(ClipRRect), findsAtLeastNWidgets(1));
    });
  });
}
