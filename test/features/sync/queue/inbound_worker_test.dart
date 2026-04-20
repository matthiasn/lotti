import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

class _MockRoom extends Mock implements Room {}

class _MockVectorClockService extends Mock implements VectorClockService {}

/// Spy wrapper around [SyncSequenceLogService] that counts invocations
/// of `runWithDeferredMissingEntries` so F1 (batch-level coalescing of
/// the nudge window) can be asserted without triggering a real gap.
class _SpySequenceLog extends SyncSequenceLogService {
  _SpySequenceLog({
    required super.syncDatabase,
    required super.vectorClockService,
    required super.loggingService,
  });

  int deferredWrapperCalls = 0;

  @override
  Future<T> runWithDeferredMissingEntries<T>(
    Future<T> Function() action,
  ) async {
    deferredWrapperCalls++;
    return super.runWithDeferredMissingEntries(action);
  }
}

Event _buildSyncEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
}) {
  final event = _MockEvent();
  final content = <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(EventTypes.Message);
  when(() => event.content).thenReturn(content);
  when(() => event.text).thenReturn('stub text');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': EventTypes.Message,
    'content': content,
  });
  return event;
}

void main() {
  late SyncDatabase db;
  late MockLoggingService logging;
  late InboundQueue queue;
  late _SpySequenceLog sequenceLog;
  late _MockRoom room;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockLoggingService();
    queue = InboundQueue(db: db, logging: logging);
    sequenceLog = _SpySequenceLog(
      syncDatabase: db,
      vectorClockService: _MockVectorClockService(),
      loggingService: logging,
    );
    room = _MockRoom();
    when(() => room.id).thenReturn(roomId);
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  InboundWorker buildWorker({
    required Future<ApplyOutcome> Function(InboundQueueEntry) apply,
  }) {
    return InboundWorker(
      queue: queue,
      sequenceLogService: sequenceLog,
      resolveRoom: () async => room,
      apply: (entry, _) => apply(entry),
      logging: logging,
      initialBackoff: const Duration(milliseconds: 10),
      maxBackoff: const Duration(milliseconds: 100),
      maxAttempts: 4,
    );
  }

  test(
    'drainToCompletion applies every queue entry exactly once and '
    'coalesces missing-entries nudges into ONE emission per batch (F1)',
    () async {
      final events = [
        _buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 100),
        _buildSyncEvent(eventId: r'$b', roomId: roomId, originTsMs: 200),
        _buildSyncEvent(eventId: r'$c', roomId: roomId, originTsMs: 300),
        _buildSyncEvent(eventId: r'$d', roomId: roomId, originTsMs: 400),
      ];
      await queue.enqueueBatch(events, producer: InboundEventProducer.live);

      final applied = <String>[];
      final worker = buildWorker(
        apply: (entry) async {
          applied.add(entry.eventId);
          return ApplyOutcome.applied;
        },
      );

      final appliedCount = await worker.drainToCompletion();
      expect(appliedCount, events.length);
      expect(applied, [r'$a', r'$b', r'$c', r'$d']);

      // Critical F1 assertion: the worker wraps the whole batch in
      // ONE deferred-nudges window, not one per event. A per-event
      // wrapping would be 4 here — the fragmentation the design
      // review flagged.
      expect(sequenceLog.deferredWrapperCalls, 1);
    },
  );

  test(
    'retriable outcome bumps attempts and re-queues with backoff',
    () async {
      // Drive the queue's `clock.now()` off a mutable virtual clock so
      // retry/backoff scheduling can be advanced without real sleeps
      // (see repo test guideline: no `Future.delayed`/real `Timer` in
      // tests). Initial backoff is 10ms, so virtual advances of 20ms
      // and 40ms comfortably cross attempt 2 (20ms) and attempt 3
      // (40ms) boundaries.
      var virtualNow = DateTime(2024);
      await withClock(Clock(() => virtualNow), () async {
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$retry',
            roomId: roomId,
            originTsMs: 42,
          ),
        );
        var attempt = 0;
        final worker = buildWorker(
          apply: (entry) async {
            attempt++;
            return attempt <= 2 ? ApplyOutcome.retriable : ApplyOutcome.applied;
          },
        );

        // Drain once: apply #1 is retriable, queue stays non-empty but
        // with nextDueAt in the future, so drainToCompletion returns 0.
        final firstApplied = await worker.drainToCompletion();
        expect(firstApplied, 0);

        // Cross the first backoff window in virtual time.
        virtualNow = virtualNow.add(const Duration(milliseconds: 20));
        final secondApplied = await worker.drainToCompletion();
        expect(secondApplied, 0); // Second attempt still retries.

        virtualNow = virtualNow.add(const Duration(milliseconds: 40));
        final thirdApplied = await worker.drainToCompletion();
        expect(thirdApplied, 1); // Third attempt succeeds.

        final stats = await queue.stats();
        expect(stats.total, 0);
      });
    },
  );

  test(
    'maxAttempts exceeds skips the entry permanently',
    () async {
      var virtualNow = DateTime(2024);
      await withClock(Clock(() => virtualNow), () async {
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$wedge',
            roomId: roomId,
            originTsMs: 1,
          ),
        );
        final worker = buildWorker(
          apply: (entry) async => ApplyOutcome.retriable,
        );

        // Drain repeatedly; maxAttempts=4 in the test wiring.
        // Backoff caps at 100ms; advancing 120ms between drains
        // guarantees every scheduled retry is due.
        for (var i = 0; i < 6; i++) {
          await worker.drainToCompletion();
          virtualNow = virtualNow.add(const Duration(milliseconds: 120));
        }

        final stats = await queue.stats();
        expect(stats.total, 0);
      });
    },
  );

  test(
    'decryptionPending outcome reschedules with shorter backoff',
    () async {
      var virtualNow = DateTime(2024);
      await withClock(Clock(() => virtualNow), () async {
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$enc',
            roomId: roomId,
            originTsMs: 1,
          ),
        );
        var attempt = 0;
        final worker = buildWorker(
          apply: (entry) async {
            attempt++;
            return attempt == 1
                ? ApplyOutcome.decryptionPending
                : ApplyOutcome.applied;
          },
        );

        await worker.drainToCompletion();
        // decryptionPending base backoff is 250ms; 260ms virtual cross.
        virtualNow = virtualNow.add(const Duration(milliseconds: 260));
        final applied = await worker.drainToCompletion();
        expect(applied, 1);
      });
    },
  );

  test('noRoom defers the batch via retry, never marks skipped', () async {
    await queue.enqueueLive(
      _buildSyncEvent(
        eventId: r'$noroom',
        roomId: roomId,
        originTsMs: 1,
      ),
    );
    final worker = InboundWorker(
      queue: queue,
      sequenceLogService: sequenceLog,
      resolveRoom: () async => null,
      apply: (_, _) async => ApplyOutcome.applied,
      logging: logging,
      initialBackoff: const Duration(milliseconds: 10),
    );
    await worker.drainToCompletion();
    final stats = await queue.stats();
    expect(stats.total, 1);
  });
}
