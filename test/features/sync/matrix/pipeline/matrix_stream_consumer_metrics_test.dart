import 'package:flutter_test/flutter_test.dart';
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
import 'package:mocktail/mocktail.dart';

// Minimal mocks for constructor deps; tests do not exercise these.
class MockSessionManager extends Mock implements MatrixSessionManager {}

class MockRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockEventProcessor extends Mock implements SyncEventProcessor {}

class MockReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSentEventRegistry extends Mock implements SentEventRegistry {}

void main() {
  setUpAll(() {
    // Some tests and verifications use StackTrace matchers in this suite.
    registerFallbackValue(StackTrace.empty);
  });

  MatrixStreamConsumer buildConsumer({required MetricsCounters metrics}) {
    return MatrixStreamConsumer(
      sessionManager: MockSessionManager(),
      roomManager: MockRoomManager(),
      loggingService: MockLoggingService(),
      journalDb: MockJournalDb(),
      settingsDb: MockSettingsDb(),
      eventProcessor: MockEventProcessor(),
      readMarkerService: MockReadMarkerService(),
      sentEventRegistry: MockSentEventRegistry(),
      collectMetrics: true,
      metricsCounters: metrics,
    );
  }

  test('metricsSnapshot exposes processedPerAppliedPct when both > 0', () {
    final metrics = MetricsCounters(collect: true)
      ..incDbApplied()
      ..incDbApplied()
      ..incProcessed()
      ..incProcessed()
      ..incProcessed();

    final consumer = buildConsumer(metrics: metrics);

    final snap = consumer.metricsSnapshot();
    expect(snap['dbApplied'], 2);
    expect(snap['processed'], 3);
    // 3/2 => 1.5 => 150%
    expect(snap['processedPerAppliedPct'], 150);
  });

  test('recordConnectivitySignal increments signalConnectivity metric', () {
    final metrics = MetricsCounters(collect: true);
    final snap = (buildConsumer(metrics: metrics)
          ..recordConnectivitySignal())
        .metricsSnapshot();
    expect(snap['signalConnectivity'], 1);
  });
}
