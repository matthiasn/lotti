import 'dart:async';

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

/// Minimal bootstrap runner that records invocations. Each call is
/// an awaitable completer so tests can gate a run mid-flight.
class _RecordingRunner {
  _RecordingRunner({bool defaultCompleted = true})
    : _defaultCompleted = defaultCompleted;

  final bool _defaultCompleted;
  final List<_RunnerCall> calls = <_RunnerCall>[];
  Future<bool> Function(Room room, BridgeMarker marker)? override;

  BootstrapRunner get runner =>
      ({
        required Room room,
        required BridgeMarker marker,
      }) async {
        final call = _RunnerCall(room: room, marker: marker);
        calls.add(call);
        final o = override;
        if (o != null) return o(room, marker);
        return _defaultCompleted;
      };
}

class _RunnerCall {
  _RunnerCall({required this.room, required this.marker});

  final Room room;
  final BridgeMarker marker;

  int? get untilTimestamp => marker.lastAppliedTs;
  String? get anchorEventId => marker.lastAppliedEventId;
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
    int? markerTs = 1000,
    String? anchorEventId,
    Future<Room?> Function()? resolveRoom,
    _RecordingRunner? runner,
    Duration incompleteRetryDelay = const Duration(seconds: 10),
    int maxIncompleteRetries = 3,
  }) {
    final recording = runner ?? _RecordingRunner();
    return BridgeCoordinator(
      client: client,
      currentRoomId: () => roomId,
      resolveRoom: resolveRoom ?? () async => null,
      readMarker: () async => BridgeMarker(
        lastAppliedTs: markerTs,
        lastAppliedEventId: anchorEventId,
      ),
      bootstrapRunner: recording.runner,
      logging: logging,
      incompleteRetryDelay: incompleteRetryDelay,
      maxIncompleteRetries: maxIncompleteRetries,
    );
  }

  test('non-limited syncs are ignored', () async {
    final coordinator = buildCoordinator()..start();
    syncCtl.add(_nonLimitedSyncFor(roomId));
    await Future<void>.delayed(Duration.zero);
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
    'missing timestamp invokes the runner with untilTimestamp=null — '
    'fresh client case walks the full visible history',
    () async {
      final room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
      final runner = _RecordingRunner();
      final coordinator = buildCoordinator(
        markerTs: null,
        resolveRoom: () async => room,
        runner: runner,
      );
      await coordinator.bridgeNow();
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.room, same(room));
      expect(runner.calls.single.untilTimestamp, isNull);
      verify(
        () => logging.captureEvent(
          any<String>(that: contains('queue.bridge.start mode=fresh')),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  test(
    'marker with anchor event id forwards both through to the runner — '
    'reconnect path prefers forward-walk anchored on last applied event',
    () async {
      final room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
      final runner = _RecordingRunner();
      final coordinator = BridgeCoordinator(
        client: client,
        currentRoomId: () => roomId,
        resolveRoom: () async => room,
        readMarker: () async => const BridgeMarker(
          lastAppliedTs: 5000,
          lastAppliedEventId: r'$anchor-event',
        ),
        bootstrapRunner: runner.runner,
        logging: logging,
      );
      await coordinator.bridgeNow();
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.untilTimestamp, 5000);
      expect(runner.calls.single.anchorEventId, r'$anchor-event');
      verify(
        () => logging.captureEvent(
          any<String>(
            that: contains('queue.bridge.start mode=reconnect.forward'),
          ),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  test(
    'marker with ts but no anchor falls back to the backward mode — '
    'cannot forward-walk without an event id to anchor on',
    () async {
      final room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
      final runner = _RecordingRunner();
      final coordinator = buildCoordinator(
        resolveRoom: () async => room,
        runner: runner,
      );
      await coordinator.bridgeNow();
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.untilTimestamp, 1000);
      expect(runner.calls.single.anchorEventId, isNull);
      verify(
        () => logging.captureEvent(
          any<String>(
            that: contains('queue.bridge.start mode=reconnect.backward'),
          ),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  test(
    'runner throwing is caught, logged, and counted as incomplete so '
    'the retry machinery still kicks in',
    () async {
      final room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
      final runner = _RecordingRunner()
        ..override = (Room r, BridgeMarker m) async {
          throw StateError('bootstrap boom');
        };
      final coordinator = buildCoordinator(
        resolveRoom: () async => room,
        runner: runner,
        incompleteRetryDelay: const Duration(milliseconds: 10),
      );
      await coordinator.bridgeNow();
      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain', that: contains('bootstrap')),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
      // Retry timer should have scheduled a second call after 10ms.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(runner.calls.length, greaterThanOrEqualTo(2));
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

  test(
    'isRunning flips false → true on start and back to false on stop',
    () async {
      final coordinator = buildCoordinator();
      expect(coordinator.isRunning, isFalse);
      coordinator.start();
      expect(coordinator.isRunning, isTrue);
      await coordinator.stop();
      expect(coordinator.isRunning, isFalse);
    },
  );

  test(
    'subscription onError forwards to logging.captureException so a '
    'broken sync stream does not crash the coordinator silently',
    () async {
      final coordinator = buildCoordinator()..start();
      syncCtl.addError(StateError('sync pipe broken'), StackTrace.empty);
      await Future<void>.delayed(Duration.zero);
      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(
            named: 'subDomain',
            that: contains('subscription'),
          ),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
      await coordinator.stop();
    },
  );

  test(
    'a second trigger that lands while a bridge is in-flight is coalesced '
    'into exactly one rerun after the in-flight pass completes',
    () async {
      final room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
      final firstCallGate = Completer<void>();
      final runner = _RecordingRunner()
        ..override = (Room r, BridgeMarker m) async {
          if (r.id == roomId && !firstCallGate.isCompleted) {
            // First call: wait for the gate.
            // Second and later calls resolve immediately.
          }
          return true;
        };
      // Override the override: first call gated, subsequent immediate.
      var callCount = 0;
      runner.override = (Room r, BridgeMarker m) async {
        callCount++;
        if (callCount == 1) await firstCallGate.future;
        return true;
      };
      final coordinator = buildCoordinator(
        resolveRoom: () async => room,
        runner: runner,
      );
      final firstBridge = coordinator.bridgeNow();
      await Future<void>.delayed(Duration.zero);
      unawaited(coordinator.bridgeNow());
      await Future<void>.delayed(Duration.zero);
      expect(callCount, 1);
      firstCallGate.complete();
      await firstBridge;
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
        if (callCount >= 2) break;
      }
      expect(callCount, 2);
    },
  );

  test(
    'sync-room change between trigger and resolveRoom causes '
    'queue.bridge.skip reason=roomChanged — no cross-room catch-up',
    () async {
      final otherRoom = _MockRoom();
      when(() => otherRoom.id).thenReturn('!otherRoom:example.org');
      final runner = _RecordingRunner();
      final coordinator = buildCoordinator(
        resolveRoom: () async => otherRoom,
        runner: runner,
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
      expect(runner.calls, isEmpty);
    },
  );

  group('retry outcomes', () {
    late _MockRoom room;

    setUp(() {
      room = _MockRoom();
      when(() => room.id).thenReturn(roomId);
    });

    test(
      'completed run clears the retry counter and emits no incomplete log',
      () async {
        final runner = _RecordingRunner();
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
        );
        await coordinator.bridgeNow();
        expect(runner.calls, hasLength(1));
        verifyNever(
          () => logging.captureEvent(
            any<String>(
              that: contains('queue.bridge.incomplete'),
            ),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        );
      },
    );

    test(
      'incomplete run schedules a bounded retry timer and the retry '
      'eventually fires _bridge again',
      () async {
        var callCount = 0;
        final runner = _RecordingRunner()
          ..override = (Room r, BridgeMarker m) async {
            callCount++;
            return callCount > 1; // first call incomplete, then completes.
          };
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
          incompleteRetryDelay: const Duration(milliseconds: 10),
        );
        await coordinator.bridgeNow();
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
      'maxIncompleteRetries consecutive incomplete runs',
      () async {
        final runner = _RecordingRunner(defaultCompleted: false);
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
          incompleteRetryDelay: const Duration(milliseconds: 5),
          maxIncompleteRetries: 2,
        );
        await coordinator.bridgeNow();
        await Future<void>.delayed(const Duration(milliseconds: 80));
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
        final runner = _RecordingRunner(defaultCompleted: false);
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
          incompleteRetryDelay: const Duration(milliseconds: 50),
        );
        await coordinator.bridgeNow();
        final callsAtStop = runner.calls.length;
        await coordinator.stop();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(runner.calls.length, callsAtStop);
      },
    );

    test(
      'onBridgeCompleted fires once per terminal walk — the backfill '
      'service uses this to dispatch requests for anything still '
      'missing now that the walk has settled',
      () async {
        final runner = _RecordingRunner();
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
        );
        var completions = 0;
        coordinator.onBridgeCompleted = () => completions++;

        await coordinator.bridgeNow();

        expect(completions, 1);
        await coordinator.stop();
      },
    );

    test(
      'coalesced reruns fire onBridgeCompleted exactly once — the '
      'single-flight cascade is a single logical walk from the '
      "consumer's perspective, not two",
      () async {
        final firstCallGate = Completer<void>();
        var callCount = 0;
        final runner = _RecordingRunner()
          ..override = (Room r, BridgeMarker m) async {
            callCount++;
            if (callCount == 1) await firstCallGate.future;
            return true;
          };
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
        );
        var completions = 0;
        coordinator.onBridgeCompleted = () => completions++;

        // Kick off the first bridge, then pile on a second while the
        // first is still gated — the second should coalesce into a
        // rerun rather than start its own walk.
        final firstBridge = coordinator.bridgeNow();
        await Future<void>.delayed(Duration.zero);
        unawaited(coordinator.bridgeNow());
        await Future<void>.delayed(Duration.zero);
        expect(callCount, 1);
        expect(completions, 0);

        firstCallGate.complete();
        await firstBridge;
        // Drain the unawaited rerun so its finally block can fire.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
          if (callCount >= 2) break;
        }
        expect(callCount, 2);
        expect(completions, 1);
        await coordinator.stop();
      },
    );

    test(
      'onBridgeCompleted does not fire after stop() even if a walk was '
      'racing with shutdown',
      () async {
        final runner = _RecordingRunner();
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
        );
        var completions = 0;
        coordinator.onBridgeCompleted = () => completions++;

        await coordinator.stop();
        await coordinator.bridgeNow();

        expect(completions, 0);
      },
    );

    test(
      'onBridgeCompleted throwing is caught and logged — the finally '
      'block must not let a callback error bubble out and break the '
      'single-flight reset',
      () async {
        final runner = _RecordingRunner();
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
        );
        // ignore: cascade_invocations
        coordinator.onBridgeCompleted = () {
          throw StateError('nudge blew up');
        };

        // bridgeNow must not rethrow the callback failure.
        await coordinator.bridgeNow();

        // Next call proceeds normally — the in-flight guard was still
        // cleared by the finally block, the callback failure
        // notwithstanding.
        await coordinator.bridgeNow();
        await coordinator.stop();
      },
    );
  });
}
