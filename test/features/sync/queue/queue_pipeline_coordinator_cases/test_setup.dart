part of '../queue_pipeline_coordinator_test.dart';

SyncUpdate _roomKeySyncFor(String roomId) {
  return SyncUpdate(
    nextBatch: 'next-key',
    toDevice: [
      BasicEventWithSender(
        type: EventTypes.RoomKey,
        content: <String, Object?>{'room_id': roomId},
        senderId: '@alice:example.org',
      ),
    ],
  );
}

/// Builds a fully stubbed live sync event for the pipeline-integration group.
Event _buildLiveSyncEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
}) {
  final event = MockEvent();
  final content = <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(EventTypes.Message);
  // Integration tests inject events via the coordinator's live timeline;
  // `_handleLiveEvent` drops non-`synced` emissions as SDK fake-sync
  // artefacts.
  when(() => event.status).thenReturn(EventStatus.synced);
  when(() => event.content).thenReturn(content);
  when(() => event.text).thenReturn('stub');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': EventTypes.Message,
    'sender': '@tester:example.org',
    'content': content,
  });
  return event;
}

/// Completes when [matches] holds for the queue's stats, re-checking on every
/// depth change. Hard 5s timeout so a stalled `depthChanges` fails fast
/// instead of hanging the suite.
Future<void> _waitForQueueStats(
  InboundQueue queue,
  bool Function(QueueStats stats) matches,
) async {
  final completer = Completer<void>();

  Future<void> check() async {
    if (completer.isCompleted) return;
    final stats = await queue.stats();
    if (matches(stats) && !completer.isCompleted) {
      completer.complete();
    }
  }

  final sub = queue.depthChanges.listen((_) async {
    try {
      await check();
    } catch (error, stack) {
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    }
  });
  try {
    await check();
    // Fail-fast guard, not a wait: this fires only if depthChanges stops
    // emitting (a regression in _emitDepth) — without it the integration
    // tests would hang until the CI job timeout instead of failing here.
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException(
        'queue stats never matched within 5s - depthChanges stalled?',
      ),
    );
  } finally {
    await sub.cancel();
  }
}

class _QueueCoordinatorTestSetup {
  late SyncDatabase syncDb;
  late JournalDb journalDb;
  late MockSettingsDb settingsDb;
  late MockMatrixSessionManager sessionManager;
  late MockSyncRoomManager roomManager;
  late MockSyncEventProcessor processor;
  late MockSyncSequenceLogService sequenceLog;
  late MockDomainLogger logging;
  late MockInboundQueue queue;
  late MockInboundWorker worker;
  late MockBridgeCoordinator bridge;
  late MockQueueMarkerSeeder seeder;
  late StreamController<Event> timelineCtl;
  late CachedStreamController<SyncUpdate> syncCtl;
  late MockMatrixClient client;
  final roomId = '!roomA:example.org';

  void registerLifecycle() {
    setUpAll(registerAllFallbackValues);

    tearDownAll(_GladosBench.closeSharedDbs);

    setUp(() {
      syncDb = SyncDatabase(inMemoryDatabase: true);
      journalDb = JournalDb(inMemoryDatabase: true);
      settingsDb = MockSettingsDb();
      sessionManager = MockMatrixSessionManager();
      roomManager = MockSyncRoomManager();
      processor = MockSyncEventProcessor();
      sequenceLog = MockSyncSequenceLogService();
      logging = MockDomainLogger();
      queue = MockInboundQueue();
      worker = MockInboundWorker();
      bridge = MockBridgeCoordinator();
      seeder = MockQueueMarkerSeeder();
      timelineCtl = StreamController<Event>.broadcast(sync: true);
      syncCtl = CachedStreamController<SyncUpdate>();
      client = MockMatrixClient();
      when(() => client.onSync).thenReturn(syncCtl);

      when(
        () => sessionManager.timelineEvents,
      ).thenAnswer((_) => timelineCtl.stream);
      when(() => sessionManager.client).thenReturn(client);
      when(() => roomManager.currentRoomId).thenReturn(roomId);
      when(() => roomManager.currentRoom).thenReturn(null);
      // Start and every walk read the marker to claim the range above it;
      // no legacy marker unless a test says otherwise.
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(() => seeder.seedIfAbsent(any())).thenAnswer((_) async => true);
      when(() => queue.pruneStrandedEntries(any())).thenAnswer((_) async => 0);
      when(worker.start).thenAnswer((_) async {});
      when(() => worker.stop()).thenAnswer((_) async {});
      when(worker.drainToCompletion).thenAnswer((_) async => 0);
      when(bridge.start).thenReturn(null);
      when(bridge.stop).thenAnswer((_) async {});
      when(bridge.bridgeNow).thenAnswer((_) async {});
      when(() => queue.dispose()).thenAnswer((_) async {});
      when(() => queue.enqueueLive(any())).thenAnswer(
        (_) async => EnqueueResult.empty,
      );
      when(() => queue.stats()).thenAnswer(
        (_) async => const QueueStats(
          total: 0,
          byProducer: {},
          oldestEnqueuedAt: null,
        ),
      );
      when(() => queue.earliestReadyAt()).thenAnswer((_) async => null);
      when(() => queue.resumeFloorTs(any())).thenAnswer((_) async => null);
      when(() => queue.resumeFloorRevision(any())).thenReturn(0);
      when(
        () => queue.completeResumeWalk(
          roomId: any<String>(named: 'roomId'),
          walkStartedAtFloorRevision: any(
            named: 'walkStartedAtFloorRevision',
          ),
          unresolvedFloorTs: any(named: 'unresolvedFloorTs'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => queue.lowerResumeFloor(
          roomId: any<String>(named: 'roomId'),
          originTs: any<int>(named: 'originTs'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => queue.lowerResumeFloorFromWalk(
          roomId: any<String>(named: 'roomId'),
          originTs: any<int>(named: 'originTs'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await timelineCtl.close();
      await syncCtl.close();
      await syncDb.close();
      await journalDb.close();
    });
  }

  /// Consumes the claim `start()` makes before anything can apply: the
  /// floor one above the room's (absent) marker.
  void verifyStartClaim() => verify(
    () => queue.lowerResumeFloor(roomId: roomId, originTs: 1),
  ).called(1);

  QueuePipelineCoordinator build({
    AttachmentIngestor? attachmentIngestor,
  }) => QueuePipelineCoordinator(
    syncDb: syncDb,
    settingsDb: settingsDb,
    journalDb: journalDb,
    sessionManager: sessionManager,
    roomManager: roomManager,
    eventProcessor: processor,
    sequenceLogService: sequenceLog,
    activityGate: null,
    logging: logging,
    attachmentIngestor: attachmentIngestor,
    queueOverride: queue,
    workerOverride: worker,
    bridgeOverride: bridge,
    seederOverride: seeder,
  );

  Event buildEvent(String type) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(r'$a');
    when(() => e.roomId).thenReturn(roomId);
    when(() => e.type).thenReturn(type);
    // `_handleLiveEvent` drops non-synced fake-sync emissions from
    // the Matrix SDK; every test building a "real" live event needs
    // to declare it synced.
    when(() => e.status).thenReturn(EventStatus.synced);
    when(
      () => e.originServerTs,
    ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1234));
    return e;
  }
}
