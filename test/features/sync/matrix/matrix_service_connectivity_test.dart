import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockGateway extends Mock implements MatrixSyncGateway {}

class MockMessageSender extends Mock implements MatrixMessageSender {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockEventProcessor extends Mock implements SyncEventProcessor {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockRoomManager extends Mock implements SyncRoomManager {}

class MockSessionManager extends Mock implements MatrixSessionManager {}

class MockPipeline extends Mock implements MatrixStreamConsumer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixService connectivity coalescing', () {
    // Counter to track rescan calls across the test case
    var rescanCount = 0;
    late MockLoggingService logging;
    late MockGateway gateway;
    late MockMessageSender sender;
    late MockJournalDb journalDb;
    late MockSettingsDb settingsDb;
    late MockReadMarkerService readMarkerService;
    late MockEventProcessor eventProcessor;
    late MockSecureStorage storage;
    late MockRoomManager roomManager;
    late MockSessionManager sessionManager;
    late MockPipeline pipeline;
    late Directory tempDir;
    late StreamController<List<ConnectivityResult>> conn;

    setUp(() {
      logging = MockLoggingService();
      gateway = MockGateway();
      sender = MockMessageSender();
      journalDb = MockJournalDb();
      settingsDb = MockSettingsDb();
      readMarkerService = MockReadMarkerService();
      eventProcessor = MockEventProcessor();
      storage = MockSecureStorage();
      roomManager = MockRoomManager();
      sessionManager = MockSessionManager();
      pipeline = MockPipeline();
      tempDir = Directory.systemTemp.createTempSync('matrix_service_conn_');
      conn = StreamController<List<ConnectivityResult>>.broadcast();

      // Default no-op logging
      when(() => logging.captureEvent(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});
      when(() => logging.captureException(any<Object>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
              stackTrace: any<StackTrace?>(named: 'stackTrace')))
          .thenAnswer((_) async {});

      // Pipeline methods used by connectivity flow
      when(() => pipeline.recordConnectivitySignal()).thenAnswer((_) {});
      // Reset counter; track calls for precise assertions without relying solely on verify
      when(() => pipeline.forceRescan(
              includeCatchUp: any<bool>(named: 'includeCatchUp')))
          .thenAnswer((_) async {
        rescanCount++;
      });

      // Stubs for disposals invoked by MatrixService.dispose()
      when(() => sessionManager.dispose()).thenAnswer((_) async {});
      when(() => roomManager.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      await conn.close();
    });

    test('multiple connectivity regains coalesce into one rescan per window',
        () async {
      fakeAsync((async) {
        final service = MatrixService(
          gateway: gateway,
          loggingService: logging,
          activityGate:
              UserActivityGate(activityService: UserActivityService()),
          messageSender: sender,
          journalDb: journalDb,
          settingsDb: settingsDb,
          readMarkerService: readMarkerService,
          eventProcessor: eventProcessor,
          secureStorage: storage,
          sentEventRegistry: SentEventRegistry(),
          roomManager: roomManager,
          sessionManager: sessionManager,
          pipelineOverride: pipeline,
          connectivityStream: conn.stream,
        );

        // Fire a burst of connectivity events.
        conn
          ..add([ConnectivityResult.wifi])
          ..add([ConnectivityResult.wifi])
          ..add([ConnectivityResult.wifi]);
        async.elapse(const Duration(milliseconds: 50));

        // One rescan in-flight — others coalesced.
        expect(rescanCount, 1);

        // Another burst still within coalescing window.
        conn
          ..add([ConnectivityResult.mobile])
          ..add([ConnectivityResult.ethernet]);
        async.elapse(const Duration(milliseconds: 50));

        // Still only one rescan so far.
        expect(rescanCount, 1);

        // After the min gap (~2s), a new event should trigger another rescan.
        async.elapse(const Duration(seconds: 2));
        conn.add([ConnectivityResult.wifi]);
        async.elapse(const Duration(milliseconds: 50));

        // With coalescing, two connectivity-driven rescans are expected here
        expect(rescanCount, 2);

        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });
  });
}
