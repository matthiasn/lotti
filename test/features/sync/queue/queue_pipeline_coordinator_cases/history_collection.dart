part of '../queue_pipeline_coordinator_test.dart';

extension _HistoryCollectionCases on _QueueCoordinatorTestSetup {
  void registerHistoryCollection() {
    group('collectHistory', () {
      test('throws StateError when no current room', () async {
        when(() => roomManager.currentRoomId).thenReturn(null);
        final coordinator = build();
        await expectLater(
          coordinator.collectHistory(),
          throwsA(isA<StateError>()),
        );
      });

      test(
        'exits immediately when the server has no history',
        () async {
          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => roomManager.currentRoom).thenReturn(room);
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);
          when(() => timeline.events).thenReturn(<Event>[]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});

          final coordinator = build();
          final infos = <BootstrapPageInfo>[];
          final result = await coordinator.collectHistory(
            onProgress: infos.add,
          );

          expect(result.stopReason, BootstrapStopReason.serverExhausted);
          expect(result.totalEvents, 0);
          expect(infos, isEmpty);
          verify(timeline.cancelSubscriptions).called(1);
        },
      );

      test(
        'forwards progress info and appends pages to the real queue',
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

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => roomManager.currentRoom).thenReturn(room);
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          // Must carry the real `syncMessageType`. A fixture with any other
          // msgtype is classified as non-payload and dropped by
          // `enqueueBatch` as filteredOutByType — the walk then looks
          // successful while the queue stays empty.
          final event = buildSyncEvent(
            eventId: r'$bootstrap',
            roomId: roomId,
            originTsMs: 10,
          );
          when(() => timeline.events).thenReturn(<Event>[event]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});

          final infos = <BootstrapPageInfo>[];
          final result = await coordinator.collectHistory(
            onProgress: infos.add,
          );

          expect(result.stopReason, BootstrapStopReason.serverExhausted);
          expect(infos, hasLength(1));
          // `totalEventsSoFar` counts what the sink SAW, not what it accepted,
          // so it cannot carry this test's claim on its own: assert the row
          // actually landed in the queue.
          expect(infos.single.totalEventsSoFar, 1);
          final stats = await realQueue.depthSnapshot();
          expect(
            stats.total,
            1,
            reason: 'the page must be appended to the queue, not merely seen',
          );
        },
      );

      test(
        'encrypted history uses the production SDK decryptor before enqueue',
        () async {
          final realQueue = InboundQueue(db: syncDb, logging: logging);
          addTearDown(realQueue.dispose);
          final encryption = MockEncryption();
          when(() => client.encryption).thenReturn(encryption);
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

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => roomManager.currentRoom).thenReturn(room);
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          final encrypted = buildEvent(EventTypes.Encrypted);
          final decrypted = MockEvent();
          when(() => decrypted.eventId).thenReturn(r'$decrypted-bootstrap');
          when(() => decrypted.roomId).thenReturn(roomId);
          when(() => decrypted.type).thenReturn(EventTypes.Message);
          when(
            () => decrypted.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1234));
          when(() => decrypted.content).thenReturn(<String, dynamic>{
            'msgtype': syncMessageType,
          });
          when(decrypted.toJson).thenReturn(<String, dynamic>{
            'event_id': r'$decrypted-bootstrap',
            'room_id': roomId,
            'origin_server_ts': 1234,
            'type': EventTypes.Message,
            'content': <String, dynamic>{'msgtype': syncMessageType},
          });
          when(
            () => encryption.decryptRoomEvent(encrypted),
          ).thenAnswer((_) async => decrypted);
          when(() => timeline.events).thenReturn(<Event>[encrypted]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});

          final result = await coordinator.collectHistory();

          expect(result.stopReason, BootstrapStopReason.serverExhausted);
          verify(() => encryption.decryptRoomEvent(encrypted)).called(1);
          expect((await realQueue.stats()).total, 1);
          expect(await realQueue.resumeFloorTs(roomId), isNull);
        },
      );

      test(
        'onProgress exception does not abort the bootstrap',
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

          final room = MockRoom();
          when(() => room.id).thenReturn(roomId);
          final timeline = MockTimeline();
          when(() => roomManager.currentRoom).thenReturn(room);
          when(
            () => room.getTimeline(limit: any(named: 'limit')),
          ).thenAnswer((_) async => timeline);

          final event = buildSyncEvent(
            eventId: r'$bootstrap2',
            roomId: roomId,
            originTsMs: 20,
          );
          when(() => timeline.events).thenReturn(<Event>[event]);
          when(() => timeline.canRequestHistory).thenReturn(false);
          when(timeline.cancelSubscriptions).thenAnswer((_) {});

          final result = await coordinator.collectHistory(
            onProgress: (_) => throw StateError('UI unmounted'),
          );

          expect(result.stopReason, BootstrapStopReason.serverExhausted);
          // A throwing progress callback must not cost the page: the row still
          // reaches the queue.
          final stats = await realQueue.depthSnapshot();
          expect(stats.total, 1);
        },
      );
    });
  }
}
