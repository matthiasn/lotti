import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

class _FakeClient extends Fake implements Client {}

class _FakeRoom extends Fake implements Room {}

class _FakeTimeline extends Fake implements Timeline {}

class _FakeEvent extends Fake implements Event {}

class ThrowingMetricsCounters extends MetricsCounters {
  ThrowingMetricsCounters() : super(collect: true);

  @override
  void incDbIgnoredByVectorClock() {
    throw StateError('metrics failure');
  }
}

void registerMatrixStreamConsumerFallbacks() {
  registerFallbackValue(StackTrace.empty);
  // Fallbacks for typed `any<T>` matchers used in mocks.
  registerFallbackValue(_FakeClient());
  registerFallbackValue(_FakeRoom());
  registerFallbackValue(_FakeTimeline());
  registerFallbackValue(_FakeEvent());
}

({MatrixStreamConsumer consumer, MockLoggingService logger}) buildConsumer({
  MetricsCounters? metrics,
  SentEventRegistry? sentEventRegistry,
}) {
  final session = MockMatrixSessionManager();
  final roomManager = MockSyncRoomManager();
  final logger = MockLoggingService();
  final journalDb = MockJournalDb();
  final settingsDb = MockSettingsDb();
  final processor = MockSyncEventProcessor();
  final readMarker = MockSyncReadMarkerService();
  final registry = sentEventRegistry ?? SentEventRegistry();

  when(() => processor.cachePurgeListener = any()).thenAnswer((_) => null);
  when(
    () => logger.captureEvent(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
    ),
  ).thenAnswer((_) {});
  when(
    () => logger.captureException(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
    ),
  ).thenAnswer((_) {});

  final consumer = MatrixStreamConsumer(
    skipSyncWait: true,
    sessionManager: session,
    roomManager: roomManager,
    loggingService: logger,
    journalDb: journalDb,
    settingsDb: settingsDb,
    eventProcessor: processor,
    readMarkerService: readMarker,
    collectMetrics: true,
    metricsCounters: metrics,
    sentEventRegistry: registry,
  );

  return (consumer: consumer, logger: logger);
}
