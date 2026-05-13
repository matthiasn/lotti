import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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

enum _GeneratedBridgeRoomResolution { noRoom, currentRoom, changedRoom }

enum _GeneratedBridgeMarkerTsKind { absent, zero, present }

enum _GeneratedBridgeAnchorKind { absent, present }

enum _GeneratedBridgeTriggerKind {
  bridgeNow,
  limitedCurrentRoom,
  limitedOtherRoom,
  nonLimitedCurrentRoom,
}

extension on _GeneratedBridgeTriggerKind {
  bool get shouldStartBridge =>
      this == _GeneratedBridgeTriggerKind.bridgeNow ||
      this == _GeneratedBridgeTriggerKind.limitedCurrentRoom;
}

class _GeneratedBridgeScenario {
  const _GeneratedBridgeScenario({
    required this.roomResolution,
    required this.markerTsKind,
    required this.anchorKind,
    required this.triggers,
    required this.slot,
  });

  final _GeneratedBridgeRoomResolution roomResolution;
  final _GeneratedBridgeMarkerTsKind markerTsKind;
  final _GeneratedBridgeAnchorKind anchorKind;
  final List<_GeneratedBridgeTriggerKind> triggers;
  final int slot;

  String get expectedRoomId => '!generated-bridge-$slot:example.org';
  String get actualRoomId =>
      roomResolution == _GeneratedBridgeRoomResolution.changedRoom
      ? '!generated-bridge-other-$slot:example.org'
      : expectedRoomId;

  int? get markerTs {
    switch (markerTsKind) {
      case _GeneratedBridgeMarkerTsKind.absent:
        return null;
      case _GeneratedBridgeMarkerTsKind.zero:
        return 0;
      case _GeneratedBridgeMarkerTsKind.present:
        return 1000 + slot;
    }
  }

  String? get anchorEventId {
    switch (anchorKind) {
      case _GeneratedBridgeAnchorKind.absent:
        return null;
      case _GeneratedBridgeAnchorKind.present:
        return '\$generated-anchor-$slot';
    }
  }

  int get expectedRunnerCalls {
    if (roomResolution != _GeneratedBridgeRoomResolution.currentRoom) return 0;
    return triggers.where((trigger) => trigger.shouldStartBridge).length;
  }

  @override
  String toString() {
    return '_GeneratedBridgeScenario('
        'roomResolution: $roomResolution, '
        'markerTsKind: $markerTsKind, '
        'anchorKind: $anchorKind, '
        'triggers: $triggers, '
        'slot: $slot'
        ')';
  }
}

extension _AnyGeneratedBridgeScenario on glados.Any {
  glados.Generator<_GeneratedBridgeRoomResolution> get bridgeRoomResolution =>
      glados.AnyUtils(
        this,
      ).choose(_GeneratedBridgeRoomResolution.values);

  glados.Generator<_GeneratedBridgeMarkerTsKind> get bridgeMarkerTsKind =>
      glados.AnyUtils(this).choose(_GeneratedBridgeMarkerTsKind.values);

  glados.Generator<_GeneratedBridgeAnchorKind> get bridgeAnchorKind =>
      glados.AnyUtils(this).choose(_GeneratedBridgeAnchorKind.values);

  glados.Generator<_GeneratedBridgeTriggerKind> get bridgeTriggerKind =>
      glados.AnyUtils(this).choose(_GeneratedBridgeTriggerKind.values);

  glados.Generator<_GeneratedBridgeScenario> get bridgeScenario =>
      glados.CombinableAny(this).combine5(
        bridgeRoomResolution,
        bridgeMarkerTsKind,
        bridgeAnchorKind,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(1, 12, bridgeTriggerKind),
        glados.IntAnys(this).intInRange(0, 6),
        (
          _GeneratedBridgeRoomResolution roomResolution,
          _GeneratedBridgeMarkerTsKind markerTsKind,
          _GeneratedBridgeAnchorKind anchorKind,
          List<_GeneratedBridgeTriggerKind> triggers,
          int slot,
        ) => _GeneratedBridgeScenario(
          roomResolution: roomResolution,
          markerTsKind: markerTsKind,
          anchorKind: anchorKind,
          triggers: triggers,
          slot: slot,
        ),
      );
}

Future<void> _drainBridgeCoordinatorMicrotasks() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.value();
  }
}

void main() {
  late SyncDatabase db;
  late MockLoggingService logging;
  late InboundQueue queue;
  late MockMatrixClient client;
  late CachedStreamController<SyncUpdate> syncCtl;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockLoggingService();
    queue = InboundQueue(db: db, logging: logging);
    client = MockMatrixClient();
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
      final room = MockRoom();
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
      final room = MockRoom();
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
      final room = MockRoom();
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
      final room = MockRoom();
      when(() => room.id).thenReturn(roomId);
      final retried = Completer<void>();
      var callCount = 0;
      final runner = _RecordingRunner()
        ..override = (Room r, BridgeMarker m) async {
          callCount++;
          if (callCount >= 2 && !retried.isCompleted) {
            retried.complete();
          }
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
      await retried.future.timeout(const Duration(seconds: 2));
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
      final room = MockRoom();
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
      final otherRoom = MockRoom();
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

  glados.Glados(
    glados.any.bridgeScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'generated trigger streams only bridge the active room and preserve marker',
    (scenario) async {
      final generatedClient = MockMatrixClient();
      final generatedSyncCtl = CachedStreamController<SyncUpdate>();
      final generatedLogging = MockLoggingService();
      final generatedRoom = MockRoom();
      final runner = _RecordingRunner();
      when(() => generatedClient.onSync).thenReturn(generatedSyncCtl);
      when(() => generatedRoom.id).thenReturn(scenario.actualRoomId);

      final coordinator = BridgeCoordinator(
        client: generatedClient,
        currentRoomId: () => scenario.expectedRoomId,
        resolveRoom: () async {
          if (scenario.roomResolution ==
              _GeneratedBridgeRoomResolution.noRoom) {
            return null;
          }
          return generatedRoom;
        },
        readMarker: () async => BridgeMarker(
          lastAppliedTs: scenario.markerTs,
          lastAppliedEventId: scenario.anchorEventId,
        ),
        bootstrapRunner: runner.runner,
        logging: generatedLogging,
      )..start();

      try {
        for (final trigger in scenario.triggers) {
          switch (trigger) {
            case _GeneratedBridgeTriggerKind.bridgeNow:
              await coordinator.bridgeNow();
            case _GeneratedBridgeTriggerKind.limitedCurrentRoom:
              generatedSyncCtl.add(_limitedSyncFor(scenario.expectedRoomId));
            case _GeneratedBridgeTriggerKind.limitedOtherRoom:
              generatedSyncCtl.add(_limitedSyncFor('!other:example.org'));
            case _GeneratedBridgeTriggerKind.nonLimitedCurrentRoom:
              generatedSyncCtl.add(_nonLimitedSyncFor(scenario.expectedRoomId));
          }
          await _drainBridgeCoordinatorMicrotasks();
        }

        expect(
          runner.calls,
          hasLength(scenario.expectedRunnerCalls),
          reason: '$scenario',
        );
        for (final call in runner.calls) {
          expect(call.room, same(generatedRoom), reason: '$scenario');
          expect(
            call.untilTimestamp,
            scenario.markerTs,
            reason: '$scenario',
          );
          expect(
            call.anchorEventId,
            scenario.anchorEventId,
            reason: '$scenario',
          );
        }
      } finally {
        await coordinator.stop();
        await generatedSyncCtl.close();
      }
    },
    tags: 'glados',
  );

  group('retry outcomes', () {
    late MockRoom room;

    setUp(() {
      room = MockRoom();
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
        final retryCompleted = Completer<void>();
        final runner = _RecordingRunner()
          ..override = (Room r, BridgeMarker m) async {
            callCount++;
            if (callCount > 1 && !retryCompleted.isCompleted) {
              retryCompleted.complete();
            }
            return callCount > 1; // first call incomplete, then completes.
          };
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
          incompleteRetryDelay: const Duration(milliseconds: 10),
        );
        await coordinator.bridgeNow();
        await retryCompleted.future.timeout(const Duration(seconds: 2));
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
        final gaveUp = Completer<void>();
        final runner = _RecordingRunner(defaultCompleted: false);
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
          incompleteRetryDelay: const Duration(milliseconds: 5),
          maxIncompleteRetries: 2,
        );
        when(
          () => logging.captureEvent(
            any<String>(that: contains('queue.bridge.incomplete.giveUp')),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) {
          if (!gaveUp.isCompleted) gaveUp.complete();
        });
        await coordinator.bridgeNow();
        await gaveUp.future.timeout(const Duration(seconds: 2));
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
      () {
        fakeAsync((async) {
          final runner = _RecordingRunner(defaultCompleted: false);
          final coordinator = buildCoordinator(
            resolveRoom: () async => room,
            runner: runner,
            incompleteRetryDelay: const Duration(milliseconds: 50),
          );
          unawaited(coordinator.bridgeNow());
          async.flushMicrotasks();
          final callsAtStop = runner.calls.length;
          unawaited(coordinator.stop());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 120))
            ..flushMicrotasks();
          expect(runner.calls.length, callsAtStop);
        });
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
        final gate = Completer<void>();
        final runner = _RecordingRunner()
          ..override = (Room r, BridgeMarker m) async {
            await gate.future;
            return true;
          };
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
        );
        var completions = 0;
        coordinator.onBridgeCompleted = () => completions++;

        // Start a walk that is gated mid-flight, then request shutdown
        // while the walk is still running. `stop()` awaits the
        // in-flight bridge, so release the gate so the walk can
        // complete — the finally block must observe `_stopped == true`
        // and skip the completion callback.
        final walk = coordinator.bridgeNow();
        await Future<void>.delayed(Duration.zero);
        final shutdown = coordinator.stop();
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        await walk;
        await shutdown;

        expect(completions, 0);
      },
    );

    test(
      'isBridgeInFlight is true while a walk is running and clears once '
      'the walk settles — this is the signal the backfill service '
      'reads to skip analysis during a walk',
      () async {
        final gate = Completer<void>();
        final runner = _RecordingRunner()
          ..override = (Room r, BridgeMarker m) async {
            await gate.future;
            return true;
          };
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
        );

        expect(coordinator.isBridgeInFlight, isFalse);

        final walk = coordinator.bridgeNow();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.isBridgeInFlight, isTrue);

        gate.complete();
        await walk;
        expect(coordinator.isBridgeInFlight, isFalse);
        await coordinator.stop();
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

        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: endsWith('.onCompleted'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);

        // Next call proceeds normally — the in-flight guard was still
        // cleared by the finally block, the callback failure
        // notwithstanding.
        await coordinator.bridgeNow();
        expect(runner.calls, hasLength(2));
        await coordinator.stop();
      },
    );

    test(
      'onBridgeCompleted is suppressed while an incomplete-retry timer '
      'is queued — the bounded retry is expected to close the gap, so '
      'the callback must not nudge the backfill service into '
      'dispatching ~100-entry requests ahead of the retry',
      () async {
        final runner = _RecordingRunner(defaultCompleted: false);
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
          incompleteRetryDelay: const Duration(milliseconds: 50),
        );
        var completions = 0;
        coordinator.onBridgeCompleted = () => completions++;

        await coordinator.bridgeNow();

        // Walk reported incomplete → a retry timer was armed → the
        // completion callback must NOT have fired.
        expect(completions, 0);

        await coordinator.stop();
      },
    );

    test(
      'onBridgeCompleted fires on the retry that successfully completes '
      'after a prior incomplete walk',
      () async {
        final outcomes = <bool>[false, true];
        var index = 0;
        final completed = Completer<void>();
        final runner = _RecordingRunner()
          ..override = (Room r, BridgeMarker m) async {
            final result = outcomes[index.clamp(0, outcomes.length - 1)];
            index++;
            return result;
          };
        final coordinator = buildCoordinator(
          resolveRoom: () async => room,
          runner: runner,
          incompleteRetryDelay: const Duration(milliseconds: 10),
        );
        var completions = 0;
        coordinator.onBridgeCompleted = () {
          completions++;
          if (!completed.isCompleted) completed.complete();
        };

        await coordinator.bridgeNow();

        await completed.future.timeout(const Duration(seconds: 2));
        expect(index, 2);
        expect(completions, 1);

        await coordinator.stop();
      },
    );
  });
}
