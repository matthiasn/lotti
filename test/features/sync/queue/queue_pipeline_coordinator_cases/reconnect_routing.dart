part of '../queue_pipeline_coordinator_test.dart';

extension _ReconnectRoutingCases on _QueueCoordinatorTestSetup {
  void registerReconnectRouting() {
    test(
      'a resume floor behind the applied anchor dispatches backward from '
      'the floor instead of stepping over the known gap',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = QueuePipelineCoordinator(
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
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);

        final forwardTimeline = MockTimeline();
        final anchor = MockEvent();
        when(() => anchor.eventId).thenReturn(r'$anchor');
        when(
          () => anchor.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(5000));
        when(() => forwardTimeline.events).thenReturn(<Event>[anchor]);
        when(() => forwardTimeline.canRequestFuture).thenReturn(false);
        when(forwardTimeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => forwardTimeline);

        final backwardTimeline = MockTimeline();
        when(() => backwardTimeline.events).thenReturn(<Event>[]);
        when(() => backwardTimeline.canRequestHistory).thenReturn(false);
        when(backwardTimeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => backwardTimeline);

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          untilTimestamp: 5000,
          anchorEventId: r'$anchor',
          resumeFloorTs: 3000,
        );

        expect(completed, isTrue);
        verify(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).called(1);
        verifyNever(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test(
      'anchor event id dispatches to room.getTimeline(eventContextId:) '
      'and NOT to the backward walk — this is the load-bearing reconnect '
      'path that closes gaps the cached backward timeline cannot',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = QueuePipelineCoordinator(
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
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final timeline = MockTimeline();
        final anchor = MockEvent();
        when(() => anchor.eventId).thenReturn(r'$anchor');
        when(
          () => anchor.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
        when(() => timeline.events).thenReturn(<Event>[anchor]);
        when(() => timeline.canRequestFuture).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => timeline);
        when(() => roomManager.currentRoom).thenReturn(room);

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          anchorEventId: r'$anchor',
        );

        expect(completed, isTrue);
        // Forward walk exclusively — no backward fallback triggered
        // because the anchor resolved successfully.
        verify(
          () => room.getTimeline(
            eventContextId: r'$anchor',
            limit: any(named: 'limit'),
          ),
        ).called(1);
        verifyNever(
          () => room.getTimeline(limit: any(named: 'limit')),
        );
      },
    );

    test(
      'anchor unresolvable on the server → falls back to backward walk '
      'so reconnect never silently no-ops when the anchor has been '
      'compacted out',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = QueuePipelineCoordinator(
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
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        // Forward-walk timeline: empty events (anchor unresolvable).
        final forwardTl = MockTimeline();
        when(() => forwardTl.events).thenReturn(<Event>[]);
        when(() => forwardTl.canRequestFuture).thenReturn(true);
        when(forwardTl.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => forwardTl);
        // Backward-walk timeline: empty, server-exhausted.
        final backwardTl = MockTimeline();
        when(() => backwardTl.events).thenReturn(<Event>[]);
        when(() => backwardTl.canRequestHistory).thenReturn(false);
        when(backwardTl.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => backwardTl);
        when(() => roomManager.currentRoom).thenReturn(room);

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          untilTimestamp: 50,
          anchorEventId: r'$compacted',
        );

        expect(completed, isTrue);
        verify(
          () => room.getTimeline(
            eventContextId: r'$compacted',
            limit: any(named: 'limit'),
          ),
        ).called(1);
        // Fallback backward walk also ran.
        verify(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).called(1);
      },
    );

    test(
      'forward walk that exhausts its round-trip budget while the server '
      'still has more reports INCOMPLETE, so the bridge retries — mapping '
      'boundaryReached to completed is what let a walk cover 51 events of a '
      '150-message burst and report success, stranding the rest',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = QueuePipelineCoordinator(
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
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        // Non-payload events, so every page is `filteredOutByType` and
        // nothing reaches the queue. That is the shape observed in the
        // failing run: 50 round trips, accepted=0, server still advertising
        // more. It also keeps the walk clear of queue back-pressure, so the
        // only thing that can stop it is the budget.
        Event buildEvent(int index) {
          final event = MockEvent();
          when(() => event.eventId).thenReturn('\$e$index');
          when(
            () => event.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100 + index));
          when(() => event.roomId).thenReturn(roomId);
          when(() => event.type).thenReturn(EventTypes.Message);
          when(() => event.content).thenReturn(<String, dynamic>{});
          when(event.toJson).thenReturn(<String, dynamic>{
            'event_id': '\$e$index',
            'room_id': roomId,
            'origin_server_ts': 100 + index,
            'type': EventTypes.Message,
            'content': <String, dynamic>{},
          });
          return event;
        }

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final timeline = MockTimeline();
        final anchor = MockEvent();
        when(() => anchor.eventId).thenReturn(r'$anchor');
        when(
          () => anchor.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
        final events = <Event>[anchor, buildEvent(0)];
        var futureCalls = 0;
        when(() => timeline.events).thenAnswer((_) => events);
        // The server never runs out — exactly the live-burst case, where the
        // walk keeps trailing the tip one event per round trip.
        when(() => timeline.canRequestFuture).thenReturn(true);
        when(
          () =>
              timeline.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          futureCalls++;
          events.add(buildEvent(futureCalls));
        });
        when(timeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => timeline);
        when(() => roomManager.currentRoom).thenReturn(room);

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          anchorEventId: r'$anchor',
        );

        expect(completed, isFalse);
        // The budget is spent on requests, so a server handing back one event
        // per call still gets the full allowance: the anchor context fetch
        // plus `cap - 1` pagination calls.
        expect(futureCalls, SyncTuning.forwardWalkRoundTripCap - 1);
        // No backward-walk fallback: that path is reserved for an
        // unresolvable anchor, and this anchor resolved fine.
        verifyNever(() => room.getTimeline(limit: any(named: 'limit')));
      },
    );

    test(
      'forward-walk requestFuture error mid-walk returns incomplete '
      'without falling back — totalPages > 0 means the bridge made '
      'progress, so the retry machinery should bounce rather than '
      'redoing the already-applied pages via the backward path',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = QueuePipelineCoordinator(
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
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final timeline = MockTimeline();
        final anchor = MockEvent();
        when(() => anchor.eventId).thenReturn(r'$anchor');
        when(
          () => anchor.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
        final e1 = MockEvent();
        when(() => e1.eventId).thenReturn(r'$e1');
        when(
          () => e1.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(110));
        when(() => e1.roomId).thenReturn(roomId);
        when(() => e1.type).thenReturn(EventTypes.Message);
        when(() => e1.content).thenReturn(<String, dynamic>{});
        when(e1.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$e1',
          'room_id': roomId,
          'origin_server_ts': 110,
          'type': EventTypes.Message,
          'content': <String, dynamic>{},
        });
        when(() => timeline.events).thenReturn(<Event>[anchor, e1]);
        when(() => timeline.canRequestFuture).thenReturn(true);
        when(
          () =>
              timeline.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenThrow(StateError('network lost'));
        when(timeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => timeline);
        when(() => roomManager.currentRoom).thenReturn(room);

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          anchorEventId: r'$anchor',
        );

        // `_BootstrapOutcome.incomplete` translates to `false` from
        // `_runBootstrap`; no backward-walk fallback is triggered
        // because the walk made progress before throwing.
        expect(completed, isFalse);
        verify(
          () => room.getTimeline(
            eventContextId: r'$anchor',
            limit: any(named: 'limit'),
          ),
        ).called(1);
        verifyNever(
          () => room.getTimeline(limit: any(named: 'limit')),
        );
      },
    );

    test(
      'successful forward-walk clears a prior barren-bridge signal so '
      'a later gap signal does not spuriously trigger an unbounded '
      'recovery walk when the forward walk already closed the gap',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = QueuePipelineCoordinator(
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
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        // Phase 1 — prime the barren-bridge flag with a backward walk
        // that ends boundaryReached + 0 accepted.
        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final barrenEvent = MockEvent();
        when(() => barrenEvent.eventId).thenReturn(r'$e-0');
        when(
          () => barrenEvent.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(50));
        when(() => barrenEvent.roomId).thenReturn(roomId);
        when(() => barrenEvent.type).thenReturn(EventTypes.Message);
        when(() => barrenEvent.content).thenReturn(<String, dynamic>{});
        when(barrenEvent.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$e-0',
          'room_id': roomId,
          'origin_server_ts': 50,
          'type': EventTypes.Message,
          'content': <String, dynamic>{},
        });
        final barrenEvents = <Event>[barrenEvent];
        final barrenTl = MockTimeline();
        when(() => barrenTl.events).thenAnswer((_) => barrenEvents);
        // Keep requesting history so the boundary-continuation cap
        // trips with totalAccepted==0 — that's the shape that flips
        // `hasBarrenBridgeSignal` to true.
        when(() => barrenTl.canRequestHistory).thenReturn(true);
        var historyCalls = 0;
        when(
          () =>
              barrenTl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          historyCalls++;
          final e = MockEvent();
          when(() => e.eventId).thenReturn(r'$e-$historyCalls');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(50 - historyCalls));
          when(() => e.roomId).thenReturn(roomId);
          when(() => e.type).thenReturn(EventTypes.Message);
          when(() => e.content).thenReturn(<String, dynamic>{});
          when(e.toJson).thenReturn(<String, dynamic>{
            'event_id': r'$e-$historyCalls',
            'room_id': roomId,
            'origin_server_ts': 50 - historyCalls,
            'type': EventTypes.Message,
            'content': <String, dynamic>{},
          });
          barrenEvents.insert(0, e);
        });
        when(barrenTl.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => barrenTl);
        when(() => roomManager.currentRoom).thenReturn(room);

        await coordinator.runBootstrapForTest(
          room: room,
          untilTimestamp: 100,
        );
        expect(coordinator.hasBarrenBridgeSignal, isTrue);

        // Phase 2 — forward walk completes successfully.
        final forwardTl = MockTimeline();
        final anchor = MockEvent();
        when(() => anchor.eventId).thenReturn(r'$anchor');
        when(
          () => anchor.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
        when(() => forwardTl.events).thenReturn(<Event>[anchor]);
        when(() => forwardTl.canRequestFuture).thenReturn(false);
        when(forwardTl.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => forwardTl);

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          anchorEventId: r'$anchor',
        );
        expect(completed, isTrue);
        expect(
          coordinator.hasBarrenBridgeSignal,
          isFalse,
          reason: 'forward-walk completion must clear the barren flag',
        );
      },
    );
  }

  void registerReconnectDispatchProperties() {
    test(
      'dispatch matrix without a resume floor: forward walk runs iff an '
      'anchor exists; backward walk runs iff there is no anchor or the '
      'forward walk made no progress (errorNoProgress)',
      () async {
        const cases =
            <
              ({
                String name,
                bool anchorPresent,
                String forwardOutcome,
                bool expectForward,
                bool expectBackward,
                bool expectedCompleted,
              })
            >[
              (
                name: 'anchor+completed',
                anchorPresent: true,
                forwardOutcome: 'completed',
                expectForward: true,
                expectBackward: false,
                expectedCompleted: true,
              ),
              (
                name: 'anchor+incomplete',
                anchorPresent: true,
                forwardOutcome: 'incomplete',
                expectForward: true,
                expectBackward: false,
                expectedCompleted: false,
              ),
              (
                name: 'anchor+errorNoProgress',
                anchorPresent: true,
                forwardOutcome: 'errorNoProgress',
                expectForward: true,
                expectBackward: true,
                expectedCompleted: true,
              ),
              (
                name: 'noAnchor',
                anchorPresent: false,
                forwardOutcome: 'completed',
                expectForward: false,
                expectBackward: true,
                expectedCompleted: true,
              ),
            ];

        for (final scenario in cases) {
          final realQueue = InboundQueue(db: syncDb, logging: logging);
          final coordinator = QueuePipelineCoordinator(
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
          await coordinator.start();

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);

          // Forward-walk timeline stub shaped by the scenario outcome.
          final forwardTl = MockTimeline();
          when(forwardTl.cancelSubscriptions).thenAnswer((_) {});
          switch (scenario.forwardOutcome) {
            case 'completed':
              // Anchor resolves, no future pages -> boundary reached.
              final anchor = MockEvent();
              when(() => anchor.eventId).thenReturn(r'$anchor');
              when(
                () => anchor.originServerTs,
              ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
              when(() => forwardTl.events).thenReturn(<Event>[anchor]);
              when(() => forwardTl.canRequestFuture).thenReturn(false);
            case 'incomplete':
              // First page succeeds (anchor + one newer event), the next
              // pagination throws -> error with totalPages > 0 ->
              // incomplete (no fallback).
              final anchor = MockEvent();
              when(() => anchor.eventId).thenReturn(r'$anchor');
              when(
                () => anchor.originServerTs,
              ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
              final newer = MockEvent();
              when(() => newer.eventId).thenReturn(r'$newer');
              when(
                () => newer.originServerTs,
              ).thenReturn(DateTime.fromMillisecondsSinceEpoch(110));
              when(() => newer.roomId).thenReturn(roomId);
              when(() => newer.type).thenReturn(EventTypes.Message);
              when(() => newer.content).thenReturn(<String, dynamic>{});
              when(newer.toJson).thenReturn(<String, dynamic>{
                'event_id': r'$newer',
                'room_id': roomId,
                'origin_server_ts': 110,
                'type': EventTypes.Message,
                'content': <String, dynamic>{},
              });
              when(() => forwardTl.events).thenReturn(<Event>[anchor, newer]);
              when(() => forwardTl.canRequestFuture).thenReturn(true);
              when(
                () => forwardTl.requestFuture(
                  historyCount: any(named: 'historyCount'),
                ),
              ).thenThrow(StateError('network lost'));
            case 'errorNoProgress':
              // Anchor unresolvable: empty context chunk, no pages.
              when(() => forwardTl.events).thenReturn(<Event>[]);
              when(() => forwardTl.canRequestFuture).thenReturn(true);
          }
          when(
            () => room.getTimeline(
              eventContextId: any(named: 'eventContextId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => forwardTl);

          // Backward-walk timeline: empty + server exhausted -> true.
          final backwardTl = MockTimeline();
          when(() => backwardTl.events).thenReturn(<Event>[]);
          when(() => backwardTl.canRequestHistory).thenReturn(false);
          when(backwardTl.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => backwardTl);
          when(() => roomManager.currentRoom).thenReturn(room);

          final completed = await coordinator.runBootstrapForTest(
            room: room,
            untilTimestamp: 50,
            anchorEventId: scenario.anchorPresent ? r'$anchor' : null,
          );

          expect(completed, scenario.expectedCompleted, reason: scenario.name);
          if (scenario.expectForward) {
            verify(
              () => room.getTimeline(
                eventContextId: r'$anchor',
                limit: any(named: 'limit'),
              ),
            ).called(1);
          } else {
            // The backward walk passes eventContextId: null, which a bare
            // any() would also match — constrain to non-null to assert
            // "no forward walk" specifically.
            verifyNever(
              () => room.getTimeline(
                eventContextId: any(named: 'eventContextId', that: isNotNull),
                limit: any(named: 'limit'),
              ),
            );
          }
          if (scenario.expectBackward) {
            verify(
              () => room.getTimeline(limit: any(named: 'limit')),
            ).called(1);
          } else {
            verifyNever(
              () => room.getTimeline(limit: any(named: 'limit')),
            );
          }

          await coordinator.stop();
          await realQueue.dispose();
        }
      },
    );
  }
}
