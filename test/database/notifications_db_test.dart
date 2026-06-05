import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  late NotificationsDb db;

  setUp(() {
    db = NotificationsDb(inMemoryDatabase: true, background: false);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotificationsDb', () {
    test('forLinkedEntity returns empty list for unknown task id', () async {
      await db.upsertNotification(
        _notification(
          id: 'other',
          createdAt: DateTime.utc(2026, 5, 17, 10),
          updatedAt: DateTime.utc(2026, 5, 17, 10),
          scheduledFor: DateTime.utc(2026, 5, 17, 12),
          linkedTaskId: 'task-1',
        ),
      );

      expect(await db.forLinkedEntity('no-such-task'), isEmpty);
    });

    test('persists notifications and filters due/upcoming rows', () async {
      final now = DateTime.utc(2026, 5, 17, 10);
      final due = _notification(
        id: 'due',
        linkedTaskId: 'task-1',
        scheduledFor: now.subtract(const Duration(minutes: 5)),
      );
      final upcoming = _notification(
        id: 'upcoming',
        linkedTaskId: 'task-1',
        scheduledFor: now.add(const Duration(hours: 1)),
      );
      final seen = _notification(
        id: 'seen',
        linkedTaskId: 'task-2',
        scheduledFor: now.subtract(const Duration(minutes: 1)),
        seenAt: now,
      );

      await db.upsertNotification(due);
      await db.upsertNotification(upcoming);
      await db.upsertNotification(seen);

      expect(await db.notificationById('due'), due);
      expect(
        (await db.dueNow(now)).map((entity) => entity.id),
        ['due'],
      );
      expect(
        (await db.upcoming(now)).map((entity) => entity.id),
        ['upcoming'],
      );
      expect(await db.unseenCount(now), 1);
      expect(await db.countAllNotifications(), 3);
      expect(
        (await db.forLinkedEntity('task-1')).map((entity) => entity.id),
        ['upcoming', 'due'],
      );
    });

    test(
      'upsert keeps latest content while merging state and clocks',
      () async {
        final createdAt = DateTime.utc(2026, 5, 17, 8);
        final existing = _notification(
          id: 'merge-me',
          createdAt: createdAt,
          updatedAt: DateTime.utc(2026, 5, 17, 10),
          scheduledFor: DateTime.utc(2026, 5, 17, 12),
          title: 'Original title',
          body: 'Original body',
          seenAt: DateTime.utc(2026, 5, 17, 14),
        );
        final olderIncoming = _notification(
          id: 'merge-me',
          createdAt: createdAt,
          updatedAt: DateTime.utc(2026, 5, 17, 9),
          scheduledFor: DateTime.utc(2026, 5, 17, 11),
          title: 'Older title',
          body: 'Older body',
          actedOnAt: DateTime.utc(2026, 5, 17, 13),
          vectorClock: const VectorClock({'remote': 2}),
        );
        final newerIncoming = _notification(
          id: 'merge-me',
          createdAt: createdAt,
          updatedAt: DateTime.utc(2026, 5, 17, 11),
          scheduledFor: DateTime.utc(2026, 5, 17, 16),
          title: 'Newer title',
          body: 'Newer body',
          seenAt: DateTime.utc(2026, 5, 17, 15),
          deletedAt: DateTime.utc(2026, 5, 17, 17),
          vectorClock: const VectorClock({'local': 2, 'remote': 1}),
        );

        await db.upsertNotification(existing);
        final afterOlder = await db.upsertNotification(olderIncoming);

        expect(afterOlder?.title, 'Original title');
        expect(afterOlder?.body, 'Original body');
        expect(afterOlder?.meta.seenAt, DateTime.utc(2026, 5, 17, 14));
        expect(afterOlder?.meta.actedOnAt, DateTime.utc(2026, 5, 17, 13));
        expect(
          afterOlder?.meta.vectorClock,
          const VectorClock({'local': 1, 'remote': 2}),
        );

        final afterNewer = await db.upsertNotification(newerIncoming);

        expect(afterNewer?.title, 'Newer title');
        expect(afterNewer?.body, 'Newer body');
        expect(afterNewer?.meta.scheduledFor, DateTime.utc(2026, 5, 17, 16));
        expect(afterNewer?.meta.seenAt, DateTime.utc(2026, 5, 17, 14));
        expect(afterNewer?.meta.actedOnAt, DateTime.utc(2026, 5, 17, 13));
        expect(afterNewer?.meta.deletedAt, DateTime.utc(2026, 5, 17, 17));
        expect(
          afterNewer?.meta.vectorClock,
          const VectorClock({'local': 2, 'remote': 2}),
        );
      },
    );

    test(
      'mergeState preserves the earliest non-null state timestamps',
      () async {
        final missing = await db.mergeState(
          id: 'missing',
          seenAt: DateTime.utc(2026, 5, 17, 10),
        );
        expect(missing.isMissing, isTrue);
        expect(missing.changed, isFalse);

        await db.upsertNotification(_notification(id: 'stateful'));

        final first = await db.mergeState(
          id: 'stateful',
          seenAt: DateTime.utc(2026, 5, 17, 13),
          actedOnAt: DateTime.utc(2026, 5, 17, 14),
          vectorClock: const VectorClock({'remote': 1}),
          originatingHostId: 'remote',
        );
        final second = await db.mergeState(
          id: 'stateful',
          seenAt: DateTime.utc(2026, 5, 17, 15),
          actedOnAt: DateTime.utc(2026, 5, 17, 12),
          deletedAt: DateTime.utc(2026, 5, 17, 16),
          vectorClock: const VectorClock({'remote': 2, 'other': 1}),
          originatingHostId: 'other',
        );
        final unchanged = await db.mergeState(
          id: 'stateful',
          seenAt: DateTime.utc(2026, 5, 17, 18),
        );

        expect(first.changed, isTrue);
        expect(second.changed, isTrue);
        expect(unchanged.changed, isFalse);
        expect(second.entity?.meta.seenAt, DateTime.utc(2026, 5, 17, 13));
        expect(second.entity?.meta.actedOnAt, DateTime.utc(2026, 5, 17, 12));
        expect(second.entity?.meta.deletedAt, DateTime.utc(2026, 5, 17, 16));
        expect(
          second.entity?.meta.vectorClock,
          const VectorClock({'local': 1, 'remote': 2, 'other': 1}),
        );
        expect(second.entity?.meta.originatingHostId, 'other');
      },
    );

    test('streams vector clocks in deterministic batches', () async {
      await db.upsertNotification(
        _notification(
          id: 'a',
          vectorClock: const VectorClock({'a-host': 1}),
        ),
      );
      await db.upsertNotification(
        _notification(
          id: 'b',
          vectorClock: const VectorClock({'b-host': 2}),
        ),
      );

      final batches = await db
          .streamNotificationsWithVectorClock(batchSize: 1)
          .toList();

      expect(batches, hasLength(2));
      expect(batches.first.single.id, 'a');
      expect(batches.first.single.vectorClock, {'a-host': 1});
      expect(batches.last.single.id, 'b');
      expect(batches.last.single.vectorClock, {'b-host': 2});
    });

    test(
      'keyset pagination walks every row exactly once with multi-row batches',
      () async {
        for (var i = 0; i < 7; i++) {
          // ids are lexicographically ordered so keyset seek `id > lastId` is
          // monotonic. Mixing widths exercises the comparator beyond plain int
          // ordering.
          final id = i.toString().padLeft(2, '0');
          await db.upsertNotification(
            _notification(
              id: id,
              vectorClock: VectorClock({'host-$i': i}),
            ),
          );
        }

        final batches = await db
            .streamNotificationsWithVectorClock(batchSize: 3)
            .toList();

        // 7 rows / batchSize=3 → batches of 3, 3, 1.
        expect(batches.map((b) => b.length).toList(), [3, 3, 1]);
        final ids = [for (final batch in batches) ...batch.map((r) => r.id)];
        expect(ids, ['00', '01', '02', '03', '04', '05', '06']);
      },
    );
  });
}

NotificationEntity _notification({
  required String id,
  String linkedTaskId = 'task-id',
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? scheduledFor,
  DateTime? seenAt,
  DateTime? actedOnAt,
  DateTime? deletedAt,
  VectorClock vectorClock = const VectorClock({'local': 1}),
  String title = 'Task reminder',
  String body = 'Review this task',
}) {
  final created = createdAt ?? DateTime.utc(2026, 5, 17, 9);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: created,
      updatedAt: updatedAt ?? created,
      scheduledFor: scheduledFor ?? DateTime.utc(2026, 5, 17, 12),
      seenAt: seenAt,
      actedOnAt: actedOnAt,
      deletedAt: deletedAt,
      vectorClock: vectorClock,
      originatingHostId: 'local',
    ),
    linkedTaskId: linkedTaskId,
    suggestionCount: 1,
    title: title,
    body: body,
  );
}
