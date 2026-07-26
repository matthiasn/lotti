import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'pending_decryption_pen_test_helpers.dart';

void main() {
  late SyncDatabase db;
  late MockDomainLogger logging;
  late InboundQueue queue;
  late MockRoom room;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockDomainLogger();
    queue = InboundQueue(db: db, logging: logging);
    room = MockRoom();
    when(() => room.id).thenReturn(roomId);
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  test(
    'hold returns false for already-decrypted events so producer can enqueue them',
    () {
      final pen = PendingDecryptionPen(logging: logging);
      final plain = buildEvent(
        eventId: r'$plain',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Message,
      );
      expect(pen.hold(plain), isFalse);
      expect(pen.size, 0);
    },
  );

  test('hold retains encrypted events (F3)', () {
    final pen = PendingDecryptionPen(logging: logging);
    final enc = buildEvent(
      eventId: r'$enc',
      roomId: roomId,
      originTsMs: 1,
      type: EventTypes.Encrypted,
    );
    expect(pen.hold(enc), isTrue);
    expect(pen.size, 1);
  });

  test(
    'flushInto forwards decrypted events to the queue via room.getEventById',
    () async {
      final pen = PendingDecryptionPen(logging: logging);
      const encId = r'$rotate';
      final encrypted = buildEvent(
        eventId: encId,
        roomId: roomId,
        originTsMs: 100,
        type: EventTypes.Encrypted,
      );
      pen.hold(encrypted);

      final decrypted = buildEvent(
        eventId: encId,
        roomId: roomId,
        originTsMs: 100,
        type: EventTypes.Message,
      );
      when(() => room.getEventById(encId)).thenAnswer((_) async => decrypted);

      final outcome = await pen.flushInto(queue: queue, room: room);
      expect(outcome.enqueued, 1);
      expect(outcome.stillEncrypted, 0);
      expect(pen.size, 0);

      final stats = await queue.stats();
      expect(stats.total, 1);
    },
  );

  test('flushInto keeps still-encrypted events for the next sweep', () async {
    final pen = PendingDecryptionPen(logging: logging);
    final encrypted = buildEvent(
      eventId: r'$stuck',
      roomId: roomId,
      originTsMs: 1,
      type: EventTypes.Encrypted,
    );
    pen.hold(encrypted);
    when(() => room.getEventById(r'$stuck')).thenAnswer((_) async => encrypted);

    final outcome = await pen.flushInto(queue: queue, room: room);
    expect(outcome.enqueued, 0);
    expect(outcome.stillEncrypted, 1);
    expect(pen.size, 1);
  });

  test(
    'entry exceeding maxAttempts is dropped without being enqueued',
    () async {
      final pen = PendingDecryptionPen(
        logging: logging,
        maxAttempts: 2,
        // Models per-sweep semantics, so both cadences are disabled.
        attemptInterval: Duration.zero,
        lookupInterval: Duration.zero,
      );
      final encrypted = buildEvent(
        eventId: r'$doomed',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      pen.hold(encrypted);
      when(
        () => room.getEventById(r'$doomed'),
      ).thenAnswer((_) async => encrypted);

      await pen.flushInto(queue: queue, room: room);
      await pen.flushInto(queue: queue, room: room);

      expect(pen.size, 0);
      final stats = await queue.stats();
      expect(stats.total, 0);
    },
  );

  test(
    'a fast drain loop cannot burn the decryption budget',
    () async {
      // The InboundWorker sweeps the pen at the top of every drain
      // iteration and loops straight back after a non-empty batch, so while
      // a burst drains the pen is swept many times a second. Counting one
      // attempt per sweep made the whole 20-attempt budget cost ~2ms of
      // wall clock: ciphertext was dropped while its Megolm key was still
      // in flight, on exactly the slow links where keys take longest.
      final pen = PendingDecryptionPen(logging: logging, maxAttempts: 3);
      final encrypted = buildEvent(
        eventId: r'$keyStillInFlight',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      final held = DateTime.utc(2026, 7, 26, 12);
      await withClock(Clock.fixed(held), () async {
        pen.hold(encrypted);
      });
      when(
        () => room.getEventById(r'$keyStillInFlight'),
      ).thenAnswer((_) async => encrypted);

      // A hundred sweeps inside one second — what a draining burst does.
      await withClock(
        Clock.fixed(held.add(const Duration(seconds: 1))),
        () async {
          for (var i = 0; i < 100; i++) {
            await pen.flushInto(queue: queue, room: room);
          }
        },
      );
      expect(
        pen.size,
        1,
        reason: 'sweeps are free; only elapsed time may spend the budget',
      );

      // The key finally lands, well after those 100 sweeps would have
      // exhausted a per-sweep budget.
      final decrypted = buildEvent(
        eventId: r'$keyStillInFlight',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Message,
      );
      when(
        () => room.getEventById(r'$keyStillInFlight'),
      ).thenAnswer((_) async => decrypted);
      await withClock(
        Clock.fixed(held.add(const Duration(seconds: 5))),
        () async {
          await pen.flushInto(queue: queue, room: room);
        },
      );

      expect(pen.size, 0);
      final stats = await queue.stats();
      expect(stats.total, 1, reason: 'the event still reaches the queue');
    },
  );

  test(
    'the budget is still spent once attempts are properly spaced',
    () async {
      // The give-up path must survive: an entry whose key never arrives is
      // dropped after maxAttempts * attemptInterval of real time.
      final pen = PendingDecryptionPen(
        logging: logging,
        maxAttempts: 3,
        // Spelled out even though it is the default: the interval is the
        // subject of this test, not incidental configuration.
        // ignore: avoid_redundant_argument_values
        attemptInterval: const Duration(seconds: 30),
      );
      final encrypted = buildEvent(
        eventId: r'$neverArrives',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      final held = DateTime.utc(2026, 7, 26, 12);
      await withClock(Clock.fixed(held), () async => pen.hold(encrypted));
      when(
        () => room.getEventById(r'$neverArrives'),
      ).thenAnswer((_) async => encrypted);

      for (final minutes in [1, 2, 3]) {
        await withClock(
          Clock.fixed(held.add(Duration(minutes: minutes))),
          () async {
            await pen.flushInto(queue: queue, room: room);
          },
        );
      }

      expect(pen.size, 0, reason: 'a key that never arrives still gives up');
      final stats = await queue.stats();
      expect(stats.total, 0, reason: 'ciphertext never reaches the queue');
    },
  );

  test('reports the oldest held timestamp per room', () async {
    // This is what keeps the sync marker from stepping over held ciphertext.
    final pen = PendingDecryptionPen(logging: logging);
    expect(pen.oldestHeldOriginTs(roomId), isNull);

    pen
      ..hold(
        buildEvent(
          eventId: r'$mid',
          roomId: roomId,
          originTsMs: 5000,
          type: EventTypes.Encrypted,
        ),
      )
      ..hold(
        buildEvent(
          eventId: r'$old',
          roomId: roomId,
          originTsMs: 2000,
          type: EventTypes.Encrypted,
        ),
      )
      ..hold(
        buildEvent(
          eventId: r'$elsewhere',
          roomId: '!other:example.org',
          originTsMs: 100,
          type: EventTypes.Encrypted,
        ),
      );

    // Oldest, not most recently held — and scoped to the room, so one room's
    // backlog cannot pin another room's marker.
    expect(pen.oldestHeldOriginTs(roomId), 2000);
    expect(pen.oldestHeldOriginTs('!other:example.org'), 100);
    expect(pen.oldestHeldOriginTs('!empty:example.org'), isNull);
  });

  test(
    'a fast drain loop does not re-query the room for every sweep',
    () async {
      // The lookup is the expensive half of a sweep, and the worker flushes
      // the whole pen before every batch with `inboundWorkerBatchSize == 1`.
      // Draining 10k rows against a full pen would issue millions of
      // sequential `getEventById` calls. That was self-limiting only while
      // entries were dropped after 20 sweeps; holding them for ten real
      // minutes makes the load persist, so the lookup needs its own cadence.
      final pen = PendingDecryptionPen(logging: logging);
      final encrypted = buildEvent(
        eventId: r'$sealed',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      final held = DateTime.utc(2026, 7, 26, 12);
      await withClock(Clock.fixed(held), () async => pen.hold(encrypted));

      var lookups = 0;
      when(() => room.getEventById(r'$sealed')).thenAnswer((_) async {
        lookups++;
        return encrypted;
      });

      // 100 sweeps inside one instant — what a burst drain does.
      await withClock(
        Clock.fixed(held.add(const Duration(seconds: 5))),
        () async {
          for (var i = 0; i < 100; i++) {
            await pen.flushInto(queue: queue, room: room);
          }
        },
      );
      expect(
        lookups,
        1,
        reason: 'one lookup per entry per lookupInterval, not per sweep',
      );

      // A later sweep, past the interval, looks again — so a key that lands
      // is still noticed promptly.
      await withClock(
        Clock.fixed(held.add(const Duration(seconds: 7))),
        () async {
          await pen.flushInto(queue: queue, room: room);
        },
      );
      expect(lookups, 2);
      expect(pen.size, 1, reason: 'still held, still encrypted');
    },
  );

  test('capacity eviction drops the oldest entry', () async {
    final pen = PendingDecryptionPen(logging: logging, capacity: 2);
    final a = buildEvent(
      eventId: r'$a',
      roomId: roomId,
      originTsMs: 1,
      type: EventTypes.Encrypted,
    );
    final b = buildEvent(
      eventId: r'$b',
      roomId: roomId,
      originTsMs: 2,
      type: EventTypes.Encrypted,
    );
    final c = buildEvent(
      eventId: r'$c',
      roomId: roomId,
      originTsMs: 3,
      type: EventTypes.Encrypted,
    );
    pen
      ..hold(a)
      ..hold(b)
      ..hold(c);

    // Stage decrypted versions for $b and $c; if the pen ever asks for
    // $a it would have to be an eviction regression, and the flush
    // would crash on the missing stub.
    final bDecrypted = buildEvent(
      eventId: r'$b',
      roomId: roomId,
      originTsMs: 2,
      type: EventTypes.Message,
    );
    final cDecrypted = buildEvent(
      eventId: r'$c',
      roomId: roomId,
      originTsMs: 3,
      type: EventTypes.Message,
    );
    when(
      () => room.getEventById(r'$b'),
    ).thenAnswer((_) async => bDecrypted);
    when(
      () => room.getEventById(r'$c'),
    ).thenAnswer((_) async => cDecrypted);

    expect(pen.size, 2);

    final outcome = await pen.flushInto(queue: queue, room: room);
    expect(outcome.enqueued, 2);
    expect(pen.size, 0);
    verifyNever(() => room.getEventById(r'$a'));

    final ready = await queue.peekBatchReady(maxBatch: 10);
    expect(ready.map((e) => e.eventId).toList(), [r'$b', r'$c']);
  });

  test(
    're-holding an existing event refreshes heldAt and keeps the pen at '
    'the same size',
    () {
      final pen = PendingDecryptionPen(logging: logging, capacity: 4);
      final encrypted = buildEvent(
        eventId: r'$rehold',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      expect(pen.hold(encrypted), isTrue);
      expect(pen.size, 1);
      // Second hold for the same id must not grow the pen.
      expect(pen.hold(encrypted), isTrue);
      expect(pen.size, 1);
    },
  );

  test(
    'flushInto swallows a getEventById error and treats the held event '
    'as still-encrypted for the next sweep',
    () async {
      final pen = PendingDecryptionPen(logging: logging);
      final encrypted = buildEvent(
        eventId: r'$err',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      pen.hold(encrypted);
      when(
        () => room.getEventById(r'$err'),
      ).thenThrow(StateError('sdk glitch'));

      final outcome = await pen.flushInto(queue: queue, room: room);
      expect(outcome.stillEncrypted, 1);
      expect(pen.size, 1);
      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain', that: contains('fetch')),
        ),
      ).called(1);
    },
  );

  test(
    'startSweeping fires the periodic flush and stop() awaits the '
    'in-flight sweep before returning',
    () async {
      final pen =
          PendingDecryptionPen(
            logging: logging,
            sweepInterval: const Duration(milliseconds: 10),
          )..hold(
            buildEvent(
              eventId: r'$sweep',
              roomId: roomId,
              originTsMs: 1,
              type: EventTypes.Encrypted,
            ),
          );
      final decrypted = buildEvent(
        eventId: r'$sweep',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Message,
      );
      when(
        () => room.getEventById(r'$sweep'),
      ).thenAnswer((_) async => decrypted);

      final enqueued = queue.depthChanges.firstWhere(
        (signal) => signal.total == 1,
      );
      pen.startSweeping(resolveRoom: () async => room, queue: queue);
      await enqueued.timeout(const Duration(seconds: 2));
      expect(pen.size, 0);
      await pen.stop();
      final stats = await queue.stats();
      expect(stats.total, 1);
    },
  );

  test(
    'startSweeping is a no-op when sweepInterval is null (default) so the '
    'worker-driven mode does not accidentally spin its own timer',
    () {
      final pen = PendingDecryptionPen(logging: logging)
        ..startSweeping(resolveRoom: () async => room, queue: queue);
      // No timer has been installed — calling stop() is a no-op too.
      expect(pen.size, 0);
    },
  );

  glados.Glados(
    glados.any.penScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'generated hold and flush sequences match the bounded pen model',
    (scenario) async {
      final localDb = SyncDatabase(inMemoryDatabase: true);
      final localLogging = MockDomainLogger();
      final localQueue = InboundQueue(db: localDb, logging: localLogging);
      final localRoom = MockRoom();
      when(() => localRoom.id).thenReturn(roomId);

      try {
        final pen = PendingDecryptionPen(
          logging: localLogging,
          capacity: scenario.capacity,
          maxAttempts: scenario.maxAttempts,
          // The model counts one attempt per flush and one lookup per sweep,
          // so this scenario opts out of both real-time cadences.
          attemptInterval: Duration.zero,
          lookupInterval: Duration.zero,
        );
        final expected = ExpectedPenModel(
          capacity: scenario.capacity,
          maxAttempts: scenario.maxAttempts,
        );
        var activeFlush = const GeneratedPenOperation(
          kind: GeneratedPenOperationKind.flushAllStillEncrypted,
          targetSlot: 0,
        );
        when(
          () => localRoom.getEventById(any()),
        ).thenAnswer((invocation) async {
          final eventId = invocation.positionalArguments.single as String;
          if (activeFlush.throwsFor(eventId)) {
            throw StateError('generated fetch failure');
          }
          return buildEvent(
            eventId: eventId,
            roomId: roomId,
            originTsMs: 1000 + int.parse(eventId.split('-').last),
            type: activeFlush.decrypts(eventId)
                ? EventTypes.Message
                : EventTypes.Encrypted,
          );
        });

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case GeneratedPenOperationKind.holdEncrypted:
              expect(
                pen.hold(
                  buildEvent(
                    eventId: operation.eventId,
                    roomId: roomId,
                    originTsMs: 1000 + operation.targetSlot,
                    type: EventTypes.Encrypted,
                  ),
                ),
                isTrue,
              );
              expected.holdEncrypted(operation.eventId);
            case GeneratedPenOperationKind.holdPlain:
              expect(
                pen.hold(
                  buildEvent(
                    eventId: operation.eventId,
                    roomId: roomId,
                    originTsMs: 1000 + operation.targetSlot,
                    type: EventTypes.Message,
                  ),
                ),
                isFalse,
              );
            case GeneratedPenOperationKind.flushAllStillEncrypted:
            case GeneratedPenOperationKind.flushAllDecrypt:
            case GeneratedPenOperationKind.flushTargetDecrypt:
            case GeneratedPenOperationKind.flushTargetThrows:
              activeFlush = operation;
              final actual = await pen.flushInto(
                queue: localQueue,
                room: localRoom,
              );
              final expectedFlush = expected.flush(operation);
              expect(actual.enqueued, expectedFlush.enqueued);
              expect(actual.stillEncrypted, expectedFlush.stillEncrypted);
              expect(actual.dropped, expectedFlush.dropped);
          }

          expect(pen.size, expected.held.length);
        }

        final stats = await localQueue.stats();
        expect(stats.total, expected.queuedEventIds.length);
      } finally {
        await localQueue.dispose();
        await localDb.close();
      }
    },
    tags: 'glados',
  );
}
