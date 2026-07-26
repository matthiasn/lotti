import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/bootstrap_sink.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

Event _buildEvent({
  required String eventId,
  required int originTsMs,
  String roomId = '!roomA:example.org',
  String type = EventTypes.Message,
}) {
  final event = MockEvent();
  final content = <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(type);
  when(() => event.content).thenReturn(content);
  when(() => event.text).thenReturn('stub');
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

enum _GeneratedBootstrapOperationKind { page, cancel }

enum _GeneratedBootstrapDrainKind { completes, timesOut }

class _GeneratedBootstrapOperation {
  const _GeneratedBootstrapOperation({
    required this.kind,
    required this.drainKind,
    required this.pageSize,
    required this.acceptedSlot,
  });

  final _GeneratedBootstrapOperationKind kind;
  final _GeneratedBootstrapDrainKind drainKind;
  final int pageSize;
  final int acceptedSlot;

  int get acceptedCount => acceptedSlot > pageSize ? pageSize : acceptedSlot;

  bool get timesOut => drainKind == _GeneratedBootstrapDrainKind.timesOut;

  @override
  String toString() {
    return '_GeneratedBootstrapOperation('
        'kind: $kind, '
        'drainKind: $drainKind, '
        'pageSize: $pageSize, '
        'acceptedSlot: $acceptedSlot'
        ')';
  }
}

class _GeneratedBootstrapScenario {
  const _GeneratedBootstrapScenario({
    required this.highWater,
    required this.operations,
  });

  final int highWater;
  final List<_GeneratedBootstrapOperation> operations;

  List<_GeneratedBootstrapOperation> get pageOperations =>
      operations.where((operation) {
        return operation.kind == _GeneratedBootstrapOperationKind.page;
      }).toList();

  List<bool> expectedResults() {
    final results = <bool>[];
    var cancelled = false;
    for (final operation in operations) {
      switch (operation.kind) {
        case _GeneratedBootstrapOperationKind.cancel:
          cancelled = true;
        case _GeneratedBootstrapOperationKind.page:
          if (cancelled) {
            results.add(false);
          } else {
            results.add(!operation.timesOut);
          }
      }
    }
    return results;
  }

  int get expectedAppendCalls {
    var cancelled = false;
    var calls = 0;
    for (final operation in operations) {
      switch (operation.kind) {
        case _GeneratedBootstrapOperationKind.cancel:
          cancelled = true;
        case _GeneratedBootstrapOperationKind.page:
          if (!cancelled) calls++;
      }
    }
    return calls;
  }

  int get expectedLastAccepted {
    var cancelled = false;
    var lastAccepted = 0;
    for (final operation in operations) {
      switch (operation.kind) {
        case _GeneratedBootstrapOperationKind.cancel:
          cancelled = true;
        case _GeneratedBootstrapOperationKind.page:
          if (cancelled) {
            lastAccepted = 0;
          } else {
            lastAccepted = operation.acceptedCount;
          }
      }
    }
    return lastAccepted;
  }

  @override
  String toString() {
    return '_GeneratedBootstrapScenario('
        'highWater: $highWater, '
        'operations: $operations'
        ')';
  }
}

extension _AnyGeneratedBootstrapScenario on glados.Any {
  glados.Generator<_GeneratedBootstrapOperationKind>
  get bootstrapOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedBootstrapOperationKind.values);

  glados.Generator<_GeneratedBootstrapDrainKind> get bootstrapDrainKind =>
      glados.AnyUtils(this).choose(_GeneratedBootstrapDrainKind.values);

  glados.Generator<_GeneratedBootstrapOperation> get bootstrapOperation =>
      glados.CombinableAny(this).combine4(
        bootstrapOperationKind,
        bootstrapDrainKind,
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 6),
        (
          _GeneratedBootstrapOperationKind kind,
          _GeneratedBootstrapDrainKind drainKind,
          int pageSize,
          int acceptedSlot,
        ) => _GeneratedBootstrapOperation(
          kind: kind,
          drainKind: drainKind,
          pageSize: pageSize,
          acceptedSlot: acceptedSlot,
        ),
      );

  glados.Generator<_GeneratedBootstrapScenario> get bootstrapScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 8),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(1, 24, bootstrapOperation),
        (
          int highWater,
          List<_GeneratedBootstrapOperation> operations,
        ) => _GeneratedBootstrapScenario(
          highWater: highWater,
          operations: operations,
        ),
      );
}

void main() {
  late SyncDatabase db;
  late MockDomainLogger logging;
  late InboundQueue queue;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockDomainLogger();
    queue = InboundQueue(db: db, logging: logging);
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  BootstrapPageInfo info(int pageIndex, int total) => BootstrapPageInfo(
    pageIndex: pageIndex,
    totalEventsSoFar: total,
    oldestTimestampSoFar: null,
    serverHasMore: true,
    elapsed: const Duration(milliseconds: 1),
  );

  test(
    'onPage forwards events to queue and returns true under high-water',
    () async {
      final sink = QueueBootstrapSink(queue: queue, logging: logging);
      final events = [
        _buildEvent(eventId: r'$a', originTsMs: 1),
        _buildEvent(eventId: r'$b', originTsMs: 2),
      ];
      final cont = await sink.onPage(events, info(0, events.length));
      expect(cont, isTrue);
      final stats = await queue.stats();
      expect(stats.total, 2);
      expect(stats.byProducer[InboundEventProducer.bootstrap], 2);
    },
  );

  test(
    'still-encrypted backfill goes to the pen instead of the floor',
    () async {
      // `enqueueBatch` refuses ciphertext — writing it into `raw_json` would
      // lose the payload on the next `Event.fromJson` round-trip — and
      // reports it as `deferredPendingDecryption`, whose contract is that the
      // *caller* retains the event and re-submits after decryption. The live
      // producer honours that. Backfill did not: it handed pages straight to
      // the queue and ignored the count, so every event the startup bridge
      // replayed while still encrypted was discarded outright — no row, no
      // pen entry, no ledger row, nothing to retry and nothing to notice.
      final pen = PendingDecryptionPen(logging: logging);
      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        pen: pen,
      );

      final events = [
        _buildEvent(eventId: r'$plain', originTsMs: 1),
        _buildEvent(
          eventId: r'$sealed',
          originTsMs: 2,
          type: EventTypes.Encrypted,
        ),
      ];
      final cont = await sink.onPage(events, info(0, events.length));

      expect(cont, isTrue);
      final stats = await queue.stats();
      expect(stats.total, 1, reason: 'only the decrypted event is a row');
      expect(
        pen.size,
        1,
        reason:
            'the ciphertext is held, not dropped, so it can be '
            're-submitted once its key arrives',
      );
    },
  );

  test(
    'a full pen stops pagination instead of evicting the oldest ciphertext',
    () async {
      // A forward walk emits up to 50 pages of 200 and manual history
      // collection is unbounded, while the pen is a fixed LRU. Ciphertext
      // creates no queue rows, so the depth-based back-pressure never fires —
      // the walk would run the pen's oldest entries straight off the end,
      // recreating the loss this sink exists to prevent. Stopping is safe:
      // held events clamp the sync marker, so the next run resumes from the
      // right anchor rather than skipping the gap.
      final pen = PendingDecryptionPen(logging: logging, capacity: 2);
      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        pen: pen,
      );

      final page = [
        for (var i = 0; i < 2; i++)
          _buildEvent(
            eventId: '\$sealed$i',
            originTsMs: i + 1,
            type: EventTypes.Encrypted,
          ),
      ];
      final cont = await sink.onPage(page, info(0, page.length));

      expect(pen.size, 2);
      expect(
        cont,
        isTrue,
        reason:
            'a page that fits exactly is admitted whole; the stop comes '
            'when the next page has nowhere to go',
      );
      expect(
        sink.lastAcceptedCount,
        2,
        reason:
            'retained ciphertext counts as accepted, so the caller does '
            'not read this page as a stale-cache miss',
      );
    },
  );

  test(
    'admission is checked before holding, so nothing is evicted',
    () async {
      // `hold` enforces capacity itself by evicting the oldest entry, so a
      // guard that runs after the page has been held has already destroyed
      // something: a nearly-full pen taking two new events evicts one, then
      // reports a size that looks like it stopped in time.
      final pen = PendingDecryptionPen(logging: logging, capacity: 2);
      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        pen: pen,
      );

      // Fill one slot, leaving exactly one free.
      await sink.onPage([
        _buildEvent(
          eventId: r'$first',
          originTsMs: 1,
          type: EventTypes.Encrypted,
        ),
      ], info(0, 1));
      expect(pen.size, 1);

      // Two more new events against one free slot.
      final cont = await sink.onPage([
        _buildEvent(
          eventId: r'$second',
          originTsMs: 2,
          type: EventTypes.Encrypted,
        ),
        _buildEvent(
          eventId: r'$third',
          originTsMs: 3,
          type: EventTypes.Encrypted,
        ),
      ], info(1, 2));

      expect(cont, isFalse, reason: 'pagination stops at the boundary');
      expect(pen.size, 2, reason: 'filled exactly, never overflowed');
      expect(
        pen.holds(r'$first'),
        isTrue,
        reason: 'the oldest entry must not have been evicted to make room',
      );
    },
  );

  test(
    'an overflow event is recorded as a resume floor, not discarded',
    () async {
      // Breaking out of the scan throws away work that has already crossed
      // the network — later plaintext and already-held events included — and
      // the manual "Fetch all history" path has no automatic retry to pick
      // them up afterwards.
      final pen = PendingDecryptionPen(logging: logging, capacity: 1);
      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        pen: pen,
      );

      final cont = await sink.onPage([
        _buildEvent(
          eventId: r'$sealedA',
          originTsMs: 1,
          type: EventTypes.Encrypted,
        ),
        // No slot left for this one...
        _buildEvent(
          eventId: r'$sealedB',
          originTsMs: 2,
          type: EventTypes.Encrypted,
        ),
        // ...but this one needs no slot and must still be queued.
        _buildEvent(eventId: r'$plain', originTsMs: 3),
      ], info(0, 3));

      expect(cont, isFalse, reason: 'pagination still stops');
      expect(pen.size, 1, reason: 'capacity respected, nothing evicted');
      expect(pen.holds(r'$sealedA'), isTrue);
      // The overflow event has no row and no pen entry, so nothing in memory
      // protects it. The durable floor does: it says a resume must reach back
      // to it, and the bridge refuses a forward anchor ahead of the floor.
      expect(
        await queue.resumeFloorTs('!roomA:example.org'),
        2,
        reason: 'the omitted event is recorded as outstanding',
      );
      // With that recorded, the rest of an already-fetched page is safe to
      // queue — which is exactly what the floor bought.
      final stats = await queue.stats();
      expect(stats.total, 1, reason: 'the plaintext after the gap is kept');
    },
  );

  test(
    'capacity is budgeted per room, not across the whole pen',
    () async {
      // The pen's capacity and LRU are global. Ciphertext left over from a
      // room the user switched away from would otherwise consume the entire
      // budget and stop the active room's bootstrap dead — `onRoomChanged`
      // prunes queue rows but not the pen.
      final pen = PendingDecryptionPen(logging: logging, capacity: 1)
        ..hold(
          _buildEvent(
            eventId: r'$stale',
            originTsMs: 1,
            roomId: '!oldRoom:example.org',
            type: EventTypes.Encrypted,
          ),
        );

      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        pen: pen,
      );
      final cont = await sink.onPage([
        _buildEvent(
          eventId: r'$fresh',
          originTsMs: 2,
          type: EventTypes.Encrypted,
        ),
      ], info(0, 1));

      expect(
        cont,
        isTrue,
        reason: 'the active room has its own budget and is not blocked',
      );
      expect(pen.holds(r'$fresh'), isTrue);
    },
  );

  test('cancelSignal stops pagination between pages', () async {
    // Make the pre-cancel queue contain >highWater entries so the sink
    // awaits drain when the next onPage fires.
    for (var i = 0; i < 5; i++) {
      await queue.enqueueLive(
        _buildEvent(eventId: '\$pre$i', originTsMs: i),
      );
    }
    // Cancel signal completes immediately.
    final cancel = Future<void>.value();
    final sink = QueueBootstrapSink(
      queue: queue,
      logging: logging,
      highWater: 0,
      backPressureTimeout: const Duration(seconds: 5),
      cancelSignal: cancel,
    );
    final next = [
      _buildEvent(eventId: r'$page1', originTsMs: 100),
    ];
    final cont = await sink.onPage(next, info(0, 6));
    expect(cont, isFalse);
  });

  test(
    'cancelSignal that completed before the first onPage enters the '
    'early-exit path and returns false without calling the queue — '
    'resets lastAcceptedCount to 0 so a caller polling the accepted '
    'count between pages sees "nothing happened this tick" rather '
    'than a stale value from an earlier pass',
    () async {
      final cancel = Future<void>.value();
      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        cancelSignal: cancel,
      );
      // Let the cancel-signal handler flip _cancelled to true.
      await Future<void>.delayed(Duration.zero);

      final events = [
        _buildEvent(eventId: r'$pre-cancelled', originTsMs: 1),
      ];
      final cont = await sink.onPage(events, info(0, 1));
      expect(cont, isFalse);
      expect(sink.lastAcceptedCount, 0);

      // Queue must be untouched — the early exit bailed before
      // appendBootstrapPage.
      final stats = await queue.stats();
      expect(stats.total, 0);
    },
  );

  test(
    'back-pressure timeout returns false so paging halts on wedged worker',
    () async {
      for (var i = 0; i < 5; i++) {
        await queue.enqueueLive(
          _buildEvent(eventId: '\$pre$i', originTsMs: i),
        );
      }
      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        highWater: 0,
        backPressureTimeout: const Duration(milliseconds: 50),
      );
      final page = [
        _buildEvent(eventId: r'$x', originTsMs: 1000),
      ];
      final cont = await sink.onPage(page, info(0, 6));
      expect(cont, isFalse);
    },
  );

  glados.Glados(
    glados.any.bootstrapScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated pages preserve accepted counts, cancellation, and timeouts',
    (scenario) async {
      final generatedQueue = MockInboundQueue();
      final generatedLogging = MockDomainLogger();
      final cancelCompleter = Completer<void>();
      final appendedPages = <List<String>>[];
      final drainTimeouts = <bool>[];
      final expectedPageOperations = <_GeneratedBootstrapOperation>[];

      when(
        () => generatedLogging.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenReturn(null);
      when(() => generatedQueue.appendBootstrapPage(any())).thenAnswer((
        invocation,
      ) async {
        final events = invocation.positionalArguments.single as List<Event>;
        final operation = expectedPageOperations.removeAt(0);
        appendedPages.add(events.map((event) => event.eventId).toList());
        drainTimeouts.add(operation.timesOut);
        final accepted = operation.acceptedCount;
        return EnqueueResult(
          accepted: accepted,
          duplicatesDropped: events.length - accepted,
          filteredOutByType: 0,
          deferredPendingDecryption: 0,
          oldestTsAccepted: 0,
          newestTsAccepted: 0,
        );
      });
      when(
        () => generatedQueue.waitForDrainAtMostTo(
          any<int>(),
          timeout: any<Duration>(named: 'timeout'),
        ),
      ).thenAnswer((_) async {
        if (drainTimeouts.removeAt(0)) {
          throw TimeoutException('generated drain timeout');
        }
      });

      final sink = QueueBootstrapSink(
        queue: generatedQueue,
        logging: generatedLogging,
        highWater: scenario.highWater,
        backPressureTimeout: const Duration(milliseconds: 25),
        cancelSignal: cancelCompleter.future,
      );
      final observedResults = <bool>[];
      var pageIndex = 0;
      var totalEvents = 0;

      for (final operation in scenario.operations) {
        switch (operation.kind) {
          case _GeneratedBootstrapOperationKind.cancel:
            if (!cancelCompleter.isCompleted) {
              cancelCompleter.complete();
            }
            await Future<void>.value();
          case _GeneratedBootstrapOperationKind.page:
            if (!cancelCompleter.isCompleted) {
              expectedPageOperations.add(operation);
            }
            final events = [
              for (var i = 0; i < operation.pageSize; i++)
                _buildEvent(
                  eventId: 'generated-$pageIndex-$i',
                  originTsMs: totalEvents + i,
                ),
            ];
            observedResults.add(
              await sink.onPage(events, info(pageIndex, totalEvents)),
            );
            totalEvents += events.length;
            pageIndex++;
        }
      }

      expect(observedResults, scenario.expectedResults(), reason: '$scenario');
      expect(appendedPages, hasLength(scenario.expectedAppendCalls));
      expect(sink.lastAcceptedCount, scenario.expectedLastAccepted);
      if (scenario.expectedAppendCalls == 0) {
        verifyNever(
          () => generatedQueue.waitForDrainAtMostTo(
            any<int>(),
            timeout: any<Duration>(named: 'timeout'),
          ),
        );
      } else {
        verify(
          () => generatedQueue.waitForDrainAtMostTo(
            scenario.highWater,
            timeout: const Duration(milliseconds: 25),
          ),
        ).called(scenario.expectedAppendCalls);
      }
    },
    tags: 'glados',
  );
}
