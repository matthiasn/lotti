import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncSettingsPage', () {
    late MockJournalDb mockJournalDb;
    late MockSyncDatabase mockSyncDb;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockSyncDb = MockSyncDatabase();

      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));
      when(mockSyncDb.watchOutboxCount).thenAnswer((_) => Stream<int>.value(0));

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncDatabase>(mockSyncDb)
        ..registerSingleton<UserActivityService>(UserActivityService());
    });

    tearDown(getIt.reset);

    testWidgets(
      'renders provisioned setup, maintenance, outbox, conflicts, stats, '
      'and backfill items',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const SyncSettingsPage()),
        );
        // The page is a StatelessWidget gated on a synchronous config-flag
        // stream; no long animations, so a bounded pump suffices.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final context = tester.element(find.byType(SyncSettingsPage));
        expect(
          find.text(context.messages.provisionedSyncTitle),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.settingsMatrixMaintenanceTitle),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.settingsSyncOutboxTitle),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.settingsConflictsTitle),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.settingsMatrixStatsTitle),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.backfillSettingsTitle),
          findsOneWidget,
        );
      },
    );

    testWidgets('gate hides page when Matrix flag is OFF', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSyncDb = MockSyncDatabase();
      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(false));
      when(mockSyncDb.watchOutboxCount).thenAnswer((_) => Stream<int>.value(0));
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncDatabase>(mockSyncDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();

      final context = tester.element(find.byType(SyncSettingsPage));
      expect(
        find.text(context.messages.provisionedSyncTitle),
        findsNothing,
      );
      expect(
        find.text(context.messages.settingsMatrixMaintenanceTitle),
        findsNothing,
      );
      expect(
        find.text(context.messages.settingsMatrixStatsTitle),
        findsNothing,
      );
    });

    testWidgets('uses design system grouped list layout', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      // 1 ProvisionedSyncSettingsCard (contains a DesignSystemListItem)
      // + 6 regular DesignSystemListItems = 7 (added "This device" / node-profile entry)
      expect(find.byType(DesignSystemListItem), findsNWidgets(7));
      expect(find.byType(ProvisionedSyncSettingsCard), findsOneWidget);
    });

    testWidgets('shows settings icons for each item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 6 regular items + 1 provisioned card = 7 SettingsIcon (node-profile added)
      expect(find.byType(SettingsIcon), findsNWidgets(7));
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mail), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(find.byIcon(Icons.devices_rounded), findsOneWidget);
    });

    testWidgets('shows chevron trailing icon on each item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(7));
    });

    testWidgets('shows dividers between items but not after last', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final items = tester.widgetList<DesignSystemListItem>(
        find.byType(DesignSystemListItem),
      );
      final dividerFlags = items.map((item) => item.showDivider).toList();

      // All except last should show divider
      for (var i = 0; i < dividerFlags.length - 1; i++) {
        expect(
          dividerFlags[i],
          isTrue,
          reason: 'Item $i should show divider',
        );
      }
      expect(dividerFlags.last, isFalse, reason: 'Last item has no divider');
    });

    testWidgets('outbox item shows mailbox badge icon', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(OutboxBadgeIcon), findsOneWidget);
    });

    testWidgets('renders subtitles for all items', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final context = tester.element(find.byType(SyncSettingsPage));
      expect(
        find.text(context.messages.provisionedSyncSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsMatrixMaintenanceSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsAdvancedOutboxSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsSyncConflictsSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsSyncStatsSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.backfillSettingsSubtitle),
        findsOneWidget,
      );
    });

    group('row navigation', () {
      // Each row's tap fires `context.beamToNamed(<route>)`. We wrap the page
      // in a real BeamerProvider whose delegate exposes the destination routes,
      // tap each row by its localized title, then assert the delegate actually
      // navigated to the expected path. The title is resolved per-row instead
      // of hard-coded so the test stays in sync with the source ordering.
      String titleFor(BuildContext context, int index) {
        final m = context.messages;
        return [
          m.settingsMatrixMaintenanceTitle,
          m.settingsSyncOutboxTitle,
          m.settingsConflictsTitle,
          m.settingsMatrixStatsTitle,
          m.backfillSettingsTitle,
          m.settingsSyncNodeProfileTitle,
        ][index];
      }

      // (rowIndex, expected destination path) for every reachable onTap.
      const cases = <(int, String)>[
        (0, '/settings/sync/matrix/maintenance'),
        (1, '/settings/sync/outbox'),
        (2, '/settings/advanced/conflicts'),
        (3, '/settings/sync/stats'),
        (4, '/settings/sync/backfill'),
        (5, '/settings/sync/node-profile'),
      ];

      for (final (rowIndex, expectedPath) in cases) {
        testWidgets('row $rowIndex taps beam to $expectedPath', (tester) async {
          final delegate = BeamerDelegate(
            locationBuilder: RoutesLocationBuilder(
              routes: {
                for (final (_, path) in cases)
                  path: (_, _, _) => const SizedBox.shrink(),
                '/': (_, _, _) => const SyncSettingsPage(),
              },
            ).call,
          );

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              BeamerProvider(
                routerDelegate: delegate,
                child: const SyncSettingsPage(),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final context = tester.element(find.byType(SyncSettingsPage));
          final title = find.text(titleFor(context, rowIndex));
          expect(title, findsOneWidget);
          await tester.ensureVisible(title);
          await tester.tap(title);
          // Bounded pump covers the Beamer route transition (~300ms) without
          // risking the 10s pumpAndSettle timeout.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(
            delegate.currentBeamLocation.state.routeInformation.uri.path,
            expectedPath,
          );
        });
      }
    });
  });
}
