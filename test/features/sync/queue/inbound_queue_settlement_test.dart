import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'test_utils.dart';

/// The rule book itself; the ladders' arithmetic is pinned by the worker
/// tests, which drive it through the in-process gateway.
void main() {
  const roomId = '!room:example.org';
  late SyncDatabase db;
  late InboundQueue queue;
  late InboundQueueSettlement settlement;

  setUpAll(() => registerFallbackValue(StackTrace.empty));

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    queue = InboundQueue(
      trust: AdmittingSyncEventTrust(),
      db: db,
      logging: MockDomainLogger(),
    );
    settlement = InboundQueueSettlement(queue: queue, maxAttempts: 3);
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  Future<List<InboundQueueEntry>> enqueueAndLease(List<String> ids) async {
    for (final (i, id) in ids.indexed) {
      await queue.enqueueLive(
        buildSyncEvent(eventId: id, roomId: roomId, originTsMs: i + 1),
      );
    }
    return queue.peekBatchReady(maxBatch: ids.length);
  }

  Future<Map<String, String>> statuses() async {
    final rows = await db.select(db.inboundEventQueue).get();
    return {for (final r in rows) r.eventId: r.status};
  }

  test(
    'records a mixed batch in one pass and counts what was applied',
    () async {
      final [a, b, c, d] = await enqueueAndLease([r'$a', r'$b', r'$c', r'$d']);

      final applied = await settlement.settle([
        InboundEntryOutcome(a, ApplyOutcome.applied),
        InboundEntryOutcome(b, ApplyOutcome.retriable),
        InboundEntryOutcome(c, ApplyOutcome.permanentSkip),
        InboundEntryOutcome(d, ApplyOutcome.undecodable),
      ]);

      expect(applied, 1);
      expect(await statuses(), {
        r'$a': InboundQueueStatuses.applied,
        r'$b': InboundQueueStatuses.retrying,
        r'$c': InboundQueueStatuses.abandoned,
        r'$d': InboundQueueStatuses.abandoned,
      });
      final rows = await db.select(db.inboundEventQueue).get();
      final reasons = {for (final r in rows) r.eventId: r.lastErrorReason};
      expect(reasons[r'$c'], 'permanentSkip');
      expect(reasons[r'$d'], undecodableReason);
      expect(reasons[r'$b'], RetryReason.retriable.name);
    },
  );

  test(
    'a generic retry past the attempt budget is abandoned with its reason',
    () async {
      final [entry] = await enqueueAndLease([r'$tired']);
      final spent = InboundQueueEntry(
        queueId: entry.queueId,
        eventId: entry.eventId,
        roomId: entry.roomId,
        originTs: entry.originTs,
        enqueuedAt: entry.enqueuedAt,
        attempts: 2,
        rawJson: entry.rawJson,
      );

      await settlement.settle([
        InboundEntryOutcome(spent, ApplyOutcome.missingBase),
      ]);

      final row = await db.select(db.inboundEventQueue).getSingle();
      expect(row.status, InboundQueueStatuses.abandoned);
      expect(row.lastErrorReason, 'maxAttempts(missingBase)');
    },
  );

  test(
    'a barrier is never abandoned for attempts, only re-scheduled',
    () async {
      final [entry] = await enqueueAndLease([r'$barrier']);
      final spent = InboundQueueEntry(
        queueId: entry.queueId,
        eventId: entry.eventId,
        roomId: entry.roomId,
        originTs: entry.originTs,
        enqueuedAt: entry.enqueuedAt,
        attempts: 500,
        rawJson: entry.rawJson,
      );

      await settlement.settle([
        InboundEntryOutcome(spent, ApplyOutcome.pendingBarrier),
      ]);

      final row = await db.select(db.inboundEventQueue).getSingle();
      expect(row.status, InboundQueueStatuses.retrying);
      expect(row.attempts, 501);
    },
  );

  test(
    'an attachment still missing after its wall-clock grace is abandoned',
    () async {
      var now = DateTime(2026, 10, 24, 12);
      await withClock(Clock(() => now), () async {
        final [entry] = await enqueueAndLease([r'$media']);
        now = now.add(const Duration(minutes: 11));

        await settlement.settle([
          InboundEntryOutcome(entry, ApplyOutcome.pendingAttachment),
        ]);
      });

      final row = await db.select(db.inboundEventQueue).getSingle();
      expect(row.status, InboundQueueStatuses.abandoned);
      expect(row.lastErrorReason, 'pendingAttachmentTimeout');
    },
  );

  test(
    'the whole batch is one transaction: nothing lands if one write fails',
    () async {
      final [a, b] = await enqueueAndLease([r'$a', r'$b']);
      await db.customStatement('''
      CREATE TRIGGER refuse_abandon BEFORE UPDATE OF status ON inbound_event_queue
      WHEN NEW.status = 'abandoned'
      BEGIN SELECT RAISE(ABORT, 'no abandoning today'); END
    ''');

      await expectLater(
        settlement.settle([
          InboundEntryOutcome(a, ApplyOutcome.applied),
          InboundEntryOutcome(b, ApplyOutcome.permanentSkip),
        ]),
        throwsA(anything),
      );

      // The applied row rolled back with the refused one.
      expect(await statuses(), {
        r'$a': InboundQueueStatuses.leased,
        r'$b': InboundQueueStatuses.leased,
      });
    },
  );
}
