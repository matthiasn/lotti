// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(const VectorClock(<String, int>{}));
  });

  late NotificationsDb notificationsDb;
  late MockJournalDb journalDb;
  late MockVectorClockService vectorClockService;
  late MockOutboxService outboxService;
  late MockUpdateNotifications updateNotifications;
  late MockNotificationScheduler scheduler;
  late NotificationRepository repository;

  final fixedNow = DateTime.utc(2026, 5, 17, 10);

  setUp(() {
    notificationsDb = NotificationsDb(
      inMemoryDatabase: true,
      background: false,
    );
    journalDb = MockJournalDb();
    vectorClockService = MockVectorClockService();
    outboxService = MockOutboxService();
    updateNotifications = MockUpdateNotifications();
    scheduler = MockNotificationScheduler();

    when(
      () => journalDb.getConfigFlag(enableSyncedAlertsFlag),
    ).thenAnswer((_) async => true);
    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'host-a');
    when(
      () => vectorClockService.getNextVectorClock(
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async => const VectorClock({'host-a': 1}));
    when(
      () => outboxService.enqueueNotification(
        any<NotificationEntity>(),
        originatingHostId: any(named: 'originatingHostId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => outboxService.enqueueNotificationStateUpdate(
        id: any(named: 'id'),
        seenAt: any(named: 'seenAt'),
        actedOnAt: any(named: 'actedOnAt'),
        deletedAt: any(named: 'deletedAt'),
        vectorClock: any(named: 'vectorClock'),
        originatingHostId: any(named: 'originatingHostId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => scheduler.schedule(
        any<NotificationEntity>(),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async {});

    repository = NotificationRepository(
      notificationsDb: notificationsDb,
      journalDb: journalDb,
      vectorClockService: vectorClockService,
      outboxService: outboxService,
      updateNotifications: updateNotifications,
      scheduler: scheduler,
      now: () => fixedNow,
    );
  });

  tearDown(() async {
    await notificationsDb.close();
  });

  group('NotificationRepository.create', () {
    test(
      'createTaskSuggestion uses linkedTaskId-derived id by default',
      () async {
        final saved = await repository.createTaskSuggestion(
          linkedTaskId: 'task-default',
          suggestionCount: 1,
          title: 'Look',
          body: 'b',
        );

        expect(
          saved!.meta.id,
          repository.notificationIdForTaskSuggestion('task-default'),
        );
      },
    );

    test(
      'createTaskSuggestion seeds the row id from idSeed when provided so a '
      'fresh agent wave does not collide with an already-acted-on row for '
      'the same task',
      () async {
        final first = await repository.createTaskSuggestion(
          linkedTaskId: 'task-X',
          suggestionCount: 1,
          title: 'First wave',
          body: 'b',
          idSeed: 'change-set-1',
        );
        final second = await repository.createTaskSuggestion(
          linkedTaskId: 'task-X',
          suggestionCount: 1,
          title: 'Second wave',
          body: 'b',
          idSeed: 'change-set-2',
        );

        // Different seeds → different inbox rows.
        expect(first!.meta.id, isNot(second!.meta.id));
        // The seeded id matches the same derivation the producer would use
        // if it called the helper directly.
        expect(
          first.meta.id,
          repository.notificationIdForTaskSuggestion('change-set-1'),
        );
        expect(
          second.meta.id,
          repository.notificationIdForTaskSuggestion('change-set-2'),
        );
        // Both rows still deep-link to the underlying task.
        expect(first.linkedEntityId, 'task-X');
        expect(second.linkedEntityId, 'task-X');
      },
    );

    test(
      'createTaskSuggestion enriches meta, persists, enqueues and notifies',
      () async {
        final saved = await repository.createTaskSuggestion(
          linkedTaskId: 'task-1',
          suggestionCount: 3,
          title: 'Review suggestions',
          body: 'Three tasks need review',
          category: 'work',
        );

        expect(saved, isA<TaskSuggestionNotification>());
        final entity = saved! as TaskSuggestionNotification;
        expect(entity.linkedTaskId, 'task-1');
        expect(entity.suggestionCount, 3);
        expect(entity.title, 'Review suggestions');
        expect(entity.body, 'Three tasks need review');
        expect(entity.meta.id, isNotEmpty);
        expect(entity.meta.originatingHostId, 'host-a');
        expect(entity.meta.updatedAt, fixedNow);
        expect(entity.meta.scheduledFor, fixedNow);
        expect(entity.meta.vectorClock, const VectorClock({'host-a': 1}));
        expect(entity.meta.category, 'work');

        expect(
          await notificationsDb.notificationById(entity.meta.id),
          entity,
        );

        verify(
          () => vectorClockService.getNextVectorClock(previous: null),
        ).called(1);
        verify(() => outboxService.enqueueNotification(entity)).called(1);
        verify(() => scheduler.schedule(entity, now: fixedNow)).called(1);
        verify(
          () => updateNotifications.notify(
            {entity.meta.id, 'task-1', inboxNotification},
            fromSync: false,
          ),
        ).called(1);
      },
    );

    test(
      'createTaskOverdue produces a TaskOverdueNotification with stable id',
      () async {
        final saved = await repository.createTaskOverdue(
          linkedTaskId: 'task-2',
          title: 'Task overdue',
          body: 'Past the deadline',
        );

        expect(saved, isA<TaskOverdueNotification>());
        final overdue = saved! as TaskOverdueNotification;
        expect(overdue.linkedTaskId, 'task-2');
        expect(overdue.title, 'Task overdue');
        expect(
          overdue.meta.id,
          repository.notificationIdForTaskOverdue('task-2'),
        );

        verify(() => outboxService.enqueueNotification(overdue)).called(1);
        verify(() => scheduler.schedule(overdue, now: fixedNow)).called(1);
      },
    );

    test('returns null and skips side effects when flag is disabled', () async {
      when(
        () => journalDb.getConfigFlag(enableSyncedAlertsFlag),
      ).thenAnswer((_) async => false);

      final saved = await repository.createTaskSuggestion(
        linkedTaskId: 'task-disabled',
        suggestionCount: 1,
        title: 't',
        body: 'b',
      );

      expect(saved, isNull);
      expect(await notificationsDb.countAllNotifications(), 0);
      verifyNever(() => vectorClockService.getHost());
      verifyNever(
        () => outboxService.enqueueNotification(any<NotificationEntity>()),
      );
      verifyNever(
        () => scheduler.schedule(
          any<NotificationEntity>(),
          now: any(named: 'now'),
        ),
      );
      verifyNever(
        () => updateNotifications.notify(
          any<Set<String>>(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });

    test('returns null when vector clock service has no host yet', () async {
      when(() => vectorClockService.getHost()).thenAnswer((_) async => null);

      final saved = await repository.createTaskSuggestion(
        linkedTaskId: 'task-no-host',
        suggestionCount: 1,
        title: 't',
        body: 'b',
      );

      expect(saved, isNull);
      expect(await notificationsDb.countAllNotifications(), 0);
      verifyNever(
        () => outboxService.enqueueNotification(any<NotificationEntity>()),
      );
    });

    test(
      'create skips side effects when upsert is a no-op merge',
      () async {
        // Seed an identical row so the merge in upsertNotification returns
        // null (no change).
        final placeholder = _entityForCreate(
          id: 'existing-no-op',
          linkedTaskId: 'task-noop',
          createdAt: fixedNow,
          updatedAt: fixedNow,
          scheduledFor: fixedNow,
          vectorClock: const VectorClock({'host-a': 1}),
          originatingHostId: 'host-a',
        );
        await notificationsDb.upsertNotification(placeholder);
        clearInteractions(updateNotifications);
        clearInteractions(outboxService);
        clearInteractions(scheduler);

        final result = await repository.create(placeholder);

        expect(result, isNull);
        verifyNever(
          () => outboxService.enqueueNotification(any<NotificationEntity>()),
        );
        verifyNever(
          () => scheduler.schedule(
            any<NotificationEntity>(),
            now: any(named: 'now'),
          ),
        );
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'create forwards an existing non-empty vector clock as previous',
      () async {
        final placeholder = _entityForCreate(
          id: 'with-prior-clock',
          linkedTaskId: 'task-prior',
          createdAt: fixedNow,
          updatedAt: fixedNow,
          scheduledFor: fixedNow,
          vectorClock: const VectorClock({'host-a': 5}),
          originatingHostId: '',
        );

        await repository.create(placeholder);

        verify(
          () => vectorClockService.getNextVectorClock(
            previous: const VectorClock({'host-a': 5}),
          ),
        ).called(1);
      },
    );
  });

  group('NotificationRepository state changes', () {
    Future<NotificationEntity> seed({
      DateTime? seenAt,
      DateTime? actedOnAt,
      DateTime? deletedAt,
    }) async {
      final base = _entityForCreate(
        id: 'state-test',
        linkedTaskId: 'task-state',
        createdAt: fixedNow.subtract(const Duration(hours: 2)),
        updatedAt: fixedNow.subtract(const Duration(hours: 1)),
        scheduledFor: fixedNow,
        vectorClock: const VectorClock({'host-a': 1}),
        originatingHostId: 'host-a',
        seenAt: seenAt,
        actedOnAt: actedOnAt,
        deletedAt: deletedAt,
      );
      await notificationsDb.upsertNotification(base);
      clearInteractions(updateNotifications);
      clearInteractions(outboxService);
      clearInteractions(scheduler);
      return base;
    }

    test('markSeen merges state, enqueues update and notifies', () async {
      await seed();
      when(
        () => vectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer((_) async => const VectorClock({'host-a': 2}));

      final updated = await repository.markSeen('state-test');

      expect(updated, isNotNull);
      expect(updated!.meta.seenAt, fixedNow);
      expect(updated.meta.vectorClock, const VectorClock({'host-a': 2}));

      verify(
        () => outboxService.enqueueNotificationStateUpdate(
          id: 'state-test',
          seenAt: fixedNow,
          actedOnAt: null,
          deletedAt: null,
          vectorClock: const VectorClock({'host-a': 2}),
          originatingHostId: 'host-a',
        ),
      ).called(1);
      verify(() => scheduler.schedule(updated)).called(1);
      verify(
        () => updateNotifications.notify(
          {'state-test', 'task-state', inboxNotification},
          fromSync: false,
        ),
      ).called(1);
    });

    test('markActedOn forwards actedOnAt only', () async {
      await seed();
      await repository.markActedOn('state-test');

      verify(
        () => outboxService.enqueueNotificationStateUpdate(
          id: 'state-test',
          seenAt: null,
          actedOnAt: fixedNow,
          deletedAt: null,
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: 'host-a',
        ),
      ).called(1);
    });

    test('retract forwards deletedAt only', () async {
      await seed();
      await repository.retract('state-test');

      verify(
        () => outboxService.enqueueNotificationStateUpdate(
          id: 'state-test',
          seenAt: null,
          actedOnAt: null,
          deletedAt: fixedNow,
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: 'host-a',
        ),
      ).called(1);
    });

    test('state mutation returns null when notification is missing', () async {
      final result = await repository.markSeen('does-not-exist');

      expect(result, isNull);
      verifyNever(() => vectorClockService.getHost());
      verifyNever(
        () => outboxService.enqueueNotificationStateUpdate(
          id: any(named: 'id'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });

    test(
      'state mutation is idempotent when the field is already populated',
      () async {
        await seed(seenAt: fixedNow.subtract(const Duration(minutes: 5)));

        final result = await repository.markSeen('state-test');

        expect(result, isNull);
        verifyNever(() => vectorClockService.getHost());
        verifyNever(
          () => outboxService.enqueueNotificationStateUpdate(
            id: any(named: 'id'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ),
        );
      },
    );

    test(
      'state mutation skips outbox when flag is disabled but still notifies',
      () async {
        await seed();
        when(
          () => journalDb.getConfigFlag(enableSyncedAlertsFlag),
        ).thenAnswer((_) async => false);
        when(
          () => vectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        ).thenAnswer((_) async => const VectorClock({'host-a': 3}));

        final updated = await repository.markSeen('state-test');

        expect(updated, isNotNull);
        expect(updated!.meta.seenAt, fixedNow);
        verifyNever(
          () => outboxService.enqueueNotificationStateUpdate(
            id: any(named: 'id'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ),
        );
        verify(() => scheduler.schedule(updated)).called(1);
        verify(
          () => updateNotifications.notify(
            {'state-test', 'task-state', inboxNotification},
            fromSync: false,
          ),
        ).called(1);
      },
    );

    test('state mutation returns null when host is unavailable', () async {
      await seed();
      when(() => vectorClockService.getHost()).thenAnswer((_) async => null);

      final result = await repository.markSeen('state-test');

      expect(result, isNull);
      verifyNever(
        () => outboxService.enqueueNotificationStateUpdate(
          id: any(named: 'id'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });
  });

  group('NotificationRepository pass-throughs', () {
    test('notificationById delegates to NotificationsDb', () async {
      final stored = _entityForCreate(
        id: 'lookup-id',
        linkedTaskId: 'task-lookup',
        createdAt: fixedNow,
        updatedAt: fixedNow,
        scheduledFor: fixedNow,
        vectorClock: const VectorClock({'host-a': 1}),
        originatingHostId: 'host-a',
      );
      await notificationsDb.upsertNotification(stored);

      expect(
        await repository.notificationById('lookup-id'),
        stored,
      );
      expect(await repository.notificationById('missing'), isNull);
    });

    test('unseenCount delegates to NotificationsDb', () async {
      await notificationsDb.upsertNotification(
        _entityForCreate(
          id: 'unseen',
          linkedTaskId: 'task-unseen',
          createdAt: fixedNow.subtract(const Duration(hours: 2)),
          updatedAt: fixedNow.subtract(const Duration(hours: 1)),
          scheduledFor: fixedNow.subtract(const Duration(minutes: 1)),
          vectorClock: const VectorClock({'host-a': 1}),
          originatingHostId: 'host-a',
        ),
      );

      expect(await repository.unseenCount(fixedNow), 1);
    });

    test(
      'notification id helpers are deterministic and version 5 UUIDs',
      () {
        expect(
          repository.notificationIdForTaskSuggestion('task-1'),
          repository.notificationIdForTaskSuggestion('task-1'),
        );
        expect(
          repository.notificationIdForTaskOverdue('task-1'),
          repository.notificationIdForTaskOverdue('task-1'),
        );
        expect(
          repository.notificationIdForTaskSuggestion('task-1'),
          isNot(repository.notificationIdForTaskOverdue('task-1')),
        );
        expect(
          repository.notificationIdForTaskSuggestion('task-1'),
          isNot(repository.notificationIdForTaskSuggestion('task-2')),
        );
        // UUID v5 in 8-4-4-4-12 form, version nibble = 5.
        final id = repository.notificationIdForTaskSuggestion('task-1');
        expect(
          id,
          matches(
            RegExp(
              '^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-'
              r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      },
    );
  });
}

NotificationEntity _entityForCreate({
  required String id,
  required String linkedTaskId,
  required DateTime createdAt,
  required DateTime updatedAt,
  required DateTime scheduledFor,
  required VectorClock vectorClock,
  required String originatingHostId,
  DateTime? seenAt,
  DateTime? actedOnAt,
  DateTime? deletedAt,
}) {
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      scheduledFor: scheduledFor,
      seenAt: seenAt,
      actedOnAt: actedOnAt,
      deletedAt: deletedAt,
      vectorClock: vectorClock,
      originatingHostId: originatingHostId,
    ),
    linkedTaskId: linkedTaskId,
    suggestionCount: 2,
    title: 'Title',
    body: 'Body',
  );
}
