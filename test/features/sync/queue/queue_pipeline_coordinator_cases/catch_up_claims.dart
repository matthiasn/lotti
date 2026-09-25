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
      'holds the SDK slice until limited metadata protects the old anchor',
      () async {
        await seedMarker(ts: 100, eventId: r'$before-gap');
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final coordinator = buildReal(realQueue);
        await coordinator.start();
        addTearDown(coordinator.stop);
        // A successful startup walk has already covered the startup interval.
        await realQueue.completeResumeWalk(
          roomId: roomId,
          walkStartedAtFloorRevision: realQueue.resumeFloorRevision(roomId),
          unresolvedFloorTs: null,
        );
        expect((await readMarkerRow()).resumeFloorTs, isNull);

        syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
        timelineCtl.add(syncPayload(r'$after-gap', 900));
        await pumpEventQueue();
        expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
        expect((await readMarkerRow()).lastAppliedTs, 100);

        syncCtl.add(
          SyncUpdate(
            nextBatch: 'limited-batch',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  timeline: TimelineUpdate(limited: true),
                ),
              },
            ),
          ),
        );
        await _waitForQueueStats(realQueue, (stats) => stats.total == 1);
        final ready = await realQueue.peekBatchReady(maxBatch: 1);
        await realQueue.commitApplied(ready.single);
        final marker = await readMarkerRow();
        expect(marker.lastAppliedTs, 900);
        expect(marker.resumeFloorTs, 101);
        expect(
          BridgeMarker(
            lastAppliedTs: marker.lastAppliedTs,
            lastAppliedEventId: marker.lastAppliedEventId,
            resumeFloorTs: marker.resumeFloorTs,
          ).anchorIsSafe,
          isFalse,
        );
      },
    );

    for (final endStatus in [
      SyncStatus.error,
      SyncStatus.cleaningUp,
      SyncStatus.finished,
    ]) {
      test(
        'SDK batch $endStatus awaits a conservative claim before admission',
        () async {
          final coordinator = build();
          await coordinator.start();
          addTearDown(coordinator.stop);
          final claim = Completer<void>();
          when(
            () => queue.claimAboveMarker(
              roomId: roomId,
              readAppliedTs: any(named: 'readAppliedTs'),
              walkLocal: any(named: 'walkLocal'),
            ),
          ).thenAnswer((_) => claim.future);
          syncStatusCtl
            ..add(const SyncStatusUpdate(SyncStatus.processing))
            ..add(const SyncStatusUpdate(SyncStatus.processing, progress: .5));
          timelineCtl.add(syncPayload(r'$held', 900));
          syncStatusCtl.add(SyncStatusUpdate(endStatus));
          await pumpEventQueue();
          verifyNever(() => queue.enqueueLive(any()));
          claim.complete();
          await pumpEventQueue();
          verify(() => queue.enqueueLive(any())).called(1);
        },
      );
    }

    test('SDK batch retries a failed claim before the live insert', () async {
      await seedMarker(ts: 0, eventId: r'$legacy-anchor');
      when(
        () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
      ).thenAnswer((_) async => '100');
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
      var reads = 0;
      when(
        () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
      ).thenAnswer((_) async {
        if (++reads == 1) throw StateError('marker read failed');
        return '100';
      });
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
      timelineCtl.add(syncPayload(r'$after-failed-claim', 900));
      await pumpEventQueue();
      expect(await syncDb.select(syncDb.inboundEventQueue).get(), isEmpty);
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.error));
      await _waitForQueueStats(realQueue, (stats) => stats.total == 1);
      final ready = await realQueue.peekBatchReady(maxBatch: 1);
      await realQueue.commitApplied(ready.single);
      final marker = await readMarkerRow();
      expect(marker.lastAppliedTs, 900);
      expect(marker.resumeFloorTs, 101);
      expect(reads, 2);
      verify(
        () => logging.error(
          LogDomain.sync,
          any<Object>(that: isA<StateError>()),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(
            named: 'subDomain',
            that: endsWith('.syncBatch.claim'),
          ),
        ),
      ).called(1);
    });

    test('SDK batch admission waits across overlapping responses', () async {
      final coordinator = build();
      await coordinator.start();
      addTearDown(coordinator.stop);
      final claim = Completer<void>();
      when(
        () => queue.claimAboveMarker(
          roomId: roomId,
          readAppliedTs: any(named: 'readAppliedTs'),
          walkLocal: any(named: 'walkLocal'),
        ),
      ).thenAnswer((_) => claim.future);
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
      final first = syncPayload(r'$first-response', 900);
      timelineCtl.add(first);
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.error));
      await pumpEventQueue();
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
      final second = syncPayload(r'$second-response', 901);
      timelineCtl.add(second);
      claim.complete();
      await pumpEventQueue();
      verifyNever(() => queue.enqueueLive(any()));
      syncCtl.add(SyncUpdate(nextBatch: 'second-response'));
      await pumpEventQueue();
      expect(
        verify(() => queue.enqueueLive(captureAny())).captured,
        [first, second],
      );
    });

    test('SDK batch status stream errors protect held events', () async {
      final coordinator = build();
      await coordinator.start();
      addTearDown(coordinator.stop);
      final claim = Completer<void>();
      when(
        () => queue.claimAboveMarker(
          roomId: roomId,
          readAppliedTs: any(named: 'readAppliedTs'),
          walkLocal: any(named: 'walkLocal'),
        ),
      ).thenAnswer((_) => claim.future);
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
      final event = syncPayload(r'$stream-error', 900);
      timelineCtl.add(event);
      syncStatusCtl.addError(StateError('status stream failed'));
      await pumpEventQueue();
      verifyNever(() => queue.enqueueLive(any()));
      claim.complete();
      await pumpEventQueue();
      verify(() => queue.enqueueLive(event)).called(1);
    });

    test(
      'SDK batch stop drops a held slice and restart accepts new events',
      () async {
        final coordinator = build();
        await coordinator.start();
        addTearDown(coordinator.stop);
        syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
        timelineCtl.add(syncPayload(r'$dropped-on-stop', 900));
        await pumpEventQueue();
        await coordinator.stop();
        verifyNever(() => queue.enqueueLive(any()));
        await coordinator.start();
        final fresh = syncPayload(r'$new-session', 901);
        timelineCtl.add(fresh);
        await pumpEventQueue();
        verify(() => queue.enqueueLive(fresh)).called(1);
      },
    );

    test('SDK batch normal metadata releases without claiming a gap', () async {
      when(() => sessionManager.isProcessingSync).thenReturn(true);
      final coordinator = build();
      await coordinator.start();
      addTearDown(coordinator.stop);
      verifyStartClaim();
      timelineCtl.add(syncPayload(r'$attached-mid-batch', 900));
      await pumpEventQueue();
      verifyNever(() => queue.enqueueLive(any()));
      syncCtl.add(SyncUpdate(nextBatch: 'complete-batch'));
      await pumpEventQueue();
      verify(() => queue.enqueueLive(any())).called(1);
      verifyNever(
        () => queue.lowerResumeFloor(
          roomId: any(named: 'roomId'),
          originTs: any(named: 'originTs'),
        ),
      );
    });

    test(
      'SDK batch shutdown drains a claim already writing to the queue',
      () async {
        final coordinator = build();
        await coordinator.start();
        final claim = Completer<void>();
        when(
          () => queue.claimAboveMarker(
            roomId: roomId,
            readAppliedTs: any(named: 'readAppliedTs'),
            walkLocal: any(named: 'walkLocal'),
          ),
        ).thenAnswer((_) => claim.future);
        syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
        timelineCtl.add(syncPayload(r'$held-for-claim', 900));
        syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.error));
        var stopped = false;
        final stop = coordinator.stop().then((_) => stopped = true);
        await pumpEventQueue();
        expect(stopped, isFalse);
        verifyNever(worker.stop);
        verifyNever(queue.dispose);
        claim.complete();
        await stop;
        expect(stopped, isTrue);
        verifyNever(() => queue.enqueueLive(any()));
        verify(worker.stop).called(1);
      },
    );

    test('SDK batch failed startup drains its pending claim', () async {
      final starting = Completer<void>();
      when(worker.start).thenAnswer((_) => starting.future);
      final coordinator = build();
      var unwound = false;
      final start = coordinator.start();
      final failed = expectLater(start, throwsStateError).then(
        (_) => unwound = true,
      );
      await pumpEventQueue();
      final claim = Completer<void>();
      when(
        () => queue.claimAboveMarker(
          roomId: roomId,
          readAppliedTs: any(named: 'readAppliedTs'),
          walkLocal: any(named: 'walkLocal'),
        ),
      ).thenAnswer((_) => claim.future);
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.processing));
      timelineCtl.add(syncPayload(r'$failed-startup', 900));
      syncStatusCtl.add(const SyncStatusUpdate(SyncStatus.error));
      starting.completeError(StateError('worker failed to start'));
      await pumpEventQueue();
      expect(unwound, isFalse);
      verifyNever(worker.stop);
      claim.complete();
      await failed;
      verifyNever(() => queue.enqueueLive(any()));
      verify(worker.stop).called(1);
    });

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(1, 12),
      glados.ExploreConfig(numRuns: 25),
    ).test('SDK batch progress updates preserve ordered admission', (
      count,
    ) async {
      final coordinator = build();
      clearInteractions(queue);
      await coordinator.start();
      try {
        for (var index = 0; index < count; index++) {
          syncStatusCtl.add(
            SyncStatusUpdate(
              SyncStatus.processing,
              progress: index / count,
            ),
          );
          timelineCtl.add(syncPayload('\$batch-$index', 900 + index));
        }
        await pumpEventQueue();
        verifyNever(() => queue.enqueueLive(any()));
        syncCtl.add(SyncUpdate(nextBatch: 'normal'));
        await pumpEventQueue();
        final admitted = verify(
          () => queue.enqueueLive(captureAny()),
        ).captured.cast<Event>();
        expect(admitted.map((event) => event.eventId), [
          for (var index = 0; index < count; index++) '\$batch-$index',
        ]);
      } finally {
        await coordinator.stop();
      }
    }, tags: 'glados');

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

        timelineCtl.add(syncPayload(r'$live', 9000));
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

        timelineCtl.add(buildEvent(EventTypes.Message));
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
