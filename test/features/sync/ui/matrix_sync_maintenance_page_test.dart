import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _StubSyncController extends SyncMaintenanceController {
  @override
  SyncState build() => const SyncState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  group('MatrixSyncMaintenancePage', () {
    late MockJournalDb mockJournalDb;
    late MockMaintenance mockMaintenance;

    setUp(() {
      mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));

      mockMaintenance = MockMaintenance();
      when(() => mockMaintenance.deleteSyncDb()).thenAnswer((_) async {});
      when(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          agentRepository: any(named: 'agentRepository'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockMaintenance.purgeSentOutboxItems(
          retention: any(named: 'retention'),
          chunkSize: any(named: 'chunkSize'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => 0);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(mockMaintenance);
    });

    tearDown(getIt.reset);

    Widget buildPage({List<Override> overrides = const []}) {
      return makeTestableWidgetWithScaffold(
        const MatrixSyncMaintenancePage(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
          journalDbProvider.overrideWithValue(mockJournalDb),
          syncControllerProvider.overrideWith(_StubSyncController.new),
          ...overrides,
        ],
      );
    }

    testWidgets('renders sync maintenance cards', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      expect(
        find.text(context.messages.maintenanceDeleteSyncDb),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.maintenanceSyncDefinitions),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.maintenanceReSync),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.maintenanceRecreateFts5),
        findsNothing,
      );
    });

    testWidgets('delete sync database card shows confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceDeleteSyncDb));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          context.messages.maintenanceDeleteDatabaseQuestion('Sync'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.maintenanceDeleteDatabaseConfirm),
        findsOneWidget,
      );
    });

    testWidgets('delete sync database card deletes database when confirmed', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceDeleteSyncDb));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(
        find.text(context.messages.maintenanceDeleteDatabaseConfirm),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mockMaintenance.deleteSyncDb()).called(1);
    });

    testWidgets('sync definitions card opens sync modal', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceSyncDefinitions));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(context.messages.syncEntitiesConfirm),
        findsOneWidget,
      );
    });

    testWidgets('re-sync card opens re-sync modal', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceReSync));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Re-sync entries'), findsOneWidget);
    });

    testWidgets('populate sequence log card opens modal', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(
        find.text(context.messages.maintenancePopulateSequenceLog),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(context.messages.maintenancePopulateSequenceLogConfirm),
        findsOneWidget,
      );
    });

    testWidgets('purge sent outbox card shows confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(
        find.text(context.messages.maintenancePurgeSentOutbox),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(context.messages.maintenancePurgeSentOutboxQuestion),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.maintenancePurgeSentOutboxConfirm),
        findsOneWidget,
      );
      // Maintenance.purgeSentOutboxItems must NOT have been called yet —
      // the chunked DELETE + VACUUM is destructive and should only fire
      // after the user explicitly confirms.
      verifyNever(
        () => mockMaintenance.purgeSentOutboxItems(
          retention: any(named: 'retention'),
          chunkSize: any(named: 'chunkSize'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });

    testWidgets('purge sent outbox card calls Maintenance when confirmed', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(
        find.text(context.messages.maintenancePurgeSentOutbox),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(
        find.text(context.messages.maintenancePurgeSentOutboxConfirm),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => mockMaintenance.purgeSentOutboxItems(
          retention: any(named: 'retention'),
          chunkSize: any(named: 'chunkSize'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    });

    testWidgets('uses design system grouped list layout', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      expect(find.byType(DesignSystemListItem), findsNWidgets(5));
      expect(find.byType(SettingsIcon), findsNWidgets(5));
    });

    testWidgets('shows chevron trailing icon on each item', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(5));
    });

    testWidgets('shows correct settings icons', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sync_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.playlist_add_check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
    });

    testWidgets('shows dividers between items but not after last', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final items = tester.widgetList<DesignSystemListItem>(
        find.byType(DesignSystemListItem),
      );
      final dividerFlags = items.map((item) => item.showDivider).toList();

      for (var i = 0; i < dividerFlags.length - 1; i++) {
        expect(
          dividerFlags[i],
          isTrue,
          reason: 'Item $i should show divider',
        );
      }
      expect(dividerFlags.last, isFalse, reason: 'Last item has no divider');
    });

    testWidgets('hides content when Matrix flag disabled', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockMaintenance = MockMaintenance();
      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(false));
      when(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          agentRepository: any(named: 'agentRepository'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockMaintenance.deleteSyncDb()).thenAnswer((_) async {});

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(mockMaintenance);

      await tester.pumpWidget(buildPage());
      await tester.pump();

      final scaffoldContext = tester.element(find.byType(Scaffold));
      expect(
        find.text(scaffoldContext.messages.maintenanceReSync),
        findsNothing,
      );
      expect(
        find.text(scaffoldContext.messages.maintenanceDeleteSyncDb),
        findsNothing,
      );
    });
  });
}
