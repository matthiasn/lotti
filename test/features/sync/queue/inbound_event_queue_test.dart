import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

Event _buildSyncEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
  String type = EventTypes.Message,
  Map<String, dynamic>? content,
}) {
  final event = _MockEvent();
  final eventContent = content ?? <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(type);
  when(() => event.content).thenReturn(eventContent);
  when(() => event.text).thenReturn('stub text');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': type,
    'content': eventContent,
  });
  return event;
}

void main() {
  late SyncDatabase db;
  late MockLoggingService logging;
  late InboundQueue queue;
  const roomA = '!roomA:example.org';
  const roomB = '!roomB:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockLoggingService();
    queue = InboundQueue(
      db: db,
      logging: logging,
      leaseDuration: const Duration(seconds: 1),
    );
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  group('enqueue', () {
    test('single live event inserted and counted', () async {
      final event = _buildSyncEvent(
        eventId: r'$e1',
        roomId: roomA,
        originTsMs: 1000,
      );
      final result = await queue.enqueueLive(event);
      expect(result.accepted, 1);
      expect(result.duplicatesDropped, 0);
      expect(result.filteredOutByType, 0);
      final stats = await queue.stats();
      expect(stats.total, 1);
      expect(stats.byProducer[InboundEventProducer.live], 1);
    });

    test('duplicate eventId silently dropped on insert', () async {
      final event = _buildSyncEvent(
        eventId: r'$dup',
        roomId: roomA,
        originTsMs: 2000,
      );
      await queue.enqueueLive(event);
      final result = await queue.enqueueLive(event);
      expect(result.accepted, 0);
      expect(result.duplicatesDropped, 1);
      final stats = await queue.stats();
      expect(stats.total, 1);
    });

    test(
      'non-payload events filtered out (F4)',
      () async {
        final event = _buildSyncEvent(
          eventId: r'$state',
          roomId: roomA,
          originTsMs: 3000,
          type: EventTypes.RoomName,
          content: <String, dynamic>{'name': 'Renamed'},
        );
        final result = await queue.enqueueLive(event);
        expect(result.accepted, 0);
        expect(result.filteredOutByType, 1);
        final stats = await queue.stats();
        expect(stats.total, 0);
      },
    );

    test(
      'encrypted events deferred — not enqueued (F3)',
      () async {
        final event = _buildSyncEvent(
          eventId: r'$enc',
          roomId: roomA,
          originTsMs: 4000,
          type: EventTypes.Encrypted,
          content: <String, dynamic>{
            'msgtype': syncMessageType,
            'algorithm': 'm.megolm.v1.aes-sha2',
          },
        );
        final result = await queue.enqueueLive(event);
        expect(result.accepted, 0);
        expect(result.deferredPendingDecryption, 1);
        final stats = await queue.stats();
        expect(stats.total, 0);
      },
    );

    test('batch insert attributes producer correctly', () async {
      final events = [
        _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 100),
        _buildSyncEvent(eventId: r'$b', roomId: roomA, originTsMs: 200),
        _buildSyncEvent(eventId: r'$c', roomId: roomA, originTsMs: 300),
      ];
      final result = await queue.enqueueBatch(
        events,
        producer: InboundEventProducer.bridge,
      );
      expect(result.accepted, 3);
      final stats = await queue.stats();
      expect(stats.byProducer[InboundEventProducer.bridge], 3);
    });
  });

  group('peekBatchReady', () {
    test('returns entries in origin_ts ascending order', () async {
      await queue.enqueueBatch(
        [
          _buildSyncEvent(eventId: r'$late', roomId: roomA, originTsMs: 3000),
          _buildSyncEvent(eventId: r'$early', roomId: roomA, originTsMs: 1000),
          _buildSyncEvent(eventId: r'$mid', roomId: roomA, originTsMs: 2000),
        ],
        producer: InboundEventProducer.live,
      );
      final batch = await queue.peekBatchReady();
      expect(batch.map((e) => e.eventId).toList(), [
        r'$early',
        r'$mid',
        r'$late',
      ]);
    });

    test(
      'stamps lease — peek twice returns empty until lease expires',
      () async {
        final frozen = DateTime.fromMillisecondsSinceEpoch(50_000);
        await withClock(Clock.fixed(frozen), () async {
          await queue.enqueueLive(
            _buildSyncEvent(eventId: r'$e', roomId: roomA, originTsMs: 1),
          );
          final first = await queue.peekBatchReady();
          expect(first, hasLength(1));
          final second = await queue.peekBatchReady();
          expect(second, isEmpty);
        });
        // Fast-forward past the 1s lease duration.
        await withClock(
          Clock.fixed(frozen.add(const Duration(seconds: 2))),
          () async {
            final third = await queue.peekBatchReady();
            expect(third, hasLength(1));
          },
        );
      },
    );
  });

  group('commitApplied (F2 + F5)', () {
    test('deletes row and advances marker on newer timestamp', () async {
      await queue.enqueueLive(
        _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 1000),
      );
      final batch = await queue.peekBatchReady();
      await queue.commitApplied(batch.single);
      final stats = await queue.stats();
      expect(stats.total, 0);
      final marker = await (db.select(
        db.queueMarkers,
      )..where((t) => t.roomId.equals(roomA))).getSingle();
      expect(marker.lastAppliedEventId, r'$a');
      expect(marker.lastAppliedTs, 1000);
      expect(marker.lastAppliedCommitSeq, 1);
    });

    test(
      'does not regress marker on out-of-order apply (F2)',
      () async {
        // Apply a newer event first, then an older one (live + bridge race).
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$newer', roomId: roomA, originTsMs: 5000),
        );
        final firstBatch = await queue.peekBatchReady();
        await queue.commitApplied(firstBatch.single);

        await queue.enqueueBatch(
          [
            _buildSyncEvent(
              eventId: r'$older',
              roomId: roomA,
              originTsMs: 1000,
            ),
          ],
          producer: InboundEventProducer.bridge,
        );
        final secondBatch = await queue.peekBatchReady();
        await queue.commitApplied(secondBatch.single);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingle();
        expect(marker.lastAppliedEventId, r'$newer');
        expect(marker.lastAppliedTs, 5000);
        // Commit sequence still bumps for diagnostics, but the marker
        // did not regress to the older event.
      },
    );

    test(
      'non-durable (placeholder) eventId does not overwrite last_applied_event_id',
      () async {
        // First commit a server-assigned event.
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$real', roomId: roomA, originTsMs: 1000),
        );
        final first = await queue.peekBatchReady();
        await queue.commitApplied(first.single);

        // Then a placeholder-id event with a newer timestamp.
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: 'lotti-placeholder-42',
            roomId: roomA,
            originTsMs: 2000,
          ),
        );
        final second = await queue.peekBatchReady();
        await queue.commitApplied(second.single);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingle();
        // Timestamp advances...
        expect(marker.lastAppliedTs, 2000);
        // ...but last_applied_event_id keeps the durable server id.
        expect(marker.lastAppliedEventId, r'$real');
      },
    );
  });

  group('scheduleRetry', () {
    test(
      'bumps attempts, pushes nextDueAt, releases lease',
      () async {
        final frozen = DateTime.fromMillisecondsSinceEpoch(100_000);
        await withClock(Clock.fixed(frozen), () async {
          await queue.enqueueLive(
            _buildSyncEvent(eventId: r'$r1', roomId: roomA, originTsMs: 1),
          );
          final batch = await queue.peekBatchReady();
          final entry = batch.single;
          await queue.scheduleRetry(
            entry,
            const Duration(seconds: 3),
            reason: RetryReason.retriable,
          );
          final row = await (db.select(
            db.inboundEventQueue,
          )..where((t) => t.queueId.equals(entry.queueId))).getSingle();
          expect(row.attempts, 1);
          expect(
            row.nextDueAt,
            frozen.millisecondsSinceEpoch + 3000,
          );
          expect(row.leaseUntil, 0);
        });
      },
    );
  });

  group('pruneStrandedEntries (F6)', () {
    test('deletes rows whose roomId does not match the current room', () async {
      await queue.enqueueLive(
        _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 1),
      );
      await queue.enqueueLive(
        _buildSyncEvent(eventId: r'$b', roomId: roomB, originTsMs: 2),
      );
      final removed = await queue.pruneStrandedEntries(roomA);
      expect(removed, 1);
      final stats = await queue.stats();
      expect(stats.total, 1);
    });
  });

  group('depthChanges', () {
    test(
      'emits after enqueue, commit, prune',
      () async {
        final depths = <int>[];
        final sub = queue.depthChanges.listen((s) => depths.add(s.total));
        final event = _buildSyncEvent(
          eventId: r'$depth',
          roomId: roomA,
          originTsMs: 1,
        );
        await queue.enqueueLive(event);
        final batch = await queue.peekBatchReady();
        await queue.commitApplied(batch.single);
        // Pump the event queue so the async depth emissions land.
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(depths, isNotEmpty);
        expect(depths.last, 0);
      },
    );
  });
}
