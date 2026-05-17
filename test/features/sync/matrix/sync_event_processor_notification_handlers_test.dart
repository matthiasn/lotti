// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  group('SyncEventProcessor - Notifications', () {
    late NotificationsDb notificationsDb;
    late MockNotificationScheduler scheduler;
    late SyncEventProcessor notificationProcessor;

    setUp(() {
      notificationsDb = NotificationsDb(
        inMemoryDatabase: true,
        background: false,
      );
      scheduler = MockNotificationScheduler();
      when(
        () => scheduler.schedule(any<NotificationEntity>()),
      ).thenAnswer((_) async {});

      notificationProcessor = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        notificationsDb: notificationsDb,
        notificationScheduler: scheduler,
      );
    });

    tearDown(() async {
      await notificationsDb.close();
    });

    test('applies full notification payloads into notifications DB', () async {
      final notification = _notification(
        id: 'notification-id',
        linkedTaskId: 'task-1',
      );
      final message = SyncMessage.notification(
        id: notification.meta.id,
        jsonPath: '/notifications/notification-id.json',
        vectorClock: notification.meta.vectorClock,
        originatingHostId: 'remote-host',
      );

      await notificationProcessor.apply(
        prepared: PreparedSyncEvent.forTesting(
          event: event,
          syncMessage: message,
          resolvedNotification: notification,
        ),
        journalDb: journalDb,
      );

      expect(
        await notificationsDb.notificationById(notification.meta.id),
        notification,
      );
      verify(() => scheduler.schedule(notification)).called(1);
      verify(
        () => updateNotifications.notify(
          {notification.meta.id, 'task-1', inboxNotification},
          fromSync: true,
        ),
      ).called(1);
    });

    test(
      'applies notification state updates and reschedules changed rows',
      () async {
        final base = _notification(
          id: 'notification-id',
          linkedTaskId: 'task-1',
        );
        final seenAt = DateTime.utc(2026, 5, 17, 12);
        await notificationsDb.upsertNotification(base);

        await notificationProcessor.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: SyncMessage.notificationStateUpdate(
              id: base.meta.id,
              seenAt: seenAt,
              vectorClock: const VectorClock({'remote-host': 2}),
              originatingHostId: 'remote-host',
            ),
          ),
          journalDb: journalDb,
        );

        final updated = await notificationsDb.notificationById(base.meta.id);
        expect(updated?.meta.seenAt, seenAt);
        expect(
          updated?.meta.vectorClock,
          const VectorClock({'local-host': 1, 'remote-host': 2}),
        );
        final scheduled =
            verify(
                  () => scheduler.schedule(captureAny<NotificationEntity>()),
                ).captured.single
                as NotificationEntity;
        expect(scheduled.meta.seenAt, seenAt);
        verify(
          () => updateNotifications.notify(
            {base.meta.id, 'task-1', inboxNotification},
            fromSync: true,
          ),
        ).called(1);
      },
    );

    test('state update without base notification remains retriable', () async {
      await expectLater(
        notificationProcessor.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: const SyncMessage.notificationStateUpdate(
              id: 'missing-notification',
              seenAt: null,
              vectorClock: VectorClock({'remote-host': 1}),
              originatingHostId: 'remote-host',
            ),
          ),
          journalDb: journalDb,
        ),
        throwsA(isA<FileSystemException>()),
      );

      verifyNever(() => scheduler.schedule(any<NotificationEntity>()));
      verifyNever(
        () => updateNotifications.notify(
          any<Set<String>>(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });
  });
}

NotificationEntity _notification({
  required String id,
  required String linkedTaskId,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'local-host': 1}),
      originatingHostId: 'local-host',
    ),
    linkedTaskId: linkedTaskId,
    suggestionCount: 2,
    title: 'Review suggestions',
    body: 'Two tasks need review',
  );
}
