import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

class _MockRoom extends Mock implements Room {}

class _MockVectorClockService extends Mock implements VectorClockService {}

class _MockActivityGate extends Mock implements UserActivityGate {}

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

  test(
    'permanentSkip outcome deletes the row via markSkipped and advances '
    'the marker past the poison event',
    () async {
      await queue.enqueueLive(
        _buildSyncEvent(
          eventId: r'$poison',
          roomId: roomId,
          originTsMs: 5000,
        ),
      );
      final worker = buildWorker(
        apply: (_) async => ApplyOutcome.permanentSkip,
      );
      final applied = await worker.drainToCompletion();
      expect(applied, 0);
      final stats = await queue.stats();
      expect(stats.total, 0);
      final marker = await (db.select(
        db.queueMarkers,
      )..where((t) => t.roomId.equals(roomId))).getSingle();
      expect(marker.lastAppliedEventId, r'$poison');
      expect(marker.lastAppliedTs, 5000);
    },
  );

  test(
    'missingBase outcome schedules a retry with the missingBase reason',
    () async {
      var virtualNow = DateTime(2024);
      await withClock(Clock(() => virtualNow), () async {
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$missing',
            roomId: roomId,
            originTsMs: 1,
          ),
        );
        var attempt = 0;
        final worker = buildWorker(
          apply: (_) async {
            attempt++;
            return attempt == 1
                ? ApplyOutcome.missingBase
                : ApplyOutcome.applied;
          },
        );

        final first = await worker.drainToCompletion();
        expect(first, 0);
        // Same exponential curve as retriable (initialBackoff = 10ms).
        virtualNow = virtualNow.add(const Duration(milliseconds: 20));
        final second = await worker.drainToCompletion();
        expect(second, 1);
      });
    },
  );

  test(
    'apply callback that throws is captured and treated as retriable',
    () async {
      var virtualNow = DateTime(2024);
      await withClock(Clock(() => virtualNow), () async {
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$throws',
            roomId: roomId,
            originTsMs: 1,
          ),
        );
        var attempt = 0;
        final worker = buildWorker(
          apply: (_) async {
            attempt++;
            if (attempt == 1) {
              throw StateError('boom');
            }
            return ApplyOutcome.applied;
          },
        );

        expect(await worker.drainToCompletion(), 0);
        virtualNow = virtualNow.add(const Duration(milliseconds: 20));
        expect(await worker.drainToCompletion(), 1);
        // The apply throw must be logged so oncall can see it.
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain', that: contains('apply')),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    },
  );

  group('lifecycle', () {
    test('stop() returns immediately when worker never started', () async {
      final worker = buildWorker(apply: (_) async => ApplyOutcome.applied);
      expect(worker.isRunning, isFalse);
      await worker.stop();
      expect(worker.isRunning, isFalse);
    });

    test('start() is idempotent and stop() completes the loop', () async {
      final worker = buildWorker(apply: (_) async => ApplyOutcome.applied);
      await worker.start();
      // A second start while running is a no-op (no new loop spawned).
      await worker.start();
      expect(worker.isRunning, isTrue);
      await worker.stop();
      expect(worker.isRunning, isFalse);
    });

    test(
      'running loop drains newly enqueued events and stop() awaits '
      'loop completion',
      () async {
        final applied = <String>[];
        final worker = buildWorker(
          apply: (entry) async {
            applied.add(entry.eventId);
            return ApplyOutcome.applied;
          },
        );
        await worker.start();
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$live', roomId: roomId, originTsMs: 1),
        );
        // Give the loop a turn to observe the depth change and drain.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
          if (applied.isNotEmpty) break;
        }
        expect(applied, [r'$live']);
        await worker.stop();
        expect(worker.isRunning, isFalse);
      },
    );

    test(
      'loop flushes the decryption pen before peeking the queue each '
      'iteration',
      () async {
        final pen = PendingDecryptionPen(logging: logging);
        final worker = InboundWorker(
          queue: queue,
          sequenceLogService: sequenceLog,
          resolveRoom: () async => room,
          apply: (_, _) async => ApplyOutcome.applied,
          logging: logging,
          decryptionPen: pen,
        );
        final encrypted = _MockEvent();
        when(() => encrypted.eventId).thenReturn(r'$enc1');
        when(() => encrypted.roomId).thenReturn(roomId);
        when(() => encrypted.type).thenReturn(EventTypes.Encrypted);
        when(() => encrypted.content).thenReturn(
          <String, dynamic>{'algorithm': 'm.megolm.v1.aes-sha2'},
        );
        pen.hold(encrypted);
        expect(pen.size, 1);

        final decrypted = _buildSyncEvent(
          eventId: r'$enc1',
          roomId: roomId,
          originTsMs: 42,
        );
        when(
          () => room.getEventById(r'$enc1'),
        ).thenAnswer((_) async => decrypted);

        await worker.start();
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(Duration.zero);
          if (pen.size == 0) break;
        }
        await worker.stop();
        expect(pen.size, 0);
      },
    );

    test(
      'loop wakes up near the soonest retry nextDueAt instead of sleeping '
      'for the full idleTick (P1 — decryptionPending/missingBase/noRoom '
      'retries were previously rounded up to idleTick)',
      () async {
        var attempt = 0;
        final worker = InboundWorker(
          queue: queue,
          sequenceLogService: sequenceLog,
          resolveRoom: () async => room,
          apply: (_, _) async {
            attempt++;
            return attempt == 1
                ? ApplyOutcome.decryptionPending
                : ApplyOutcome.applied;
          },
          logging: logging,
          initialBackoff: const Duration(milliseconds: 10),
          // idleTick is deliberately long so a regression (idleTick
          // wins the race) would show up as a hard test timeout; the
          // ready-timestamp path must steer the loop well under it.
          idleTick: const Duration(seconds: 30),
        );
        await worker.start();
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$wake',
            roomId: roomId,
            originTsMs: 1,
          ),
        );
        final stopwatch = Stopwatch()..start();
        for (var i = 0; i < 500; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if ((await queue.stats()).total == 0) break;
        }
        stopwatch.stop();
        await worker.stop();
        expect((await queue.stats()).total, 0);
        // decryptionPending base backoff is 250ms. The loop must wake
        // near that deadline; anything close to the 30s idleTick would
        // be a regression back to the rounded-up sleep.
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      },
    );

    test(
      'enqueue that lands during peek is seen by the depthChanges '
      'subscription that was attached before peek (no missed signal)',
      () async {
        final applied = <String>[];
        final worker = InboundWorker(
          queue: queue,
          sequenceLogService: sequenceLog,
          resolveRoom: () async => room,
          apply: (entry, _) async {
            applied.add(entry.eventId);
            return ApplyOutcome.applied;
          },
          logging: logging,
          idleTick: const Duration(seconds: 30),
        );
        await worker.start();
        // Without a pre-peek subscription, an enqueue landing between a
        // peek-empty result and a post-peek listen would only be
        // noticed after idleTick. Enqueue immediately — the loop must
        // observe it promptly.
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$race',
            roomId: roomId,
            originTsMs: 1,
          ),
        );
        for (var i = 0; i < 200; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (applied.isNotEmpty) break;
        }
        await worker.stop();
        expect(applied, [r'$race']);
      },
    );

    test(
      'an uncaught exception in the loop body is captured by _logging and '
      '_running is cleared so start() can relaunch afterwards',
      () async {
        // Resolve throws on the first call (pen.flushInto path); after
        // that returns the real room so start() can succeed again.
        var resolveCalls = 0;
        final decryptionPen = PendingDecryptionPen(logging: logging);
        final worker = InboundWorker(
          queue: queue,
          sequenceLogService: sequenceLog,
          resolveRoom: () async {
            resolveCalls++;
            if (resolveCalls == 1) {
              throw StateError('resolve boom');
            }
            return room;
          },
          apply: (_, _) async => ApplyOutcome.applied,
          logging: logging,
          decryptionPen: decryptionPen,
        );
        // Holding an encrypted event forces the pen.flushInto branch
        // which calls _resolveRoom() and blows up on the first call.
        final enc = _MockEvent();
        when(() => enc.eventId).thenReturn(r'$enc');
        when(() => enc.roomId).thenReturn(roomId);
        when(() => enc.type).thenReturn(EventTypes.Encrypted);
        when(() => enc.content).thenReturn(<String, dynamic>{});
        decryptionPen.hold(enc);

        await worker.start();
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(Duration.zero);
          if (!worker.isRunning) break;
        }
        expect(worker.isRunning, isFalse);
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(
              named: 'subDomain',
              that: contains('loop'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test(
      'activity gate is awaited on every loop iteration via '
      '_waitUntilIdleOrStopped',
      () async {
        final gate = _MockActivityGate();
        var waitCalls = 0;
        when(gate.waitUntilIdle).thenAnswer((_) async {
          waitCalls++;
        });
        final worker = InboundWorker(
          queue: queue,
          sequenceLogService: sequenceLog,
          resolveRoom: () async => room,
          apply: (_, _) async => ApplyOutcome.applied,
          logging: logging,
          activityGate: gate,
        );
        await worker.start();
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$gated', roomId: roomId, originTsMs: 1),
        );
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(Duration.zero);
          if ((await queue.stats()).total == 0) break;
        }
        await worker.stop();
        expect(waitCalls, greaterThanOrEqualTo(1));
      },
    );
  });

  group('prepareBatch hook', () {
    test(
      'prepareBatch is invoked once per batch with every entry, '
      'before any per-entry apply runs — proves the worker wires the '
      'batch-parallel prepare path end to end',
      () async {
        final events = [
          _buildSyncEvent(eventId: r'$p1', roomId: roomId, originTsMs: 10),
          _buildSyncEvent(eventId: r'$p2', roomId: roomId, originTsMs: 20),
          _buildSyncEvent(eventId: r'$p3', roomId: roomId, originTsMs: 30),
        ];
        await queue.enqueueBatch(events, producer: InboundEventProducer.live);

        final prepareInvocations = <List<String>>[];
        final applyInvocations = <String>[];
        final worker = InboundWorker(
          queue: queue,
          sequenceLogService: sequenceLog,
          resolveRoom: () async => room,
          apply: (entry, _) async {
            applyInvocations.add(entry.eventId);
            // Applies must observe a fully-populated prepareInvocations
            // list — prepareBatch ran ahead of the first apply call.
            expect(prepareInvocations, hasLength(1));
            return ApplyOutcome.applied;
          },
          prepareBatch: (entries, _) async {
            prepareInvocations.add([for (final e in entries) e.eventId]);
          },
          logging: logging,
          initialBackoff: const Duration(milliseconds: 10),
          maxBackoff: const Duration(milliseconds: 100),
          maxAttempts: 4,
        );

        final appliedCount = await worker.drainToCompletion();
        expect(appliedCount, 3);
        expect(prepareInvocations, hasLength(1));
        expect(prepareInvocations.single, [r'$p1', r'$p2', r'$p3']);
        expect(applyInvocations, [r'$p1', r'$p2', r'$p3']);
      },
    );

    test(
      'a throw from prepareBatch is logged but does not abort the '
      'per-entry apply loop — the adapter is expected to classify '
      'per-entry failures, so a top-level throw is a bug to surface, '
      'not a reason to strand the batch',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$fail', roomId: roomId, originTsMs: 1),
        );

        final applied = <String>[];
        final worker = InboundWorker(
          queue: queue,
          sequenceLogService: sequenceLog,
          resolveRoom: () async => room,
          apply: (entry, _) async {
            applied.add(entry.eventId);
            return ApplyOutcome.applied;
          },
          prepareBatch: (entries, _) async {
            throw StateError('prepareBatch boom');
          },
          logging: logging,
          initialBackoff: const Duration(milliseconds: 10),
          maxBackoff: const Duration(milliseconds: 100),
          maxAttempts: 4,
        );

        final appliedCount = await worker.drainToCompletion();
        expect(appliedCount, 1);
        expect(applied, [r'$fail']);
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('prepareBatch'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );
  });
}
