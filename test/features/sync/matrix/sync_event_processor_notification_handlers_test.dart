// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_event_processor_notification_handlers_test_helpers.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  /// Builds the in-memory NotificationsDb + scheduler + processor trio used
  /// by both groups; only the optional sequence log differs.
  ({
    NotificationsDb db,
    MockNotificationScheduler scheduler,
    SyncEventProcessor processor,
  })
  buildNotificationProcessor({SyncSequenceLogService? sequenceLogService}) {
    final db = NotificationsDb(inMemoryDatabase: true, background: false);
    final scheduler = MockNotificationScheduler();
    when(
      () => scheduler.schedule(any<NotificationEntity>()),
    ).thenAnswer((_) async {});
    final processor = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      settingsDb: settingsDb,
      journalEntityLoader: journalEntityLoader,
      notificationsDb: db,
      notificationScheduler: scheduler,
      sequenceLogService: sequenceLogService,
    );
    return (db: db, scheduler: scheduler, processor: processor);
  }

  group('SyncEventProcessor - Notifications', () {
    late NotificationsDb notificationsDb;
    late MockNotificationScheduler scheduler;
    late SyncEventProcessor notificationProcessor;

    setUp(() {
      final bench = buildNotificationProcessor();
      notificationsDb = bench.db;
      scheduler = bench.scheduler;
      notificationProcessor = bench.processor;
    });

    tearDown(() async {
      await notificationsDb.close();
    });

    test('applies full notification payloads into notifications DB', () async {
      final notification = hNotification(
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
        final base = hNotification(
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

    test(
      'notification apply without resolved payload defers without receipt',
      () async {
        final sequenceLog = MockSyncSequenceLogService();
        hStubRecordReceived(sequenceLog);

        final processorWithLog = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          notificationsDb: notificationsDb,
          notificationScheduler: scheduler,
          sequenceLogService: sequenceLog,
        );

        await processorWithLog.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: const SyncMessage.notification(
              id: 'deferred',
              jsonPath: '/notifications/deferred.json',
              vectorClock: VectorClock({'remote-host': 1}),
              originatingHostId: 'remote-host',
            ),
          ),
          journalDb: journalDb,
        );

        // No receipt, no upsert, no scheduling — the queue should retry once
        // the attachment lands.
        verifyNever(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
            jsonPath: any(named: 'jsonPath'),
          ),
        );
        verifyNever(() => scheduler.schedule(any<NotificationEntity>()));
      },
    );
  });
}
