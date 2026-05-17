import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late NotificationsDb notificationsDb;
  late MockNotificationService notificationService;
  late MockJournalDb journalDb;
  late NotificationScheduler scheduler;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    notificationsDb = NotificationsDb(
      inMemoryDatabase: true,
      background: false,
    );
    notificationService = MockNotificationService();
    journalDb = MockJournalDb();
    scheduler = NotificationScheduler(
      notificationsDb: notificationsDb,
      notificationServiceProvider: () => notificationService,
      journalDb: journalDb,
    );

    _stubFlag(journalDb, enabled: true);
    _stubNotificationService(notificationService);
  });

  tearDown(() async {
    await notificationsDb.close();
  });

  group('NotificationScheduler', () {
    test('maps stable string ids to positive notification ids', () {
      expect(
        NotificationScheduler.notificationIdFor('notification-id'),
        869828,
      );
      expect(
        NotificationScheduler.notificationIdFor('task:123'),
        1316966838,
      );
      expect(
        NotificationScheduler.notificationIdFor(
          '00000000-0000-0000-0000-000000000000',
        ),
        1044877009,
      );
    });

    test(
      'shows due notifications immediately with the task deep link',
      () async {
        final now = DateTime.utc(2026, 5, 17, 10);
        final entity = _notification(
          id: 'due-id',
          linkedTaskId: 'task-1',
          scheduledFor: now.subtract(const Duration(minutes: 1)),
        );

        await scheduler.schedule(entity, now: now);

        verify(
          () => notificationService.showNotificationNow(
            title: 'Due title',
            body: 'Due body',
            notificationId: NotificationScheduler.notificationIdFor('due-id'),
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: '/tasks/task-1',
          ),
        ).called(1);
        verifyNever(
          () => notificationService.scheduleNotificationAt(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notifyAt: any(named: 'notifyAt'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        );
        verifyNever(() => notificationService.cancelNotification(any()));
      },
    );

    test('schedules future notifications at their full timestamp', () async {
      final now = DateTime.utc(2026, 5, 17, 10);
      final notifyAt = DateTime.utc(2026, 5, 18, 7, 45);
      final entity = _notification(
        id: 'future-id',
        linkedTaskId: 'task-2',
        scheduledFor: notifyAt,
      );

      await scheduler.schedule(entity, now: now);

      verify(
        () => notificationService.scheduleNotificationAt(
          title: 'Due title',
          body: 'Due body',
          notifyAt: notifyAt,
          notificationId: NotificationScheduler.notificationIdFor('future-id'),
          showOnMobile: true,
          showOnDesktop: true,
          deepLink: '/tasks/task-2',
        ),
      ).called(1);
      verifyNever(
        () => notificationService.showNotificationNow(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationId: any(named: 'notificationId'),
          showOnMobile: any(named: 'showOnMobile'),
          showOnDesktop: any(named: 'showOnDesktop'),
          deepLink: any(named: 'deepLink'),
        ),
      );
      verifyNever(() => notificationService.cancelNotification(any()));
    });

    test('cancels notifications that must not be shown', () async {
      final now = DateTime.utc(2026, 5, 17, 10);
      final scenarios = [
        (
          enabled: false,
          entity: _notification(id: 'disabled-id'),
        ),
        (
          enabled: true,
          entity: _notification(id: 'seen-id', seenAt: now),
        ),
        (
          enabled: true,
          entity: _notification(id: 'deleted-id', deletedAt: now),
        ),
      ];

      for (final scenario in scenarios) {
        clearInteractions(notificationService);
        _stubFlag(journalDb, enabled: scenario.enabled);

        await scheduler.schedule(scenario.entity, now: now);

        verify(
          () => notificationService.cancelNotification(
            NotificationScheduler.notificationIdFor(scenario.entity.id),
          ),
        ).called(1);
        verifyNever(
          () => notificationService.showNotificationNow(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        );
        verifyNever(
          () => notificationService.scheduleNotificationAt(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notifyAt: any(named: 'notifyAt'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        );
      }
    });

    test('cancel cancels by FNV-derived os notification id', () async {
      await scheduler.cancel('cancel-target');

      verify(
        () => notificationService.cancelNotification(
          NotificationScheduler.notificationIdFor('cancel-target'),
        ),
      ).called(1);
    });

    test(
      'schedule falls back to wall-clock now when caller omits now',
      () async {
        final farFuture = DateTime.utc(2099);
        final entity = _notification(
          id: 'fallback-now',
          scheduledFor: farFuture,
        );

        await scheduler.schedule(entity);

        verify(
          () => notificationService.scheduleNotificationAt(
            title: 'Due title',
            body: 'Due body',
            notifyAt: farFuture,
            notificationId: NotificationScheduler.notificationIdFor(
              'fallback-now',
            ),
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: '/tasks/task-id',
          ),
        ).called(1);
      },
    );

    test(
      'reconcile falls back to wall-clock now when caller omits now',
      () async {
        await notificationsDb.upsertNotification(
          _notification(
            id: 'reconcile-fallback',
            scheduledFor: DateTime.utc(2099),
          ),
        );

        await scheduler.reconcile();

        verify(
          () => notificationService.scheduleNotificationAt(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notifyAt: DateTime.utc(2099),
            notificationId: NotificationScheduler.notificationIdFor(
              'reconcile-fallback',
            ),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        ).called(1);
      },
    );

    test(
      'reconcile cancels stale scheduled alerts when flag is off',
      () async {
        _stubFlag(journalDb, enabled: false);
        final now = DateTime.utc(2026, 5, 17, 10);
        final dueEntity = _notification(
          id: 'reconcile-due',
          scheduledFor: now.subtract(const Duration(minutes: 5)),
        );
        final upcomingEntity = _notification(
          id: 'reconcile-upcoming',
          scheduledFor: now.add(const Duration(hours: 1)),
        );
        await notificationsDb.upsertNotification(dueEntity);
        await notificationsDb.upsertNotification(upcomingEntity);

        await scheduler.reconcile(now: now);

        verify(
          () => notificationService.cancelNotification(
            NotificationScheduler.notificationIdFor('reconcile-due'),
          ),
        ).called(1);
        verify(
          () => notificationService.cancelNotification(
            NotificationScheduler.notificationIdFor('reconcile-upcoming'),
          ),
        ).called(1);
        verifyNever(
          () => notificationService.showNotificationNow(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        );
        verifyNever(
          () => notificationService.scheduleNotificationAt(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notifyAt: any(named: 'notifyAt'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        );
      },
    );

    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 64),
    ).test(
      'notificationIdFor is deterministic and a positive 31-bit int',
      (
        id,
      ) {
        final hash = NotificationScheduler.notificationIdFor(id);
        expect(hash, NotificationScheduler.notificationIdFor(id));
        expect(hash, greaterThanOrEqualTo(0));
        expect(hash, lessThanOrEqualTo(0x7fffffff));
      },
      tags: 'glados',
    );

    test(
      'reconcile schedules every active due and upcoming notification',
      () async {
        final now = DateTime.utc(2026, 5, 17, 10);
        final due = _notification(
          id: 'due-reconcile',
          scheduledFor: now.subtract(const Duration(minutes: 5)),
        );
        final upcoming = _notification(
          id: 'upcoming-reconcile',
          scheduledFor: now.add(const Duration(hours: 2)),
        );
        final seen = _notification(
          id: 'seen-reconcile',
          scheduledFor: now.subtract(const Duration(minutes: 1)),
          seenAt: now,
        );

        await notificationsDb.upsertNotification(due);
        await notificationsDb.upsertNotification(upcoming);
        await notificationsDb.upsertNotification(seen);

        await scheduler.reconcile(now: now);

        verify(
          () => notificationService.showNotificationNow(
            title: 'Due title',
            body: 'Due body',
            notificationId: NotificationScheduler.notificationIdFor(
              'due-reconcile',
            ),
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: '/tasks/task-id',
          ),
        ).called(1);
        verify(
          () => notificationService.scheduleNotificationAt(
            title: 'Due title',
            body: 'Due body',
            notifyAt: upcoming.meta.scheduledFor,
            notificationId: NotificationScheduler.notificationIdFor(
              'upcoming-reconcile',
            ),
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: '/tasks/task-id',
          ),
        ).called(1);
        verifyNever(() => notificationService.cancelNotification(any()));
      },
    );
  });
}

void _stubFlag(MockJournalDb db, {required bool enabled}) {
  when(
    () => db.getConfigFlag(enableSyncedAlertsFlag),
  ).thenAnswer((_) async => enabled);
}

void _stubNotificationService(MockNotificationService service) {
  when(
    () => service.showNotificationNow(
      title: any(named: 'title'),
      body: any(named: 'body'),
      notificationId: any(named: 'notificationId'),
      showOnMobile: any(named: 'showOnMobile'),
      showOnDesktop: any(named: 'showOnDesktop'),
      deepLink: any(named: 'deepLink'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => service.scheduleNotificationAt(
      title: any(named: 'title'),
      body: any(named: 'body'),
      notifyAt: any(named: 'notifyAt'),
      notificationId: any(named: 'notificationId'),
      showOnMobile: any(named: 'showOnMobile'),
      showOnDesktop: any(named: 'showOnDesktop'),
      deepLink: any(named: 'deepLink'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => service.cancelNotification(any()),
  ).thenAnswer((_) async {});
}

NotificationEntity _notification({
  required String id,
  String linkedTaskId = 'task-id',
  DateTime? scheduledFor,
  DateTime? seenAt,
  DateTime? deletedAt,
}) {
  final createdAt = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.taskOverdue(
    meta: NotificationMeta(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      scheduledFor: scheduledFor ?? DateTime.utc(2026, 5, 17, 12),
      seenAt: seenAt,
      deletedAt: deletedAt,
      vectorClock: const VectorClock({'host': 1}),
      originatingHostId: 'host',
    ),
    linkedTaskId: linkedTaskId,
    title: 'Due title',
    body: 'Due body',
  );
}
