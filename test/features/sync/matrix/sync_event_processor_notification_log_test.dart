// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

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

  group('SyncEventProcessor - Notification sequence log', () {
    late NotificationsDb notificationsDb;
    late MockNotificationScheduler scheduler;
    late MockSyncSequenceLogService sequenceLog;
    late SyncEventProcessor processorWithLog;

    setUp(() {
      sequenceLog = MockSyncSequenceLogService();
      hStubRecordReceived(sequenceLog);
      final bench = buildNotificationProcessor(sequenceLogService: sequenceLog);
      notificationsDb = bench.db;
      scheduler = bench.scheduler;

      processorWithLog = bench.processor;
    });

    tearDown(() async {
      await notificationsDb.close();
    });

    test(
      'records full notification receipt and traces detected gaps',
      () async {
        when(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
            jsonPath: any(named: 'jsonPath'),
          ),
        ).thenAnswer(
          (_) async => [(hostId: 'remote-host', counter: 5)],
        );

        final notification = hNotification(
          id: 'with-receipt',
          linkedTaskId: 'task-1',
        );
        final message = SyncMessage.notification(
          id: notification.meta.id,
          jsonPath: '/notifications/with-receipt.json',
          vectorClock: notification.meta.vectorClock,
          originatingHostId: 'remote-host',
        );

        await processorWithLog.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: message,
            resolvedNotification: notification,
          ),
          journalDb: journalDb,
        );

        verify(
          () => sequenceLog.recordReceivedEntry(
            entryId: notification.meta.id,
            vectorClock: notification.meta.vectorClock,
            originatingHostId: 'remote-host',
            coveredVectorClocks: null,
            payloadType: SyncSequencePayloadType.notification,
            jsonPath: '/notifications/with-receipt.json',
          ),
        ).called(1);
      },
    );

    test(
      'traces detected gaps on notification state update receipt',
      () async {
        when(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer(
          (_) async => [(hostId: 'remote-host', counter: 7)],
        );

        await notificationsDb.upsertNotification(
          hNotification(id: 'state-gap', linkedTaskId: 'task-1'),
        );

        await processorWithLog.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: SyncMessage.notificationStateUpdate(
              id: 'state-gap',
              seenAt: DateTime.utc(2026, 5, 17, 14),
              vectorClock: const VectorClock({'remote-host': 5}),
              originatingHostId: 'remote-host',
            ),
          ),
          journalDb: journalDb,
        );

        verify(
          () => sequenceLog.recordReceivedEntry(
            entryId: 'state-gap',
            vectorClock: const VectorClock({'remote-host': 5}),
            originatingHostId: 'remote-host',
            payloadType: SyncSequencePayloadType.notificationStateUpdate,
          ),
        ).called(1);
      },
    );

    test(
      'records state update receipt for changed rows',
      () async {
        await notificationsDb.upsertNotification(
          hNotification(id: 'state-receipt', linkedTaskId: 'task-1'),
        );

        await processorWithLog.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: SyncMessage.notificationStateUpdate(
              id: 'state-receipt',
              seenAt: DateTime.utc(2026, 5, 17, 13),
              vectorClock: const VectorClock({'remote-host': 2}),
              originatingHostId: 'remote-host',
            ),
          ),
          journalDb: journalDb,
        );

        verify(
          () => sequenceLog.recordReceivedEntry(
            entryId: 'state-receipt',
            vectorClock: const VectorClock({'remote-host': 2}),
            originatingHostId: 'remote-host',
            payloadType: SyncSequencePayloadType.notificationStateUpdate,
          ),
        ).called(1);
      },
    );

    test(
      'db-not-wired notification still records the receipt',
      () async {
        final processorNoDb = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: sequenceLog,
        );

        await processorNoDb.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: const SyncMessage.notification(
              id: 'no-db',
              jsonPath: '/notifications/no-db.json',
              vectorClock: VectorClock({'remote-host': 1}),
              originatingHostId: 'remote-host',
            ),
            resolvedNotification: null,
          ),
          journalDb: journalDb,
        );

        verify(
          () => sequenceLog.recordReceivedEntry(
            entryId: 'no-db',
            vectorClock: const VectorClock({'remote-host': 1}),
            originatingHostId: 'remote-host',
            coveredVectorClocks: null,
            payloadType: SyncSequencePayloadType.notification,
            jsonPath: '/notifications/no-db.json',
          ),
        ).called(1);
      },
    );

    test(
      'db-not-wired state update still records the receipt',
      () async {
        final processorNoDb = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: sequenceLog,
        );

        await processorNoDb.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: const SyncMessage.notificationStateUpdate(
              id: 'no-db-state',
              vectorClock: VectorClock({'remote-host': 1}),
              originatingHostId: 'remote-host',
            ),
          ),
          journalDb: journalDb,
        );

        verify(
          () => sequenceLog.recordReceivedEntry(
            entryId: 'no-db-state',
            vectorClock: const VectorClock({'remote-host': 1}),
            originatingHostId: 'remote-host',
            payloadType: SyncSequencePayloadType.notificationStateUpdate,
          ),
        ).called(1);
      },
    );

    test(
      'captures and swallows recordReceivedEntry exceptions',
      () async {
        when(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
            jsonPath: any(named: 'jsonPath'),
          ),
        ).thenThrow(Exception('boom'));

        final notification = hNotification(
          id: 'throwing-receipt',
          linkedTaskId: 'task-1',
        );

        await processorWithLog.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: SyncMessage.notification(
              id: notification.meta.id,
              jsonPath: '/notifications/throwing-receipt.json',
              vectorClock: notification.meta.vectorClock,
              originatingHostId: 'remote-host',
            ),
            resolvedNotification: notification,
          ),
          journalDb: journalDb,
        );

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'recordReceived',
          ),
        ).called(1);
      },
    );

    test(
      'captures and swallows state update recordReceivedEntry exceptions',
      () async {
        await notificationsDb.upsertNotification(
          hNotification(id: 'state-throwing', linkedTaskId: 'task-1'),
        );
        when(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('state boom'));

        await processorWithLog.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: SyncMessage.notificationStateUpdate(
              id: 'state-throwing',
              seenAt: DateTime.utc(2026, 5, 17, 14),
              vectorClock: const VectorClock({'remote-host': 3}),
              originatingHostId: 'remote-host',
            ),
          ),
          journalDb: journalDb,
        );

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'recordReceived',
          ),
        ).called(1);
      },
    );

    group('resolveNotification via process()', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('notification_resolve');
        if (getIt.isRegistered<Directory>()) getIt.unregister<Directory>();
        getIt.registerSingleton<Directory>(tempDir);
      });

      tearDown(() async {
        await getIt.reset();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
        'resolves and applies a SyncNotification with on-disk JSON payload',
        () async {
          final notification = hNotification(
            id: 'resolved-from-disk',
            linkedTaskId: 'task-1',
          );

          const relativePath = '/notifications/resolved-from-disk.json';
          final file = File(
            path.join(tempDir.path, 'notifications', 'resolved-from-disk.json'),
          );
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(notification.toJson()));

          final message = SyncMessage.notification(
            id: notification.meta.id,
            jsonPath: relativePath,
            vectorClock: notification.meta.vectorClock,
            originatingHostId: 'remote-host',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processorWithLog.process(event: event, journalDb: journalDb);

          expect(
            await notificationsDb.notificationById(notification.meta.id),
            notification,
          );
          verify(() => scheduler.schedule(notification)).called(1);
        },
      );
    });

    test(
      'skips receipt entirely when originatingHostId is empty',
      () async {
        final notification = hNotification(
          id: 'no-origin',
          linkedTaskId: 'task-1',
        );

        await processorWithLog.apply(
          prepared: PreparedSyncEvent.forTesting(
            event: event,
            syncMessage: SyncMessage.notification(
              id: notification.meta.id,
              jsonPath: '/notifications/no-origin.json',
              vectorClock: notification.meta.vectorClock,
              originatingHostId: '',
            ),
            resolvedNotification: notification,
          ),
          journalDb: journalDb,
        );

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
      },
    );
  });
}
