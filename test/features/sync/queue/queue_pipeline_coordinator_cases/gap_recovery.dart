part of '../queue_pipeline_coordinator_test.dart';

extension _GapRecoveryCases on _QueueCoordinatorTestSetup {
  void registerGapRecovery() {
    group('gap-triggered unbounded bootstrap (barren-bridge recovery)', () {
      // Shared helper: stubs a [MockTimeline] with [events] and wires
      // `requestHistory` so that each call either adds more events
      // (also below the boundary, so the sink can stay unproductive)
      // or flips `canRequestHistory` to false to end the walk.
      MockTimeline stubTimeline({
        required List<Event> events,
        required bool Function() canRequestHistory,
        required Future<void> Function(int historyCount) onRequestHistory,
      }) {
        final tl = MockTimeline();
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => canRequestHistory());
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((invocation) async {
          final hc = invocation.namedArguments[#historyCount] as int? ?? 0;
          await onRequestHistory(hc);
        });
        when(tl.cancelSubscriptions).thenAnswer((_) {});
        return tl;
      }

      Event buildSyncPayload({
        required String id,
        required int tsMs,
      }) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn(id);
        when(() => e.roomId).thenReturn(roomId);
        when(() => e.type).thenReturn(EventTypes.Message);
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(tsMs));
        // Non-sync content so `InboundQueue.appendBootstrapPage` drops it
        // as `filteredOutByType` — the sink reports 0 accepted, which is
        // exactly the signal the barren-bridge path keys off.
        when(() => e.content).thenReturn(<String, dynamic>{});
        when(e.toJson).thenReturn(<String, dynamic>{
          'event_id': id,
          'room_id': roomId,
          'origin_server_ts': tsMs,
          'type': EventTypes.Message,
          'content': <String, dynamic>{},
        });
        return e;
      }

      QueuePipelineCoordinator buildWithRealQueue() {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        return QueuePipelineCoordinator(
          syncDb: syncDb,
          settingsDb: settingsDb,
          journalDb: journalDb,
          sessionManager: sessionManager,
          roomManager: roomManager,
          eventProcessor: processor,
          sequenceLogService: sequenceLog,
          activityGate: null,
          logging: logging,
          queueOverride: realQueue,
          workerOverride: worker,
          bridgeOverride: bridge,
          seederOverride: seeder,
        );
      }

      test(
        'reconnect bridge that hits boundaryReached with zero accepted '
        'records a barren-bridge signal — subsequent maybeStartGapRecovery '
        'runs an unbounded walk',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          // Boundary at ts=100. Every event we feed is at ts=50, which
          // crosses the boundary on the very first page. The SDK also
          // always claims it has more history so the strategy tries up
          // to `boundaryContinuationCap` continuations — each still
          // producing boundary-crossing, 0-accepted pages. That is the
          // "barren" shape we want to detect.
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          // `maybeStartGapRecovery` resolves the room via
          // `_resolveRoom`, which consults the room manager first and
          // then falls back to `client.getRoomById`. Wire the cache so
          // the recovery walk has the same room as the reconnect walk.
          when(() => roomManager.currentRoom).thenReturn(room);
          var historyCalls = 0;
          final events = <Event>[buildSyncPayload(id: r'$e-0', tsMs: 50)];
          final timeline = stubTimeline(
            events: events,
            canRequestHistory: () => true,
            onRequestHistory: (_) async {
              historyCalls++;
              events.insert(
                0,
                buildSyncPayload(
                  id: r'$e-$historyCalls',
                  tsMs: 50 - historyCalls,
                ),
              );
            },
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          final reconnectCompleted = await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 100,
          );

          expect(reconnectCompleted, isTrue);
          expect(coordinator.hasBarrenBridgeSignal, isTrue);

          // The gap recovery path now runs an unbounded walk. Swap in a
          // second timeline that has one more round-trip's worth of
          // events and then declares itself exhausted, so we can
          // observe that an extra `getTimeline` was issued.
          final recoveryEvents = <Event>[];
          final recoveryTimeline = stubTimeline(
            events: recoveryEvents,
            canRequestHistory: () => false,
            onRequestHistory: (_) async {},
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => recoveryTimeline);

          coordinator.maybeStartGapRecovery();
          expect(coordinator.gapRecoveryInFlight, isTrue);
          // Flag consumed up-front so a burst of subsequent gap signals
          // coalesces instead of spawning a second walk.
          expect(coordinator.hasBarrenBridgeSignal, isFalse);

          await coordinator.gapRecoveryFuture;
          expect(coordinator.gapRecoveryInFlight, isFalse);

          // Two bootstrap passes total: the barren reconnect plus the
          // gap-recovery unbounded walk.
          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(2);
        },
      );

      test(
        'productive reconnect bridge (accepted > 0) does not set the '
        'barren signal, so gap recovery is a no-op',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          // Page has exactly one event below the boundary, and the
          // real InboundQueue will `filteredOutByType`-drop it — so the
          // test actually drives the "barren" path, not the "productive"
          // one. To force "productive" without wiring the full sync
          // message pipeline, flip the bridge into a non-boundary
          // completion via `serverExhausted`: the event is emitted and
          // the SDK has no more history. That is a different stopReason
          // and must also clear the barren flag.
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final events = <Event>[buildSyncPayload(id: r'$e-prod', tsMs: 50)];
          final timeline = stubTimeline(
            events: events,
            canRequestHistory: () => false,
            onRequestHistory: (_) async {},
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          final completed = await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 100,
          );

          expect(completed, isTrue);
          // serverExhausted (not boundaryReached) — not barren.
          expect(coordinator.hasBarrenBridgeSignal, isFalse);

          coordinator.maybeStartGapRecovery();
          expect(coordinator.gapRecoveryInFlight, isFalse);

          // Only the initial bootstrap pass; gap recovery did not fire.
          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(1);
        },
      );

      test(
        'fresh-mode bootstrap (untilTimestamp=null) never sets the '
        'barren signal even when the walk accepts zero events — a '
        'fresh walk with no acceptance means the server has nothing, '
        'so re-running it is pointless',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = stubTimeline(
            events: <Event>[],
            canRequestHistory: () => false,
            onRequestHistory: (_) async {},
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          final completed = await coordinator.runBootstrapForTest(
            room: room,
          );

          expect(completed, isTrue);
          expect(coordinator.hasBarrenBridgeSignal, isFalse);

          coordinator.maybeStartGapRecovery();
          expect(coordinator.gapRecoveryInFlight, isFalse);
        },
      );

      test(
        'forward bootstrap with an unresolvable anchor falls back to the '
        'backward walk (errorNoProgress path)',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          // Forward walk: the anchor context fetch throws, producing
          // totalPages == 0 + error == _BootstrapOutcome.errorNoProgress.
          when(
            () => room.getTimeline(
              eventContextId: any(named: 'eventContextId'),
            ),
          ).thenThrow(Exception('anchor context fetch failed'));
          // Backward walk: empty, exhausted timeline -> completes cleanly.
          final timeline = stubTimeline(
            events: <Event>[],
            canRequestHistory: () => false,
            onRequestHistory: (_) async {},
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          final completed = await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 100,
            anchorEventId: r'$compacted-away-anchor',
          );

          // The fallback chain completed via the backward walk.
          expect(completed, isTrue);
          verify(
            () => logging.log(
              LogDomain.sync,
              any(that: contains('fallbackToBackward')),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
          // The backward walk actually ran after the forward failure.
          verify(() => room.getTimeline(limit: any(named: 'limit'))).called(1);
        },
      );

      test(
        'maybeStartGapRecovery is a no-op when no barren bridge has '
        'been recorded yet — gap detection on a healthy pipeline does '
        'not burn a full /messages walk',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          expect(coordinator.hasBarrenBridgeSignal, isFalse);

          coordinator.maybeStartGapRecovery();
          expect(coordinator.gapRecoveryInFlight, isFalse);
        },
      );

      test(
        'barren signal expires after barrenBridgeTtl — a stale cache '
        'wedge from hours ago does not hijack a later gap into an '
        'unbounded walk',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          final baseTime = DateTime(2026, 4, 21, 10);
          await withClock(Clock.fixed(baseTime), () async {
            final room = MockRoom();
            when(() => room.id).thenReturn(roomId);
            var historyCalls = 0;
            final events = <Event>[buildSyncPayload(id: r'$e-0', tsMs: 50)];
            final timeline = stubTimeline(
              events: events,
              canRequestHistory: () => true,
              onRequestHistory: (_) async {
                historyCalls++;
                events.insert(
                  0,
                  buildSyncPayload(
                    id: r'$e-$historyCalls',
                    tsMs: 50 - historyCalls,
                  ),
                );
              },
            );
            when(
              () => room.getTimeline(limit: any(named: 'limit')),
            ).thenAnswer((_) async => timeline);

            await coordinator.runBootstrapForTest(
              room: room,
              untilTimestamp: 100,
            );
            expect(coordinator.hasBarrenBridgeSignal, isTrue);
          });

          // Advance past the TTL. The barren signal must auto-clear on
          // the next `maybeStartGapRecovery` call.
          final afterTtl = baseTime.add(
            QueuePipelineCoordinator.barrenBridgeTtl +
                const Duration(seconds: 1),
          );
          await withClock(Clock.fixed(afterTtl), () async {
            coordinator.maybeStartGapRecovery();
            expect(coordinator.gapRecoveryInFlight, isFalse);
            expect(coordinator.hasBarrenBridgeSignal, isFalse);
          });
        },
      );

      test(
        'concurrent maybeStartGapRecovery calls coalesce onto the '
        'in-flight recovery — a burst of gap signals from a replay '
        'batch does not spawn parallel /messages walks',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          // First: record the barren bridge.
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(room);
          var historyCalls = 0;
          final events = <Event>[buildSyncPayload(id: r'$e-0', tsMs: 50)];
          final barrenTimeline = stubTimeline(
            events: events,
            canRequestHistory: () => true,
            onRequestHistory: (_) async {
              historyCalls++;
              events.insert(
                0,
                buildSyncPayload(
                  id: r'$e-$historyCalls',
                  tsMs: 50 - historyCalls,
                ),
              );
            },
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => barrenTimeline);

          await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 100,
          );
          expect(coordinator.hasBarrenBridgeSignal, isTrue);

          // Now swap in a recovery timeline whose `getTimeline` we can
          // count. The first recovery call triggers a walk; a second
          // concurrent call must not spawn a second `getTimeline`.
          final recoveryCompleter = Completer<Timeline>();
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) => recoveryCompleter.future);

          coordinator.maybeStartGapRecovery();
          expect(coordinator.gapRecoveryInFlight, isTrue);

          // Second call lands while the first is still awaiting the
          // getTimeline future — it should coalesce and not start
          // another walk.
          coordinator.maybeStartGapRecovery();

          // Resolve the recovery timeline with an empty, exhausted
          // snapshot so the walk completes.
          final recoveryTimeline = stubTimeline(
            events: <Event>[],
            canRequestHistory: () => false,
            onRequestHistory: (_) async {},
          );
          recoveryCompleter.complete(recoveryTimeline);
          await coordinator.gapRecoveryFuture;

          expect(coordinator.gapRecoveryInFlight, isFalse);
          // Exactly two `getTimeline` calls total: the barren reconnect
          // and the one coalesced recovery walk.
          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(2);
        },
      );

      test(
        'gap recovery whose room can no longer be resolved logs the '
        'skip=noRoom line and does no backward walk — the room vanished '
        'between recording the barren signal and the recovery firing',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          // Record the barren bridge against a resolvable room.
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(room);
          var historyCalls = 0;
          final events = <Event>[buildSyncPayload(id: r'$e-0', tsMs: 50)];
          final barrenTimeline = stubTimeline(
            events: events,
            canRequestHistory: () => true,
            onRequestHistory: (_) async {
              historyCalls++;
              events.insert(
                0,
                buildSyncPayload(
                  id: r'$e-$historyCalls',
                  tsMs: 50 - historyCalls,
                ),
              );
            },
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => barrenTimeline);

          await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 100,
          );
          expect(coordinator.hasBarrenBridgeSignal, isTrue);

          // The room vanishes before recovery fires: `_resolveRoom`
          // returns null (cache null, no current room id).
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => roomManager.currentRoomId).thenReturn(null);

          coordinator.maybeStartGapRecovery();
          await coordinator.gapRecoveryFuture;
          expect(coordinator.gapRecoveryInFlight, isFalse);

          verify(
            () => logging.log(
              any<LogDomain>(),
              any<String>(
                that: contains(
                  'queue.coordinator.gapRecovery.skip reason=noRoom',
                ),
              ),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).called(1);
          // No second backward walk: only the barren reconnect issued a
          // `getTimeline`; recovery bailed at the noRoom guard.
          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(1);
        },
      );

      test(
        'an exception while resolving the room for gap recovery is caught '
        'and logged under the gapRecovery subDomain — a failed recovery '
        'must never escape as an unhandled fire-and-forget error',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(room);
          var historyCalls = 0;
          final events = <Event>[buildSyncPayload(id: r'$e-0', tsMs: 50)];
          final barrenTimeline = stubTimeline(
            events: events,
            canRequestHistory: () => true,
            onRequestHistory: (_) async {
              historyCalls++;
              events.insert(
                0,
                buildSyncPayload(
                  id: r'$e-$historyCalls',
                  tsMs: 50 - historyCalls,
                ),
              );
            },
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => barrenTimeline);

          await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 100,
          );
          expect(coordinator.hasBarrenBridgeSignal, isTrue);

          // `_resolveRoom` now throws: cache is null and the gateway
          // lookup blows up, so the recovery's outer try/catch fires.
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => roomManager.currentRoomId).thenReturn(roomId);
          when(
            () => client.getRoomById(roomId),
          ).thenThrow(StateError('gateway down'));

          coordinator.maybeStartGapRecovery();
          await coordinator.gapRecoveryFuture;
          expect(coordinator.gapRecoveryInFlight, isFalse);

          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('gapRecovery'),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'backward walk whose requestHistory throws ends in stopReason=error '
        'and _runBackwardBootstrap returns false so the bridge schedules a '
        'bounded retry instead of treating the walk as complete',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();
          addTearDown(() async => coordinator.stop());

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          // First page has one event (so the walk does not immediately
          // serverExhaust), the SDK still claims more history, and the
          // follow-up `requestHistory` throws — that is the exact shape
          // that yields BootstrapStopReason.error from the backward walk.
          final timeline = stubTimeline(
            events: <Event>[buildSyncPayload(id: r'$e-err', tsMs: 500)],
            canRequestHistory: () => true,
            onRequestHistory: (_) async {
              throw StateError('network lost mid-backward-walk');
            },
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          // Fresh-mode walk (untilTimestamp == null) so no boundary
          // logic interferes — the only terminal reason available is the
          // requestHistory throw.
          final completed = await coordinator.runBootstrapForTest(room: room);

          expect(
            completed,
            isFalse,
            reason: 'error stopReason maps to false from _runBackwardBootstrap',
          );
          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('bootstrap.requestHistory'),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'stop() awaits an in-flight gap-recovery walk before tearing the '
        'queue down — a recovery /messages walk launched moments before '
        'shutdown must settle so its sink writes finish before disposal',
        () async {
          final coordinator = buildWithRealQueue();
          await coordinator.start();

          // Record the barren bridge so a gap signal can launch recovery.
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(room);
          var historyCalls = 0;
          final events = <Event>[buildSyncPayload(id: r'$e-0', tsMs: 50)];
          final barrenTimeline = stubTimeline(
            events: events,
            canRequestHistory: () => true,
            onRequestHistory: (_) async {
              historyCalls++;
              events.insert(
                0,
                buildSyncPayload(
                  id: r'$e-$historyCalls',
                  tsMs: 50 - historyCalls,
                ),
              );
            },
          );
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => barrenTimeline);

          await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 100,
          );
          expect(coordinator.hasBarrenBridgeSignal, isTrue);

          // Block the recovery walk's getTimeline on a completer so the
          // recovery future stays in-flight while we call stop().
          final recoveryGate = Completer<Timeline>();
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) => recoveryGate.future);

          coordinator.maybeStartGapRecovery();
          expect(coordinator.gapRecoveryInFlight, isTrue);

          // stop() must reach the gapRecovery teardown stage and await the
          // in-flight future. Kick it off without awaiting, prove it has
          // NOT completed while recovery is gated, then release the gate.
          var stopDone = false;
          final stopFuture = coordinator.stop().then((_) => stopDone = true);
          await pumpEventQueue();
          expect(
            stopDone,
            isFalse,
            reason: 'stop must block on the in-flight gap recovery',
          );

          // Release the recovery walk with an empty, exhausted snapshot.
          recoveryGate.complete(
            stubTimeline(
              events: <Event>[],
              canRequestHistory: () => false,
              onRequestHistory: (_) async {},
            ),
          );

          await stopFuture;
          expect(stopDone, isTrue);
          expect(coordinator.gapRecoveryInFlight, isFalse);
          expect(coordinator.isRunning, isFalse);
          // Teardown reached the post-gap-recovery stages: the worker was
          // stopped only after the recovery walk settled.
          verify(() => worker.stop()).called(1);
        },
      );
    });
  }
}
