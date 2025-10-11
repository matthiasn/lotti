// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockMatrixTimelineListener extends Mock
    implements MatrixTimelineListener {}

class MockLoggingService extends Mock implements LoggingService {}

class MockClient extends Mock implements Client {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockSyncLifecycleCoordinator extends Mock
    implements SyncLifecycleCoordinator {}

class MockMatrixMessageSender extends Mock implements MatrixMessageSender {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  MatrixService makeService({required bool enableV2}) {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final messageSender = MockMatrixMessageSender();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();

    when(() => sessionManager.client).thenReturn(client);
    // No need to stub onLoginStateChanged for these tests.
    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => lifecycleCoordinator.isActive).thenReturn(false);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    return MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: enableV2,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
    );
  }

  test('getV2Metrics returns null when V2 disabled', () async {
    final service = makeService(enableV2: false);
    final metrics = await service.getV2Metrics();
    expect(metrics, isNull);
  });

  test('getV2Metrics returns metrics when V2 enabled', () async {
    final service = makeService(enableV2: true);
    final metrics = await service.getV2Metrics();
    expect(metrics, isA<V2Metrics>());
    // Expect default zeros from fresh pipeline map
    expect(metrics?.processed, greaterThanOrEqualTo(0));
  });

  test('getDiagnosticInfo does not include v2Metrics (typed-only)', () async {
    final service = makeService(enableV2: true);
    final info = await service.getDiagnosticInfo();
    expect(info.containsKey('v2Metrics'), isFalse);
  });
}

class TestUserActivityService extends UserActivityService {}

class TestUserActivityGate extends UserActivityGate {
  TestUserActivityGate(UserActivityService service)
      : super(activityService: service, idleThreshold: Duration.zero);
}
