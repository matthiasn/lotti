import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockClient extends Mock implements Client {}

class _MockRoom extends Mock implements Room {}

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
    'no marker stored yields queue.bridge.skip reason=noMarker',
    () async {
      final coordinator = buildCoordinator(
        markerEventId: null,
        markerTs: null,
        resolveRoom: () async => _MockRoom(),
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
}
