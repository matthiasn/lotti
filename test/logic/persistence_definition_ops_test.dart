import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/notifications/model/notification_kind_flags.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_definition_ops.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
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
  late MockNotificationScheduler notificationScheduler;
  late MockOutboxService outboxService;
  late MockFts5Db fts5Db;
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
    notificationScheduler = MockNotificationScheduler();
    outboxService = MockOutboxService();
    fts5Db = MockFts5Db();
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<OutboxService>(outboxService)
          ..registerSingleton<Fts5Db>(fts5Db)
          ..registerSingleton<NotificationService>(notificationService)
          ..registerSingleton<NotificationScheduler>(notificationScheduler);
      },
    );
    when(
      () => notificationScheduler.reconcile(now: any(named: 'now')),
    ).thenAnswer((_) async {});
    logic = MockPersistenceLogic();
    ops = PersistenceDefinitionOps(logic);

    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});
    when(() => mocks.updateNotifications.notify(any())).thenReturn(null);
    when(
      () => notificationService.cancelNotification(any()),
    ).thenAnswer((_) async {});
    when(notificationService.cancelAllNotifications).thenAnswer((_) async {});
    when(
      () => notificationService.scheduleHabitNotification(
        any(),
        daysToAdd: any(named: 'daysToAdd'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mocks.journalDb.getAllHabitDefinitions(),
    ).thenAnswer((_) async => const []);
  });

  HabitDefinition habitNamed(String id, {bool active = true}) =>
      HabitDefinition(
        id: id,
        name: id,
        description: '',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
        vectorClock: null,
        active: active,
        private: false,
      );

  /// Two habits, one archived: the re-arm must skip the archived one, the
  /// sweep must not.
  void withHabits() {
    when(() => mocks.journalDb.getAllHabitDefinitions()).thenAnswer(
      (_) async => [habitNamed('walk'), habitNamed('read', active: false)],
    );
  }

  tearDown(tearDownTestGetIt);

  test('renaming a choice reindexes historical measurements', () async {
    final previous = measurableHydration;
    final renamed = previous.copyWith(
      choices: [
        for (final choice in previous.choices!)
          if (choice.id == hydrationClear.id)
            choice.copyWith(title: 'Transparent')
          else
            choice,
      ],
    );
    final entries = [testMeasurementHydrationEntry];
    when(
      () => mocks.journalDb.getMeasurableDataTypeById(previous.id),
    ).thenAnswer((_) async => previous);
    when(
      () => mocks.journalDb.upsertEntityDefinition(renamed),
    ).thenAnswer((_) async => 1);
    when(
      () => mocks.journalDb.getMeasurementsByTypeIncludingPrivate(
        type: previous.id,
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => entries);
    when(
      () => fts5Db.reindexMeasurements(renamed, entries),
    ).thenAnswer((_) async {});

    final affected = await ops.upsertEntityDefinitionImpl(renamed);

    expect(affected, 1);
    verify(() => fts5Db.reindexMeasurements(renamed, entries)).called(1);
    verify(
      () => mocks.updateNotifications.notify({
        renamed.id,
        measurablesNotification,
      }),
    ).called(1);
    verify(() => outboxService.enqueueMessage(any())).called(1);
  });

  test(
    'archiving or reordering choices does not rebuild unchanged text',
    () async {
      final previous = measurableHydration;
      final reordered = previous.copyWith(
        choices: [
          ...previous.choices!.reversed.map(
            (choice) =>
                choice.copyWith(archived: choice.id == hydrationClear.id),
          ),
        ],
      );
      when(
        () => mocks.journalDb.getMeasurableDataTypeById(previous.id),
      ).thenAnswer((_) async => previous);
      when(
        () => mocks.journalDb.upsertEntityDefinition(reordered),
      ).thenAnswer((_) async => 1);

      await ops.upsertEntityDefinitionImpl(reordered);

      verifyNoMoreInteractions(fts5Db);
      verifyNever(
        () => mocks.journalDb.getMeasurementsByTypeIncludingPrivate(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      );
    },
  );

  group('stale local edits -', () {
    test(
      'an edit the database skips as older is re-stamped and written again, '
      'and the re-stamped copy is what syncs',
      () async {
        final stale = categoryMindfulness.copyWith(
          updatedAt: DateTime(2026, 9, 5, 10),
        );
        final fixedNow = DateTime(2026, 9, 5, 12);
        final answers = <int>[0, 1];
        when(
          () => mocks.journalDb.upsertEntityDefinition(any()),
        ).thenAnswer((_) async => answers.removeAt(0));
        when(
          () => mocks.journalDb.definitionStamp(any()),
        ).thenAnswer((_) async => null);

        final affected = await withClock(
          Clock.fixed(fixedNow),
          () => ops.upsertEntityDefinitionImpl(stale),
        );

        expect(affected, 1);
        final written = verify(
          () => mocks.journalDb.upsertEntityDefinition(captureAny()),
        ).captured.cast<EntityDefinition>().toList();
        expect(written, hasLength(2));
        expect(written.first, stale);
        expect(written.last.updatedAt, fixedNow);
        expect(written.last.id, stale.id);
        final message =
            verify(
                  () => outboxService.enqueueMessage(captureAny()),
                ).captured.single
                as SyncEntityDefinition;
        expect(message.entityDefinition.updatedAt, fixedNow);
      },
    );

    test('an edit the database applies is written exactly once', () async {
      when(
        () => mocks.journalDb.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await ops.upsertEntityDefinitionImpl(categoryMindfulness);

      verify(
        () => mocks.journalDb.upsertEntityDefinition(categoryMindfulness),
      ).called(1);
    });

    test(
      'the retry is built from the stored stamp: above its timestamp even '
      'when that runs ahead of our clock, and carrying its vector clock',
      () async {
        final storedAt = DateTime(2026, 9, 5, 14);
        final fixedNow = DateTime(2026, 9, 5, 12);
        final stale = categoryMindfulness.copyWith(
          updatedAt: DateTime(2026, 9, 5, 10),
          vectorClock: const VectorClock({'a': 1}),
        );
        final answers = <int>[0, 1];
        when(
          () => mocks.journalDb.upsertEntityDefinition(any()),
        ).thenAnswer((_) async => answers.removeAt(0));
        when(() => mocks.journalDb.definitionStamp(any())).thenAnswer(
          (_) async => (
            updatedAt: storedAt,
            vectorClock: const VectorClock({'a': 2}),
          ),
        );

        final affected = await withClock(
          Clock.fixed(fixedNow),
          () => ops.upsertEntityDefinitionImpl(stale),
        );

        expect(affected, 1);
        final written = verify(
          () => mocks.journalDb.upsertEntityDefinition(captureAny()),
        ).captured.cast<EntityDefinition>().toList();
        expect(written, hasLength(2));
        expect(
          written.last.updatedAt,
          storedAt.add(const Duration(milliseconds: 1)),
        );
        expect(written.last.vectorClock?.vclock, {'a': 2});
        final message =
            verify(
                  () => outboxService.enqueueMessage(captureAny()),
                ).captured.single
                as SyncEntityDefinition;
        expect(message.entityDefinition, written.last);
      },
    );

    test(
      'an edit refused twice is reported as unsaved and is neither '
      'announced, reindexed nor synced',
      () async {
        when(
          () => mocks.journalDb.upsertEntityDefinition(any()),
        ).thenAnswer((_) async => 0);
        when(() => mocks.journalDb.definitionStamp(any())).thenAnswer(
          (_) async => (updatedAt: DateTime(2026, 9, 5, 14), vectorClock: null),
        );

        final affected = await ops.upsertEntityDefinitionImpl(
          categoryMindfulness,
        );

        expect(affected, 0);
        verifyNever(() => mocks.updateNotifications.notify(any()));
        verifyNever(() => outboxService.enqueueMessage(any()));
      },
    );

    test('a stale dashboard edit is re-stamped the same way', () async {
      final fixedNow = DateTime(2026, 9, 5, 12);
      final answers = <int>[0, 1];
      when(
        () => mocks.journalDb.upsertDashboardDefinition(any()),
      ).thenAnswer((_) async => answers.removeAt(0));
      when(
        () => mocks.journalDb.definitionStamp(any()),
      ).thenAnswer((_) async => null);

      final affected = await withClock(
        Clock.fixed(fixedNow),
        () => ops.upsertDashboardDefinitionImpl(dashboard),
      );

      expect(affected, 1);
      final written = verify(
        () => mocks.journalDb.upsertDashboardDefinition(captureAny()),
      ).captured.cast<DashboardDefinition>().toList();
      expect(written, hasLength(2));
      expect(written.last.updatedAt, fixedNow);
    });
  });

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

    test(
      'switching on re-arms reminders written while the flag was off',
      () async {
        withStoredStatus(status: false);

        await ops.setConfigFlagImpl(notificationsFlag(status: true));

        // Rows created while the flag was off never armed an OS alarm, and the
        // repository's idempotent creates skip existing rows — without this
        // reconcile, only the next app start would arm them.
        verify(
          () => notificationScheduler.reconcile(now: any(named: 'now')),
        ).called(1);
      },
    );

    test('switching off sweeps every alarm instead of reconciling', () async {
      withStoredStatus(status: true);

      await ops.setConfigFlagImpl(notificationsFlag(status: false));

      // Alarms armed weeks ahead would still fire; the rows stay in the
      // inbox for when notifications come back on.
      verify(notificationService.cancelAllNotifications).called(1);
      verifyNever(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      );
    });

    test('the sweep runs before the badge is cleared', () async {
      withStoredStatus(status: true);

      await ops.setConfigFlagImpl(notificationsFlag(status: false));

      // The zero-badge post is itself a notification; sweeping after it
      // would take it down again and leave the count on the icon.
      verifyInOrder([
        notificationService.cancelAllNotifications,
        notificationService.updateBadge,
      ]);
    });

    test('a sweep failure still clears the badge and saves', () async {
      withStoredStatus(status: true);
      when(
        notificationService.cancelAllNotifications,
      ).thenThrow(StateError('channel'));

      await expectLater(
        ops.setConfigFlagImpl(notificationsFlag(status: false)),
        completes,
      );

      verify(notificationService.updateBadge).called(1);
    });

    test('switching on re-arms the reminder of every active habit', () async {
      withStoredStatus(status: false);
      withHabits();

      await ops.setConfigFlagImpl(notificationsFlag(status: true));

      // Habit reminders have no inbox row for the reconcile to find.
      verify(
        () => notificationService.scheduleHabitNotification(
          habitNamed('walk'),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      ).called(1);
      verifyNever(
        () => notificationService.scheduleHabitNotification(
          habitNamed('read', active: false),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      );
      verifyNever(notificationService.cancelAllNotifications);
    });

    test('re-writing an already-on flag does not reconcile', () async {
      withStoredStatus(status: true);

      await ops.setConfigFlagImpl(notificationsFlag(status: true));

      verifyNever(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      );
    });

    test('a reconcile failure does not fail the settings write', () async {
      withStoredStatus(status: false);
      when(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      ).thenThrow(StateError('db gone'));

      // Same contract as the badge: the setting is saved, re-arming alarms is
      // best-effort and logged.
      await expectLater(
        ops.setConfigFlagImpl(notificationsFlag(status: true)),
        completes,
      );
    });
  });
  group('setConfigFlagImpl applies the per-kind switches', () {
    void withStored(String name, {required bool status}) {
      when(() => mocks.journalDb.getConfigFlagByName(name)).thenAnswer(
        (_) async => ConfigFlag(name: name, description: 'd', status: status),
      );
      when(
        () => mocks.journalDb.upsertConfigFlag(any()),
      ).thenAnswer((_) async => 1);
    }

    ConfigFlag flagOf(String name, {required bool status}) =>
        ConfigFlag(name: name, description: 'd', status: status);

    setUp(() {
      when(notificationService.updateBadge).thenAnswer((_) async {});
    });

    for (final name in notificationRowKindFlags) {
      test('$name switched off drops its alarms through a reconcile', () async {
        withStored(name, status: true);

        await ops.setConfigFlagImpl(flagOf(name, status: false));

        // The scheduler cancels per row once the kind answers false; no
        // badge work and no sweep, which would hit every other kind too.
        verify(
          () => notificationScheduler.reconcile(now: any(named: 'now')),
        ).called(1);
        verifyNever(notificationService.updateBadge);
        verifyNever(notificationService.cancelAllNotifications);
      });
    }

    test('a kind switched on re-arms its rows', () async {
      withStored(notifyGoalAlertsFlag, status: false);

      await ops.setConfigFlagImpl(flagOf(notifyGoalAlertsFlag, status: true));

      verify(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      ).called(1);
    });

    test('re-writing a kind switch unchanged does nothing', () async {
      withStored(notifyGoalAlertsFlag, status: true);

      await ops.setConfigFlagImpl(flagOf(notifyGoalAlertsFlag, status: true));

      verifyNever(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      );
      verifyNever(() => outboxService.enqueueMessage(any()));
    });

    test('the badge switch refreshes the icon and nothing else', () async {
      withStored(showTaskBadgeFlag, status: true);

      await ops.setConfigFlagImpl(flagOf(showTaskBadgeFlag, status: false));

      verify(notificationService.updateBadge).called(1);
      verifyNever(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      );
      verifyNever(notificationService.cancelAllNotifications);
    });

    test("habit reminders switched off cancel every habit's alarm", () async {
      withStored(notifyHabitRemindersFlag, status: true);
      withHabits();

      await ops.setConfigFlagImpl(
        flagOf(notifyHabitRemindersFlag, status: false),
      );

      // Archived habits too: an alarm left from before archiving is exactly
      // what the user is asking to silence.
      verify(
        () => notificationService.cancelNotification('walk'.hashCode),
      ).called(1);
      verify(
        () => notificationService.cancelNotification('read'.hashCode),
      ).called(1);
      verifyNever(
        () => notificationService.scheduleHabitNotification(
          any(),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      );
      verifyNever(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      );
    });

    test('habit reminders switched on re-arm every active habit', () async {
      withStored(notifyHabitRemindersFlag, status: false);
      withHabits();

      await ops.setConfigFlagImpl(
        flagOf(notifyHabitRemindersFlag, status: true),
      );

      verify(
        () => notificationService.scheduleHabitNotification(
          habitNamed('walk'),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      ).called(1);
      verifyNever(
        () => notificationService.scheduleHabitNotification(
          habitNamed('read', active: false),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      );
      verifyNever(() => notificationService.cancelNotification(any()));
    });

    test('a habit sweep failure does not fail the settings write', () async {
      withStored(notifyHabitRemindersFlag, status: true);
      when(
        () => mocks.journalDb.getAllHabitDefinitions(),
      ).thenThrow(StateError('db gone'));

      await expectLater(
        ops.setConfigFlagImpl(flagOf(notifyHabitRemindersFlag, status: false)),
        completes,
      );
    });

    test('the wording switch has no immediate consequence', () async {
      // It binds the next wake that authors a banner; alarms already armed
      // keep their words either way, so there is nothing to reconcile.
      withStored(notifyAgentCopyFlag, status: false);

      await ops.setConfigFlagImpl(flagOf(notifyAgentCopyFlag, status: true));

      verifyNever(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      );
      verifyNever(notificationService.updateBadge);
      verifyNever(notificationService.cancelAllNotifications);
    });

    test('a flag that is no notification preference touches nothing', () async {
      withStored('private', status: false);

      await ops.setConfigFlagImpl(flagOf('private', status: true));

      verifyNever(
        () => notificationScheduler.reconcile(now: any(named: 'now')),
      );
      verifyNever(notificationService.updateBadge);
      verifyNever(notificationService.cancelAllNotifications);
      verifyNever(() => mocks.journalDb.getAllHabitDefinitions());
    });
  });
}
