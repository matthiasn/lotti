part of '../queue_pipeline_coordinator_test.dart';

enum _GeneratedLiveRoomKind { current, foreign, noCurrentRoom }

enum _GeneratedLiveStatusKind { synced, sending, sent, error }

enum _GeneratedLiveEventKind { message, encrypted }

enum _GeneratedLiveSelfEchoKind { absent, present }

enum _GeneratedLiveIngestorKind { succeeds, throwsError }

class _GeneratedLiveIngressOperation {
  const _GeneratedLiveIngressOperation({
    required this.roomKind,
    required this.statusKind,
    required this.eventKind,
    required this.selfEchoKind,
    required this.slot,
  });

  final _GeneratedLiveRoomKind roomKind;
  final _GeneratedLiveStatusKind statusKind;
  final _GeneratedLiveEventKind eventKind;
  final _GeneratedLiveSelfEchoKind selfEchoKind;
  final int slot;

  EventStatus get status {
    switch (statusKind) {
      case _GeneratedLiveStatusKind.synced:
        return EventStatus.synced;
      case _GeneratedLiveStatusKind.sending:
        return EventStatus.sending;
      case _GeneratedLiveStatusKind.sent:
        return EventStatus.sent;
      case _GeneratedLiveStatusKind.error:
        return EventStatus.error;
    }
  }

  String get type {
    switch (eventKind) {
      case _GeneratedLiveEventKind.message:
        return EventTypes.Message;
      case _GeneratedLiveEventKind.encrypted:
        return EventTypes.Encrypted;
    }
  }

  bool get hasCurrentRoom => roomKind != _GeneratedLiveRoomKind.noCurrentRoom;

  bool get eventMatchesCurrentRoom =>
      roomKind != _GeneratedLiveRoomKind.foreign;

  bool get synced => statusKind == _GeneratedLiveStatusKind.synced;

  bool get selfEcho => selfEchoKind == _GeneratedLiveSelfEchoKind.present;

  bool get reachesDownstream =>
      hasCurrentRoom && eventMatchesCurrentRoom && synced && !selfEcho;

  @override
  String toString() {
    return '_GeneratedLiveIngressOperation('
        'roomKind: $roomKind, '
        'statusKind: $statusKind, '
        'eventKind: $eventKind, '
        'selfEchoKind: $selfEchoKind, '
        'slot: $slot'
        ')';
  }
}

class _GeneratedLiveIngressScenario {
  const _GeneratedLiveIngressScenario({
    required this.operations,
    required this.ingestorKind,
  });

  final List<_GeneratedLiveIngressOperation> operations;
  final _GeneratedLiveIngestorKind ingestorKind;

  String get currentRoomId => '!generated-live:example.org';

  String eventIdAt(int index) {
    return '\$generated-live-$index-${operations[index].slot}';
  }

  String eventRoomIdAt(int index) {
    final operation = operations[index];
    switch (operation.roomKind) {
      case _GeneratedLiveRoomKind.current:
      case _GeneratedLiveRoomKind.noCurrentRoom:
        return currentRoomId;
      case _GeneratedLiveRoomKind.foreign:
        return '!generated-foreign-${operation.slot}:example.org';
    }
  }

  int get expectedIngestorCalls => _downstreamOperations.length;

  int get expectedQueueCalls => _downstreamOperations
      .where(
        (operation) => operation.eventKind == _GeneratedLiveEventKind.message,
      )
      .length;

  int get expectedFloorCalls => _downstreamOperations
      .where(
        (operation) => operation.eventKind == _GeneratedLiveEventKind.encrypted,
      )
      .length;

  Iterable<_GeneratedLiveIngressOperation> get _downstreamOperations sync* {
    for (final operation in operations) {
      if (operation.reachesDownstream) yield operation;
    }
  }

  @override
  String toString() {
    return '_GeneratedLiveIngressScenario('
        'operations: $operations, '
        'ingestorKind: $ingestorKind'
        ')';
  }
}

extension _AnyGeneratedLiveIngressScenario on glados.Any {
  glados.Generator<_GeneratedLiveRoomKind> get liveRoomKind =>
      glados.AnyUtils(this).choose(_GeneratedLiveRoomKind.values);

  glados.Generator<_GeneratedLiveStatusKind> get liveStatusKind =>
      glados.AnyUtils(this).choose(_GeneratedLiveStatusKind.values);

  glados.Generator<_GeneratedLiveEventKind> get liveEventKind =>
      glados.AnyUtils(this).choose(_GeneratedLiveEventKind.values);

  glados.Generator<_GeneratedLiveSelfEchoKind> get liveSelfEchoKind =>
      glados.AnyUtils(this).choose(_GeneratedLiveSelfEchoKind.values);

  glados.Generator<_GeneratedLiveIngestorKind> get liveIngestorKind =>
      glados.AnyUtils(this).choose(_GeneratedLiveIngestorKind.values);

  glados.Generator<_GeneratedLiveIngressOperation> get liveIngressOperation =>
      glados.CombinableAny(this).combine5(
        liveRoomKind,
        liveStatusKind,
        liveEventKind,
        liveSelfEchoKind,
        glados.IntAnys(this).intInRange(0, 8),
        (
          _GeneratedLiveRoomKind roomKind,
          _GeneratedLiveStatusKind statusKind,
          _GeneratedLiveEventKind eventKind,
          _GeneratedLiveSelfEchoKind selfEchoKind,
          int slot,
        ) => _GeneratedLiveIngressOperation(
          roomKind: roomKind,
          statusKind: statusKind,
          eventKind: eventKind,
          selfEchoKind: selfEchoKind,
          slot: slot,
        ),
      );

  glados.Generator<_GeneratedLiveIngressScenario> get liveIngressScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(1, 24, liveIngressOperation),
        liveIngestorKind,
        (
          List<_GeneratedLiveIngressOperation> operations,
          _GeneratedLiveIngestorKind ingestorKind,
        ) => _GeneratedLiveIngressScenario(
          operations: operations,
          ingestorKind: ingestorKind,
        ),
      );
}

/// Shared scaffolding for the coordinator properties.
///
/// Creates the full local mock set with the same baseline stubs as the
/// file-level `setUp()`, plus the in-memory databases the coordinator
/// constructor requires (never written by these properties). Property
/// bodies re-stub only the members their model drives (queue.stats,
/// earliestReadyAt, ...) — a later `when(...)` wins.
class _GladosBench {
  _GladosBench() {
    when(
      () => sessionManager.timelineEvents,
    ).thenAnswer((_) => timelineCtl.stream);
    when(() => sessionManager.client).thenReturn(client);
    when(() => client.onSync).thenReturn(syncCtl);
    when(() => roomManager.currentRoomId).thenReturn(null);
    when(() => roomManager.currentRoom).thenReturn(null);
    when(
      () => settingsDb.itemByKey(any<String>()),
    ).thenAnswer((_) async => null);
    when(
      () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
    ).thenAnswer((_) async => 1);
    when(() => seeder.seedIfAbsent(any())).thenAnswer((_) async => true);
    when(() => queue.pruneStrandedEntries(any())).thenAnswer((_) async => 0);
    when(worker.start).thenAnswer((_) async {});
    when(worker.stop).thenAnswer((_) async {});
    when(worker.drainToCompletion).thenAnswer((_) async => 0);
    when(bridge.start).thenReturn(null);
    when(bridge.stop).thenAnswer((_) async {});
    when(bridge.bridgeNow).thenAnswer((_) async {});
    when(queue.dispose).thenAnswer((_) async {});
    when(queue.stats).thenAnswer(
      (_) async => const QueueStats(
        total: 0,
        byProducer: {},
        oldestEnqueuedAt: null,
      ),
    );
    when(queue.earliestReadyAt).thenAnswer((_) async => null);
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
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    when(
      () => logging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  }

  /// Shared placeholder databases for the coordinator's required
  /// constructor args. The Glados properties mock the queue/worker, so these
  /// are never written - sharing one pair across every generated
  /// run avoids ~5-10ms of Drift in-memory setup per run. Closed once via
  /// [closeSharedDbs] in the file's tearDownAll.
  static SyncDatabase? _sharedSyncDb;
  static JournalDb? _sharedJournalDb;

  static Future<void> closeSharedDbs() async {
    await _sharedSyncDb?.close();
    _sharedSyncDb = null;
    await _sharedJournalDb?.close();
    _sharedJournalDb = null;
  }

  final SyncDatabase syncDb = _sharedSyncDb ??= SyncDatabase(
    inMemoryDatabase: true,
  );
  final JournalDb journalDb = _sharedJournalDb ??= JournalDb(
    inMemoryDatabase: true,
  );
  final settingsDb = MockSettingsDb();
  final sessionManager = MockMatrixSessionManager();
  final roomManager = MockSyncRoomManager();
  final processor = MockSyncEventProcessor();
  final sequenceLog = MockSyncSequenceLogService();
  final logging = MockDomainLogger();
  final queue = MockInboundQueue();
  final worker = MockInboundWorker();
  final bridge = MockBridgeCoordinator();
  final seeder = MockQueueMarkerSeeder();
  final client = MockMatrixClient();
  final room = MockRoom();
  final timelineCtl = StreamController<Event>.broadcast(sync: true);
  final syncCtl = CachedStreamController<SyncUpdate>();
  final sentEventRegistry = SentEventRegistry();

  QueuePipelineCoordinator buildCoordinator({
    AttachmentIngestor? attachmentIngestor,
    SentEventRegistry? sentEventRegistry,
    AttachmentIndex? attachmentIndex,
    UpdateNotifications? updateNotifications,
  }) {
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
      attachmentIndex: attachmentIndex,
      updateNotifications: updateNotifications,
      attachmentIngestor: attachmentIngestor,
      sentEventRegistry: sentEventRegistry,
      queueOverride: queue,
      workerOverride: worker,
      bridgeOverride: bridge,
      seederOverride: seeder,
    );
  }

  Future<void> dispose() async {
    await timelineCtl.close();
    await syncCtl.close();
    // The shared databases stay open across runs; see [closeSharedDbs].
  }
}

extension _LiveIngressPropertyCases on _QueueCoordinatorTestSetup {
  void registerLiveIngressProperties() {
    glados.Glados(
      glados.any.liveIngressScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated live ingress filters room/status/self-echo before queueing',
      (scenario) async {
        final bench = _GladosBench();
        addTearDown(bench.dispose);
        final ingestor = _FakeAttachmentIngestor(
          shouldThrow:
              scenario.ingestorKind == _GeneratedLiveIngestorKind.throwsError,
        );
        final enqueuedEvents = <Event>[];
        final loweredFloors = <({String roomId, int originTs})>[];
        String? currentRoomId = scenario.currentRoomId;

        when(() => bench.roomManager.currentRoomId).thenAnswer(
          (_) => currentRoomId,
        );
        when(() => bench.queue.enqueueLive(any())).thenAnswer((
          invocation,
        ) async {
          enqueuedEvents.add(invocation.positionalArguments.single as Event);
          return EnqueueResult.empty;
        });
        when(
          () => bench.queue.lowerResumeFloor(
            roomId: any<String>(named: 'roomId'),
            originTs: any<int>(named: 'originTs'),
          ),
        ).thenAnswer((invocation) async {
          loweredFloors.add((
            roomId: invocation.namedArguments[#roomId] as String,
            originTs: invocation.namedArguments[#originTs] as int,
          ));
        });

        final coordinator = bench.buildCoordinator(
          attachmentIngestor: ingestor,
          sentEventRegistry: bench.sentEventRegistry,
        );

        try {
          await coordinator.start();
          for (var i = 0; i < scenario.operations.length; i++) {
            final operation = scenario.operations[i];
            final eventId = scenario.eventIdAt(i);
            currentRoomId = operation.hasCurrentRoom
                ? scenario.currentRoomId
                : null;
            if (operation.selfEcho) {
              bench.sentEventRegistry.register(eventId);
            }

            final event = MockEvent();
            when(() => event.eventId).thenReturn(eventId);
            when(() => event.roomId).thenReturn(scenario.eventRoomIdAt(i));
            when(() => event.type).thenReturn(operation.type);
            when(() => event.status).thenReturn(operation.status);
            when(
              () => event.originServerTs,
            ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
            bench.timelineCtl.add(event);
            await pumpEventQueue();
          }
          await coordinator.stop();

          expect(
            ingestor.processCalls,
            hasLength(scenario.expectedIngestorCalls),
            reason: '$scenario',
          );
          expect(
            loweredFloors,
            hasLength(scenario.expectedFloorCalls),
            reason: '$scenario',
          );
          expect(
            enqueuedEvents,
            hasLength(scenario.expectedQueueCalls),
            reason: '$scenario',
          );
        } finally {
          await coordinator.stop();
        }
      },
      tags: 'glados',
    );
  }
}
