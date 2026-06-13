import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/features/sync/queue/queue_marker_advancer.dart';

const _roomA = '!roomA:example.org';

InboundQueueEntry _entry({
  required int queueId,
  required String eventId,
  required int originTs,
  String roomId = _roomA,
}) => InboundQueueEntry(
  queueId: queueId,
  eventId: eventId,
  roomId: roomId,
  originTs: originTs,
  producer: InboundEventProducer.live,
  enqueuedAt: 1000,
  attempts: 0,
  leaseUntil: 0,
  rawJson: '{}',
);

void main() {
  late SyncDatabase db;
  late QueueMarkerAdvancer advancer;

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    advancer = QueueMarkerAdvancer(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertRow({
    required String eventId,
    required int originTs,
    String roomId = _roomA,
    String status = InboundQueueStatuses.enqueued,
  }) => db
      .into(db.inboundEventQueue)
      .insert(
        InboundEventQueueCompanion.insert(
          eventId: eventId,
          roomId: roomId,
          originTs: originTs,
          producer: InboundEventProducer.live.name,
          rawJson: '{}',
          enqueuedAt: 1000,
          status: Value(status),
        ),
      );

  Future<QueueMarkerItem?> readMarker([String roomId = _roomA]) => (db.select(
    db.queueMarkers,
  )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();

  /// Mirrors the caller-owned status flip: `commitApplied` moves the
  /// row out of the active set in the same transaction that advances
  /// the marker, so an already-committed row must not pin the clamp.
  Future<void> markApplied(int queueId) =>
      (db.update(
        db.inboundEventQueue,
      )..where((t) => t.queueId.equals(queueId))).write(
        const InboundEventQueueCompanion(
          status: Value(InboundQueueStatuses.applied),
        ),
      );

  group('advanceIfNewer', () {
    test('creates the marker with ts, durable event id and seq 1', () async {
      final queueId = await insertRow(eventId: r'$a', originTs: 5000);
      final advanced = await advancer.advanceIfNewer(
        _entry(queueId: queueId, eventId: r'$a', originTs: 5000),
      );
      expect(advanced, isTrue);
      final marker = await readMarker();
      expect(marker?.lastAppliedTs, 5000);
      expect(marker?.lastAppliedEventId, r'$a');
      expect(marker?.lastAppliedCommitSeq, 1);
    });

    test('older candidate than stored marker does not regress (F2)', () async {
      final newerId = await insertRow(eventId: r'$newer', originTs: 9000);
      await advancer.advanceIfNewer(
        _entry(queueId: newerId, eventId: r'$newer', originTs: 9000),
      );
      await markApplied(newerId);
      final olderId = await insertRow(eventId: r'$older', originTs: 4000);
      final advanced = await advancer.advanceIfNewer(
        _entry(queueId: olderId, eventId: r'$older', originTs: 4000),
      );
      expect(advanced, isFalse);
      final marker = await readMarker();
      expect(marker?.lastAppliedTs, 9000);
      expect(marker?.lastAppliedEventId, r'$newer');
      expect(marker?.lastAppliedCommitSeq, 1);
    });

    test(
      'older active row in the same room clamps the marker to '
      'oldestActive - 1 and leaves the event id slot null',
      () async {
        await insertRow(eventId: r'$older-active', originTs: 6000);
        final committingId = await insertRow(eventId: r'$c', originTs: 8000);
        final advanced = await advancer.advanceIfNewer(
          _entry(queueId: committingId, eventId: r'$c', originTs: 8000),
        );
        expect(advanced, isTrue);
        final marker = await readMarker();
        expect(marker?.lastAppliedTs, 5999);
        // A clamped advance does not correspond to a specific event.
        expect(marker?.lastAppliedEventId, isNull);
      },
    );

    test('abandoned and applied rows do not pin the marker', () async {
      await insertRow(
        eventId: r'$poison',
        originTs: 6000,
        status: InboundQueueStatuses.abandoned,
      );
      await insertRow(
        eventId: r'$done',
        originTs: 6500,
        status: InboundQueueStatuses.applied,
      );
      final committingId = await insertRow(eventId: r'$c', originTs: 8000);
      final advanced = await advancer.advanceIfNewer(
        _entry(queueId: committingId, eventId: r'$c', originTs: 8000),
      );
      expect(advanced, isTrue);
      final marker = await readMarker();
      expect(marker?.lastAppliedTs, 8000);
      expect(marker?.lastAppliedEventId, r'$c');
    });

    test('the committing row itself never pins the marker', () async {
      // The entry's own row is still `leased` mid-commit; the
      // excludeQueueId predicate must keep it out of the clamp probe.
      final queueId = await insertRow(
        eventId: r'$self',
        originTs: 7000,
        status: InboundQueueStatuses.leased,
      );
      final advanced = await advancer.advanceIfNewer(
        _entry(queueId: queueId, eventId: r'$self', originTs: 7000),
      );
      expect(advanced, isTrue);
      final marker = await readMarker();
      expect(marker?.lastAppliedTs, 7000);
      expect(marker?.lastAppliedEventId, r'$self');
    });

    test('active rows in other rooms do not clamp this room', () async {
      await insertRow(
        eventId: r'$elsewhere',
        originTs: 1,
        roomId: '!roomB:example.org',
      );
      final queueId = await insertRow(eventId: r'$c', originTs: 8000);
      final advanced = await advancer.advanceIfNewer(
        _entry(queueId: queueId, eventId: r'$c', originTs: 8000),
      );
      expect(advanced, isTrue);
      expect((await readMarker())?.lastAppliedTs, 8000);
      expect(await readMarker('!roomB:example.org'), isNull);
    });

    test(
      'equal timestamps tie-break on event id: lexically greater '
      'advances, lexically smaller does not',
      () async {
        final firstId = await insertRow(eventId: r'$b', originTs: 5000);
        await advancer.advanceIfNewer(
          _entry(queueId: firstId, eventId: r'$b', originTs: 5000),
        );
        await markApplied(firstId);

        final greaterId = await insertRow(eventId: r'$c', originTs: 5000);
        expect(
          await advancer.advanceIfNewer(
            _entry(queueId: greaterId, eventId: r'$c', originTs: 5000),
          ),
          isTrue,
        );
        await markApplied(greaterId);
        expect((await readMarker())?.lastAppliedEventId, r'$c');
        expect((await readMarker())?.lastAppliedCommitSeq, 2);

        final smallerId = await insertRow(eventId: r'$a', originTs: 5000);
        expect(
          await advancer.advanceIfNewer(
            _entry(queueId: smallerId, eventId: r'$a', originTs: 5000),
          ),
          isFalse,
        );
        expect((await readMarker())?.lastAppliedEventId, r'$c');
      },
    );

    test(
      r'placeholder (non-$) event id advances the ts but is never '
      'written into the durable event id slot',
      () async {
        final durableId = await insertRow(eventId: r'$durable', originTs: 3000);
        await advancer.advanceIfNewer(
          _entry(queueId: durableId, eventId: r'$durable', originTs: 3000),
        );
        await markApplied(durableId);
        final placeholderId = await insertRow(
          eventId: 'lotti-placeholder',
          originTs: 6000,
        );
        final advanced = await advancer.advanceIfNewer(
          _entry(
            queueId: placeholderId,
            eventId: 'lotti-placeholder',
            originTs: 6000,
          ),
        );
        expect(advanced, isTrue);
        final marker = await readMarker();
        expect(marker?.lastAppliedTs, 6000);
        // The previous durable id is preserved, not overwritten.
        expect(marker?.lastAppliedEventId, r'$durable');
      },
    );

    test('commit seq increments on every successful advance', () async {
      for (var i = 1; i <= 3; i++) {
        final queueId = await insertRow(
          eventId: '\$seq-$i',
          originTs: i * 1000,
        );
        await advancer.advanceIfNewer(
          _entry(queueId: queueId, eventId: '\$seq-$i', originTs: i * 1000),
        );
        await markApplied(queueId);
      }
      expect((await readMarker())?.lastAppliedCommitSeq, 3);
    });
  });
}
