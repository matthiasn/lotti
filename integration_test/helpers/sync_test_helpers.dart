import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
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
  String? id,
  DateTime? timestamp,
  String? text,
}) {
  final entryId = id ?? uuid.v1();
  final now = timestamp ?? DateTime.now();

  return JournalEntry(
    meta: Metadata(
      id: entryId,
      createdAt: now,
      dateFrom: now,
      dateTo: now,
      updatedAt: now,
      starred: false,
      vectorClock: VectorClock({deviceName: index}),
    ),
    entryText: EntryText(
      plainText: text ?? 'Test from $deviceName #$index - $now',
    ),
  );
}

/// Create and send a test message
Future<void> sendTestMessage({
  required MatrixService matrixService,
  required String deviceName,
  required int index,
  required String roomId,
  String? text,
}) async {
  final entry = createTestEntry(
    deviceName: deviceName,
    index: index,
    text: text,
  );

  final jsonPath = relativeEntityPath(entry);
  await saveJournalEntityJson(entry);

  await matrixService.sendMatrixMsg(
    SyncMessage.journalEntity(
      id: entry.meta.id,
      status: SyncEntryStatus.initial,
      vectorClock: entry.meta.vectorClock ?? const VectorClock({}),
      jsonPath: jsonPath,
    ),
    myRoomId: roomId,
  );
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
    final request = await httpClient
        .getUrl(Uri.parse('http://localhost:8008/_matrix/client/versions'));
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

/// Create a MatrixService instance for testing
MatrixService createMatrixService({
  required MatrixConfig config,
  required MatrixSyncGateway gateway,
  required LoggingService loggingService,
  required JournalDb journalDb,
  required SettingsDb settingsDb,
  required SecureStorage secureStorage,
  required String deviceName,
  required UserActivityService activityService,
  required Directory documentsDirectory,
  required UpdateNotifications updateNotifications,
  required AiConfigRepository aiConfigRepository,
  required SentEventRegistry sentEventRegistry,
  bool collectSyncMetrics = true,
}) {
  final activityGate = UserActivityGate(
    activityService: activityService,
  );
  final messageSender = MatrixMessageSender(
    loggingService: loggingService,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
    sentEventRegistry: sentEventRegistry,
  );
  final readMarkerService = SyncReadMarkerService(
    settingsDb: settingsDb,
    loggingService: loggingService,
  );
  final eventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    updateNotifications: updateNotifications,
    aiConfigRepository: aiConfigRepository,
    settingsDb: settingsDb,
  );

  return MatrixService(
    matrixConfig: config,
    gateway: gateway,
    loggingService: loggingService,
    activityGate: activityGate,
    messageSender: messageSender,
    journalDb: journalDb,
    settingsDb: settingsDb,
    readMarkerService: readMarkerService,
    eventProcessor: eventProcessor,
    secureStorage: secureStorage,
    deviceDisplayName: deviceName,
    ownsActivityGate: true,
    attachmentIndex: AttachmentIndex(logging: loggingService),
    sentEventRegistry: sentEventRegistry,
    collectSyncMetrics: collectSyncMetrics,
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
