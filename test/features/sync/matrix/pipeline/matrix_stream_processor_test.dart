import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockJournalDb extends Mock implements JournalDb {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockEventProcessor extends Mock implements SyncEventProcessor {}

class _MockReadMarkerService extends Mock implements SyncReadMarkerService {}

class _MockSentEventRegistry extends Mock implements SentEventRegistry {}

class _MockClient extends Mock implements Client {}

class _MockTimeline extends Mock implements Timeline {}

void main() {
  late _MockRoomManager roomManager;
  late LoggingService loggingService;
  late _MockJournalDb journalDb;
  late _MockSettingsDb settingsDb;
  late _MockEventProcessor eventProcessor;
  late _MockReadMarkerService readMarkerService;
  late _MockSentEventRegistry sentEventRegistry;
  late _MockClient client;
  late MetricsCounters metrics;

  setUp(() {
    roomManager = _MockRoomManager();
    loggingService = LoggingService();
    journalDb = _MockJournalDb();
    settingsDb = _MockSettingsDb();
    eventProcessor = _MockEventProcessor();
    readMarkerService = _MockReadMarkerService();
    sentEventRegistry = _MockSentEventRegistry();
    client = _MockClient();
    metrics = MetricsCounters(collect: true);
  });

  MatrixStreamProcessor createProcessor({
    bool collectMetrics = true,
  }) {
    return MatrixStreamProcessor(
      roomManager: roomManager,
      loggingService: loggingService,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: eventProcessor,
      readMarkerService: readMarkerService,
      sentEventRegistry: sentEventRegistry,
      clientProvider: () => client,
      liveTimelineProvider: _MockTimeline.new,
      metricsCounters: metrics,
      collectMetrics: collectMetrics,
    );
  }

  group('MatrixStreamProcessor', () {
    test('can be constructed', () {
      final processor = createProcessor();

      expect(processor, isNotNull);
    });

    test('initial state has null lastProcessedEventId', () {
      final processor = createProcessor();

      expect(processor.lastProcessedEventId, isNull);
    });

    test('initial state has null lastProcessedTs', () {
      final processor = createProcessor();

      expect(processor.lastProcessedTs, isNull);
    });

    test('setLastProcessed updates eventId and timestamp', () {
      final processor = createProcessor()
        ..setLastProcessed(eventId: r'$event1', timestamp: 1000);

      expect(processor.lastProcessedEventId, r'$event1');
      expect(processor.lastProcessedTs, 1000);
    });

    test('wasCompletedSync returns false for unknown id', () {
      final processor = createProcessor();

      expect(processor.wasCompletedSync(r'$unknown'), isFalse);
    });

    test('debugCollectMetrics reflects constructor parameter', () {
      final withMetrics = createProcessor();
      expect(withMetrics.debugCollectMetrics, isTrue);

      final withoutMetrics = createProcessor(collectMetrics: false);
      expect(withoutMetrics.debugCollectMetrics, isFalse);
    });

    test('metrics getter returns MetricsCounters', () {
      final processor = createProcessor();

      expect(processor.metrics, metrics);
    });

    test('metricsSnapshot returns a map', () {
      final processor = createProcessor();
      final snapshot = processor.metricsSnapshot();

      expect(snapshot, isA<Map<String, int>>());
    });

    test('diagnosticsStrings returns map with lastIgnoredCount', () {
      final processor = createProcessor();
      final diag = processor.diagnosticsStrings();

      expect(diag, containsPair('lastIgnoredCount', '0'));
    });

    test('recordConnectivitySignal increments metric', () {
      createProcessor().recordConnectivitySignal();

      expect(metrics.signalConnectivity, 1);
    });

    test('dispose completes without error', () {
      expect(createProcessor().dispose, returnsNormally);
    });

    group('processOrdered', () {
      test('returns early when room is null', () async {
        when(() => roomManager.currentRoom).thenReturn(null);

        final processor = createProcessor();
        final event = _createMockSyncEvent(r'$ev1', 1000);

        // Should complete without error
        await processor.processOrdered([event]);

        // Verify that no processing was attempted.
        verifyNever(() => sentEventRegistry.prune());
      });

      test('returns early for empty list', () async {
        final mockRoom = _MockRoom();
        when(() => roomManager.currentRoom).thenReturn(mockRoom);

        final processor = createProcessor();

        await processor.processOrdered([]);
      });
    });

    group('retryNow', () {
      test('completes without error when retry tracker is empty', () async {
        final processor = createProcessor();

        await processor.retryNow();
      });
    });
  });
}

class _MockRoom extends Mock implements Room {}

Event _createMockSyncEvent(String eventId, int tsMs) {
  final event = _MockEvent();
  when(() => event.eventId).thenReturn(eventId);
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(tsMs));
  when(() => event.content).thenReturn(<String, dynamic>{});
  when(() => event.roomId).thenReturn('!room:server');
  when(() => event.type).thenReturn('m.room.message');
  when(() => event.senderId).thenReturn('@user:server');
  return event;
}

class _MockEvent extends Mock implements Event {}
