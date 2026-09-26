part of '../queue_pipeline_coordinator_test.dart';

/// The catch-up claims of `specs/tla/InboundQueue.tla`: before anything
/// newer than an uncaptured range can apply and move the anchor past it,
/// that range is held in the durable resume floor.
extension _CatchUpClaimCases on _QueueCoordinatorTestSetup {
  void registerCatchUpClaims() {
    Event syncPayload(String id, int tsMs) {
      final event = MockEvent();
      final content = <String, dynamic>{'msgtype': syncMessageType};
      when(() => event.eventId).thenReturn(id);
      when(() => event.roomId).thenReturn(roomId);
      when(() => event.type).thenReturn(EventTypes.Message);
      when(() => event.status).thenReturn(EventStatus.synced);
      when(() => event.content).thenReturn(content);
      when(
        () => event.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(tsMs));
      when(event.toJson).thenReturn(<String, dynamic>{
        'event_id': id,
        'sender': '@peer:example.org',
        'room_id': roomId,
        'origin_server_ts': tsMs,
        'type': EventTypes.Message,
        'content': content,
      });
      return event;
    }

    Future<void> seedMarker({required int ts, String? eventId}) => syncDb
        .into(syncDb.queueMarkers)
        .insert(
          QueueMarkersCompanion.insert(
            roomId: roomId,
            lastAppliedTs: Value(ts),
            lastAppliedEventId: Value(eventId),
          ),
        );

    Future<QueueMarkerItem> readMarkerRow() => (syncDb.select(
      syncDb.queueMarkers,
    )..where((t) => t.roomId.equals(roomId))).getSingle();

    /// Applies [event] the way the worker does, as a newer live event that
    /// lands while the walk's remainder is still unfetched.
    Future<void> applyLive(InboundQueue realQueue, Event event) async {
      await realQueue.enqueueLive(event);
      final batch = await realQueue.peekBatchReady(maxBatch: 1);
      await realQueue.commitApplied(batch.single);
    }

    QueuePipelineCoordinator buildReal(InboundQueue realQueue) =>
        QueuePipelineCoordinator(
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

    test(
      'real SDK emits payload before its limited response is admitted',
      () async {
        await seedMarker(ts: 5000, eventId: r'$anchor');
        final sdkDb = MockMatrixDatabase();
        final httpClient = MockHttpClient();
        final sdk = Client(
          'response-admission-test',
          database: sdkDb,
          httpClient: httpClient,
        );
        addTearDown(() => sdk.dispose(closeDatabase: false));
        final room = Room(id: roomId, client: sdk)..partial = false;
        sdk.rooms.add(room);
        when(() => sessionManager.client).thenReturn(sdk);
        when(
          () => sessionManager.timelineEvents,
        ).thenAnswer((_) => sdk.onTimelineEvent.stream);
        when(() => roomManager.currentRoom).thenReturn(room);
        final payload = MatrixEvent(
          type: EventTypes.Message,
          eventId: r'$sdk-payload',
          senderId: '@peer:example.org',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(9000),
          content: {'msgtype': syncMessageType},
        );
        final update = JoinedRoomUpdate(
          timeline: TimelineUpdate(
            limited: true,
            prevBatch: 'before-gap',
            events: [payload],
          ),
        );
        when(
          () => sdkDb.deleteTimelineForRoom(roomId),
        ).thenAnswer((_) async {});
        when(
          () => sdkDb.getUser(payload.senderId, room),
        ).thenAnswer((_) async => null);
        when(
          () => sdkDb.storeEventUpdate(
            roomId,
            payload,
            EventUpdateType.timeline,
            sdk,
          ),
        ).thenAnswer((_) async {});
        final reachedStore = Completer<void>();
        final releaseStore = Completer<void>();
        when(
          () => sdkDb.storeRoomUpdate(roomId, update, any(), sdk),
        ).thenAnswer((_) async {
          reachedStore.complete();
          await releaseStore.future;
        });
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);
        await coordinator.start();
        addTearDown(coordinator.stop);
        await realQueue.completeResumeWalk(
          roomId: roomId,
          walkStartedAtFloorRevision: realQueue.resumeFloorRevision(roomId),
          unresolvedFloorTs: null,
        );
        final timelineIds = <String>[];
        final observed = sdk.onTimelineEvent.stream.listen(
          (event) => timelineIds.add(event.eventId),
        );
        addTearDown(observed.cancel);
        final response = sdk.handleSync(
          SyncUpdate(
            nextBatch: 'real-response',
            rooms: RoomsUpdate(join: {roomId: update}),
          ),
        );
        await reachedStore.future;
        try {
          await pumpEventQueue();
          expect(timelineIds, [payload.eventId]);
          expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
          // A nested synthetic SDK pass emits onSync while the real room
          // response is still parked after its timeline callbacks.
          await sdk.handleSync(SyncUpdate(nextBatch: 'synthetic'));
          await pumpEventQueue();
          expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
          expect((await readMarkerRow()).resumeFloorTs, isNull);
        } finally {
          releaseStore.complete();
          await response;
        }
        await pumpEventQueue();
        final batch = await realQueue.peekBatchReady(maxBatch: 1);
        expect(batch.map((row) => row.eventId), [payload.eventId]);
        await realQueue.commitApplied(batch.single);
        final marker = await readMarkerRow();
        expect(marker.lastAppliedTs, 9000);
        expect(marker.resumeFloorTs, 5001);
        verifyZeroInteractions(httpClient);
      },
    );

    test(
      'response admission claims a limited gap before its payload applies',
      () async {
        await seedMarker(ts: 5000, eventId: r'$anchor');
        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        when(() => room.partial).thenReturn(false);
        when(() => room.client).thenReturn(client);
        when(() => roomManager.currentRoom).thenReturn(room);
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);
        await coordinator.start();
        addTearDown(coordinator.stop);
        await realQueue.completeResumeWalk(
          roomId: roomId,
          walkStartedAtFloorRevision: realQueue.resumeFloorRevision(roomId),
          unresolvedFloorTs: null,
        );
        expect((await readMarkerRow()).resumeFloorTs, isNull);
        final raw = MatrixEvent.fromJson({
          'event_id': r'$slice',
          'sender': '@peer:example.org',
          'origin_server_ts': 9000,
          'type': EventTypes.Message,
          'content': {'msgtype': syncMessageType},
        });
        timelineCtl.add(Event.fromMatrixEvent(raw, room));
        await pumpEventQueue();
        expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
        // A synthetic SDK pass must not admit another response's slice.
        syncCtl.add(
          SyncUpdate(
            nextBatch: '',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(),
              },
            ),
          ),
        );
        await pumpEventQueue();
        expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
        syncCtl.add(
          SyncUpdate(
            nextBatch: 'limited',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  timeline: TimelineUpdate(
                    limited: true,
                    events: [raw],
                    prevBatch: 'before-gap',
                  ),
                ),
              },
            ),
          ),
        );
        await pumpEventQueue();
        final batch = await realQueue.peekBatchReady(maxBatch: 1);
        expect(batch.map((row) => row.eventId), [r'$slice']);
        expect((await readMarkerRow()).resumeFloorTs, 5001);
        await realQueue.commitApplied(batch.single);
        final marker = await readMarkerRow();
        expect(marker.lastAppliedTs, 9000);
        expect(marker.resumeFloorTs, 5001);
      },
    );

    test(
      'unavailable response room retains its range before later payloads',
      () async {
        await seedMarker(ts: 5000, eventId: r'$anchor');
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);
        await coordinator.start();
        addTearDown(coordinator.stop);
        await realQueue.completeResumeWalk(
          roomId: roomId,
          walkStartedAtFloorRevision: realQueue.resumeFloorRevision(roomId),
          unresolvedFloorTs: null,
        );
        syncCtl.add(
          SyncUpdate(
            nextBatch: 'room-unavailable',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  timeline: TimelineUpdate(
                    events: [
                      MatrixEvent.fromJson(
                        syncPayload(r'$unresolved-room', 6000).toJson(),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ),
        );
        await pumpEventQueue();
        expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
        expect((await readMarkerRow()).resumeFloorTs, 5001);
        deliverPayload(syncPayload(r'$room-restored', 9000));
        await pumpEventQueue();
        final batch = await realQueue.peekBatchReady(maxBatch: 1);
        expect(batch.map((row) => row.eventId), [r'$room-restored']);
        await realQueue.commitApplied(batch.single);
        final marker = await readMarkerRow();
        expect(marker.lastAppliedTs, 9000);
        expect(marker.resumeFloorTs, 5001);
      },
    );

    test(
      'failed response admission retains every unqueued event for repair',
      () async {
        await seedMarker(ts: 5000, eventId: r'$anchor');
        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        when(() => room.partial).thenReturn(false);
        when(() => room.client).thenReturn(client);
        when(() => roomManager.currentRoom).thenReturn(room);
        final encryption = MockEncryption();
        when(() => client.encryption).thenReturn(encryption);
        when(
          () => encryption.decryptRoomEvent(any()),
        ).thenThrow(StateError('key store unavailable'));
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);
        await coordinator.start();
        addTearDown(coordinator.stop);
        await realQueue.completeResumeWalk(
          roomId: roomId,
          walkStartedAtFloorRevision: realQueue.resumeFloorRevision(roomId),
          unresolvedFloorTs: null,
        );
        verify(bridge.bridgeNow).called(1);
        final encrypted = MatrixEvent.fromJson({
          'event_id': r'$encrypted',
          'sender': '@peer:example.org',
          'origin_server_ts': 6000,
          'type': EventTypes.Encrypted,
          'content': <String, dynamic>{},
        });
        final unqueued = MatrixEvent.fromJson({
          'event_id': r'$unqueued',
          'sender': '@peer:example.org',
          'origin_server_ts': 7000,
          'type': EventTypes.Message,
          'content': {'msgtype': syncMessageType},
        });
        syncCtl.add(
          SyncUpdate(
            nextBatch: 'failed',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  timeline: TimelineUpdate(events: [encrypted, unqueued]),
                ),
              },
            ),
          ),
        );
        await pumpEventQueue();
        expect((await readMarkerRow()).resumeFloorTs, 6000);
        expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
        verify(bridge.bridgeNow).called(1);
        deliverPayload(syncPayload(r'$later', 9000));
        await pumpEventQueue();
        final batch = await realQueue.peekBatchReady(maxBatch: 1);
        expect(batch.map((row) => row.eventId), [r'$later']);
        await realQueue.commitApplied(batch.single);
        final marker = await readMarkerRow();
        expect(marker.lastAppliedTs, 9000);
        expect(marker.resumeFloorTs, 6000);
      },
    );

    test(
      'start claims the range above the marker before the live stream '
      'and the worker can apply anything (ClaimOnStart: a live event '
      'applied ahead of the startup bridge moved the anchor past the '
      'events that arrived while the app was down)',
      () async {
        final coordinator = build();
        await coordinator.start();

        verifyInOrder([
          () => queue.lowerResumeFloor(roomId: roomId, originTs: 1),
          () => sessionManager.timelineEvents,
          worker.start,
        ]);
        await coordinator.stop();
      },
    );

    test(
      'a start claim whose marker read throws is retained, and resolved '
      'before the first live event enters the queue (RetainFailedClaim: '
      'the lost claim let a live event apply past the range that arrived '
      'while the app was down)',
      () async {
        await syncDb
            .into(syncDb.queueMarkers)
            .insert(
              QueueMarkersCompanion.insert(
                roomId: roomId,
                lastAppliedEventId: const Value(r'$anchor'),
              ),
            );
        var legacyReads = 0;
        when(
          () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
        ).thenAnswer((_) async {
          legacyReads++;
          if (legacyReads == 1) throw StateError('database is locked');
          return '5000';
        });
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);
        await coordinator.start();
        addTearDown(coordinator.stop);

        var row = await readMarkerRow();
        expect(row.resumeFloorTs, isNull);
        verify(
          () => logging.error(
            LogDomain.sync,
            any<Object>(that: isA<StateError>()),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(
              named: 'subDomain',
              that: endsWith('.start.claim'),
            ),
          ),
        ).called(1);

        deliverPayload(syncPayload(r'$live', 9000));
        await pumpEventQueue();

        row = await readMarkerRow();
        expect(row.resumeFloorTs, 5001);
        final queued = await syncDb.select(syncDb.inboundEventQueue).get();
        expect(queued.map((r) => r.eventId), [r'$live']);
      },
    );

    test(
      'a start claim that throws is logged and the pipeline still starts; '
      'the retained floor is persisted before the first queue insert',
      () async {
        when(
          () => queue.lowerResumeFloor(roomId: roomId, originTs: 1),
        ).thenThrow(StateError('floor write failed'));
        final coordinator = build();
        await coordinator.start();

        expect(coordinator.isRunning, isTrue);
        verify(worker.start).called(1);
        verify(
          () => logging.error(
            LogDomain.sync,
            any<Object>(that: isA<StateError>()),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(
              named: 'subDomain',
              that: endsWith('.start.claim'),
            ),
          ),
        ).called(1);
        await coordinator.stop();
      },
    );

    test(
      'a failed live enqueue whose floor write also throws logs both and '
      'still requests the pass',
      () async {
        when(
          () => queue.enqueueLive(any()),
        ).thenThrow(StateError('queue closed'));
        final coordinator = build();
        await coordinator.start();
        verifyStartClaim();
        verify(bridge.bridgeNow).called(1);
        when(
          () => queue.lowerResumeFloor(roomId: roomId, originTs: 1234),
        ).thenThrow(StateError('floor write failed'));

        deliverPayload(buildEvent(EventTypes.Message));
        await pumpEventQueue();

        verify(
          () => logging.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(
              named: 'subDomain',
              that: endsWith('.enqueue.floor'),
            ),
          ),
        ).called(1);
        verify(bridge.bridgeNow).called(1);
        await coordinator.stop();
      },
    );

    test(
      'a limited sync claims the gap through the real bridge before its '
      'pass runs (ClaimOnGap)',
      () async {
        when(() => client.getRoomById(roomId)).thenReturn(null);
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
        await pumpEventQueue();
        verifyStartClaim();

        syncCtl.add(
          SyncUpdate(
            nextBatch: 'next-limited',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  timeline: TimelineUpdate(
                    limited: true,
                    prevBatch: 'pb-gap',
                    events: const <MatrixEvent>[],
                  ),
                ),
              },
            ),
          ),
        );
        await pumpEventQueue();

        verify(
          () => queue.lowerResumeFloor(roomId: roomId, originTs: 1),
        ).called(1);
        await coordinator.stop();
      },
    );

    test(
      'start claims one above a stored marker, so the startup walk still '
      'runs forward from the anchor',
      () async {
        await seedMarker(ts: 5000, eventId: r'$anchor');
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);
        await coordinator.start();
        addTearDown(coordinator.stop);

        final row = await readMarkerRow();
        expect(row.resumeFloorTs, 5001);
        expect(
          BridgeMarker(
            lastAppliedTs: row.lastAppliedTs,
            lastAppliedEventId: row.lastAppliedEventId,
            resumeFloorTs: row.resumeFloorTs,
          ).anchorIsSafe,
          isTrue,
        );
      },
    );

    test(
      'an incomplete backward walk leaves its claim in the floor, so a '
      'retry after its tip page applied walks back instead of forward '
      "from the tip (ClaimOnWalk: the tip's anchor skipped every older "
      'page for good)',
      () async {
        await seedMarker(ts: 100);
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final tip = syncPayload(r'$tip', 300);
        final timeline = MockTimeline();
        when(() => timeline.events).thenReturn(<Event>[tip]);
        when(() => timeline.canRequestHistory).thenReturn(true);
        when(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenThrow(StateError('network lost'));
        when(timeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          untilTimestamp: 100,
        );
        expect(completed, isFalse);

        // The tip page applies; its event becomes the anchor.
        final batch = await realQueue.peekBatchReady(maxBatch: 1);
        expect(batch.single.eventId, r'$tip');
        await realQueue.commitApplied(batch.single);

        final row = await readMarkerRow();
        expect(row.lastAppliedEventId, r'$tip');
        expect(row.resumeFloorTs, 101);
        final marker = BridgeMarker(
          lastAppliedTs: row.lastAppliedTs,
          lastAppliedEventId: row.lastAppliedEventId,
          resumeFloorTs: row.resumeFloorTs,
        );
        expect(marker.anchorIsSafe, isFalse);
        expect(marker.backwardWalkBound, 101);
      },
    );

    test(
      'an incomplete forward walk checkpoints its floor at its cursor: '
      'the retry resumes forward while nothing newer applied, and walks '
      'back to the cursor, not to the old anchor, once something did '
      '(CheckpointForward)',
      () async {
        await seedMarker(ts: 100, eventId: r'$anchor');
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final anchor = syncPayload(r'$anchor', 100);
        final e1 = syncPayload(r'$e1', 110);
        final timeline = MockTimeline();
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

        final completed = await coordinator.runBootstrapForTest(
          room: room,
          untilTimestamp: 100,
          anchorEventId: r'$anchor',
        );
        expect(completed, isFalse);

        var row = await readMarkerRow();
        expect(row.resumeFloorTs, 111);

        // The walk's own row applies: the anchor reaches the cursor and
        // the retry can keep walking forward from it.
        final walked = await realQueue.peekBatchReady(maxBatch: 1);
        await realQueue.commitApplied(walked.single);
        row = await readMarkerRow();
        expect(row.lastAppliedEventId, r'$e1');
        expect(
          BridgeMarker(
            lastAppliedTs: row.lastAppliedTs,
            lastAppliedEventId: row.lastAppliedEventId,
            resumeFloorTs: row.resumeFloorTs,
          ).anchorIsSafe,
          isTrue,
        );

        // A newer live event applies past the unfetched remainder.
        await applyLive(realQueue, syncPayload(r'$live', 900));
        row = await readMarkerRow();
        final marker = BridgeMarker(
          lastAppliedTs: row.lastAppliedTs,
          lastAppliedEventId: row.lastAppliedEventId,
          resumeFloorTs: row.resumeFloorTs,
        );
        expect(marker.lastAppliedEventId, r'$live');
        expect(marker.anchorIsSafe, isFalse);
        expect(marker.backwardWalkBound, 111);
      },
    );
  }
}
