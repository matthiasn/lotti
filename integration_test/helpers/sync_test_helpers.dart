import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_repository.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:uuid/uuid.dart';

import 'toxiproxy_controller.dart';

const uuid = Uuid();

/// Wait until a condition is true, with timeout
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(minutes: 1),
  Duration pollInterval = const Duration(milliseconds: 100),
  String? message,
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException(
        message ?? 'Condition not met within ${timeout.inSeconds}s',
        timeout,
      );
    }
    await Future<void>.delayed(pollInterval);
  }
}

/// Wait until an async condition is true, with timeout
Future<void> waitUntilAsync(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(minutes: 1),
  Duration pollInterval = const Duration(milliseconds: 100),
  String? message,
}) async {
  final stopwatch = Stopwatch()..start();
  while (!await condition()) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException(
        message ?? 'Async condition not met within ${timeout.inSeconds}s',
        timeout,
      );
    }
    await Future<void>.delayed(pollInterval);
  }
}

/// Wait for a specified duration
Future<void> waitSeconds(int seconds) async {
  await Future<void>.delayed(Duration(seconds: seconds));
}

/// Wait for a specified duration in milliseconds
Future<void> waitMs(int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
}

/// Test configuration for Matrix
class TestConfig {
  const TestConfig._();

  static const testHomeServerNormal = 'http://localhost:8008';
  static const testHomeServerDegraded = 'http://localhost:18008';
  static const testPassword = '?Secret123@';

  static String get testHomeServer {
    const slowNetwork = bool.fromEnvironment('SLOW_NETWORK');
    return slowNetwork ? testHomeServerDegraded : testHomeServerNormal;
  }

  static MatrixConfig configForUser(String username) => MatrixConfig(
    homeServer: testHomeServer,
    user: username,
    password: testPassword,
  );
}

/// Create a test journal entry
JournalEntry createTestEntry({
  required String deviceName,
  required int index,
  required DateTime timestamp,
  String? id,
  String? text,
}) {
  final entryId = id ?? uuid.v1();

  return JournalEntry(
    meta: Metadata(
      id: entryId,
      createdAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      updatedAt: timestamp,
      starred: false,
      vectorClock: VectorClock({deviceName: index}),
    ),
    entryText: EntryText(
      plainText: text ?? 'Test from $deviceName #$index - $timestamp',
    ),
  );
}

/// Persists a fixture and sends it through the real outbox, including the
/// sequence binding peers need to request it after a network gap.
Future<JournalEntry> sendTestMessage({
  required SyncTestDevice device,
  required int index,
  String? text,
}) async {
  final entry = createTestEntry(
    deviceName: device.hostId,
    index: index + 1,
    timestamp: DateTime.utc(2024, 3, 15).add(Duration(seconds: index)),
    text: text,
  );
  await device.journalDb.updateJournalEntity(entry);
  await device.outbox.enqueueMessageOrThrow(
    SyncMessage.journalEntity(
      id: entry.meta.id,
      status: SyncEntryStatus.initial,
      vectorClock: entry.meta.vectorClock,
      jsonPath: relativeEntityPath(entry),
      originatingHostId: device.hostId,
    ),
  );
  // Sending must finish before the test advances to its next network phase.
  // This observer never nudges the runner or retries a failed row.
  await waitUntilAsync(() async {
    final pending = await device.syncDb.getOutboxItems(
      limit: 100,
      statuses: const [
        OutboxStatus.pending,
        OutboxStatus.sending,
        OutboxStatus.error,
      ],
    );
    if (pending.any((item) => item.status == OutboxStatus.error.index)) {
      throw StateError('Outbox failed to send fixture ${entry.meta.id}');
    }
    return pending.isEmpty;
  }, message: 'Outbox did not send fixture ${entry.meta.id}');
  return entry;
}

/// A simulated device's real transport, outbox and automatic gap recovery.
/// Database and Matrix-client lifetimes remain owned by the calling fixture.
class SyncTestDevice {
  SyncTestDevice({
    required this.matrixService,
    required this.outbox,
    required this.backfill,
    required this.journalDb,
    required this.syncDb,
    required this.hostId,
  });

  final MatrixService matrixService;
  final MatrixOutboxService outbox;
  final BackfillRequestService backfill;
  final JournalDb journalDb;
  final SyncDatabase syncDb;
  final String hostId;

  Future<void> dispose() async {
    backfill.dispose();
    try {
      await outbox.dispose();
    } finally {
      await matrixService.dispose();
    }
  }
}

/// Setup Toxiproxy for testing
Future<ToxiproxyController> setupToxiproxy() async {
  final controller = ToxiproxyController();
  await controller.setup();
  return controller;
}

/// Helper to run a block with network disconnected
Future<T> withNetworkDisconnected<T>(
  ToxiproxyController toxiproxy,
  Future<T> Function() block,
) async {
  await toxiproxy.disconnect(ToxiproxyController.dendriteProxy);
  try {
    return await block();
  } finally {
    await toxiproxy.reconnect(ToxiproxyController.dendriteProxy);
  }
}

/// Helper to run a block with degraded network
Future<T> withDegradedNetwork<T>(
  ToxiproxyController toxiproxy,
  Future<T> Function() block, {
  int latencyMs = 500,
  int? bandwidthKbps,
}) async {
  await toxiproxy.addLatency(
    ToxiproxyController.dendriteProxy,
    latencyMs: latencyMs,
  );
  if (bandwidthKbps != null) {
    await toxiproxy.limitBandwidth(
      ToxiproxyController.dendriteProxy,
      bytesPerSecond: bandwidthKbps * 1000,
    );
  }
  try {
    return await block();
  } finally {
    await toxiproxy.reset(ToxiproxyController.dendriteProxy);
  }
}

/// Log helper for tests
void testLog(String message) {
  debugPrint('[TEST] $message');
}

/// Verify environment is ready for tests
Future<bool> verifyTestEnvironment() async {
  try {
    // Check if Dendrite is reachable
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(
      Uri.parse('http://localhost:8008/_matrix/client/versions'),
    );
    final response = await request.close();
    await response.drain<void>();
    httpClient.close();

    if (response.statusCode != 200) {
      debugPrint('Dendrite not responding correctly');
      return false;
    }

    // Check if Toxiproxy is reachable
    final toxiproxy = ToxiproxyController();
    await toxiproxy.getProxies();
    toxiproxy.close();

    return true;
  } catch (e) {
    debugPrint('Environment check failed: $e');
    return false;
  }
}

/// Creates a device with the production queue, outbox and backfill services.
///
/// The Phase-2 `InboundQueue` pipeline is wired up alongside the
/// service — a dedicated SyncDatabase + SyncSequenceLogService +
/// MatrixSessionManager + SyncRoomManager are built here and the
/// coordinator is passed in as the only inbound path. The caller owns and
/// closes the supplied databases after disposing the service. Both the loader
/// and the ingestor resolve attachments in the supplied device directory.
Future<SyncTestDevice> createSyncTestDevice({
  required MatrixConfig config,
  required MatrixSyncGateway gateway,
  required DomainLogger loggingService,
  required JournalDb journalDb,
  required SettingsDb settingsDb,
  required SecureStorage secureStorage,
  required String deviceName,
  required UserActivityService activityService,
  required Directory documentsDirectory,
  required UpdateNotifications updateNotifications,
  required AiConfigRepository aiConfigRepository,
  required SentEventRegistry sentEventRegistry,
  required SyncDatabase syncDb,
  required VectorClockService vectorClockService,
  bool collectSyncMetrics = true,
  AttachmentIndex? attachmentIndex,
}) async {
  final activityGate = UserActivityGate(
    activityService: activityService,
  );
  final messageSender = MatrixMessageSender(
    loggingService: loggingService,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
    sentEventRegistry: sentEventRegistry,
    vectorClockService: vectorClockService,
  );

  // Share a single AttachmentIndex between MatrixService and the
  // queue coordinator so `pathRecorded` signals land on the same
  // subscription the coordinator listens to. Without a shared
  // instance, resurrection never fires in integration tests.
  final sharedAttachmentIndex =
      attachmentIndex ?? AttachmentIndex(logging: loggingService);
  // A dedicated ingestor for the queue pipeline so the integration
  // tests exercise the same attachment-processing hook production
  // runs on-device. `documentsDirectory` is the per-device scratch
  // dir provided by the caller; the ingestor downloads descriptors
  // into it before the companion sync events apply.
  final queueAttachmentIngestor = AttachmentIngestor(
    documentsDirectory: documentsDirectory,
    verboseLogging: false,
  );

  final sequenceLogService = SyncSequenceLogService(
    syncDatabase: syncDb,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
  );
  final eventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    updateNotifications: updateNotifications,
    aiConfigRepository: aiConfigRepository,
    settingsDb: settingsDb,
    journalEntityLoader: SmartJournalEntityLoader(
      attachmentIndex: sharedAttachmentIndex,
      loggingService: loggingService,
      documentsDirectory: documentsDirectory,
    ),
    documentsDirectory: documentsDirectory,
    attachmentIndex: sharedAttachmentIndex,
    sequenceLogService: sequenceLogService,
    journalDb: journalDb,
    vectorClockService: vectorClockService,
    savedTaskFiltersRepository: SavedTaskFiltersRepository(
      SavedTaskFiltersPersistence(settingsDb),
      updateNotifications,
    ),
  );

  final roomManager = SyncRoomManager(
    gateway: gateway,
    settingsDb: settingsDb,
    loggingService: loggingService,
  );
  final sessionManager =
      MatrixSessionManager(
          gateway: gateway,
          roomManager: roomManager,
          loggingService: loggingService,
        )
        ..matrixConfig = config
        ..deviceDisplayName = deviceName;
  final queueCoordinator = QueuePipelineCoordinator(
    syncDb: syncDb,
    settingsDb: settingsDb,
    journalDb: journalDb,
    sessionManager: sessionManager,
    roomManager: roomManager,
    eventProcessor: eventProcessor,
    sequenceLogService: sequenceLogService,
    activityGate: activityGate,
    logging: loggingService,
    attachmentIndex: sharedAttachmentIndex,
    updateNotifications: updateNotifications,
    attachmentIngestor: queueAttachmentIngestor,
  );

  final matrixService = MatrixService(
    matrixConfig: config,
    gateway: gateway,
    loggingService: loggingService,
    activityGate: activityGate,
    messageSender: messageSender,
    settingsDb: settingsDb,
    eventProcessor: eventProcessor,
    secureStorage: secureStorage,
    deviceDisplayName: deviceName,
    ownsActivityGate: true,
    collectSyncMetrics: collectSyncMetrics,
    roomManager: roomManager,
    sessionManager: sessionManager,
    queueCoordinator: queueCoordinator,
  );
  await journalDb.upsertConfigFlag(
    const ConfigFlag(
      name: enableMatrixFlag,
      description: 'Enable Matrix Sync',
      status: true,
    ),
  );
  final outbox = MatrixOutboxService(
    syncDatabase: syncDb,
    loggingService: loggingService,
    vectorClockService: vectorClockService,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
    userActivityService: activityService,
    matrixService: matrixService,
    connectivityStream: const Stream<List<ConnectivityResult>>.empty(),
    sequenceLogService: sequenceLogService,
    domainLogger: loggingService,
  );
  final backfill = BackfillRequestService(
    sequenceLogService: sequenceLogService,
    syncDatabase: syncDb,
    outboxService: outbox,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
    documentsDirectory: documentsDirectory,
    queueCoordinator: queueCoordinator,
    domainLogger: loggingService,
  );
  // Keep this wiring aligned with get_it_sync.dart: organic sequence gaps,
  // bridge completion and queue drain must wake the same recovery services.
  sequenceLogService.onMissingEntriesDetected = () {
    backfill.nudge();
    queueCoordinator.maybeStartGapRecovery();
  };
  queueCoordinator.onBridgeCompleted = backfill.nudge;
  eventProcessor.backfillResponseHandler = BackfillResponseHandler(
    journalDb: journalDb,
    sequenceLogService: sequenceLogService,
    outboxService: outbox,
    loggingService: loggingService,
    vectorClockService: vectorClockService,
    domainLogger: loggingService,
  );
  backfill.start();
  return SyncTestDevice(
    matrixService: matrixService,
    outbox: outbox,
    backfill: backfill,
    journalDb: journalDb,
    syncDb: syncDb,
    hostId: (await vectorClockService.getHost())!,
  );
}

/// Extract emoji string from key verification emojis
String extractEmojiString(Iterable<KeyVerificationEmoji>? emojis) {
  final buffer = StringBuffer();
  if (emojis != null) {
    for (final emoji in emojis) {
      buffer.write(' ${emoji.emoji}  ');
    }
  }
  return buffer.toString();
}
