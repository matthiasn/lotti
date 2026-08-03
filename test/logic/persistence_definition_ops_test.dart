import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_definition_ops.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../widget_test_utils.dart';

/// Mirror test for [PersistenceDefinitionOps].
///
/// Verifies the notify/enqueue side effects of the definition writers and the
/// one cross-collaborator hop: `deleteDashboardDefinitionImpl` must perform its
/// soft-delete through the facade's `upsertDashboardDefinition`, not the local
/// `*Impl`, so a mocked facade is asserted to receive that call.
void main() {
  late MockPersistenceLogic logic;
  late MockNotificationService notificationService;
  late MockOutboxService outboxService;
  late PersistenceDefinitionOps ops;
  late TestGetItMocks mocks;

  final dashboard =
      EntityDefinition.dashboard(
            id: 'dash-1',
            name: 'Dash',
            description: '',
            items: const [],
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            lastReviewed: DateTime(2024, 3, 15),
            vectorClock: null,
            version: '1',
            active: true,
            private: false,
          )
          as DashboardDefinition;

  setUp(() async {
    registerAllFallbackValues();
    notificationService = MockNotificationService();
    outboxService = MockOutboxService();
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<OutboxService>(outboxService)
          ..registerSingleton<NotificationService>(notificationService);
      },
    );
    logic = MockPersistenceLogic();
    ops = PersistenceDefinitionOps(logic);

    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});
    when(() => mocks.updateNotifications.notify(any())).thenReturn(null);
    when(
      () => notificationService.cancelNotification(any()),
    ).thenAnswer((_) async {});
  });

  tearDown(tearDownTestGetIt);

  test(
    'upsertDashboardDefinitionImpl notifies and enqueues a sync update',
    () async {
      when(
        () => mocks.journalDb.upsertDashboardDefinition(any()),
      ).thenAnswer((_) async => 1);

      final affected = await ops.upsertDashboardDefinitionImpl(dashboard);

      expect(affected, 1);
      verify(
        () => mocks.updateNotifications.notify({
          dashboard.id,
          dashboardsNotification,
        }),
      ).called(1);
      final message =
          verify(
                () => outboxService.enqueueMessage(captureAny()),
              ).captured.single
              as SyncMessage;
      expect(message, isA<SyncEntityDefinition>());
    },
  );

  test(
    'deleteDashboardDefinitionImpl soft-deletes through the facade upsert',
    () async {
      when(
        () => logic.upsertDashboardDefinition(any()),
      ).thenAnswer((_) async => 1);

      final affected = await ops.deleteDashboardDefinitionImpl(dashboard);

      expect(affected, 1);
      // The delete must route through the facade (overridable) rather than the
      // local impl, and the upserted copy carries a deletedAt timestamp.
      final captured =
          verify(
                () => logic.upsertDashboardDefinition(captureAny()),
              ).captured.single
              as DashboardDefinition;
      expect(captured.deletedAt, isNotNull);
      verify(
        () => notificationService.cancelNotification(dashboard.id.hashCode),
      ).called(1);
    },
  );

  test('setConfigFlagImpl enqueues only when the status changes', () async {
    const flag = ConfigFlag(
      name: 'recording',
      description: 'd',
      status: true,
    );
    when(
      () => mocks.journalDb.getConfigFlagByName('recording'),
    ).thenAnswer(
      (_) async =>
          const ConfigFlag(name: 'recording', description: 'd', status: false),
    );
    when(
      () => mocks.journalDb.upsertConfigFlag(any()),
    ).thenAnswer((_) async => 1);

    await ops.setConfigFlagImpl(flag);

    verify(() => outboxService.enqueueMessage(any())).called(1);
  });

  group('setConfigFlagImpl refreshes the badge for the notifications flag', () {
    /// Stubs the stored flag so [status] is what the write is changing *from*.
    void withStoredStatus({required bool status}) {
      when(
        () => mocks.journalDb.getConfigFlagByName(enableNotificationsFlag),
      ).thenAnswer(
        (_) async => ConfigFlag(
          name: enableNotificationsFlag,
          description: 'd',
          status: status,
        ),
      );
      when(
        () => mocks.journalDb.upsertConfigFlag(any()),
      ).thenAnswer((_) async => 1);
    }

    ConfigFlag notificationsFlag({required bool status}) => ConfigFlag(
      name: enableNotificationsFlag,
      description: 'd',
      status: status,
    );

    setUp(() {
      when(notificationService.updateBadge).thenAnswer((_) async {});
    });

    test('switching off takes the task count off the app icon', () async {
      withStoredStatus(status: true);

      await ops.setConfigFlagImpl(notificationsFlag(status: false));

      // updateBadge is the only thing that reconciles the icon with the flag,
      // and nothing else calls it outside entry creation — so without this the
      // count sat on the icon until the user happened to write something.
      verify(notificationService.updateBadge).called(1);
    });

    test('switching on is where the permission prompt surfaces', () async {
      withStoredStatus(status: false);

      await ops.setConfigFlagImpl(notificationsFlag(status: true));

      verify(notificationService.updateBadge).called(1);
    });

    test('re-writing the same status does no badge work', () async {
      withStoredStatus(status: true);

      await ops.setConfigFlagImpl(notificationsFlag(status: true));

      verifyNever(notificationService.updateBadge);
    });

    test('another flag changing does no badge work', () async {
      when(
        () => mocks.journalDb.getConfigFlagByName('private'),
      ).thenAnswer(
        (_) async =>
            const ConfigFlag(name: 'private', description: 'd', status: false),
      );
      when(
        () => mocks.journalDb.upsertConfigFlag(any()),
      ).thenAnswer((_) async => 1);

      await ops.setConfigFlagImpl(
        const ConfigFlag(name: 'private', description: 'd', status: true),
      );

      verifyNever(notificationService.updateBadge);
    });

    test('a badge failure does not fail the settings write', () async {
      withStoredStatus(status: true);
      when(notificationService.updateBadge).thenThrow(StateError('channel'));

      // The user asked to change a setting and that write already succeeded; a
      // badge refresh that cannot reach the platform is not a reason to report
      // the setting as unsaved.
      await expectLater(
        ops.setConfigFlagImpl(notificationsFlag(status: false)),
        completes,
      );
    });
  });
}
