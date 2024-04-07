import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/inbox/save_attachments.dart';
import 'package:lotti/sync/matrix/client.dart';
import 'package:lotti/sync/matrix/config.dart';
import 'package:lotti/sync/matrix/consts.dart';
import 'package:lotti/sync/matrix/key_verification_runner.dart';
import 'package:lotti/sync/matrix/process_message.dart';
import 'package:lotti/sync/matrix/room.dart';
import 'package:lotti/sync/matrix/send_message.dart';
import 'package:lotti/sync/matrix/stats.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixService {
  MatrixService({
    this.matrixConfig,
    this.deviceDisplayName,
    String? hiveDbName,
  }) : keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast() {
    _client = createMatrixClient(hiveDbName: hiveDbName);
    incomingKeyVerificationRunnerController =
        StreamController<KeyVerificationRunner>.broadcast(
      onListen: publishIncomingRunnerState,
    );

    keyVerificationStream = keyVerificationController.stream;
    incomingKeyVerificationRunnerStream =
        incomingKeyVerificationRunnerController.stream;
  }

  void publishIncomingRunnerState() {
    incomingKeyVerificationRunner?.publishState();
  }

  final String? deviceDisplayName;
  late final Client _client;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  MatrixConfig? matrixConfig;
  LoginResponse? loginResponse;
  String? syncRoomId;
  Room? syncRoom;

  final Map<String, int> messageCounts = {};
  int sentCount = 0;

  final StreamController<MatrixStats> messageCountsController =
      StreamController<MatrixStats>.broadcast();
  KeyVerificationRunner? keyVerificationRunner;
  KeyVerificationRunner? incomingKeyVerificationRunner;
  final StreamController<KeyVerificationRunner> keyVerificationController;
  late final StreamController<KeyVerificationRunner>
      incomingKeyVerificationRunnerController;
  late final Stream<KeyVerificationRunner> keyVerificationStream;
  late final Stream<KeyVerificationRunner> incomingKeyVerificationRunnerStream;

  final incomingKeyVerificationController =
      StreamController<KeyVerification>.broadcast();

  Future<void> loginAndListen() async {
    await loadConfig();
    await login();
    await listen();
  }

  Client get client => _client;
  Future<void> login() => matrixLogin(service: this);
  Future<String?> joinRoom(String roomId) =>
      joinMatrixRoom(roomId: roomId, service: this);

  bool isLoggedIn() {
    // TODO(unassigned): find non-deprecated solution
    // ignore: deprecated_member_use
    return _client.loginState == LoginState.loggedIn;
  }

  Future<List<Event>?> getTimelineEvents() async {
    final timeline = await syncRoom?.getTimeline();
    return timeline?.events;
  }

  Future<String> createRoom() => createMatrixRoom(client: _client);

  List<DeviceKeys> getUnverified() => _client.unverifiedDevices;

  Future<void> verifyDevice(DeviceKeys deviceKeys) => verifyMatrixDevice(
        deviceKeys: deviceKeys,
        service: this,
      );

  Future<void> deleteDevice(DeviceKeys deviceKeys) async {
    final deviceId = deviceKeys.deviceId;
    if (deviceId != null) {
      await _client.deleteDevice(deviceId, auth: AuthenticationData());
    }
  }

  String? get deviceId => _client.deviceID;
  String? get deviceName => _client.deviceName;

  Stream<KeyVerification> getIncomingKeyVerificationStream() {
    return incomingKeyVerificationController.stream;
  }

  Future<void> startKeyVerificationListener() async =>
      listenForKeyVerificationRequests(service: this);

  Future<void> listen() async {
    try {
      _client.onLoginStateChanged.stream.listen((LoginState loginState) {
        debugPrint('LoginState: $loginState');
      });

      if (syncRoomId == null) {
        _loggingDb.captureEvent(
          configNotFound,
          domain: 'MATRIX_SERVICE',
          subDomain: 'listen',
        );
        return;
      }

      _client.onRoomState.stream.listen(
        (Event eventUpdate) async {
          try {
            debugPrint('>>> onRoomState ${eventUpdate.messageType} '
                '${eventUpdate.plaintextBody} '
                '${eventUpdate.text} '
                '${jsonEncode(eventUpdate.toJson())} ');

            final eventType = eventUpdate.type;
            messageCounts.update(
              eventType,
              (value) => value + 1,
              ifAbsent: () => 1,
            );

            messageCountsController.add(
              MatrixStats(
                messageCounts: messageCounts,
                sentCount: sentCount,
              ),
            );

            final attachmentMimetype = eventUpdate.attachmentMimetype;

            _loggingDb.captureEvent(
              'received ${eventUpdate.messageType}',
              domain: 'MATRIX_SERVICE',
              subDomain: 'listen',
            );

            if (attachmentMimetype.isNotEmpty) {
              final relativePath = eventUpdate.content['relativePath'];

              if (relativePath != null) {
                _loggingDb.captureEvent(
                  'downloading $relativePath',
                  domain: 'MATRIX_SERVICE',
                  subDomain: 'writeToFile',
                );

                final matrixFile =
                    await eventUpdate.downloadAndDecryptAttachment();
                final docDir = getDocumentsDirectory();
                await writeToFile(
                  matrixFile.bytes,
                  '${docDir.path}$relativePath',
                );
              } else {
                _loggingDb.captureEvent(
                  'missing relativePath',
                  domain: 'MATRIX_SERVICE',
                  subDomain: 'writeToFile',
                );
              }
            } else {
              await processMatrixMessage(eventUpdate.plaintextBody);
            }
          } catch (exception, stackTrace) {
            _loggingDb.captureException(
              exception,
              domain: 'MATRIX_SERVICE',
              subDomain: 'listen',
              stackTrace: stackTrace,
            );
          }
        },
        onError: (
          Object e,
          StackTrace stackTrace,
        ) {
          _loggingDb.captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'listen',
            stackTrace: stackTrace,
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint('$e');
      _loggingDb.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'listen',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) =>
      sendMessage(
        syncMessage,
        service: this,
        myRoomId: myRoomId,
      );

  Future<void> logout() async {
    if (_client.isLogged()) {
      await _client.logout();
    }
  }

  Future<MatrixConfig?> loadConfig() => loadMatrixConfig(service: this);
  Future<void> deleteConfig() => deleteMatrixConfig(service: this);
  Future<void> setConfig(MatrixConfig config) =>
      setMatrixConfig(config, service: this);
}
