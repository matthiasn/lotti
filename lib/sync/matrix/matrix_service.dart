import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/inbox/save_attachments.dart';
import 'package:lotti/sync/matrix/client.dart';
import 'package:lotti/sync/matrix/consts.dart';
import 'package:lotti/sync/matrix/key_verification_runner.dart';
import 'package:lotti/sync/matrix/process_message.dart';
import 'package:lotti/sync/matrix/send_message.dart';
import 'package:lotti/sync/matrix/stats.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixService {
  MatrixService({
    this.matrixConfig,
    this.deviceDisplayName,
    String? hiveDbName,
  }) : _keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast() {
    _client = createMatrixClient(hiveDbName: hiveDbName);
    _incomingKeyVerificationRunnerController =
        StreamController<KeyVerificationRunner>.broadcast(
      onListen: publishIncomingRunnerState,
    );

    keyVerificationStream = _keyVerificationController.stream;
    incomingKeyVerificationRunnerStream =
        _incomingKeyVerificationRunnerController.stream;
  }

  void publishIncomingRunnerState() {
    incomingKeyVerificationRunner?.publishState();
  }

  final String? deviceDisplayName;
  late final Client _client;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  MatrixConfig? matrixConfig;
  LoginResponse? _loginResponse;
  String? syncRoomId;
  Room? syncRoom;

  final Map<String, int> messageCounts = {};
  int sentCount = 0;

  final StreamController<MatrixStats> messageCountsController =
      StreamController<MatrixStats>.broadcast();
  KeyVerificationRunner? keyVerificationRunner;
  KeyVerificationRunner? incomingKeyVerificationRunner;
  final StreamController<KeyVerificationRunner> _keyVerificationController;
  late final StreamController<KeyVerificationRunner>
      _incomingKeyVerificationRunnerController;
  late final Stream<KeyVerificationRunner> keyVerificationStream;
  late final Stream<KeyVerificationRunner> incomingKeyVerificationRunnerStream;

  final _incomingKeyVerificationController =
      StreamController<KeyVerification>.broadcast();

  Future<void> loginAndListen() async {
    await loadMatrixConfig();
    await login();
    await listen();
  }

  Client get client {
    return _client;
  }

  Future<void> login() async {
    try {
      final matrixConfig = this.matrixConfig;

      if (matrixConfig == null) {
        _loggingDb.captureEvent(
          configNotFound,
          domain: 'MATRIX_SERVICE',
          subDomain: 'login',
        );

        return;
      }

      final homeServerSummary = await _client.checkHomeserver(
        Uri.parse(matrixConfig.homeServer),
      );

      _loggingDb.captureEvent(
        'checkHomeserver $homeServerSummary',
        domain: 'MATRIX_SERVICE',
        subDomain: 'login',
      );

      await _client.init(
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
      );

      if (!isLoggedIn()) {
        final initialDeviceDisplayName =
            deviceDisplayName ?? await createMatrixDeviceName();

        _loginResponse = await _client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: matrixConfig.user),
          password: matrixConfig.password,
          initialDeviceDisplayName: initialDeviceDisplayName,
        );

        _loggingDb.captureEvent(
          'logged in, userId ${_loginResponse?.userId},'
          ' deviceId  ${_loginResponse?.deviceId}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'login',
        );
      }

      if (isLoggedIn()) {
        await loadArchive();
      }

      final roomId = matrixConfig.roomId;

      if (roomId != null) {
        await joinRoom(roomId);
      }
    } catch (e, stackTrace) {
      debugPrint('$e');
      _loggingDb.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'login',
        stackTrace: stackTrace,
      );
    }
  }

  Future<String> joinRoom(String roomId) async {
    try {
      final joinRes = await _client.joinRoom(roomId).onError((
        error,
        stackTrace,
      ) {
        debugPrint('MatrixService join error $error');

        _loggingDb.captureException(
          error,
          domain: 'MATRIX_SERVICE',
          subDomain: 'joinRoom',
          stackTrace: stackTrace,
        );

        return error.toString();
      });
      syncRoom = _client.getRoomById(joinRes);
      syncRoomId = joinRes;

      return joinRes;
    } catch (e, stackTrace) {
      debugPrint('$e');
      _loggingDb.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'joinRoom',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  bool isLoggedIn() {
    // TODO(unassigned): find non-deprecated solution
    // ignore: deprecated_member_use
    return _client.loginState == LoginState.loggedIn;
  }

  Future<List<Event>?> getTimelineEvents() async {
    final timeline = await syncRoom?.getTimeline();
    return timeline?.events;
  }

  Future<String> createRoom() async {
    final name = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final roomId = await _client.createRoom(
      visibility: Visibility.private,
      name: name,
    );
    await loadArchive();
    final room = _client.getRoomById(roomId);
    await room?.enableEncryption();
    return roomId;
  }

  Room? getRoom(String roomId) {
    final room = _client.getRoomById(roomId);
    return room;
  }

  Future<void> loadArchive() async {
    final rooms = await _client.loadArchive();
    debugPrint('Matrix $rooms');
  }

  List<DeviceKeys> getUnverified() {
    final unverified = _client.unverifiedDevices;
    return unverified;
  }

  Future<void> verifyDevice(DeviceKeys deviceKeys) async {
    final keyVerification = await deviceKeys.startVerification();
    keyVerificationRunner = KeyVerificationRunner(
      keyVerification,
      controller: _keyVerificationController,
      name: 'Outgoing KeyVerificationRunner',
    );
  }

  Future<void> deleteDevice(DeviceKeys deviceKeys) async {
    final deviceId = deviceKeys.deviceId;
    if (deviceId != null) {
      await _client.deleteDevice(deviceId, auth: AuthenticationData());
    }
  }

  String? get deviceId {
    return _client.deviceID;
  }

  String? get deviceName {
    return _client.deviceName;
  }

  Stream<KeyVerification> getIncomingKeyVerificationStream() {
    return _incomingKeyVerificationController.stream;
  }

  Future<void> listen() async {
    try {
      _client.onLoginStateChanged.stream.listen((LoginState loginState) {
        debugPrint('LoginState: $loginState');
      });

      _client.onKeyVerificationRequest.stream.listen((
        KeyVerification keyVerification,
      ) {
        incomingKeyVerificationRunner = KeyVerificationRunner(
          keyVerification,
          controller: _incomingKeyVerificationRunnerController,
          name: 'Incoming KeyVerificationRunner',
        );

        debugPrint('Key Verification Request from ${keyVerification.deviceId}');
        _incomingKeyVerificationController.add(keyVerification);
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

  void incrementSentCount() {
    sentCount = sentCount + 1;
    messageCountsController.add(
      MatrixStats(
        messageCounts: messageCounts,
        sentCount: sentCount,
      ),
    );
  }

  Future<void> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) async {
    await sendMessage(
      syncMessage,
      client: _client,
      syncRoom: syncRoom,
      matrixConfig: matrixConfig,
      incrementSentCount: incrementSentCount,
      myRoomId: myRoomId,
    );
  }

  Future<MatrixConfig?> loadMatrixConfig() async {
    if (matrixConfig != null) {
      return matrixConfig;
    }
    final configJson = await getIt<SecureStorage>().read(key: matrixConfigKey);
    if (configJson != null) {
      matrixConfig = MatrixConfig.fromJson(
        json.decode(configJson) as Map<String, dynamic>,
      );
    }
    return matrixConfig;
  }

  Future<void> logout() async {
    if (_client.isLogged()) {
      await _client.logout();
    }
  }

  Future<void> setMatrixConfig(MatrixConfig config) async {
    matrixConfig = config;
    await getIt<SecureStorage>().write(
      key: matrixConfigKey,
      value: jsonEncode(config),
    );
  }

  Future<void> deleteMatrixConfig() async {
    await getIt<SecureStorage>().delete(
      key: matrixConfigKey,
    );
    matrixConfig = null;
    await logout();
  }
}
