import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class _MockGateway extends Mock implements MatrixSyncGateway {}

class _MockMessageSender extends Mock implements MatrixMessageSender {}

class _MockJournalDb extends Mock implements JournalDb {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockReadMarkerService extends Mock implements SyncReadMarkerService {}

class _MockEventProcessor extends Mock implements SyncEventProcessor {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockAttachmentIndex extends Mock implements AttachmentIndex {}

class _MockActivityGate extends Mock implements UserActivityGate {}

class _MockClient extends Mock implements Client {}

class _MockSentEventRegistry extends Mock implements SentEventRegistry {}

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockPipeline extends Mock implements MatrixStreamConsumer {}

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockCoordinator extends Mock implements SyncLifecycleCoordinator {}

void main() {
  late _MockGateway gateway;
  late LoggingService loggingService;
  late _MockActivityGate activityGate;
  late _MockMessageSender messageSender;
  late _MockJournalDb journalDb;
  late _MockSettingsDb settingsDb;
  late _MockReadMarkerService readMarkerService;
  late _MockEventProcessor eventProcessor;
  late _MockSecureStorage secureStorage;
  late _MockAttachmentIndex attachmentIndex;
  late _MockClient client;
  late _MockSentEventRegistry sentEventRegistry;
  late _MockSessionManager sessionManager;
  late _MockRoomManager roomManager;
  late _MockPipeline pipeline;
  late _MockSyncEngine syncEngine;
  late _MockCoordinator coordinator;

  setUpAll(() {
    registerFallbackValue(
      SyncApplyDiagnostics(
        eventId: 'fallback',
        payloadType: 'fallback',
        vectorClock: null,
        conflictStatus: 'fallback',
        applied: false,
      ),
    );
  });

  setUp(() {
    gateway = _MockGateway();
    loggingService = LoggingService();
    activityGate = _MockActivityGate();
    messageSender = _MockMessageSender();
    journalDb = _MockJournalDb();
    settingsDb = _MockSettingsDb();
    readMarkerService = _MockReadMarkerService();
    eventProcessor = _MockEventProcessor();
    secureStorage = _MockSecureStorage();
    attachmentIndex = _MockAttachmentIndex();
    client = _MockClient();
    sentEventRegistry = _MockSentEventRegistry();
    sessionManager = _MockSessionManager();
    roomManager = _MockRoomManager();
    pipeline = _MockPipeline();
    syncEngine = _MockSyncEngine();
    coordinator = _MockCoordinator();

    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.matrixConfig).thenReturn(null);
    when(() => messageSender.sentEventRegistry).thenReturn(sentEventRegistry);
    when(() => roomManager.currentRoomId).thenReturn(null);
    when(() => roomManager.currentRoom).thenReturn(null);
    when(
      () => roomManager.inviteRequests,
    ).thenAnswer((_) => const Stream.empty());
    when(() => syncEngine.lifecycleCoordinator).thenReturn(coordinator);
    when(() => gateway.unverifiedDevices()).thenReturn([]);
  });

  /// Creates a service with a provided syncEngine (no pipeline).
  MatrixService createService() {
    return MatrixService(
      gateway: gateway,
      loggingService: loggingService,
      activityGate: activityGate,
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      attachmentIndex: attachmentIndex,
      sentEventRegistry: sentEventRegistry,
      sessionManager: sessionManager,
      roomManager: roomManager,
      syncEngine: syncEngine,
      connectivityStream: const Stream.empty(),
    );
  }

  /// Creates a service with a pipeline override (no syncEngine).
  MatrixService createServiceWithPipeline() {
    when(
      () => pipeline.reportDbApplyDiagnostics(any()),
    ).thenReturn(null);
    when(
      () => pipeline.forceRescan(includeCatchUp: any(named: 'includeCatchUp')),
    ).thenAnswer((_) async {});
    return MatrixService(
      gateway: gateway,
      loggingService: loggingService,
      activityGate: activityGate,
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      attachmentIndex: attachmentIndex,
      sentEventRegistry: sentEventRegistry,
      sessionManager: sessionManager,
      roomManager: roomManager,
      pipelineOverride: pipeline,
      connectivityStream: const Stream.empty(),
    );
  }

  group('MatrixService', () {
    test('can be constructed', () {
      final service = createService();

      expect(service, isNotNull);
    });

    test('client getter returns session manager client', () {
      final service = createService();

      expect(service.client, client);
    });

    test('syncRoomId returns room manager currentRoomId', () {
      when(() => roomManager.currentRoomId).thenReturn('!room:s');

      final service = createService();

      expect(service.syncRoomId, '!room:s');
    });

    test('isLoggedIn delegates to session manager', () {
      when(() => sessionManager.isLoggedIn()).thenReturn(true);

      // Need to use the sessionManager from the existing service for this test
      // but MatrixService creates its own sessionManager if not provided
      final service = createService();

      // Cannot easily test isLoggedIn because it goes through _sessionManager
      // which is the one we injected
      expect(service.isLoggedIn(), isTrue);
    });

    test('getUnverifiedDevices delegates to gateway', () {
      final service = createService();

      final devices = service.getUnverifiedDevices();

      expect(devices, isEmpty);
      verify(() => gateway.unverifiedDevices()).called(1);
    });

    test('incrementSentCountOf updates messageCounts', () {
      final service = createService()
        ..incrementSentCountOf('journalEntity')
        ..incrementSentCountOf('journalEntity')
        ..incrementSentCountOf('entryLink');

      expect(service.sentCount, 3);
      expect(service.messageCounts['journalEntity'], 2);
      expect(service.messageCounts['entryLink'], 1);
    });

    test('messageCountsController emits stats', () async {
      final service = createService();

      final future = service.messageCountsController.stream.first;

      service.incrementSentCountOf('test');

      final stats = await future;

      expect(stats, isA<MatrixStats>());
      expect(stats.sentCount, 1);
      expect(stats.messageCounts['test'], 1);
    });

    test('forceRescan delegates to pipeline', () async {
      when(
        () =>
            pipeline.forceRescan(includeCatchUp: any(named: 'includeCatchUp')),
      ).thenAnswer((_) async {});

      final service = createServiceWithPipeline();

      await service.forceRescan();

      // The pipeline.forceRescan is called twice: once from the startup
      // unawaited call and once from the explicit forceRescan.
      verify(
        () =>
            pipeline.forceRescan(includeCatchUp: any(named: 'includeCatchUp')),
      ).called(greaterThanOrEqualTo(1));
    });

    test('retryNow delegates to pipeline', () async {
      when(() => pipeline.retryNow()).thenAnswer((_) async {});

      final service = createServiceWithPipeline();

      await service.retryNow();

      verify(() => pipeline.retryNow()).called(1);
    });

    test('getSyncMetrics returns null when metrics disabled', () async {
      final service = createService();

      final metrics = await service.getSyncMetrics();

      expect(metrics, isNull);
    });

    test('dispose closes all controllers', () async {
      when(() => syncEngine.dispose()).thenAnswer((_) async {});
      when(() => sessionManager.dispose()).thenAnswer((_) async {});
      when(() => roomManager.dispose()).thenAnswer((_) async {});

      final service = createService();

      await service.dispose();

      verify(() => syncEngine.dispose()).called(1);
      verify(() => sessionManager.dispose()).called(1);
      verify(() => roomManager.dispose()).called(1);
    });

    test('joinRoom delegates to room manager', () async {
      when(
        () => roomManager.joinRoom(any()),
      ).thenAnswer((_) async => null);

      final service = createService();
      final result = await service.joinRoom('!room:server');

      expect(result, '!room:server');
      verify(() => roomManager.joinRoom('!room:server')).called(1);
    });

    test('createRoom delegates to room manager', () async {
      when(
        () =>
            roomManager.createRoom(inviteUserIds: any(named: 'inviteUserIds')),
      ).thenAnswer((_) async => '!new:room');

      final service = createService();
      final result = await service.createRoom();

      expect(result, '!new:room');
    });

    test('getRoom delegates to room manager', () async {
      when(
        () => roomManager.loadPersistedRoomId(),
      ).thenAnswer((_) async => '!stored:room');

      final service = createService();
      final result = await service.getRoom();

      expect(result, '!stored:room');
    });

    test('leaveRoom delegates to room manager', () async {
      when(
        () => roomManager.leaveCurrentRoom(),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.leaveRoom();

      verify(() => roomManager.leaveCurrentRoom()).called(1);
    });

    test('clearPersistedRoom delegates to room manager', () async {
      when(
        () => roomManager.clearPersistedRoom(),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.clearPersistedRoom();

      verify(() => roomManager.clearPersistedRoom()).called(1);
    });

    test('inviteToSyncRoom delegates to room manager', () async {
      when(
        () => roomManager.inviteUser(any()),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.inviteToSyncRoom(userId: '@bob:server');

      verify(() => roomManager.inviteUser('@bob:server')).called(1);
    });

    test('logout delegates to sync engine', () async {
      when(() => syncEngine.logout()).thenAnswer((_) async {});

      final service = createService();
      await service.logout();

      verify(() => syncEngine.logout()).called(1);
    });

    test('debugPipeline returns pipeline override', () {
      final service = createServiceWithPipeline();

      expect(service.debugPipeline, pipeline);
    });
  });
}
