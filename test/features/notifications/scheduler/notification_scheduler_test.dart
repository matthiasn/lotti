import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late NotificationsDb notificationsDb;
  late MockNotificationService notificationService;
  late NotificationScheduler scheduler;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    notificationsDb = NotificationsDb(
      inMemoryDatabase: true,
      background: false,
    );
    notificationService = MockNotificationService();
    scheduler = NotificationScheduler(
      notificationsDb: notificationsDb,
      notificationServiceProvider: () => notificationService,
    );

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
        _notification(id: 'seen-id', seenAt: now),
        _notification(id: 'deleted-id', deletedAt: now),
        _notification(id: 'acted-id', actedOnAt: now),
      ];

      for (final entity in scenarios) {
        clearInteractions(notificationService);

        await scheduler.schedule(entity, now: now);

        verify(
          () => notificationService.cancelNotification(
            NotificationScheduler.notificationIdFor(entity.id),
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

    // `!entity.meta.scheduledFor.isAfter(effectiveNow)` is true when equal,
    // so scheduledFor == now must route to showNotificationNow, not scheduleNotificationAt.
    test(
      'shows notification immediately when scheduledFor equals now exactly',
      () async {
        final now = DateTime.utc(2026, 5, 17, 10);
        final entity = _notification(
          id: 'exact-now-id',
          linkedTaskId: 'task-exact',
          scheduledFor: now, // exactly equal to effectiveNow
        );

        await scheduler.schedule(entity, now: now);

        verify(
          () => notificationService.showNotificationNow(
            title: 'Due title',
            body: 'Due body',
            notificationId: NotificationScheduler.notificationIdFor(
              'exact-now-id',
            ),
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: '/tasks/task-exact',
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
  });

  // Routing is a switch over the union rather than a read of the shared
  // `linkedEntityId` getter, because every variant answers that getter — which
  // is how a relationship id used to be handed to the `/tasks/` route.
  group('NotificationScheduler deep links', () {
    final now = DateTime.utc(2026, 5, 17, 10);

    /// Schedules [entity] in the past and returns the deep link it carried.
    Future<String?> deepLinkOf(NotificationEntity entity) async {
      clearInteractions(notificationService);
      await scheduler.schedule(entity, now: now);
      final captured = verify(
        () => notificationService.showNotificationNow(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationId: any(named: 'notificationId'),
          showOnMobile: any(named: 'showOnMobile'),
          showOnDesktop: any(named: 'showOnDesktop'),
          deepLink: captureAny(named: 'deepLink'),
        ),
      ).captured;
      return captured.single as String?;
    }

    final past = now.subtract(const Duration(minutes: 1));

    test('a task suggestion points at its task', () async {
      expect(
        await deepLinkOf(
          _suggestion(id: 's', linkedTaskId: 't-1', scheduledFor: past),
        ),
        '/tasks/t-1',
      );
    });

    test('an overdue task points at its task', () async {
      expect(
        await deepLinkOf(
          _notification(id: 'o', linkedTaskId: 't-2', scheduledFor: past),
        ),
        '/tasks/t-2',
      );
    });

    test('a check-in reminder points at the person, not a task', () async {
      expect(
        await deepLinkOf(
          _checkIn(id: 'c', linkedRelationshipId: 'rel-9', scheduledFor: past),
        ),
        '/people/rel-9',
      );
    });
  });

  // OS-level alarms do not survive an app update, a reinstall or an Android
  // reboot, while the rows describing them do. Nothing else re-arms them:
  // `schedule` only ever runs on a write.
  group('NotificationScheduler.reconcile', () {
    final now = DateTime.utc(2026, 5, 17, 10);

    test('re-arms a future row with its original instant', () async {
      await notificationsDb.upsertNotification(
        _checkIn(
          id: 'upcoming-row',
          linkedRelationshipId: 'rel-1',
          scheduledFor: now.add(const Duration(days: 20)),
        ),
      );

      await scheduler.reconcile(now: now);

      // This is the case that matters: that alarm is the only thing standing
      // between a closed app and a missed check-in, and the OS dropped it.
      verify(
        () => notificationService.scheduleNotificationAt(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notifyAt: now.add(const Duration(days: 20)),
          notificationId: NotificationScheduler.notificationIdFor(
            'upcoming-row',
          ),
          showOnMobile: true,
          showOnDesktop: true,
          deepLink: '/people/rel-1',
        ),
      ).called(1);
    });

    test('never re-announces a row that is already due', () async {
      // Showing a notification does not mark the row, and with no tap handler
      // wired the only way to clear one is the in-app bell — so re-posting due
      // rows here would fire an OS banner on every single launch, forever.
      // The row is already in the inbox on the device the user is holding.
      await notificationsDb.upsertNotification(
        _notification(
          id: 'due-task',
          scheduledFor: now.subtract(const Duration(minutes: 5)),
        ),
      );
      await notificationsDb.upsertNotification(
        _checkIn(
          id: 'due-reminder',
          scheduledFor: now.subtract(const Duration(days: 2)),
        ),
      );

      await scheduler.reconcile(now: now);

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
    });

    test('never revives a row the user already dealt with', () async {
      // Seen, acted-on and deleted rows are excluded by the SQL predicate
      // itself, so a dismissal on any device stays dismissed on all of them.
      await notificationsDb.upsertNotification(
        _checkIn(
          id: 'seen-row',
          scheduledFor: now.add(const Duration(days: 3)),
          seenAt: now,
        ),
      );
      await notificationsDb.upsertNotification(
        _notification(
          id: 'deleted-row',
          scheduledFor: now.add(const Duration(days: 3)),
          deletedAt: now,
        ),
      );
      await notificationsDb.upsertNotification(
        _notification(
          id: 'acted-row',
          scheduledFor: now.add(const Duration(days: 3)),
          actedOnAt: now,
        ),
      );

      await scheduler.reconcile(now: now);

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
      verifyNever(() => notificationService.cancelNotification(any()));
    });

    test(
      'an empty inbox never resolves the notification service at all',
      () async {
        // The service is registered lazily so a sandboxed build does not
        // instantiate the platform plugin at startup, and reconcile runs
        // during startup. Resolving it here would undo that.
        var resolutions = 0;
        final lazyScheduler = NotificationScheduler(
          notificationsDb: notificationsDb,
          notificationServiceProvider: () {
            resolutions++;
            return notificationService;
          },
        );

        await lazyScheduler.reconcile(now: now);

        expect(resolutions, 0);
      },
    );

    test('falls back to wall-clock now when the caller omits it', () async {
      await notificationsDb.upsertNotification(
        _notification(id: 'future-row', scheduledFor: DateTime.utc(2099)),
      );

      await scheduler.reconcile();

      verify(
        () => notificationService.scheduleNotificationAt(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notifyAt: DateTime.utc(2099),
          notificationId: NotificationScheduler.notificationIdFor('future-row'),
          showOnMobile: any(named: 'showOnMobile'),
          showOnDesktop: any(named: 'showOnDesktop'),
          deepLink: any(named: 'deepLink'),
        ),
      ).called(1);
    });
  });
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

NotificationMeta _meta({
  required String id,
  DateTime? scheduledFor,
  DateTime? seenAt,
  DateTime? actedOnAt,
  DateTime? deletedAt,
}) {
  final createdAt = DateTime.utc(2026, 5, 17, 8);
  return NotificationMeta(
    id: id,
    createdAt: createdAt,
    updatedAt: createdAt,
    scheduledFor: scheduledFor ?? DateTime.utc(2026, 5, 17, 12),
    seenAt: seenAt,
    actedOnAt: actedOnAt,
    deletedAt: deletedAt,
    vectorClock: const VectorClock({'host': 1}),
    originatingHostId: 'host',
  );
}

NotificationEntity _notification({
  required String id,
  String linkedTaskId = 'task-id',
  DateTime? scheduledFor,
  DateTime? seenAt,
  DateTime? actedOnAt,
  DateTime? deletedAt,
}) {
  return NotificationEntity.taskOverdue(
    meta: _meta(
      id: id,
      scheduledFor: scheduledFor,
      seenAt: seenAt,
      actedOnAt: actedOnAt,
      deletedAt: deletedAt,
    ),
    linkedTaskId: linkedTaskId,
    title: 'Due title',
    body: 'Due body',
  );
}

NotificationEntity _suggestion({
  required String id,
  String linkedTaskId = 'task-id',
  DateTime? scheduledFor,
}) {
  return NotificationEntity.taskSuggestion(
    meta: _meta(id: id, scheduledFor: scheduledFor),
    linkedTaskId: linkedTaskId,
    suggestionCount: 2,
    title: 'Due title',
    body: 'Due body',
  );
}

NotificationEntity _checkIn({
  required String id,
  String linkedRelationshipId = 'rel-id',
  DateTime? scheduledFor,
  DateTime? seenAt,
}) {
  return NotificationEntity.relationshipCheckIn(
    meta: _meta(id: id, scheduledFor: scheduledFor, seenAt: seenAt),
    linkedRelationshipId: linkedRelationshipId,
    title: 'Due title',
    body: 'Due body',
  );
}
