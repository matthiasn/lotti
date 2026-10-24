import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_gateway.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'test_utils.dart';

void main() {
  const roomId = '!room:example.org';
  late SyncDatabase db;
  late InboundQueue queue;
  late LocalInboundQueueGateway gateway;

  setUpAll(() => registerFallbackValue(StackTrace.empty));

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    queue = InboundQueue(
      trust: AdmittingSyncEventTrust(),
      db: db,
      logging: MockDomainLogger(),
    );
    gateway = LocalInboundQueueGateway(
      queue: queue,
      settlement: InboundQueueSettlement(queue: queue),
    );
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  test('leases the oldest ready rows, which stop being ready', () async {
    await queue.enqueueLive(
      buildSyncEvent(eventId: r'$late', roomId: roomId, originTsMs: 20),
    );
    await queue.enqueueLive(
      buildSyncEvent(eventId: r'$early', roomId: roomId, originTsMs: 10),
    );

    final first = await gateway.lease(maxBatch: 1);
    final second = await gateway.lease(maxBatch: 5);
    final third = await gateway.lease(maxBatch: 5);

    expect(first.map((e) => e.eventId), [r'$early']);
    expect(second.map((e) => e.eventId), [r'$late']);
    expect(third, isEmpty);
  });

  test(
    'settling applies through the shared rules and reports the count',
    () async {
      await queue.enqueueLive(
        buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
      );
      await queue.enqueueLive(
        buildSyncEvent(eventId: r'$b', roomId: roomId, originTsMs: 2),
      );
      final [a, b] = await gateway.lease(maxBatch: 2);

      final applied = await gateway.settle([
        InboundEntryOutcome(a, ApplyOutcome.applied),
        InboundEntryOutcome(b, ApplyOutcome.retriable),
      ]);

      expect(applied, 1);
      final stats = await queue.stats();
      expect(stats.applied, 1);
      expect(stats.retrying, 1);
    },
  );

  test("reports the queue's next ready time and its changes", () async {
    expect(await gateway.earliestReadyAt(), isNull);
    final changes = <void>[];
    final sub = gateway.changes.listen(changes.add);
    addTearDown(sub.cancel);

    await queue.enqueueLive(
      buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
    );
    await pumpEventQueue();

    expect(await gateway.earliestReadyAt(), isNotNull);
    expect(changes, isNotEmpty);
  });
}
