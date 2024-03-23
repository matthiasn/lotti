import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/inbox/save_attachments.dart';
import 'package:lotti/sync/matrix/key_verification_runner.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/utils.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

const configNotFound = 'Could not find Matrix Config';
const syncMessageType = 'com.lotti.sync.message';

class MatrixStats {
  MatrixStats({
    required this.sentCount,
    required this.messageCounts,
  });

  int sentCount;
  Map<String, int> messageCounts;
}

class MatrixService {
  MatrixService({this.matrixConfig})
      : _client = createClient(),
        _keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast() {
    _incomingKeyVerificationRunnerController =
        StreamController<KeyVerificationRunner>.broadcast(
      onListen: publishIncomingRunnerState,
    );

    keyVerificationStream = _keyVerificationController.stream;
    incomingKeyVerificationStream =
        _incomingKeyVerificationRunnerController.stream;
  }

  void publishIncomingRunnerState() {
    incomingKeyVerificationRunner?.publishState();
  }

  Client _client;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  MatrixConfig? matrixConfig;
  LoginResponse? _loginResponse;

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
  late final Stream<KeyVerificationRunner> incomingKeyVerificationStream;

  final _incomingKeyVerificationController =
      StreamController<KeyVerification>.broadcast();

  static Client createClient() {
    return Client(
      'lotti',
      verificationMethods: {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.reciprocate,
      },
      shareKeysWithUnverifiedDevices: false,
      databaseBuilder: (_) async {
        final dir = await getApplicationDocumentsDirectory();
        final db = HiveCollectionsDatabase(
          'lotti_sync',
          '${dir.path}/matrix/',
        );
        await db.open();
        return db;
      },
    );
  }

  Future<void> loginAndListen() async {
    await loadMatrixConfig();
    await login();
    await listen();
  }

  Future<void> login() async {
    try {
      _client = createClient();
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
        final initialDeviceDisplayName = await createDeviceName();

        _loginResponse = await _client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: matrixConfig.user),
          password: matrixConfig.password,
          initialDeviceDisplayName: initialDeviceDisplayName,
        );

        debugPrint('MatrixService userId ${_loginResponse?.userId}');

        _loggingDb.captureEvent(
          'logged in, userId ${_loginResponse?.userId},'
          ' deviceId  ${_loginResponse?.deviceId}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'login',
        );

        debugPrint(
          'MatrixService loginResponse deviceId ${_loginResponse?.deviceId}',
        );
      }

      if (isLoggedIn()) {
        await loadArchive();
      }

      final roomId = matrixConfig.roomId;

      if (roomId != null) {
        final joinRes = await _client.joinRoom(roomId).onError((
          error,
          stackTrace,
        ) {
          debugPrint('MatrixService join error $error');

          _loggingDb.captureException(
            error,
            domain: 'MATRIX_SERVICE',
            subDomain: 'login join',
            stackTrace: stackTrace,
          );

          return error.toString();
        });
        debugPrint('MatrixService joinRes $joinRes');
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
      debugPrint('MatrixService joinRes $joinRes');
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
    );
  }

  Future<void> deleteDevice(DeviceKeys deviceKeys) async {
    final deviceId = deviceKeys.deviceId;
    if (deviceId != null) {
      await _client.deleteDevice(deviceId, auth: AuthenticationData());
    }
  }

  String? getDeviceId() {
    return _client.deviceID;
  }

  String? getDeviceName() {
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
        );

        debugPrint('Key Verification Request from ${keyVerification.deviceId}');
        _incomingKeyVerificationController.add(keyVerification);
      });

      final roomId = matrixConfig?.roomId;

      if (roomId == null) {
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
              await processMessage(eventUpdate.plaintextBody);
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

  Future<void> sendMatrixMsg(SyncMessage syncMessage) async {
    try {
      final msg = json.encode(syncMessage);
      final roomId = matrixConfig?.roomId;

      if (_client.unverifiedDevices.isNotEmpty) {
        _loggingDb.captureException(
          'Unverified devices found',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        );
        return;
      }

      if (roomId == null) {
        _loggingDb.captureEvent(
          configNotFound,
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        );
        return;
      }

      final room = _client.getRoomById(roomId);

      _loggingDb.captureEvent(
        'trying to send text message to $room',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

      final eventId = await room?.sendTextEvent(
        base64.encode(utf8.encode(msg)),
        msgtype: syncMessageType,
      );

      sentCount = sentCount + 1;

      _loggingDb.captureEvent(
        'sent text message to $room with event ID $eventId',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

      final docDir = getDocumentsDirectory();

      if (syncMessage is SyncJournalEntity) {
        final journalEntity = syncMessage.journalEntity;

        await journalEntity.maybeMap(
          journalAudio: (JournalAudio journalAudio) async {
            if (syncMessage.status == SyncEntryStatus.initial) {
              final relativePath =
                  AudioUtils.getRelativeAudioPath(journalAudio);
              final fullPath = AudioUtils.getAudioPath(journalAudio, docDir);
              final bytes = await File(fullPath).readAsBytes();

              _loggingDb.captureEvent(
                'trying to send $relativePath file message to $room',
                domain: 'MATRIX_SERVICE',
                subDomain: 'sendMatrixMsg',
              );
              final eventId = await room?.sendFileEvent(
                MatrixFile(
                  bytes: bytes,
                  name: fullPath,
                ),
                extraContent: {
                  'relativePath': relativePath,
                },
              );
              sentCount = sentCount + 1;

              _loggingDb.captureEvent(
                'sent $relativePath file message to $room, event ID $eventId',
                domain: 'MATRIX_SERVICE',
                subDomain: 'sendMatrixMsg',
              );
            }
          },
          journalImage: (JournalImage journalImage) async {
            if (syncMessage.status == SyncEntryStatus.initial) {
              final relativePath = getRelativeImagePath(journalImage);
              final fullPath = getFullImagePath(journalImage);
              final bytes = await File(fullPath).readAsBytes();

              _loggingDb.captureEvent(
                'trying to send $relativePath file message to $room',
                domain: 'MATRIX_SERVICE',
                subDomain: 'sendMatrixMsg',
              );

              final eventId = await room?.sendFileEvent(
                MatrixFile(
                  bytes: bytes,
                  name: fullPath,
                ),
                extraContent: {
                  'relativePath': relativePath,
                },
              );
              sentCount = sentCount + 1;

              messageCountsController.add(
                MatrixStats(
                  messageCounts: messageCounts,
                  sentCount: sentCount,
                ),
              );

              _loggingDb.captureEvent(
                'sent $relativePath file message to $room, event ID $eventId',
                domain: 'MATRIX_SERVICE',
                subDomain: 'sendMatrixMsg',
              );
            }
          },
          orElse: () {},
        );
      }
    } catch (e, stackTrace) {
      debugPrint('MATRIX: Error sending message: $e');
      _loggingDb.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> processMessage(String message) async {
    final journalDb = getIt<JournalDb>();
    final loggingDb = getIt<LoggingDb>();

    try {
      final decoded = utf8.decode(base64.decode(message));

      final syncMessage = SyncMessage.fromJson(
        json.decode(decoded) as Map<String, dynamic>,
      );

      _loggingDb.captureEvent(
        'processing ${syncMessage.runtimeType}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processMessage',
      );

      await syncMessage.when(
        journalEntity: (
          JournalEntity journalEntity,
          SyncEntryStatus status,
        ) async {
          await saveJournalEntityJson(journalEntity);

          if (status == SyncEntryStatus.update) {
            await journalDb.updateJournalEntity(journalEntity);
          } else {
            await journalDb.addJournalEntity(journalEntity);
          }
        },
        entryLink: (EntryLink entryLink, SyncEntryStatus _) {
          journalDb.upsertEntryLink(entryLink);
        },
        entityDefinition: (
          EntityDefinition entityDefinition,
          SyncEntryStatus status,
        ) {
          journalDb.upsertEntityDefinition(entityDefinition);
        },
        tagEntity: (
          TagEntity tagEntity,
          SyncEntryStatus status,
        ) {
          journalDb.upsertTagEntity(tagEntity);
        },
      );
    } catch (e, stackTrace) {
      loggingDb.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'processMessage',
        stackTrace: stackTrace,
      );
    }
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
    await getIt<SecureStorage>().write(
      key: matrixConfigKey,
      value: jsonEncode(matrixConfig),
    );
    matrixConfig = config;

    await logout();
    await login();
  }

  Future<void> deleteMatrixConfig() async {
    await getIt<SecureStorage>().delete(
      key: matrixConfigKey,
    );
    matrixConfig = null;
    await logout();
  }

  Future<String> createDeviceName() async {
    final operatingSystem = Platform.operatingSystem;
    var deviceName = operatingSystem;

    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
    }
    if (Platform.isMacOS) {
      final macOsInfo = await deviceInfo.macOsInfo;
      deviceName = macOsInfo.computerName;
    }
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = androidInfo.host;
    }

    final dateHhMm = DateTime.now().toIso8601String().substring(0, 16);
    return '$deviceName $dateHhMm';
  }
}
