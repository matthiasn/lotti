import 'package:beamer/beamer.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  // These tests override the mutable platform flag; capture the boot value so
  // tearDown can restore it. Without this `isMobile = true` leaks into other
  // tests under `very_good` (single isolate). See test/README.md.
  final originalIsMobile = platform.isMobile;

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

  tearDown(() {
    platform.isMobile = originalIsMobile;
    getIt.reset();
  });

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

      // Desktop: Flags, Logging Domains, Maintenance, About
      // (4 items, no health).
      expect(find.byType(DesignSystemListItem), findsNWidgets(4));
    });

    testWidgets('uses SettingsIcon as leading widget', (tester) async {
      platform.isMobile = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Material(child: AdvancedSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsIcon), findsNWidgets(4));
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

      expect(find.text(context.messages.settingsFlagsTitle), findsOneWidget);
      expect(
        find.text(context.messages.settingsFlagsSubtitle),
        findsOneWidget,
      );
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
        findsNWidgets(4),
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
      // Mobile: flags, logging, health, maintenance, about (5 items).
      expect(find.byType(DesignSystemListItem), findsNWidgets(5));
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

    testWidgets('every row beams to its canonical /settings/... URL on tap', (
      tester,
    ) async {
      // Wraps the page in a real Beamer so the onTap callbacks
      // (`context.beamToNamed(...)`) execute. Routes are no-op stubs
      // — we only assert the beam request URL.
      platform.isMobile = true;
      final delegate = BeamerDelegate(
        locationBuilder: RoutesLocationBuilder(
          routes: <String, Widget Function(BuildContext, BeamState, Object?)>{
            '/': (_, _, _) => const Material(child: AdvancedSettingsPage()),
            '/settings/flags': (_, _, _) => const SizedBox.shrink(),
            '/settings/advanced/logging_domains': (_, _, _) =>
                const SizedBox.shrink(),
            '/settings/health_import': (_, _, _) => const SizedBox.shrink(),
            '/settings/advanced/maintenance': (_, _, _) =>
                const SizedBox.shrink(),
            '/settings/advanced/about': (_, _, _) => const SizedBox.shrink(),
          },
        ).call,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BeamerProvider(
            routerDelegate: delegate,
            child: const Material(child: AdvancedSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AdvancedSettingsPage));

      for (final entry in <(String, String)>[
        (context.messages.settingsFlagsTitle, '/settings/flags'),
        (
          context.messages.settingsLoggingDomainsTitle,
          '/settings/advanced/logging_domains',
        ),
        (
          context.messages.settingsHealthImportTitle,
          '/settings/health_import',
        ),
        (
          context.messages.settingsMaintenanceTitle,
          '/settings/advanced/maintenance',
        ),
        (context.messages.settingsAboutTitle, '/settings/advanced/about'),
      ]) {
        await tester.tap(find.text(entry.$1));
        await tester.pumpAndSettle();
        expect(
          delegate.configuration.uri.toString(),
          entry.$2,
          reason: 'tapping "${entry.$1}" should beam to ${entry.$2}',
        );
      }
    });
  });
}
