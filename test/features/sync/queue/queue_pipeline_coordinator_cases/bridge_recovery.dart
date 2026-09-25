part of '../queue_pipeline_coordinator_test.dart';

extension _BridgeRecoveryCases on _QueueCoordinatorTestSetup {
  void registerBridgeRecovery() {
    group('triggerBridge with real BridgeCoordinator', () {
      test(
        'a key-trigger retries a retained floor before deciding whether to '
        'bridge',
        () async {
          await syncDb
              .into(syncDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  lastAppliedTs: const Value(5000),
                  lastAppliedEventId: const Value(r'$ahead-anchor'),
                ),
              );
          // QueueMarkerAdvancer's SQLite-trigger regression proves that a failed
          // write stays process-local and this accessor retries it. Model the
          // post-retry value here while the raw marker row deliberately remains
          // null, so the coordinator must use the accessor before gating.
          when(() => queue.resumeFloorTs(roomId)).thenAnswer((_) async => 3000);

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => room.partial).thenReturn(false);
          when(() => roomManager.currentRoom).thenReturn(room);
          final timeline = MockTimeline();
          when(() => timeline.events).thenReturn(<Event>[]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

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
            queueOverride: queue,
            workerOverride: worker,
            seederOverride: seeder,
          );
          await coordinator.start();
          addTearDown(coordinator.stop);

          syncCtl.add(_roomKeySyncFor(roomId));
          await pumpEventQueue();

          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(greaterThanOrEqualTo(1));
          verify(
            () => queue.resumeFloorTs(roomId),
          ).called(greaterThanOrEqualTo(2));
          verify(
            () => queue.completeResumeWalk(
              roomId: roomId,
              walkStartedAtFloorRevision: 0,
              unresolvedFloorTs: null,
            ),
          ).called(greaterThanOrEqualTo(1));
        },
      );

      test(
        'a bridge queued behind manual history refreshes its marker inside '
        'the shared room lane',
        () async {
          await syncDb
              .into(syncDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  lastAppliedTs: const Value(5000),
                  lastAppliedEventId: const Value(r'$ahead-anchor'),
                ),
              );
          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(room);

          final ciphertext = MockEvent();
          when(() => ciphertext.eventId).thenReturn(r'$ciphertext');
          when(() => ciphertext.roomId).thenReturn(roomId);
          when(() => ciphertext.type).thenReturn(EventTypes.Encrypted);
          when(
            () => ciphertext.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));

          final manualTimelineGate = Completer<Timeline>();
          final manualTimeline = MockTimeline();
          when(() => manualTimeline.events).thenReturn(<Event>[ciphertext]);
          when(() => manualTimeline.canRequestHistory).thenReturn(false);
          when(manualTimeline.cancelSubscriptions).thenAnswer((_) {});

          final bridgeTimeline = MockTimeline();
          when(() => bridgeTimeline.events).thenReturn(<Event>[ciphertext]);
          when(() => bridgeTimeline.canRequestHistory).thenReturn(false);
          when(bridgeTimeline.cancelSubscriptions).thenAnswer((_) {});

          var backwardTimelineCalls = 0;
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) {
            backwardTimelineCalls++;
            if (backwardTimelineCalls == 1) {
              return manualTimelineGate.future;
            }
            return Future<Timeline>.value(bridgeTimeline);
          });

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
            seederOverride: seeder,
          );

          final manualFuture = coordinator.collectHistory();
          await pumpEventQueue();
          expect(backwardTimelineCalls, 1);

          final bridgeFuture = coordinator.triggerBridge();
          await pumpEventQueue();
          expect(
            backwardTimelineCalls,
            1,
            reason: 'the bridge must wait for the manual walk in this room',
          );
          verifyNever(
            () => room.getTimeline(
              eventContextId: any(
                named: 'eventContextId',
                that: isNotNull,
              ),
              limit: any(named: 'limit'),
            ),
          );

          manualTimelineGate.complete(manualTimeline);
          await manualFuture;
          await bridgeFuture;

          expect(backwardTimelineCalls, 2);
          verifyNever(
            () => room.getTimeline(
              eventContextId: any(
                named: 'eventContextId',
                that: isNotNull,
              ),
              limit: any(named: 'limit'),
            ),
          );
          expect(await realQueue.resumeFloorTs(roomId), 1000);
          verify(
            () => logging.log(
              LogDomain.sync,
              any<String>(that: contains('queue.bootstrap.markerRefreshed')),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).called(1);
        },
      );

      test(
        'a failed floor-reconciling walk releases the room lane for its retry',
        () async {
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(room);
          final timeline = MockTimeline();
          when(() => timeline.events).thenReturn(<Event>[]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          var failAtWalkStart = true;
          when(() => queue.resumeFloorRevision(roomId)).thenAnswer((_) {
            if (failAtWalkStart) {
              throw StateError('revision unavailable');
            }
            return 0;
          });
          final coordinator = build();

          await expectLater(
            coordinator.collectHistory(),
            throwsA(isA<StateError>()),
          );
          failAtWalkStart = false;

          final retry = await coordinator.collectHistory();

          expect(retry.stopReason, BootstrapStopReason.serverExhausted);
          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(1);
        },
      );

      test(
        'a restart reloads the durable ciphertext floor and walks '
        'behind the ahead anchor before clearing the covered floor',
        () async {
          await syncDb
              .into(syncDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  lastAppliedTs: const Value(5000),
                  lastAppliedEventId: const Value(r'$ahead-anchor'),
                  resumeFloorTs: const Value(3000),
                ),
              );

          final beforeRestart = await (syncDb.select(
            syncDb.queueMarkers,
          )..where((t) => t.roomId.equals(roomId))).getSingle();
          expect(beforeRestart.resumeFloorTs, 3000);
          expect(beforeRestart.lastAppliedEventId, r'$ahead-anchor');

          final secondQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(secondQueue.dispose);
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(room);

          final backwardTimeline = MockTimeline();
          when(() => backwardTimeline.events).thenReturn(<Event>[]);
          when(() => backwardTimeline.canRequestHistory).thenReturn(false);
          when(backwardTimeline.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => backwardTimeline);

          final secondCoordinator = QueuePipelineCoordinator(
            syncDb: syncDb,
            settingsDb: settingsDb,
            journalDb: journalDb,
            sessionManager: sessionManager,
            roomManager: roomManager,
            eventProcessor: processor,
            sequenceLogService: sequenceLog,
            activityGate: null,
            logging: logging,
            queueOverride: secondQueue,
            workerOverride: worker,
            seederOverride: seeder,
          );

          await secondCoordinator.triggerBridge();

          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(1);
          verifyNever(
            () => room.getTimeline(
              eventContextId: any(named: 'eventContextId'),
              limit: any(named: 'limit'),
            ),
          );

          final afterRecovery = await (syncDb.select(
            syncDb.queueMarkers,
          )..where((t) => t.roomId.equals(roomId))).getSingle();
          expect(afterRecovery.resumeFloorTs, isNull);
          expect(afterRecovery.lastAppliedEventId, r'$ahead-anchor');
        },
      );

      test(
        'reads queue_markers row and runs bootstrap against empty timeline',
        () async {
          // Seed a queue_markers row so _readMarkerTs hits the marker
          // branch instead of falling back to settingsDb.
          await syncDb
              .into(syncDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  lastAppliedTs: const Value(42),
                ),
              );

          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => timeline.events).thenReturn(<Event>[]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          // _resolveRoom tries currentRoom first, falls back to
          // client.getRoomById — exercise the fallback.
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => client.getRoomById(roomId)).thenReturn(room);

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
            seederOverride: seeder,
          );

          await coordinator.triggerBridge();

          // The bridge should have resolved the room via client.getRoomById
          // and called getTimeline.
          verify(() => client.getRoomById(roomId)).called(1);
          verify(() => room.getTimeline(limit: any(named: 'limit'))).called(1);
        },
      );

      test(
        '_readMarkerTs falls back to settingsDb when no marker row exists',
        () async {
          when(
            () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
          ).thenAnswer((_) async => '999');

          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => timeline.events).thenReturn(<Event>[]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          when(() => roomManager.currentRoom).thenReturn(room);

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
            seederOverride: seeder,
          );

          await coordinator.triggerBridge();

          // The bridge's read, the walk's claim above the marker, and the
          // walk's refreshed read inside the lane.
          verify(
            () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
          ).called(3);
        },
      );

      test(
        r'_readMarker strips non-`$`-prefixed event ids — placeholder '
        'ids the outbox minted before the server echoed back would make '
        '`getEventContext` fail, so the forward walk must NOT run for '
        'those markers. The bridge falls back to the timestamp-bounded '
        'backward walk instead.',
        () async {
          // Seed a marker with a placeholder (non-`\$`-prefixed) event id
          // alongside a real ts. The forward walk MUST be suppressed for
          // this shape.
          await syncDb
              .into(syncDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  lastAppliedTs: const Value(5000),
                  lastAppliedEventId: const Value('lotti-placeholder-id'),
                ),
              );

          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => timeline.events).thenReturn(<Event>[]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);
          when(() => roomManager.currentRoom).thenReturn(room);

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
            seederOverride: seeder,
          );

          await coordinator.triggerBridge();

          // Backward walk was used — forward walk (eventContextId:) was
          // never invoked because the placeholder id failed the
          // `\$`-prefix filter.
          verify(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).called(1);
          verifyNever(
            () => room.getTimeline(
              eventContextId: any(named: 'eventContextId'),
              limit: any(named: 'limit'),
            ),
          );
          verify(
            () => logging.log(
              any<LogDomain>(),
              any<String>(
                that: contains('queue.bridge.start mode=reconnect.backward'),
              ),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).called(1);
        },
      );

      test(
        r'_readMarker keeps a `$`-prefixed lastAppliedEventId so the bridge '
        'forward-walks from that server-assigned anchor via '
        'getTimeline(eventContextId:) rather than the timestamp-bounded '
        'backward walk',
        () async {
          // Seed a marker carrying a real, server-assigned (`\$`-prefixed)
          // event id. `_readMarker` must surface it verbatim, which routes
          // the bridge into the forward (eventContextId) walk.
          await syncDb
              .into(syncDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  lastAppliedTs: const Value(5000),
                  lastAppliedEventId: const Value(r'$server-anchor'),
                ),
              );

          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final forwardTimeline = MockTimeline();
          final anchor = MockEvent();
          when(() => anchor.eventId).thenReturn(r'$server-anchor');
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
          when(() => roomManager.currentRoom).thenReturn(room);

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
            seederOverride: seeder,
          );

          await coordinator.triggerBridge();

          // Forward walk anchored on the preserved `\$`-prefixed id; the
          // backward (no eventContextId) walk must NOT run.
          verify(
            () => room.getTimeline(
              eventContextId: r'$server-anchor',
              limit: any(named: 'limit'),
            ),
          ).called(1);
          verifyNever(
            () => room.getTimeline(limit: any(named: 'limit')),
          );
        },
      );

      test(
        '_readMarker falls back to settingsDb ts when queue_markers has '
        'a row but lastAppliedTs is 0 — legacy-bridge handoff path where '
        "the queue row exists (seeded by QueueMarkerSeeder) but hasn't "
        'advanced yet, so the legacy settingsDb timestamp anchors the '
        'first reconnect walk',
        () async {
          await syncDb
              .into(syncDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  // ts=0 → fall through to settingsDb.
                ),
              );
          when(
            () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
          ).thenAnswer((_) async => '777');

          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => timeline.events).thenReturn(<Event>[]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);
          when(() => roomManager.currentRoom).thenReturn(room);

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
            seederOverride: seeder,
          );

          await coordinator.triggerBridge();

          // The bridge's read, the walk's claim above the marker, and the
          // walk's refreshed read inside the lane.
          verify(
            () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
          ).called(3);
        },
      );

      test(
        'bridge logs noRoom when both cache and getRoomById return null',
        () async {
          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);

          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => client.getRoomById(any())).thenReturn(null);

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
            seederOverride: seeder,
          );

          await coordinator.triggerBridge();

          verify(
            () => logging.log(
              any<LogDomain>(),
              any<String>(that: contains('queue.bridge.skip reason=noRoom')),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).called(1);
        },
      );

      test(
        'bridge logs noRoom WITHOUT consulting client.getRoomById when both '
        'the cached room and the current room id are null — the _resolveRoom '
        'guard short-circuits before the gateway lookup',
        () async {
          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);

          // Distinct from the test above: there is no current room id at
          // all, so _resolveRoom must return null on the `roomId == null`
          // branch and never reach `client.getRoomById`.
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => roomManager.currentRoomId).thenReturn(null);

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
            seederOverride: seeder,
          );

          await coordinator.triggerBridge();

          verify(
            () => logging.log(
              any<LogDomain>(),
              any<String>(that: contains('queue.bridge.skip reason=noRoom')),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).called(1);
          // The null-id guard fired before any gateway round-trip.
          verifyNever(() => client.getRoomById(any()));
        },
      );
    });
  }
}
