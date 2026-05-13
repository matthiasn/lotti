import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/features/sync/queue/queue_marker_seeder.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockWorker extends Mock implements InboundWorker {}

class _MockBridge extends Mock implements BridgeCoordinator {}

class _MockPen extends Mock implements PendingDecryptionPen {}

class _MockSeeder extends Mock implements QueueMarkerSeeder {}

/// Test double for [AttachmentIngestor] that records every `process()`
/// call and optionally throws, without needing mocktail fallbacks for
/// every named-argument type (Function, LoggingService, nullable refs).
class _FakeAttachmentIngestor implements AttachmentIngestor {
  _FakeAttachmentIngestor({this.shouldThrow = false, this.firstProcessed});

  bool shouldThrow;
  final Completer<Event>? firstProcessed;
  final List<Map<Symbol, Object?>> processCalls = <Map<Symbol, Object?>>[];

  @override
  Future<bool> process({
    required Event event,
    required LoggingService logging,
    required AttachmentIndex? attachmentIndex,
    bool scheduleDownload = false,
  }) async {
    processCalls.add({
      #event: event,
      #scheduleDownload: scheduleDownload,
    });
    if (firstProcessed case final completer? when !completer.isCompleted) {
      completer.complete(event);
    }
    if (shouldThrow) {
      throw StateError('ingestor boom');
    }
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

enum _GeneratedLiveRoomKind { current, foreign, noCurrentRoom }

enum _GeneratedLiveStatusKind { synced, sending, sent, error }

enum _GeneratedLiveEventKind { message, encrypted }

enum _GeneratedLiveSelfEchoKind { absent, present }

enum _GeneratedLivePenKind { passes, holds }

enum _GeneratedLiveIngestorKind { succeeds, throwsError }

class _GeneratedLiveIngressOperation {
  const _GeneratedLiveIngressOperation({
    required this.roomKind,
    required this.statusKind,
    required this.eventKind,
    required this.selfEchoKind,
    required this.penKind,
    required this.slot,
  });

  final _GeneratedLiveRoomKind roomKind;
  final _GeneratedLiveStatusKind statusKind;
  final _GeneratedLiveEventKind eventKind;
  final _GeneratedLiveSelfEchoKind selfEchoKind;
  final _GeneratedLivePenKind penKind;
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

  bool get penHolds => penKind == _GeneratedLivePenKind.holds;

  bool get reachesDownstream =>
      hasCurrentRoom && eventMatchesCurrentRoom && synced && !selfEcho;

  @override
  String toString() {
    return '_GeneratedLiveIngressOperation('
        'roomKind: $roomKind, '
        'statusKind: $statusKind, '
        'eventKind: $eventKind, '
        'selfEchoKind: $selfEchoKind, '
        'penKind: $penKind, '
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

  int get expectedPenCalls => _downstreamOperations.length;

  int get expectedQueueCalls =>
      _downstreamOperations.where((operation) => !operation.penHolds).length;

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

  glados.Generator<_GeneratedLivePenKind> get livePenKind =>
      glados.AnyUtils(this).choose(_GeneratedLivePenKind.values);

  glados.Generator<_GeneratedLiveIngestorKind> get liveIngestorKind =>
      glados.AnyUtils(this).choose(_GeneratedLiveIngestorKind.values);

  glados.Generator<_GeneratedLiveIngressOperation> get liveIngressOperation =>
      glados.CombinableAny(this).combine6(
        liveRoomKind,
        liveStatusKind,
        liveEventKind,
        liveSelfEchoKind,
        livePenKind,
        glados.IntAnys(this).intInRange(0, 8),
        (
          _GeneratedLiveRoomKind roomKind,
          _GeneratedLiveStatusKind statusKind,
          _GeneratedLiveEventKind eventKind,
          _GeneratedLiveSelfEchoKind selfEchoKind,
          _GeneratedLivePenKind penKind,
          int slot,
        ) => _GeneratedLiveIngressOperation(
          roomKind: roomKind,
          statusKind: statusKind,
          eventKind: eventKind,
          selfEchoKind: selfEchoKind,
          penKind: penKind,
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

enum _GeneratedDrainRoomKind { absent, present }

enum _GeneratedDrainFailureKind { none, penThrows, workerThrows, bothThrow }

enum _GeneratedDrainReadyAtKind { none, now, soon }

enum _GeneratedDrainTerminationKind { completes, timesOut }

class _GeneratedDrainStep {
  const _GeneratedDrainStep({
    required this.total,
    required this.penSize,
    required this.readyAtKind,
  });

  final int total;
  final int penSize;
  final _GeneratedDrainReadyAtKind readyAtKind;

  bool get isEmpty => total == 0 && penSize == 0;

  _GeneratedDrainStep asNonEmpty() {
    if (!isEmpty) return this;
    return _GeneratedDrainStep(
      total: 1,
      penSize: 0,
      readyAtKind: readyAtKind,
    );
  }

  @override
  String toString() {
    return '_GeneratedDrainStep('
        'total: $total, '
        'penSize: $penSize, '
        'readyAtKind: $readyAtKind'
        ')';
  }
}

class _GeneratedDrainScenario {
  const _GeneratedDrainScenario({
    required this.rawSteps,
    required this.roomKind,
    required this.failureKind,
    required this.terminationKind,
  });

  final List<_GeneratedDrainStep> rawSteps;
  final _GeneratedDrainRoomKind roomKind;
  final _GeneratedDrainFailureKind failureKind;
  final _GeneratedDrainTerminationKind terminationKind;

  bool get hasRoom => roomKind == _GeneratedDrainRoomKind.present;

  bool get penThrows =>
      failureKind == _GeneratedDrainFailureKind.penThrows ||
      failureKind == _GeneratedDrainFailureKind.bothThrow;

  bool get workerThrows =>
      failureKind == _GeneratedDrainFailureKind.workerThrows ||
      failureKind == _GeneratedDrainFailureKind.bothThrow;

  bool get timesOut =>
      terminationKind == _GeneratedDrainTerminationKind.timesOut;

  Duration get timeout =>
      timesOut ? const Duration(milliseconds: 20) : const Duration(seconds: 3);

  Duration get advanceBy =>
      timesOut ? const Duration(milliseconds: 25) : const Duration(seconds: 3);

  List<_GeneratedDrainStep> get steps {
    if (timesOut) {
      return const [
        _GeneratedDrainStep(
          total: 1,
          penSize: 0,
          readyAtKind: _GeneratedDrainReadyAtKind.none,
        ),
      ];
    }
    return [
      for (final step in rawSteps) step.asNonEmpty(),
      const _GeneratedDrainStep(
        total: 0,
        penSize: 0,
        readyAtKind: _GeneratedDrainReadyAtKind.now,
      ),
    ];
  }

  int get expectedIterations => steps.length;

  _GeneratedDrainStep stepAt(int index) {
    final materialized = steps;
    if (index < materialized.length) return materialized[index];
    return materialized.last;
  }

  @override
  String toString() {
    return '_GeneratedDrainScenario('
        'rawSteps: $rawSteps, '
        'roomKind: $roomKind, '
        'failureKind: $failureKind, '
        'terminationKind: $terminationKind'
        ')';
  }
}

extension _AnyGeneratedDrainScenario on glados.Any {
  glados.Generator<_GeneratedDrainRoomKind> get drainRoomKind =>
      glados.AnyUtils(this).choose(_GeneratedDrainRoomKind.values);

  glados.Generator<_GeneratedDrainFailureKind> get drainFailureKind =>
      glados.AnyUtils(this).choose(_GeneratedDrainFailureKind.values);

  glados.Generator<_GeneratedDrainReadyAtKind> get drainReadyAtKind =>
      glados.AnyUtils(this).choose(_GeneratedDrainReadyAtKind.values);

  glados.Generator<_GeneratedDrainTerminationKind> get drainTerminationKind =>
      glados.AnyUtils(this).choose(_GeneratedDrainTerminationKind.values);

  glados.Generator<_GeneratedDrainStep> get drainStep =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 3),
        drainReadyAtKind,
        (
          int total,
          int penSize,
          _GeneratedDrainReadyAtKind readyAtKind,
        ) => _GeneratedDrainStep(
          total: total,
          penSize: penSize,
          readyAtKind: readyAtKind,
        ),
      );

  glados.Generator<_GeneratedDrainScenario> get drainScenario =>
      glados.CombinableAny(this).combine4(
        glados.ListAnys(this).listWithLengthInRange(0, 4, drainStep),
        drainRoomKind,
        drainFailureKind,
        drainTerminationKind,
        (
          List<_GeneratedDrainStep> rawSteps,
          _GeneratedDrainRoomKind roomKind,
          _GeneratedDrainFailureKind failureKind,
          _GeneratedDrainTerminationKind terminationKind,
        ) => _GeneratedDrainScenario(
          rawSteps: rawSteps,
          roomKind: roomKind,
          failureKind: failureKind,
          terminationKind: terminationKind,
        ),
      );
}

void main() {
  late SyncDatabase syncDb;
  late JournalDb journalDb;
  late MockSettingsDb settingsDb;
  late _MockSessionManager sessionManager;
  late _MockRoomManager roomManager;
  late MockSyncEventProcessor processor;
  late MockSyncSequenceLogService sequenceLog;
  late MockLoggingService logging;
  late MockInboundQueue queue;
  late _MockWorker worker;
  late _MockBridge bridge;
  late _MockPen pen;
  late _MockSeeder seeder;
  late StreamController<Event> timelineCtl;
  late CachedStreamController<SyncUpdate> syncCtl;
  late MockMatrixClient client;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(MockEvent());
  });

  setUp(() {
    syncDb = SyncDatabase(inMemoryDatabase: true);
    journalDb = JournalDb(inMemoryDatabase: true);
    settingsDb = MockSettingsDb();
    sessionManager = _MockSessionManager();
    roomManager = _MockRoomManager();
    processor = MockSyncEventProcessor();
    sequenceLog = MockSyncSequenceLogService();
    logging = MockLoggingService();
    queue = MockInboundQueue();
    worker = _MockWorker();
    bridge = _MockBridge();
    pen = _MockPen();
    seeder = _MockSeeder();
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
    when(() => seeder.seedIfAbsent(any())).thenAnswer((_) async => true);
    when(() => queue.pruneStrandedEntries(any())).thenAnswer((_) async => 0);
    when(worker.start).thenAnswer((_) async {});
    when(() => worker.stop()).thenAnswer((_) async {});
    when(worker.drainToCompletion).thenAnswer((_) async => 0);
    when(bridge.start).thenReturn(null);
    when(bridge.stop).thenAnswer((_) async {});
    when(bridge.bridgeNow).thenAnswer((_) async {});
    when(pen.stop).thenAnswer((_) async {});
    when(() => pen.size).thenReturn(0);
    when(() => queue.dispose()).thenAnswer((_) async {});
    when(() => queue.enqueueLive(any())).thenAnswer(
      (_) async => EnqueueResult.empty,
    );
    when(() => queue.stats()).thenAnswer(
      (_) async => const QueueStats(
        total: 0,
        byProducer: {},
        readyNow: 0,
        oldestEnqueuedAt: null,
      ),
    );
    when(() => queue.earliestReadyAt()).thenAnswer((_) async => null);
    when(() => pen.hold(any())).thenReturn(false);
  });

  tearDown(() async {
    await timelineCtl.close();
    await syncCtl.close();
    await syncDb.close();
    await journalDb.close();
  });

  QueuePipelineCoordinator build() => QueuePipelineCoordinator(
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
    bridgeOverride: bridge,
    penOverride: pen,
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
    return e;
  }

  test(
    'start seeds the marker, prunes strays, starts worker + bridge',
    () async {
      final coordinator = build();
      await coordinator.start();
      expect(coordinator.isRunning, isTrue);
      verify(() => seeder.seedIfAbsent(roomId)).called(1);
      verify(() => queue.pruneStrandedEntries(roomId)).called(1);
      verify(worker.start).called(1);
      verify(bridge.start).called(1);
      await coordinator.stop();
    },
  );

  test('encrypted live event is routed through the pen (F3)', () async {
    final coordinator = build();
    await coordinator.start();

    when(() => pen.hold(any())).thenReturn(true);
    timelineCtl.add(buildEvent(EventTypes.Encrypted));
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => queue.enqueueLive(any()));
    verify(() => pen.hold(any())).called(1);
    await coordinator.stop();
  });

  test('plain live event bypasses pen and enters the queue', () async {
    final coordinator = build();
    await coordinator.start();

    timelineCtl.add(buildEvent(EventTypes.Message));
    await Future<void>.delayed(Duration.zero);

    verify(() => pen.hold(any())).called(1);
    verify(() => queue.enqueueLive(any())).called(1);
    await coordinator.stop();
  });

  test(
    'live event for a different room is ignored',
    () async {
      final coordinator = build();
      await coordinator.start();

      final foreign = MockEvent();
      when(() => foreign.eventId).thenReturn(r'$other');
      when(() => foreign.roomId).thenReturn('!someOtherRoom:example.org');
      when(() => foreign.type).thenReturn(EventTypes.Message);
      timelineCtl.add(foreign);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => pen.hold(any()));
      verifyNever(() => queue.enqueueLive(any()));
      await coordinator.stop();
    },
  );

  glados.Glados(
    glados.any.liveIngressScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'generated live ingress filters room/status/self-echo before queueing',
    (scenario) async {
      final localSyncDb = SyncDatabase(inMemoryDatabase: true);
      final localJournalDb = JournalDb(inMemoryDatabase: true);
      final localSettingsDb = MockSettingsDb();
      final localSessionManager = _MockSessionManager();
      final localRoomManager = _MockRoomManager();
      final localProcessor = MockSyncEventProcessor();
      final localSequenceLog = MockSyncSequenceLogService();
      final localLogging = MockLoggingService();
      final localQueue = MockInboundQueue();
      final localWorker = _MockWorker();
      final localBridge = _MockBridge();
      final localPen = _MockPen();
      final localSeeder = _MockSeeder();
      final localClient = MockMatrixClient();
      final localTimelineCtl = StreamController<Event>.broadcast(sync: true);
      final localSyncCtl = CachedStreamController<SyncUpdate>();
      final sentEventRegistry = SentEventRegistry();
      final ingestor = _FakeAttachmentIngestor(
        shouldThrow:
            scenario.ingestorKind == _GeneratedLiveIngestorKind.throwsError,
      );
      final penEvents = <Event>[];
      final enqueuedEvents = <Event>[];
      final penHoldsByEventId = <String, bool>{};
      String? currentRoomId = scenario.currentRoomId;

      when(
        () => localSessionManager.timelineEvents,
      ).thenAnswer((_) => localTimelineCtl.stream);
      when(() => localSessionManager.client).thenReturn(localClient);
      when(() => localClient.onSync).thenReturn(localSyncCtl);
      when(() => localRoomManager.currentRoomId).thenAnswer(
        (_) => currentRoomId,
      );
      when(() => localRoomManager.currentRoom).thenReturn(null);
      when(
        () => localSettingsDb.itemByKey(any<String>()),
      ).thenAnswer((_) async => null);
      when(
        () => localSettingsDb.saveSettingsItem(any<String>(), any<String>()),
      ).thenAnswer((_) async => 1);
      when(() => localSeeder.seedIfAbsent(any())).thenAnswer((_) async => true);
      when(
        () => localQueue.pruneStrandedEntries(any()),
      ).thenAnswer((_) async => 0);
      when(localWorker.start).thenAnswer((_) async {});
      when(localWorker.stop).thenAnswer((_) async {});
      when(localWorker.drainToCompletion).thenAnswer((_) async => 0);
      when(localBridge.start).thenReturn(null);
      when(localBridge.stop).thenAnswer((_) async {});
      when(localBridge.bridgeNow).thenAnswer((_) async {});
      when(localPen.stop).thenAnswer((_) async {});
      when(() => localPen.size).thenReturn(0);
      when(localQueue.dispose).thenAnswer((_) async {});
      when(() => localQueue.enqueueLive(any())).thenAnswer((invocation) async {
        enqueuedEvents.add(invocation.positionalArguments.single as Event);
        return EnqueueResult.empty;
      });
      when(localQueue.stats).thenAnswer(
        (_) async => const QueueStats(
          total: 0,
          byProducer: {},
          readyNow: 0,
          oldestEnqueuedAt: null,
        ),
      );
      when(localQueue.earliestReadyAt).thenAnswer((_) async => null);
      when(() => localPen.hold(any())).thenAnswer((invocation) {
        final event = invocation.positionalArguments.single as Event;
        penEvents.add(event);
        return penHoldsByEventId[event.eventId] ?? false;
      });
      when(
        () => localLogging.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      final coordinator = QueuePipelineCoordinator(
        syncDb: localSyncDb,
        settingsDb: localSettingsDb,
        journalDb: localJournalDb,
        sessionManager: localSessionManager,
        roomManager: localRoomManager,
        eventProcessor: localProcessor,
        sequenceLogService: localSequenceLog,
        activityGate: null,
        logging: localLogging,
        attachmentIngestor: ingestor,
        sentEventRegistry: sentEventRegistry,
        queueOverride: localQueue,
        workerOverride: localWorker,
        bridgeOverride: localBridge,
        penOverride: localPen,
        seederOverride: localSeeder,
      );

      try {
        await coordinator.start();
        for (var i = 0; i < scenario.operations.length; i++) {
          final operation = scenario.operations[i];
          final eventId = scenario.eventIdAt(i);
          currentRoomId = operation.hasCurrentRoom
              ? scenario.currentRoomId
              : null;
          penHoldsByEventId[eventId] = operation.penHolds;
          if (operation.selfEcho) {
            sentEventRegistry.register(eventId);
          }

          final event = MockEvent();
          when(() => event.eventId).thenReturn(eventId);
          when(() => event.roomId).thenReturn(scenario.eventRoomIdAt(i));
          when(() => event.type).thenReturn(operation.type);
          when(() => event.status).thenReturn(operation.status);
          localTimelineCtl.add(event);
        }
        await coordinator.stop();

        expect(
          ingestor.processCalls,
          hasLength(scenario.expectedIngestorCalls),
          reason: '$scenario',
        );
        expect(
          penEvents,
          hasLength(scenario.expectedPenCalls),
          reason: '$scenario',
        );
        expect(
          enqueuedEvents,
          hasLength(scenario.expectedQueueCalls),
          reason: '$scenario',
        );
      } finally {
        await localTimelineCtl.close();
        await localSyncCtl.close();
        await localSyncDb.close();
        await localJournalDb.close();
      }
    },
    tags: 'glados',
  );

  test(
    'stop(drainFirst: true) drains until empty before tearing down (F7)',
    () async {
      final coordinator = build();
      await coordinator.start();
      await coordinator.stop(drainFirst: true);

      // drainUntilEmpty calls drainToCompletion at least once.
      verify(worker.drainToCompletion).called(greaterThanOrEqualTo(1));
      verify(() => queue.stats()).called(greaterThanOrEqualTo(1));
      verify(() => worker.stop()).called(1);
      verify(bridge.stop).called(1);
      verify(pen.stop).called(1);
      verify(() => queue.dispose()).called(1);
    },
  );

  test('stop without drainFirst skips drainToCompletion', () async {
    final coordinator = build();
    await coordinator.start();
    await coordinator.stop();

    verifyNever(worker.drainToCompletion);
    verify(() => worker.stop()).called(1);
  });

  test('triggerBridge delegates to bridge.bridgeNow', () async {
    when(bridge.bridgeNow).thenAnswer((_) async {});
    final coordinator = build();
    await coordinator.triggerBridge();
    verify(bridge.bridgeNow).called(1);
  });

  test(
    'isBridgeInFlight forwards from the bridge coordinator — this is '
    'the gate the backfill service reads to skip analysis during a walk',
    () {
      when(() => bridge.isBridgeInFlight).thenReturn(true);
      final coordinator = build();
      expect(coordinator.isBridgeInFlight, isTrue);

      when(() => bridge.isBridgeInFlight).thenReturn(false);
      expect(coordinator.isBridgeInFlight, isFalse);
    },
  );

  test(
    'onBridgeCompleted getter/setter forwards to the bridge — backfill '
    'service subscribes through the coordinator facade so the two do '
    'not need to know about each other directly',
    () {
      void callback() {}
      final coordinator = build()..onBridgeCompleted = callback;
      verify(() => bridge.onBridgeCompleted = callback).called(1);

      when(() => bridge.onBridgeCompleted).thenReturn(callback);
      expect(coordinator.onBridgeCompleted, same(callback));
    },
  );

  test('start logs noRoom when there is no current room', () async {
    when(() => roomManager.currentRoomId).thenReturn(null);
    final coordinator = build();
    await coordinator.start();

    verifyNever(() => seeder.seedIfAbsent(any()));
    verify(
      () => logging.captureEvent(
        any<String>(that: contains('queue.coordinator.start.noRoom')),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).called(1);
    expect(coordinator.isRunning, isTrue);
    await coordinator.stop();
  });

  test('start swallows seeder errors and continues', () async {
    when(
      () => seeder.seedIfAbsent(any()),
    ).thenThrow(StateError('seed failed'));
    final coordinator = build();
    await coordinator.start();

    expect(coordinator.isRunning, isTrue);
    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(
          named: 'subDomain',
          that: contains('start.seed'),
        ),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

  test(
    'start unwinds when worker.start throws and leaves coordinator stopped',
    () async {
      when(worker.start).thenThrow(StateError('worker died'));
      final coordinator = build();

      await expectLater(coordinator.start(), throwsA(isA<StateError>()));
      expect(coordinator.isRunning, isFalse);
      verify(bridge.stop).called(1);
      verify(() => worker.stop()).called(1);
    },
  );

  test('handles onSync signal: postLoad called on partial room', () async {
    final room = MockRoom();
    when(() => room.partial).thenReturn(true);
    when(room.postLoad).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);

    final coordinator = build();
    await coordinator.start();

    syncCtl.add(SyncUpdate(nextBatch: 'x'));
    // Allow the async listener to fire and the follow-up postLoad future.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(room.postLoad).called(1);
    await coordinator.stop();
  });

  test(
    'onSync does not call postLoad when room is already non-partial',
    () async {
      final room = MockRoom();
      when(() => room.partial).thenReturn(false);
      when(room.postLoad).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);

      final coordinator = build();
      await coordinator.start();

      syncCtl.add(SyncUpdate(nextBatch: 'x'));
      await Future<void>.delayed(Duration.zero);

      verifyNever(room.postLoad);
      await coordinator.stop();
    },
  );

  test('safeEnqueue swallows errors from enqueueLive', () async {
    when(
      () => queue.enqueueLive(any()),
    ).thenThrow(StateError('queue closed'));
    final coordinator = build();
    await coordinator.start();

    timelineCtl.add(buildEvent(EventTypes.Message));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('enqueue')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

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
          penOverride: pen,
          seederOverride: seeder,
        );

        final room = MockRoom();
        final timeline = MockTimeline();
        when(() => roomManager.currentRoom).thenReturn(room);
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);

        final event = MockEvent();
        when(() => event.eventId).thenReturn(r'$bootstrap');
        when(() => event.roomId).thenReturn(roomId);
        when(() => event.type).thenReturn(EventTypes.Message);
        when(
          () => event.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
        when(() => event.content).thenReturn(<String, dynamic>{
          'msgtype': 'org.matrix.lotti.sync',
        });
        when(event.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$bootstrap',
          'room_id': roomId,
          'origin_server_ts': 10,
          'type': EventTypes.Message,
          'content': {'msgtype': 'org.matrix.lotti.sync'},
        });
        when(() => timeline.events).thenReturn(<Event>[event]);
        when(() => timeline.canRequestHistory).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});

        final infos = <BootstrapPageInfo>[];
        final result = await coordinator.collectHistory(
          onProgress: infos.add,
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(infos, hasLength(1));
        expect(infos.single.totalEventsSoFar, 1);
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
          penOverride: pen,
          seederOverride: seeder,
        );

        final room = MockRoom();
        final timeline = MockTimeline();
        when(() => roomManager.currentRoom).thenReturn(room);
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);

        final event = MockEvent();
        when(() => event.eventId).thenReturn(r'$bootstrap2');
        when(() => event.roomId).thenReturn(roomId);
        when(() => event.type).thenReturn(EventTypes.Message);
        when(
          () => event.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(20));
        when(() => event.content).thenReturn(<String, dynamic>{
          'msgtype': 'org.matrix.lotti.sync',
        });
        when(event.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$bootstrap2',
          'room_id': roomId,
          'origin_server_ts': 20,
          'type': EventTypes.Message,
          'content': {'msgtype': 'org.matrix.lotti.sync'},
        });
        when(() => timeline.events).thenReturn(<Event>[event]);
        when(() => timeline.canRequestHistory).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});

        final result = await coordinator.collectHistory(
          onProgress: (_) => throw StateError('UI unmounted'),
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
      },
    );
  });

  test('queue getter exposes the underlying InboundQueue', () {
    final coordinator = build();
    expect(coordinator.queue, same(queue));
  });

  test('postLoad error drops the marker so a later sync retries', () async {
    final room = MockRoom();
    when(() => room.partial).thenReturn(true);
    when(room.postLoad).thenThrow(StateError('sdk down'));
    when(() => roomManager.currentRoom).thenReturn(room);

    final coordinator = build();
    await coordinator.start();

    syncCtl.add(SyncUpdate(nextBatch: 'x'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('postLoad')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

  test('onSync error handler logs and does not crash', () async {
    final coordinator = build();
    await coordinator.start();

    syncCtl.addError(StateError('sync broke'), StackTrace.current);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('syncSub')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

  test('stop swallows drain errors and still tears down', () async {
    when(
      worker.drainToCompletion,
    ).thenThrow(StateError('drain blew up'));
    when(() => queue.stats()).thenAnswer(
      (_) async => const QueueStats(
        total: 0,
        byProducer: {},
        readyNow: 0,
        oldestEnqueuedAt: null,
      ),
    );
    when(() => pen.size).thenReturn(0);
    final coordinator = build();
    await coordinator.start();
    await coordinator.stop(drainFirst: true);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('drain')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(greaterThanOrEqualTo(1));
    verify(() => worker.stop()).called(1);
    verify(pen.stop).called(1);
    verify(() => queue.dispose()).called(1);
  });

  test(
    'coordinator built without overrides wires default collaborators',
    () async {
      when(() => sessionManager.client).thenReturn(client);
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
      );

      expect(coordinator.queue, isNotNull);
      expect(coordinator.isRunning, isFalse);
    },
  );

  group('P1 fixes', () {
    test(
      'start() fires a background bridge pass for startup catch-up',
      () async {
        final coordinator = build();
        await coordinator.start();
        // The unawaited safeStartupBridge microtask needs to settle.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verify(bridge.bridgeNow).called(1);
        await coordinator.stop();
      },
    );

    test(
      'start() skips startup bridge when there is no current room',
      () async {
        when(() => roomManager.currentRoomId).thenReturn(null);
        final coordinator = build();
        await coordinator.start();
        await Future<void>.delayed(Duration.zero);

        verifyNever(bridge.bridgeNow);
        await coordinator.stop();
      },
    );

    test(
      'start() swallows startup bridge errors with a captured exception',
      () async {
        when(bridge.bridgeNow).thenThrow(StateError('bridge broke'));
        final coordinator = build();
        await coordinator.start();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('startupBridge'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
        await coordinator.stop();
      },
    );

    test(
      'onRoomChanged seeds the new room and prunes stranded rows',
      () async {
        final coordinator = build();
        await coordinator.onRoomChanged('!other:example.org');

        verify(() => seeder.seedIfAbsent('!other:example.org')).called(1);
        verify(
          () => queue.pruneStrandedEntries('!other:example.org'),
        ).called(1);
      },
    );

    test(
      'onRoomChanged swallows seeder errors and still logs the event',
      () async {
        when(
          () => seeder.seedIfAbsent(any()),
        ).thenThrow(StateError('seed failed'));

        final coordinator = build();
        await coordinator.onRoomChanged('!other:example.org');

        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('onRoomChanged'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'drainUntilEmpty keeps looping while rows remain and the pen holds',
      () async {
        // Fake a queue that reports 2 rows on the first stats() call and
        // 0 on the second, so the loop exits on the second iteration.
        final totals = <int>[2, 0];
        when(() => queue.stats()).thenAnswer((_) async {
          final total = totals.isEmpty ? 0 : totals.removeAt(0);
          return QueueStats(
            total: total,
            byProducer: const {},
            readyNow: total,
            oldestEnqueuedAt: null,
          );
        });
        when(() => queue.earliestReadyAt()).thenAnswer(
          (_) async => clock.now().millisecondsSinceEpoch,
        );

        final coordinator = build();
        await coordinator.drainUntilEmpty(
          timeout: const Duration(seconds: 5),
        );

        // The loop should have called drainToCompletion at least twice
        // (first iteration with non-zero remaining, second with zero).
        verify(worker.drainToCompletion).called(greaterThanOrEqualTo(2));
        verify(() => queue.stats()).called(greaterThanOrEqualTo(2));
      },
    );

    test(
      'drainUntilEmpty respects the timeout and logs on timeout',
      () async {
        // Always report remaining rows so the loop only exits via timeout.
        when(() => queue.stats()).thenAnswer(
          (_) async => const QueueStats(
            total: 5,
            byProducer: {},
            readyNow: 5,
            oldestEnqueuedAt: null,
          ),
        );
        when(() => queue.earliestReadyAt()).thenAnswer((_) async => null);

        final coordinator = build();
        await coordinator.drainUntilEmpty(
          timeout: const Duration(milliseconds: 50),
        );

        verify(
          () => logging.captureEvent(
            any<String>(
              that: contains('queue.coordinator.drainUntilEmpty.timeout'),
            ),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).called(1);
      },
    );

    test(
      'drainUntilEmpty flushes the pen before sampling stats',
      () async {
        final room = MockRoom();
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => pen.flushInto(queue: queue, room: room)).thenAnswer(
          (_) async =>
              const PenFlushOutcome(enqueued: 0, stillEncrypted: 0, dropped: 0),
        );

        final coordinator = build();
        await coordinator.drainUntilEmpty(
          timeout: const Duration(milliseconds: 10),
        );

        verify(
          () => pen.flushInto(queue: queue, room: room),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    glados.Glados(
      glados.any.drainScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated drainUntilEmpty follows queue, pen, ready-at and timeout model',
      (scenario) async {
        final localSyncDb = SyncDatabase(inMemoryDatabase: true);
        final localJournalDb = JournalDb(inMemoryDatabase: true);
        final localSettingsDb = MockSettingsDb();
        final localSessionManager = _MockSessionManager();
        final localRoomManager = _MockRoomManager();
        final localProcessor = MockSyncEventProcessor();
        final localSequenceLog = MockSyncSequenceLogService();
        final localLogging = MockLoggingService();
        final localQueue = MockInboundQueue();
        final localWorker = _MockWorker();
        final localBridge = _MockBridge();
        final localPen = _MockPen();
        final localSeeder = _MockSeeder();
        final localClient = MockMatrixClient();
        final localRoom = MockRoom();
        final localTimelineCtl = StreamController<Event>.broadcast(sync: true);
        final localSyncCtl = CachedStreamController<SyncUpdate>();
        final events = <String>[];
        final exceptionSubDomains = <String>[];
        var statsCalls = 0;
        var drainCalls = 0;
        var flushCalls = 0;
        var readyAtCalls = 0;

        when(
          () => localSessionManager.timelineEvents,
        ).thenAnswer((_) => localTimelineCtl.stream);
        when(() => localSessionManager.client).thenReturn(localClient);
        when(() => localClient.onSync).thenReturn(localSyncCtl);
        when(() => localRoomManager.currentRoomId).thenReturn(roomId);
        when(() => localRoomManager.currentRoom).thenReturn(
          scenario.hasRoom ? localRoom : null,
        );
        when(() => localSeeder.seedIfAbsent(any())).thenAnswer(
          (_) async => true,
        );
        when(
          () => localQueue.pruneStrandedEntries(any()),
        ).thenAnswer((_) async => 0);
        when(localWorker.start).thenAnswer((_) async {});
        when(localWorker.stop).thenAnswer((_) async {});
        when(localWorker.drainToCompletion).thenAnswer((_) async {
          drainCalls++;
          if (scenario.workerThrows) {
            throw StateError('generated drain failure');
          }
          return 0;
        });
        when(localBridge.start).thenReturn(null);
        when(localBridge.stop).thenAnswer((_) async {});
        when(localBridge.bridgeNow).thenAnswer((_) async {});
        when(localPen.stop).thenAnswer((_) async {});
        when(
          () => localPen.flushInto(queue: localQueue, room: localRoom),
        ).thenAnswer((_) async {
          flushCalls++;
          if (scenario.penThrows) {
            throw StateError('generated pen failure');
          }
          return const PenFlushOutcome(
            enqueued: 0,
            stillEncrypted: 0,
            dropped: 0,
          );
        });
        when(localQueue.dispose).thenAnswer((_) async {});
        when(localQueue.stats).thenAnswer((_) async {
          final step = scenario.stepAt(statsCalls);
          statsCalls++;
          return QueueStats(
            total: step.total,
            byProducer: const {},
            readyNow: step.total,
            oldestEnqueuedAt: null,
          );
        });
        when(() => localPen.size).thenAnswer((_) {
          final index = statsCalls <= 0 ? 0 : statsCalls - 1;
          return scenario.stepAt(index).penSize;
        });
        when(localQueue.earliestReadyAt).thenAnswer((_) async {
          readyAtCalls++;
          final index = statsCalls <= 0 ? 0 : statsCalls - 1;
          final step = scenario.stepAt(index);
          switch (step.readyAtKind) {
            case _GeneratedDrainReadyAtKind.none:
              return null;
            case _GeneratedDrainReadyAtKind.now:
              return clock.now().millisecondsSinceEpoch;
            case _GeneratedDrainReadyAtKind.soon:
              return clock
                  .now()
                  .add(const Duration(milliseconds: 15))
                  .millisecondsSinceEpoch;
          }
        });
        when(
          () => localLogging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((invocation) {
          events.add(invocation.positionalArguments.single as String);
        });
        when(
          () => localLogging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).thenAnswer((invocation) async {
          exceptionSubDomains.add(
            invocation.namedArguments[#subDomain] as String,
          );
        });

        final coordinator = QueuePipelineCoordinator(
          syncDb: localSyncDb,
          settingsDb: localSettingsDb,
          journalDb: localJournalDb,
          sessionManager: localSessionManager,
          roomManager: localRoomManager,
          eventProcessor: localProcessor,
          sequenceLogService: localSequenceLog,
          activityGate: null,
          logging: localLogging,
          queueOverride: localQueue,
          workerOverride: localWorker,
          bridgeOverride: localBridge,
          penOverride: localPen,
          seederOverride: localSeeder,
        );

        try {
          fakeAsync((async) {
            var completed = false;
            Object? error;
            withClock(
              Clock(
                () => DateTime.utc(2026).add(async.elapsed),
              ),
              () {
                unawaited(
                  coordinator
                      .drainUntilEmpty(timeout: scenario.timeout)
                      .then<void>((_) {
                        completed = true;
                      })
                      .catchError((Object e) {
                        error = e;
                      }),
                );
              },
            );

            async
              ..flushMicrotasks()
              ..elapse(scenario.advanceBy)
              ..flushMicrotasks();

            expect(error, isNull, reason: '$scenario');
            expect(completed, isTrue, reason: '$scenario');
          });

          expect(statsCalls, scenario.expectedIterations, reason: '$scenario');
          expect(drainCalls, scenario.expectedIterations, reason: '$scenario');
          expect(
            flushCalls,
            scenario.hasRoom ? scenario.expectedIterations : 0,
            reason: '$scenario',
          );
          if (scenario.timesOut) {
            expect(
              events,
              contains(
                contains('queue.coordinator.drainUntilEmpty.timeout'),
              ),
              reason: '$scenario',
            );
          } else {
            expect(
              events,
              contains(contains('queue.coordinator.drainUntilEmpty.done')),
              reason: '$scenario',
            );
          }
          if (scenario.hasRoom && scenario.penThrows) {
            expect(
              exceptionSubDomains.where(
                (subDomain) => subDomain.endsWith('.pen'),
              ),
              hasLength(scenario.expectedIterations),
              reason: '$scenario',
            );
          }
          if (scenario.workerThrows) {
            expect(
              exceptionSubDomains.where(
                (subDomain) => subDomain.endsWith('.drain'),
              ),
              hasLength(scenario.expectedIterations),
              reason: '$scenario',
            );
          }
          expect(
            readyAtCalls,
            scenario.timesOut
                ? 1
                : scenario.expectedIterations == 0
                ? 0
                : scenario.expectedIterations - 1,
            reason: '$scenario',
          );
        } finally {
          await localTimelineCtl.close();
          await localSyncCtl.close();
          await localSyncDb.close();
          await localJournalDb.close();
        }
      },
      tags: 'glados',
    );
  });

  group('triggerBridge with real BridgeCoordinator', () {
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
          penOverride: pen,
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
          penOverride: pen,
          seederOverride: seeder,
        );

        await coordinator.triggerBridge();

        verify(
          () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
        ).called(1);
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
          penOverride: pen,
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
          () => logging.captureEvent(
            any<String>(
              that: contains('queue.bridge.start mode=reconnect.backward'),
            ),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).called(1);
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
          penOverride: pen,
          seederOverride: seeder,
        );

        await coordinator.triggerBridge();

        verify(
          () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
        ).called(1);
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
          penOverride: pen,
          seederOverride: seeder,
        );

        await coordinator.triggerBridge();

        verify(
          () => logging.captureEvent(
            any<String>(that: contains('queue.bridge.skip reason=noRoom')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).called(1);
      },
    );
  });

  group('signal-driven resurrection', () {
    test(
      'when the AttachmentIndex records a new path, the coordinator '
      'flushes the debounced batch through resurrectByPaths so an '
      'abandoned row waiting on that attachment is flipped back to '
      'enqueued in a single bulk DB call instead of a per-path SELECT '
      '+ UPDATE pair (see 2026-05-12 super_slow log: 222 hits/day at '
      '~384 ms each)',
      () async {
        final attachmentIndex = AttachmentIndex(logging: logging);
        addTearDown(attachmentIndex.dispose);
        when(
          () => queue.resurrectByPaths(any<Iterable<String>>()),
        ).thenAnswer((_) async => 1);

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
          attachmentIndex: attachmentIndex,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        final event = MockEvent();
        when(() => event.attachmentMimetype).thenReturn('audio/m4a');
        when(() => event.content).thenReturn({
          'relativePath': 'audio/2026-04-21/foo.m4a.json',
        });
        when(() => event.eventId).thenReturn(r'$attachmentEvent');
        attachmentIndex.record(event);

        await Future<void>.delayed(Duration.zero);
        await coordinator.flushPendingPathResurrectionsForTest();

        final captured =
            verify(
                  () => queue.resurrectByPaths(captureAny<Iterable<String>>()),
                ).captured.single
                as Iterable<String>;
        expect(captured, contains('/audio/2026-04-21/foo.m4a.json'));

        await coordinator.stop();
      },
    );

    test(
      'a burst of pathRecorded events lands in a single resurrectByPaths '
      'call once the debounce window closes — fold the N writer-lock '
      'transactions captured in the 2026-05-12 super_slow log (10+ '
      'identical-elapsed hits in the same millisecond span) into one '
      'bulk DB round-trip',
      () async {
        final attachmentIndex = AttachmentIndex(logging: logging);
        addTearDown(attachmentIndex.dispose);
        when(
          () => queue.resurrectByPaths(any<Iterable<String>>()),
        ).thenAnswer((_) async => 3);

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
          attachmentIndex: attachmentIndex,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        for (final path in [
          'audio/2026-04-21/a.m4a.json',
          'audio/2026-04-21/b.m4a.json',
          'images/2026-04-21/c.jpg.json',
        ]) {
          final event = MockEvent();
          when(() => event.attachmentMimetype).thenReturn('audio/m4a');
          when(() => event.content).thenReturn({'relativePath': path});
          when(() => event.eventId).thenReturn('\$ev-${path.hashCode}');
          attachmentIndex.record(event);
        }
        // Flush all queued microtasks first, then drain the timer.
        await Future<void>.delayed(Duration.zero);
        await coordinator.flushPendingPathResurrectionsForTest();

        final captured =
            verify(
                  () => queue.resurrectByPaths(captureAny<Iterable<String>>()),
                ).captured.single
                as Iterable<String>;
        expect(
          captured.toSet(),
          {
            '/audio/2026-04-21/a.m4a.json',
            '/audio/2026-04-21/b.m4a.json',
            '/images/2026-04-21/c.jpg.json',
          },
          reason:
              'three paths recorded inside one debounce window must '
              'collapse to one bulk resurrectByPaths call, not three '
              'separate ones',
        );
        // Single call covers the whole burst.
        verifyNever(() => queue.resurrectByPath(any()));

        await coordinator.stop();
      },
    );

    test(
      'coordinator.stop() awaits an in-flight resurrectByPaths flush '
      'before disposing the queue — guards against the teardown race '
      'where the debounce timer fires, kicks off a writer transaction, '
      'and stop() then disposes the queue concurrently',
      () async {
        final attachmentIndex = AttachmentIndex(logging: logging);
        addTearDown(attachmentIndex.dispose);

        // Hold the flush mid-transaction so stop() observes it
        // in-flight. We release it inside the verify so the test
        // settles, but the critical assertion is that stop()
        // *awaited* the flush (the released future completes before
        // stop() returns).
        final flushCompleter = Completer<int>();
        when(
          () => queue.resurrectByPaths(any<Iterable<String>>()),
        ).thenAnswer((_) => flushCompleter.future);

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
          attachmentIndex: attachmentIndex,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        // Push a path through the debounced subscriber and let the
        // accumulator drain into the bulk call. The mock now hangs
        // on `flushCompleter.future` so the flush is genuinely
        // in-flight when stop() runs.
        final event = MockEvent();
        when(() => event.attachmentMimetype).thenReturn('audio/m4a');
        when(() => event.content).thenReturn({
          'relativePath': 'audio/2026-04-21/foo.m4a.json',
        });
        when(() => event.eventId).thenReturn(r'$ev');
        attachmentIndex.record(event);
        await Future<void>.delayed(Duration.zero);
        // Trigger the debounce window so the flush kicks off.
        // We can't `await` the flush here — it's parked on the
        // completer — but we can let the timer fire by relying on
        // the visible-for-test entry point which schedules the
        // flush right now.
        unawaited(coordinator.flushPendingPathResurrectionsForTest());
        await Future<void>.delayed(Duration.zero);

        // Start stop() and release the flush after one microtask.
        // If stop() does not await the in-flight flush, it returns
        // before the flush completer resolves and the verify below
        // would see called=0 at that moment.
        final stopFuture = coordinator.stop();
        await Future<void>.delayed(Duration.zero);
        flushCompleter.complete(1);
        await stopFuture;

        verify(
          () => queue.resurrectByPaths(any<Iterable<String>>()),
        ).called(1);
      },
    );

    test(
      'when UpdateNotifications emits, the coordinator calls '
      'resurrectByReason(missingBase) so any abandoned row waiting '
      'on its base journal entry becomes drainable again',
      () {
        fakeAsync((async) {
          final updateNotifications = UpdateNotifications();
          addTearDown(updateNotifications.dispose);
          when(
            () => queue.resurrectByReason(any<String>()),
          ).thenAnswer((_) async => 1);

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
            updateNotifications: updateNotifications,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            penOverride: pen,
            seederOverride: seeder,
          );
          addTearDown(() async => coordinator.stop());
          var started = false;
          unawaited(coordinator.start().then((_) => started = true));
          async.flushMicrotasks();
          expect(started, isTrue);

          updateNotifications.notify({'some-entry-id'});
          async
            ..elapse(const Duration(milliseconds: 100))
            ..flushMicrotasks();

          verify(
            () => queue.resurrectByReason('missingBase'),
          ).called(greaterThanOrEqualTo(1));
        });
      },
    );
  });

  group('attachment ingestor hook', () {
    test(
      'every live event for the current room is routed through '
      'AttachmentIngestor.process so descriptor JSONs land on disk '
      'alongside the queue-pipeline enqueue',
      () async {
        final ingestor = _FakeAttachmentIngestor();

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
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        timelineCtl.add(buildEvent(EventTypes.Message));
        await Future<void>.delayed(Duration.zero);

        expect(ingestor.processCalls, hasLength(1));
        // `scheduleDownload` must be `true` so the coordinator routes
        // through the async download queue — an in-line save path would
        // block the live handler under bursty load.
        expect(ingestor.processCalls.single[#scheduleDownload], isTrue);

        await coordinator.stop();
      },
    );

    test(
      'when AttachmentIngestor.process throws, the failure is logged '
      'and the queue enqueue still happens — a broken ingestor must '
      'not strand incoming sync-payload events',
      () async {
        final ingestor = _FakeAttachmentIngestor(shouldThrow: true);
        final ingestorFailureLogged = Completer<void>();
        when(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('attachmentIngestor'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) {
          if (!ingestorFailureLogged.isCompleted) {
            ingestorFailureLogged.complete();
          }
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
          attachmentIngestor: ingestor,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        timelineCtl.add(buildEvent(EventTypes.Message));
        await ingestorFailureLogged.future;

        // The enqueue path still fires despite the ingestor throwing.
        verify(() => queue.enqueueLive(any())).called(1);
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('attachmentIngestor'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);

        await coordinator.stop();
      },
    );
  });

  group('self-echo suppression', () {
    test(
      'events this device just sent are consumed from the SentEventRegistry '
      'and never reach the queue — without this the live handler would '
      're-enqueue every outbox message as it echoes back through Matrix',
      () async {
        final registry = SentEventRegistry();
        final ingestor = _FakeAttachmentIngestor();
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
          sentEventRegistry: registry,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        final echoed = MockEvent();
        when(() => echoed.eventId).thenReturn(r'$self-echo');
        when(() => echoed.roomId).thenReturn(roomId);
        when(() => echoed.type).thenReturn(EventTypes.Message);
        when(() => echoed.status).thenReturn(EventStatus.synced);
        registry.register(r'$self-echo');

        timelineCtl.add(echoed);

        // Neither the queue nor the attachment ingestor should see the
        // event — it's ours and already on disk.
        verifyNever(() => queue.enqueueLive(any()));
        expect(ingestor.processCalls, isEmpty);

        await coordinator.stop();
      },
    );

    test(
      'peer events (not in the SentEventRegistry) still flow through — '
      'suppression must not drop messages from other devices',
      () async {
        final registry = SentEventRegistry();
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
          sentEventRegistry: registry,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        final peer = MockEvent();
        when(() => peer.eventId).thenReturn(r'$peer-event');
        when(() => peer.roomId).thenReturn(roomId);
        when(() => peer.type).thenReturn(EventTypes.Message);
        when(() => peer.status).thenReturn(EventStatus.synced);
        final enqueued = Completer<void>();
        when(() => queue.enqueueLive(peer)).thenAnswer((_) async {
          if (!enqueued.isCompleted) {
            enqueued.complete();
          }
          return EnqueueResult.empty;
        });

        timelineCtl.add(peer);
        await enqueued.future;

        verify(() => queue.enqueueLive(peer)).called(1);

        await coordinator.stop();
      },
    );

    test(
      'pre-sync fake-sync emissions (status=sending / sent / error) are '
      'dropped at the live-handler ingress — Matrix SDK 7.0.0 fires '
      '_handleFakeSync twice on every send (pending + optimistic), both '
      'with a non-synced status, and both race past the SentEventRegistry '
      'because the sender registers the real id only after sendEvent '
      'returns. Filtering by status before the registry check is the '
      'only way to guarantee these do not reach the queue.',
      () async {
        final registry = SentEventRegistry();
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
          sentEventRegistry: registry,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        // Pending fake-sync: transaction id (not server-assigned),
        // status=sending — would otherwise bypass the registry entirely
        // because the registry never learns the transaction id.
        final pending = MockEvent();
        when(() => pending.eventId).thenReturn('m1761234567890-txn-id');
        when(() => pending.roomId).thenReturn(roomId);
        when(() => pending.type).thenReturn(EventTypes.Message);
        when(() => pending.status).thenReturn(EventStatus.sending);

        // Optimistic fake-sync: real `$...` id, status=sent — the
        // registry is empty on this tick because the sender's
        // register() call has not run yet (it runs after sendEvent
        // returns, which is after this fake-sync fires).
        final optimistic = MockEvent();
        when(() => optimistic.eventId).thenReturn(r'$server-assigned-id');
        when(() => optimistic.roomId).thenReturn(roomId);
        when(() => optimistic.type).thenReturn(EventTypes.Message);
        when(() => optimistic.status).thenReturn(EventStatus.sent);

        // Error fake-sync: send failed mid-flight.
        final errored = MockEvent();
        when(() => errored.eventId).thenReturn('m-errored-txn');
        when(() => errored.roomId).thenReturn(roomId);
        when(() => errored.type).thenReturn(EventTypes.Message);
        when(() => errored.status).thenReturn(EventStatus.error);

        timelineCtl
          ..add(pending)
          ..add(optimistic)
          ..add(errored);

        // None of these should reach the queue — they are
        // SDK-generated fake-sync emissions, not real inbound events.
        verifyNever(() => queue.enqueueLive(any()));

        await coordinator.stop();
      },
    );
  });

  group('resurrection subscription error paths', () {
    test(
      'when resurrectByPaths throws on the debounced flush, the '
      'exception is logged under the resurrectByPaths subDomain — a '
      'broken queue must not silently drop resurrection signals',
      () async {
        final attachmentIndex = AttachmentIndex(logging: logging);
        addTearDown(attachmentIndex.dispose);
        when(
          () => queue.resurrectByPaths(any<Iterable<String>>()),
        ).thenThrow(StateError('queue gone'));

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
          attachmentIndex: attachmentIndex,
          queueOverride: queue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();

        final event = MockEvent();
        when(() => event.attachmentMimetype).thenReturn('audio/m4a');
        when(() => event.content).thenReturn({
          'relativePath': 'audio/2026-04-21/foo.m4a.json',
        });
        when(() => event.eventId).thenReturn(r'$attachment');
        attachmentIndex.record(event);
        await Future<void>.delayed(Duration.zero);
        await coordinator.flushPendingPathResurrectionsForTest();

        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('resurrectByPaths'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);

        await coordinator.stop();
      },
    );

    test(
      'when resurrectByReason throws on a journal-db update notify, '
      'the exception is logged under the resurrectByReason subDomain '
      'so a broken queue never silences the missing-base signal',
      () {
        fakeAsync((async) {
          final updateNotifications = UpdateNotifications();
          addTearDown(updateNotifications.dispose);
          when(
            () => queue.resurrectByReason(any<String>()),
          ).thenThrow(StateError('queue gone'));

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
            updateNotifications: updateNotifications,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            penOverride: pen,
            seederOverride: seeder,
          );
          addTearDown(() async => coordinator.stop());
          var started = false;
          unawaited(coordinator.start().then((_) => started = true));
          async.flushMicrotasks();
          expect(started, isTrue);

          updateNotifications.notify({'some-entry'});
          async
            ..elapse(const Duration(milliseconds: 100))
            ..flushMicrotasks();

          verify(
            () => logging.captureException(
              any<Object>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('resurrectByReason'),
              ),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            ),
          ).called(greaterThanOrEqualTo(1));
        });
      },
    );
  });

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
        penOverride: pen,
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
          QueuePipelineCoordinator.barrenBridgeTtl + const Duration(seconds: 1),
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
  });

  group('reconnect forward-walk dispatch (Option B)', () {
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
          penOverride: pen,
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
          penOverride: pen,
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
          penOverride: pen,
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
          penOverride: pen,
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

    test(
      'forward walk routes every paginated event through the '
      'AttachmentIngestor — bootstrap catch-up on a room with '
      'historical attachments must hydrate descriptor JSONs alongside '
      'the queue enqueue, otherwise the companion sync-payload events '
      'sit in pendingAttachment forever',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final firstProcessed = Completer<Event>();
        final ingestor = _FakeAttachmentIngestor(
          firstProcessed: firstProcessed,
        );

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
          penOverride: pen,
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
        final timeline = MockTimeline();
        when(() => timeline.events).thenReturn(<Event>[anchor, e1]);
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

        // The forward walk emitted page [e1] (anchor itself is
        // filtered) → ingestor.process must have fired for that event.
        expect(await firstProcessed.future, same(e1));
        expect(ingestor.processCalls, hasLength(1));
        expect(ingestor.processCalls.single[#event], same(e1));
      },
    );

    test(
      'backward walk with attachment ingestor routes every page event '
      'through `AttachmentIngestor.process` — covers the ingestor-aware '
      'branch for the fresh-client / anchor-unresolvable fallback',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);
        final firstProcessed = Completer<Event>();
        final ingestor = _FakeAttachmentIngestor(
          firstProcessed: firstProcessed,
        );

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
          penOverride: pen,
          seederOverride: seeder,
        );
        await coordinator.start();
        addTearDown(() async => coordinator.stop());

        final room = MockRoom();
        when(() => room.id).thenReturn(roomId);
        final e = MockEvent();
        when(() => e.eventId).thenReturn(r'$e1');
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
        when(() => e.roomId).thenReturn(roomId);
        when(() => e.type).thenReturn(EventTypes.Message);
        when(() => e.content).thenReturn(<String, dynamic>{});
        when(e.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$e1',
          'room_id': roomId,
          'origin_server_ts': 200,
          'type': EventTypes.Message,
          'content': <String, dynamic>{},
        });
        final tl = MockTimeline();
        when(() => tl.events).thenReturn(<Event>[e]);
        when(() => tl.canRequestHistory).thenReturn(false);
        when(tl.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => roomManager.currentRoom).thenReturn(room);

        // No anchor id → backward walk runs.
        final completed = await coordinator.runBootstrapForTest(room: room);
        expect(completed, isTrue);
        expect(await firstProcessed.future, same(e));
        expect(ingestor.processCalls, hasLength(1));
        expect(ingestor.processCalls.single[#event], same(e));
      },
    );
  });
}
