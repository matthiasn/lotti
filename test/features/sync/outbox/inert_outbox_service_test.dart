import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/inert_outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  late InertOutboxService service;

  final notification = NotificationEntity.taskOverdue(
    meta: NotificationMeta(
      id: 'n1',
      createdAt: DateTime(2026, 8, 5),
      updatedAt: DateTime(2026, 8, 5),
      scheduledFor: DateTime(2026, 8, 6),
      vectorClock: const VectorClock({'host': 1}),
      originatingHostId: 'host',
    ),
    linkedTaskId: 'task-1',
    title: 'Overdue',
    body: 'Task is overdue',
  );

  setUp(() {
    service = InertOutboxService();
  });

  tearDown(() async {
    await service.dispose();
  });

  group('InertOutboxService', () {
    test('enqueueMessage swallows the message and only counts it', () async {
      await service.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'demo-entry',
          jsonPath: '/text_entries/demo-entry.json',
          vectorClock: VectorClock({'host': 1}),
          status: SyncEntryStatus.initial,
        ),
      );

      expect(service.enqueueAttempts, 1);
    });

    test('enqueueMessageOrThrow never throws in a guest world', () async {
      await expectLater(
        service.enqueueMessageOrThrow(
          const SyncMessage.journalEntity(
            id: 'demo-entry',
            jsonPath: '/text_entries/demo-entry.json',
            vectorClock: VectorClock({'host': 1}),
            status: SyncEntryStatus.update,
          ),
        ),
        completes,
      );
      expect(service.enqueueAttempts, 1);
    });

    test('enqueueNotification writes no payload file and counts', () async {
      await service.enqueueNotification(notification);

      expect(service.enqueueAttempts, 1);
    });

    test('enqueueNotificationStateUpdate is a counted no-op', () async {
      await service.enqueueNotificationStateUpdate(
        id: 'n1',
        vectorClock: const VectorClock({'host': 1}),
        originatingHostId: 'host',
        seenAt: DateTime(2026),
      );

      expect(service.enqueueAttempts, 1);
    });

    test('notLoggedInGateStream never emits, so no demo-mode toasts', () {
      fakeAsync((async) {
        var events = 0;
        service.notLoggedInGateStream.listen((_) => events++);

        for (var i = 0; i < 5; i++) {
          service.enqueueMessage(
            SyncMessage.journalEntity(
              id: 'demo-$i',
              jsonPath: '/text_entries/demo-$i.json',
              vectorClock: const VectorClock({'host': 1}),
              status: SyncEntryStatus.update,
            ),
          );
        }
        async
          ..elapse(const Duration(minutes: 5))
          ..flushMicrotasks();

        expect(events, 0);
        expect(service.enqueueAttempts, 5);
      });
    });

    test('dispose closes the gate stream', () async {
      await service.dispose();

      await expectLater(
        service.notLoggedInGateStream.isEmpty,
        completion(isTrue),
      );
    });
  });
}
