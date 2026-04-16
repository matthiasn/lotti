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

class MockSyncDatabase extends Mock implements SyncDatabase {}

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
        await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      // 1 ProvisionedSyncSettingsCard (contains a DesignSystemListItem)
      // + 5 regular DesignSystemListItems = 6
      expect(find.byType(DesignSystemListItem), findsNWidgets(6));
      expect(find.byType(ProvisionedSyncSettingsCard), findsOneWidget);
    });

    testWidgets('shows settings icons for each item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pumpAndSettle();

      // 5 regular items + 1 provisioned card = 6 SettingsIcon
      expect(find.byType(SettingsIcon), findsNWidgets(6));
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mail), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('shows chevron trailing icon on each item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(6));
    });

    testWidgets('shows dividers between items but not after last', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.byType(OutboxBadgeIcon), findsOneWidget);
    });

    testWidgets('renders subtitles for all items', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pumpAndSettle();

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
        find.text(context.messages.settingsAdvancedConflictsSubtitle),
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
  });
}
