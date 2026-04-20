import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockClient extends Mock implements Client {}

class _MockRoom extends Mock implements Room {}

class _MockEvent extends Mock implements Event {}

Event _buildBridgeEvent({
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

SyncUpdate _limitedSyncFor(String roomId, {String prevBatch = 'pb-1'}) {
  return SyncUpdate(
    nextBatch: 'next-1',
    rooms: RoomsUpdate(
      join: {
        roomId: JoinedRoomUpdate(
          timeline: TimelineUpdate(
            limited: true,
            prevBatch: prevBatch,
            events: const <MatrixEvent>[],
          ),
        ),
      },
    ),
  );
}

SyncUpdate _nonLimitedSyncFor(String roomId) {
  return SyncUpdate(
    nextBatch: 'next-2',
    rooms: RoomsUpdate(
      join: {
        roomId: JoinedRoomUpdate(
          timeline: TimelineUpdate(
            events: const <MatrixEvent>[],
          ),
        ),
      },
    ),
  );
}

void main() {
  late SyncDatabase db;
  late MockLoggingService logging;
  late InboundQueue queue;
  late _MockClient client;
  late CachedStreamController<SyncUpdate> syncCtl;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockLoggingService();
    queue = InboundQueue(db: db, logging: logging);
    client = _MockClient();
    syncCtl = CachedStreamController<SyncUpdate>();
    when(() => client.onSync).thenReturn(syncCtl);
  });

  tearDown(() async {
    await syncCtl.close();
    await queue.dispose();
    await db.close();
  });

  BridgeCoordinator buildCoordinator({
    String? markerEventId = r'$anchor',
    int? markerTs = 1000,
    Future<Room?> Function()? resolveRoom,
  }) {
    return BridgeCoordinator(
      client: client,
      currentRoomId: () => roomId,
      resolveRoom: resolveRoom ?? () async => null,
      queue: queue,
      getLastReadEventId: () async => markerEventId,
      getLastReadTs: () async => markerTs,
      logging: logging,
    );
  }

  test('non-limited syncs are ignored', () async {
    final coordinator = buildCoordinator()..start();
    syncCtl.add(_nonLimitedSyncFor(roomId));
    await Future<void>.delayed(Duration.zero);
    // No bridge work means no noRoom log line either.
    verifyNever(
      () => logging.captureEvent(
        any<String>(that: contains('queue.bridge.skip reason=noRoom')),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    );
    await coordinator.stop();
  });

  test(
    'limited=true for the current room triggers bridgeNow; '
    'no-room resolver logs skip so the listener hook is provable',
    () async {
      final coordinator = buildCoordinator()..start();
      syncCtl.add(_limitedSyncFor(roomId));
      await Future<void>.delayed(Duration.zero);
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('queue.bridge.skip reason=noRoom')),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      await coordinator.stop();
    },
  );

  test(
    'missing timestamp yields queue.bridge.skip reason=noMarker',
    () async {
      final room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
      final coordinator = buildCoordinator(
        markerTs: null,
        resolveRoom: () async => room,
      )..start();
      syncCtl.add(_limitedSyncFor(roomId));
      await Future<void>.delayed(Duration.zero);
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('queue.bridge.skip reason=noMarker')),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      await coordinator.stop();
    },
  );

  test(
    'timestamp-only marker (lastEventId == null) still triggers bridge '
    'catch-up — CatchUpStrategy uses the timestamp as the anchor',
    () async {
      final room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
      var collectorCalls = 0;
      String? observedLastEventId = 'not-captured';
      final coordinator = BridgeCoordinator(
        client: client,
        currentRoomId: () => roomId,
        resolveRoom: () async => room,
        queue: queue,
        // No durable event id stored (e.g. last applied event was a
        // placeholder) but the timestamp marker is intact.
        getLastReadEventId: () async => null,
        getLastReadTs: () async => 1000,
        logging: logging,
        catchUpCollector:
            ({
              required Room room,
              required String? lastEventId,
              required BackfillFn backfill,
              required LoggingService logging,
              required num preContextSinceTs,
              required int preContextCount,
              required int maxLookback,
            }) async {
              collectorCalls++;
              observedLastEventId = lastEventId;
              return const CatchUpCollection.complete(
                events: [],
                snapshotSize: 0,
              );
            },
      );
      await coordinator.bridgeNow();
      expect(collectorCalls, 1);
      expect(observedLastEventId, isNull);
      verifyNever(
        () => logging.captureEvent(
          any<String>(that: contains('queue.bridge.skip reason=noMarker')),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    },
  );

  test('other-room limited=true syncs are ignored', () async {
    final coordinator = buildCoordinator()..start();
    syncCtl.add(_limitedSyncFor('!wrongRoom:example.org'));
    await Future<void>.delayed(Duration.zero);
    verifyNever(
      () => logging.captureEvent(
        any<String>(that: contains('queue.bridge.skip')),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    );
    await coordinator.stop();
  });

  test(
    'sync-room change between trigger and resolveRoom causes '
    'queue.bridge.skip reason=roomChanged — no cross-room catch-up',
    () async {
      // `currentRoomId` initially returns roomId. The resolveRoom
      // callback deliberately returns a DIFFERENT room, simulating a
      // mid-flight sync room swap. _runBridgeOnce must refuse to
      // enqueue into that mismatched room.
      final otherRoom = _MockRoom();
      when(() => otherRoom.id).thenReturn('!otherRoom:example.org');
      final coordinator = BridgeCoordinator(
        client: client,
        currentRoomId: () => roomId,
        resolveRoom: () async => otherRoom,
        queue: queue,
        getLastReadEventId: () async => r'$anchor',
        getLastReadTs: () async => 1000,
        logging: logging,
      );
      await coordinator.bridgeNow();
      verify(
        () => logging.captureEvent(
          any<String>(
            that: contains('queue.bridge.skip reason=roomChanged'),
          ),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      final stats = await queue.stats();
      expect(stats.total, 0);
    },
  );

  group('collection outcomes', () {
    late _MockRoom room;

    setUp(() {
      room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
    });

    CatchUpCollector stubCollector(
      Future<CatchUpCollection> Function() build,
    ) {
      return ({
        required Room room,
        required String? lastEventId,
        required BackfillFn backfill,
        required LoggingService logging,
        required num preContextSinceTs,
        required int preContextCount,
        required int maxLookback,
      }) => build();
    }

    test(
      'empty collection logs queue.bridge.empty without enqueuing anything',
      () async {
        final coordinator = BridgeCoordinator(
          client: client,
          currentRoomId: () => roomId,
          resolveRoom: () async => room,
          queue: queue,
          getLastReadEventId: () async => r'$anchor',
          getLastReadTs: () async => 1000,
          logging: logging,
          catchUpCollector: stubCollector(
            () async => const CatchUpCollection.complete(
              events: [],
              snapshotSize: 0,
            ),
          ),
        );
        await coordinator.bridgeNow();
        verify(
          () => logging.captureEvent(
            any<String>(that: contains('queue.bridge.empty')),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
        expect((await queue.stats()).total, 0);
      },
    );

    test(
      'non-empty collection enqueues under bridge producer and logs done',
      () async {
        final coordinator = BridgeCoordinator(
          client: client,
          currentRoomId: () => roomId,
          resolveRoom: () async => room,
          queue: queue,
          getLastReadEventId: () async => r'$anchor',
          getLastReadTs: () async => 1000,
          logging: logging,
          catchUpCollector: stubCollector(
            () async => CatchUpCollection.timestampAnchored(
              events: [
                _buildBridgeEvent(
                  eventId: r'$b1',
                  roomId: roomId,
                  originTsMs: 900,
                ),
                _buildBridgeEvent(
                  eventId: r'$b2',
                  roomId: roomId,
                  originTsMs: 950,
                ),
              ],
              snapshotSize: 2,
            ),
          ),
        );
        await coordinator.bridgeNow();
        final stats = await queue.stats();
        expect(stats.total, 2);
        expect(stats.byProducer[InboundEventProducer.bridge], 2);
        verify(
          () => logging.captureEvent(
            any<String>(that: contains('queue.bridge.done')),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
      },
    );

    test(
      'incomplete collection schedules a bounded retry timer and the retry '
      'eventually fires _bridge again',
      () async {
        var callCount = 0;
        final coordinator = BridgeCoordinator(
          client: client,
          currentRoomId: () => roomId,
          resolveRoom: () async => room,
          queue: queue,
          getLastReadEventId: () async => r'$anchor',
          getLastReadTs: () async => 1000,
          logging: logging,
          incompleteRetryDelay: const Duration(milliseconds: 10),
          catchUpCollector: stubCollector(() async {
            callCount++;
            if (callCount == 1) {
              return const CatchUpCollection.incomplete(
                snapshotSize: 0,
                visibleTailCount: 0,
                fallbackLimit: 100,
                reachedTimestampBoundary: false,
              );
            }
            return const CatchUpCollection.complete(
              events: [],
              snapshotSize: 0,
            );
          }),
        );
        await coordinator.bridgeNow();
        // Allow the 10ms retry timer to fire.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(callCount, greaterThanOrEqualTo(2));
        verify(
          () => logging.captureEvent(
            any<String>(that: contains('queue.bridge.incomplete.retry')),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test(
      'giving up emits queue.bridge.incomplete.giveUp after '
      'maxIncompleteRetries consecutive incomplete collections',
      () async {
        final coordinator = BridgeCoordinator(
          client: client,
          currentRoomId: () => roomId,
          resolveRoom: () async => room,
          queue: queue,
          getLastReadEventId: () async => r'$anchor',
          getLastReadTs: () async => 1000,
          logging: logging,
          incompleteRetryDelay: const Duration(milliseconds: 5),
          maxIncompleteRetries: 2,
          catchUpCollector: stubCollector(
            () async => const CatchUpCollection.incomplete(
              snapshotSize: 0,
              visibleTailCount: 0,
              fallbackLimit: 100,
              reachedTimestampBoundary: false,
            ),
          ),
        );
        await coordinator.bridgeNow();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        verify(
          () => logging.captureEvent(
            any<String>(that: contains('queue.bridge.incomplete.giveUp')),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(greaterThanOrEqualTo(1));
        await coordinator.stop();
      },
    );

    test(
      'stop() cancels a pending incomplete-retry timer so no bridge fires '
      'after shutdown',
      () async {
        var callCount = 0;
        final coordinator = BridgeCoordinator(
          client: client,
          currentRoomId: () => roomId,
          resolveRoom: () async => room,
          queue: queue,
          getLastReadEventId: () async => r'$anchor',
          getLastReadTs: () async => 1000,
          logging: logging,
          incompleteRetryDelay: const Duration(milliseconds: 50),
          catchUpCollector: stubCollector(() async {
            callCount++;
            return const CatchUpCollection.incomplete(
              snapshotSize: 0,
              visibleTailCount: 0,
              fallbackLimit: 100,
              reachedTimestampBoundary: false,
            );
          }),
        );
        await coordinator.bridgeNow();
        expect(callCount, 1);
        await coordinator.stop();
        // Wait past the retry delay — if the timer was not cancelled we
        // would see another call.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(callCount, 1);
      },
    );

    test(
      'coordinator survives a throwing collector by logging and clearing '
      'pending rerun',
      () async {
        final coordinator = BridgeCoordinator(
          client: client,
          currentRoomId: () => roomId,
          resolveRoom: () async => room,
          queue: queue,
          getLastReadEventId: () async => r'$anchor',
          getLastReadTs: () async => 1000,
          logging: logging,
          catchUpCollector: stubCollector(
            () async => throw StateError('boom'),
          ),
        );
        await coordinator.bridgeNow();
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain', that: contains('run')),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );
  });
}
