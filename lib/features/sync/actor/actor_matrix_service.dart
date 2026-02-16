import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/actor/sync_actor.dart';
import 'package:lotti/features/sync/actor/sync_actor_host.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// MatrixService wrapper that wires the sync actor isolate as a send path
/// for outbound sync messages.
///
/// The actor is the primary outbound transport path for sync messages.
class ActorMatrixService extends MatrixService {
  ActorMatrixService({
    required MatrixSyncGateway gateway,
    required LoggingService loggingService,
    required UserActivityGate activityGate,
    required MatrixMessageSender messageSender,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncReadMarkerService readMarkerService,
    required SyncEventProcessor eventProcessor,
    required SecureStorage secureStorage,
    required AttachmentIndex attachmentIndex,
    required Directory actorDatabaseDirectory,
    SentEventRegistry? sentEventRegistry,
    bool collectSyncMetrics = false,
    bool ownsActivityGate = false,
    MatrixConfig? matrixConfig,
    String? deviceDisplayName,
    SyncRoomManager? roomManager,
    MatrixSessionManager? sessionManager,
    SyncLifecycleCoordinator? lifecycleCoordinator,
    SyncEngine? syncEngine,
    Stream<List<ConnectivityResult>>? connectivityStream,
    bool runStartupRescan = true,
    bool listenConnectivityChanges = true,
  })  : _actorDatabaseDirectory = actorDatabaseDirectory,
        _actorDeviceDisplayName = deviceDisplayName,
        _loggingService = loggingService,
        super(
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
          collectSyncMetrics: collectSyncMetrics,
          ownsActivityGate: ownsActivityGate,
          matrixConfig: matrixConfig,
          deviceDisplayName: deviceDisplayName,
          roomManager: roomManager,
          sessionManager: sessionManager,
          lifecycleCoordinator: lifecycleCoordinator,
          syncEngine: syncEngine,
          connectivityStream: connectivityStream,
          runStartupRescan: runStartupRescan,
          listenConnectivityChanges: listenConnectivityChanges,
        );

  final Directory _actorDatabaseDirectory;
  final String? _actorDeviceDisplayName;
  final LoggingService _loggingService;
  static const Duration _actorInitTimeout = Duration(minutes: 2);

  SyncActorHost? _actorHost;
  Future<bool>? _actorInitInProgress;
  String? _actorDeviceId;

  @override
  List<DeviceKeys> getUnverifiedDevices() {
    final devices = super.getUnverifiedDevices();
    return devices
        .where((device) => !_isActorDevice(device))
        .toList(growable: false);
  }

  @override
  Future<void> init() async {
    await super.init();
    await _initializeSyncActor();
    await _synchronizeActorRoomState();
  }

  @override
  Future<bool> login({bool waitForLifecycle = true}) async {
    final loggedIn = await super.login(waitForLifecycle: waitForLifecycle);
    if (loggedIn) {
      await _initializeSyncActor();
      await _synchronizeActorRoomState();
    }
    return loggedIn;
  }

  @override
  Future<bool> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) async {
    final sentViaActor = await _sendViaActor(
      syncMessage,
      myRoomId: myRoomId,
    );
    if (sentViaActor) {
      return true;
    }

    return false;
  }

  @override
  Future<void> saveRoom(String roomId) async {
    await super.saveRoom(roomId);
    await _joinActorRoom(roomId);
  }

  @override
  Future<String?> joinRoom(String roomId) async {
    final joinedRoomId = await super.joinRoom(roomId);
    await _joinActorRoom(joinedRoomId ?? roomId);
    return joinedRoomId;
  }

  @override
  Future<String> createRoom({List<String>? invite}) async {
    final roomId = await super.createRoom(invite: invite);
    await _joinActorRoom(roomId);
    return roomId;
  }

  @override
  Future<void> dispose() async {
    await _disposeActorHost();
    await super.dispose();
  }

  Future<bool> _sendViaActor(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) async {
    if (getUnverifiedDevices().isNotEmpty) {
      return false;
    }

    if (!await _initializeSyncActor()) {
      return false;
    }

    final actorHost = _actorHost;
    if (actorHost == null) {
      return false;
    }

    final targetRoomId = myRoomId ?? syncRoomId;
    if (targetRoomId == null) {
      return false;
    }
    var room = client.getRoomById(targetRoomId);
    if (room == null) {
      await _joinActorRoom(targetRoomId);
      room = client.getRoomById(targetRoomId);
    }
    if (room == null) {
      return false;
    }

    final outboundMessage = await messageSender.prepareSyncMessageForSend(
      message: syncMessage,
      room: room,
    );
    if (outboundMessage == null) {
      return false;
    }

    final encodedMessage = base64.encode(
      utf8.encode(
        json.encode(outboundMessage.toJson()),
      ),
    );

    try {
      final response = await actorHost.send(
        'sendText',
        payload: <String, Object?>{
          'roomId': targetRoomId,
          'message': encodedMessage,
          'messageType': syncMessageType,
        },
      );
      if (response['ok'] == true) {
        _recordSentType(syncMessage);
        final eventId = response['eventId'];
        if (eventId is String && eventId.isNotEmpty) {
          registerSentEvent(eventId: eventId);
        }
        return true;
      }
      await _invalidateActorHostIfNotHealthy(
        actorHost,
        response['errorCode'],
      );
      return false;
    } catch (error, stackTrace) {
      await _invalidateActorHostIfNotHealthy(actorHost, 'HOST_DISPOSED');
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'actor.sendMatrixMsg',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _initializeSyncActor() async {
    if (_actorHost != null) {
      return true;
    }

    final initInProgress = _actorInitInProgress;
    if (initInProgress != null) {
      await initInProgress;
      return _actorHost != null;
    }

    final matrixConfiguration = matrixConfig;
    if (matrixConfiguration == null || matrixConfiguration.password.isEmpty) {
      return false;
    }

    _actorInitInProgress = _startSyncActor(matrixConfiguration);
    try {
      await _actorInitInProgress;
      return _actorHost != null;
    } finally {
      _actorInitInProgress = null;
    }
  }

  Future<bool> _startSyncActor(MatrixConfig matrixConfiguration) async {
    _actorDeviceId = null;
    SyncActorHost? host;
    try {
      host = await SyncActorHost.spawn(
        entrypoint: (readyPort) => syncActorEntrypoint(
          readyPort,
          processTimelineEvents: false,
        ),
      );

      final initResponse = await host.send('init', payload: <String, Object?>{
        'homeServer': matrixConfiguration.homeServer,
        'user': matrixConfiguration.user,
        'password': matrixConfiguration.password,
        'dbRootPath': _actorDatabaseDirectory.path,
        'deviceDisplayName': _actorDeviceDisplayName ?? 'LottiSyncActor',
        'eventPort': host.eventSendPort,
      }, timeout: _actorInitTimeout);

      if (initResponse['ok'] != true) {
        _loggingService.captureEvent(
          'Sync actor init failed: ${initResponse['error']}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'actor.init',
        );
        await host.dispose();
        return false;
      }

      final initActorDeviceId = initResponse['deviceId'];
      if (initActorDeviceId is String && initActorDeviceId.isNotEmpty) {
        _actorDeviceId = initActorDeviceId;
      } else {
        _actorDeviceId = null;
      }

      _actorHost = host;
      return true;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'actor.init',
        stackTrace: stackTrace,
      );
      await host?.dispose();
      _actorHost = null;
      return false;
    }
  }

  Future<void> _joinActorRoom(String roomId) async {
    final room = roomId.trim();
    if (room.isEmpty) {
      return;
    }

    if (!await _initializeSyncActor()) {
      return;
    }
    final actorHost = _actorHost;
    if (actorHost == null) {
      return;
    }

    try {
      final joinResult =
          await actorHost.send('joinRoom', payload: <String, Object?>{
        'roomId': room,
      });

      if (joinResult['ok'] != true) {
        await _invalidateActorHostIfNotHealthy(
          actorHost,
          joinResult['errorCode'],
        );
        _loggingService.captureEvent(
          'actor joinRoom failed for $room: ${joinResult['error']}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'actor.joinRoom',
        );
      }
    } catch (error, stackTrace) {
      await _invalidateActorHostIfNotHealthy(actorHost, 'HOST_DISPOSED');
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        stackTrace: stackTrace,
        subDomain: 'actor.joinRoom',
      );
    }
  }

  Future<void> _synchronizeActorRoomState() async {
    final roomId = await getRoom();
    if (roomId == null || roomId.isEmpty) {
      return;
    }
    await _joinActorRoom(roomId);
  }

  void _recordSentType(SyncMessage syncMessage) {
    final sentType = syncMessage.map(
      journalEntity: (_) => 'journalEntity',
      entityDefinition: (_) => 'entityDefinition',
      tagEntity: (_) => 'tagEntity',
      entryLink: (_) => 'entryLink',
      aiConfig: (_) => 'aiConfig',
      aiConfigDelete: (_) => 'aiConfigDelete',
      themingSelection: (_) => 'themingSelection',
      backfillRequest: (_) => 'backfillRequest',
      backfillResponse: (_) => 'backfillResponse',
    );
    incrementSentCountOf(sentType);
  }

  Future<void> _invalidateActorHostIfNotHealthy(
    SyncActorHost actorHost,
    Object? errorCode,
  ) async {
    if (errorCode == 'HOST_DISPOSED' &&
        identical(actorHost, _actorHost)) {
      await _disposeActorHost();
    }
  }

  Future<void> _disposeActorHost() async {
    final host = _actorHost;
    _actorHost = null;
    _actorInitInProgress = null;
    _actorDeviceId = null;
    await host?.dispose();
  }

  bool _isActorDevice(DeviceKeys device) {
    final actorDeviceId = _actorDeviceId;
    final currentDeviceId = client.deviceID;
    if (device.userId != client.userID) {
      return false;
    }

    if (currentDeviceId != null &&
        currentDeviceId.isNotEmpty &&
        device.deviceId != null &&
        device.deviceId == currentDeviceId) {
      return true;
    }

    if (actorDeviceId != null &&
        actorDeviceId.isNotEmpty &&
        device.deviceId != null &&
        device.deviceId == actorDeviceId) {
      return true;
    }

    final actorDeviceDisplayName =
        (_actorDeviceDisplayName?.trim().isNotEmpty == true
                ? _actorDeviceDisplayName
                : 'LottiSyncActor')
            ?.trim()
            .toLowerCase();
    final deviceDisplayName = device.deviceDisplayName?.trim().toLowerCase();
    if (actorDeviceDisplayName != null &&
        actorDeviceDisplayName.isNotEmpty &&
        deviceDisplayName != null &&
        actorDeviceDisplayName == deviceDisplayName) {
      return true;
    }

    return false;
  }
}
