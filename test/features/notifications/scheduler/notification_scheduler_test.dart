import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockNotificationService notificationService;
  late NotificationScheduler scheduler;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    notificationService = MockNotificationService();
    scheduler = NotificationScheduler(
      notificationServiceProvider: () => notificationService,
    );

    _stubNotificationService(notificationService);
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
  DateTime? actedOnAt,
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
      actedOnAt: actedOnAt,
      deletedAt: deletedAt,
      vectorClock: const VectorClock({'host': 1}),
      originatingHostId: 'host',
    ),
    linkedTaskId: linkedTaskId,
    title: 'Due title',
    body: 'Due body',
  );
}
