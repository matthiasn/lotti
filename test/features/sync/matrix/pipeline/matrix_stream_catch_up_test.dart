import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_catch_up.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart' hide MockEvent, MockRoom, MockTimeline;
import 'matrix_stream_consumer_test_support.dart';

void main() {
  setUpAll(() {
    registerMatrixStreamConsumerFallbacks();
    registerFallbackValue(<Event>[]);
  });

  Event event(String id, int ts) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(id);
    when(
      () => e.originServerTs,
    ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
    when(() => e.attachmentMimetype).thenReturn('');
    when(
      () => e.content,
    ).thenReturn(<String, Object?>{'msgtype': syncMessageType});
    return e;
  }

  void stubLogger(MockLoggingService logger) {
    when(
      () => logger.captureEvent(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => logger.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
  }

  test(
    'becomes ready on initial catch-up via best-effort when server boundary is unreachable',
    () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final processor = MockMatrixStreamProcessor();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final metrics = MetricsCounters(collect: true);
      final flushedSources = <String>[];

      stubLogger(logger);
      when(() => session.client).thenReturn(client);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => room.prev_batch).thenReturn('server-gap-token');
      when(
        () => room.getTimeline(limit: any<int>(named: 'limit')),
      ).thenAnswer((_) async => timeline);
      when(timeline.cancelSubscriptions).thenReturn(null);
      when(() => processor.lastProcessedEventId).thenReturn(r'$current');
      when(() => processor.lastProcessedTs).thenReturn(4000);
      when(
        () => processor.processOrdered(any<List<Event>>()),
      ).thenAnswer((_) async {});

      final events = <Event>[
        event('cached-old', 400),
        event('cached-new', 3000),
      ];
      when(() => timeline.events).thenAnswer((_) => events);

      final coordinator = MatrixStreamCatchUpCoordinator(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        metrics: metrics,
        collectMetrics: true,
        skipSyncWait: true,
        processor: processor,
        flushDeferredLiveScan: flushedSources.add,
        withInstance: (message) => message,
        backfill: ({
          required Timeline timeline,
          required String? lastEventId,
          required int pageSize,
          required int? maxPages,
          required LoggingService logging,
          num? untilTimestamp,
        }) async =>
            false, // Server boundary always unreachable
      )..startupMarkers = (
        eventId: 'legacy-marker',
        timestamp: 1500,
      );

      await coordinator.runInitialCatchUpIfReady();

      // Best-effort fallback returns available events as timestampAnchored,
      // so initial catch-up succeeds immediately.
      expect(coordinator.initialCatchUpReady, isTrue);
      expect(coordinator.initialCatchUpCompleted, isTrue);
      expect(coordinator.handleClientStreamSignal(), isFalse);
      expect(coordinator.handleFirstStreamEvent(), isFalse);

      verifyNever(
        () => logger.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      );

      final captured =
          verify(
                () => processor.processOrdered(captureAny<List<Event>>()),
              ).captured.single
              as List<Event>;
      expect(captured.any((e) => e.eventId == 'cached-new'), isTrue);
      verify(
        () => logger.captureEvent(
          any<Object>(
            that: contains('catchup.recovered via=timestampBoundary'),
          ),
          domain: syncLoggingDomain,
          subDomain: 'catchup',
        ),
      ).called(1);
      verify(
        () => logger.captureEvent(
          any<Object>(that: contains('catchup.initial.completed')),
          domain: syncLoggingDomain,
          subDomain: 'catchup',
        ),
      ).called(1);
    },
  );
}
