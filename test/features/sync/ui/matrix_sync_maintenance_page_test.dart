import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _StubSyncController extends SyncMaintenanceController {
  @override
  SyncState build() => const SyncState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixSyncMaintenancePage', () {
    late MockJournalDb mockJournalDb;
    late MockMaintenance mockMaintenance;

    setUp(() {
      mockJournalDb = MockJournalDb();
      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(true));

      mockMaintenance = MockMaintenance();
      when(() => mockMaintenance.deleteSyncDb()).thenAnswer((_) async {});
      when(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer((_) async {});

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
      await tester.pumpAndSettle();

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

    testWidgets('delete sync database card shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceDeleteSyncDb));
      await tester.pumpAndSettle();

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

    testWidgets('delete sync database card deletes database when confirmed',
        (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceDeleteSyncDb));
      await tester.pumpAndSettle();

      await tester
          .tap(find.text(context.messages.maintenanceDeleteDatabaseConfirm));
      await tester.pumpAndSettle();

      verify(() => mockMaintenance.deleteSyncDb()).called(1);
    });

    testWidgets('sync definitions card opens sync modal', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceSyncDefinitions));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.syncEntitiesConfirm),
        findsOneWidget,
      );
    });

    testWidgets('re-sync card opens re-sync modal', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MatrixSyncMaintenancePage));
      await tester.tap(find.text(context.messages.maintenanceReSync));
      await tester.pumpAndSettle();

      expect(find.text('Re-sync entries'), findsOneWidget);
    });

    testWidgets('hides content when Matrix flag disabled', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockMaintenance = MockMaintenance();
      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(false));
      when(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
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
