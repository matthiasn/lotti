part of '../queue_pipeline_coordinator_test.dart';

extension _ReconnectAttachmentCases on _QueueCoordinatorTestSetup {
  void registerReconnectAttachments() {
    test(
      'forward walk sends a freshly-decrypted descriptor through the '
      'AttachmentIngestor before queue classification',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final encryption = MockEncryption();
        final firstProcessed = Completer<Event>();
        final processGate = Completer<void>();
        final ingestor = _FakeAttachmentIngestor(
          firstProcessed: firstProcessed,
          processGate: processGate.future,
        );
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
          attachmentIngestor: ingestor,
          queueOverride: realQueue,
          workerOverride: worker,
          bridgeOverride: bridge,
          seederOverride: seeder,
        );
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final anchor = MockEvent();
        when(() => anchor.eventId).thenReturn(r'$anchor');
        when(
          () => anchor.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
        final encrypted = MockEvent();
        when(() => encrypted.eventId).thenReturn(r'$descriptor');
        when(
          () => encrypted.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(110));
        when(() => encrypted.roomId).thenReturn(roomId);
        when(() => encrypted.type).thenReturn(EventTypes.Encrypted);
        when(() => encrypted.content).thenReturn(<String, dynamic>{
          'ciphertext': <String, dynamic>{},
        });
        final decrypted = MockEvent();
        when(() => decrypted.eventId).thenReturn(r'$descriptor');
        when(
          () => decrypted.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(110));
        when(() => decrypted.roomId).thenReturn(roomId);
        when(() => decrypted.type).thenReturn(EventTypes.Message);
        when(() => decrypted.content).thenReturn(<String, dynamic>{
          'msgtype': 'm.file',
          'relativePath': '/journal/descriptor.json',
        });
        when(decrypted.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$descriptor',
          'room_id': roomId,
          'origin_server_ts': 110,
          'type': EventTypes.Message,
          'content': <String, dynamic>{
            'msgtype': 'm.file',
            'relativePath': '/journal/descriptor.json',
          },
        });
        when(
          () => encryption.decryptRoomEvent(encrypted),
        ).thenAnswer((_) async => decrypted);
        final timeline = MockTimeline();
        when(() => timeline.events).thenReturn(<Event>[anchor, encrypted]);
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

        final processed = await firstProcessed.future;
        var drainCompleted = false;
        final drain = coordinator.drainBootstrapAttachmentWorkForTesting().then(
          (_) => drainCompleted = true,
        );
        await Future<void>.value();
        expect(
          drainCompleted,
          isFalse,
          reason: 'the test seam must wait for fire-and-forget page workers',
        );
        processGate.complete();
        await drain;
        expect(drainCompleted, isTrue);
        expect(ingestor.processCalls, hasLength(1));
        expect(
          processed,
          same(decrypted),
          reason:
              'attachment descriptors revealed by the fresh decrypt must not '
              'be ingested as their original ciphertext',
        );
        expect(ingestor.processCalls.single[#event], same(decrypted));
        verify(() => encryption.decryptRoomEvent(encrypted)).called(1);
      },
    );

    test(
      'backward walk sends a freshly-decrypted descriptor through the '
      'AttachmentIngestor before queue classification',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final encryption = MockEncryption();
        final firstProcessed = Completer<Event>();
        final ingestor = _FakeAttachmentIngestor(
          firstProcessed: firstProcessed,
        );
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
          attachmentIngestor: ingestor,
          queueOverride: realQueue,
          workerOverride: worker,
          bridgeOverride: bridge,
          seederOverride: seeder,
        );
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final encrypted = MockEvent();
        when(() => encrypted.eventId).thenReturn(r'$descriptor');
        when(
          () => encrypted.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
        when(() => encrypted.roomId).thenReturn(roomId);
        when(() => encrypted.type).thenReturn(EventTypes.Encrypted);
        when(() => encrypted.content).thenReturn(<String, dynamic>{
          'ciphertext': <String, dynamic>{},
        });
        final decrypted = MockEvent();
        when(() => decrypted.eventId).thenReturn(r'$descriptor');
        when(
          () => decrypted.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
        when(() => decrypted.roomId).thenReturn(roomId);
        when(() => decrypted.type).thenReturn(EventTypes.Message);
        when(() => decrypted.content).thenReturn(<String, dynamic>{
          'msgtype': 'm.file',
          'relativePath': '/journal/descriptor.json',
        });
        when(decrypted.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$descriptor',
          'room_id': roomId,
          'origin_server_ts': 200,
          'type': EventTypes.Message,
          'content': <String, dynamic>{
            'msgtype': 'm.file',
            'relativePath': '/journal/descriptor.json',
          },
        });
        when(
          () => encryption.decryptRoomEvent(encrypted),
        ).thenAnswer((_) async => decrypted);
        final tl = MockTimeline();
        when(() => tl.events).thenReturn(<Event>[encrypted]);
        when(() => tl.canRequestHistory).thenReturn(false);
        when(tl.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => roomManager.currentRoom).thenReturn(room);

        // No anchor id → backward walk runs.
        final completed = await coordinator.runBootstrapForTest(room: room);
        expect(completed, isTrue);
        expect(await firstProcessed.future, same(decrypted));
        expect(ingestor.processCalls, hasLength(1));
        expect(ingestor.processCalls.single[#event], same(decrypted));
        verify(() => encryption.decryptRoomEvent(encrypted)).called(1);
      },
    );
  }
}
