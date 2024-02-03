import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

class MatrixService {
  MatrixService()
      : client = Client(
          'lotti',
          databaseBuilder: (_) async {
            final dir = await getApplicationDocumentsDirectory();
            final db = HiveCollectionsDatabase('lotti_sync', dir.path);
            await db.open();
            return db;
          },
        ) {
    login().then((value) => printUnverified()).then((value) => listen());

    Timer.periodic(const Duration(seconds: 15), (_) {
      sendMatrixMsg(
        'PING ${DateTime.now()} ${Platform.localHostname} ${Platform.isIOS}',
      );
    });
  }

  Future<void> login() async {
    const homeServer = String.fromEnvironment('MATRIX_HOME_SERVER');
    const userName = String.fromEnvironment('MATRIX_USER');
    const password = String.fromEnvironment('MATRIX_PASSWORD');
    const roomId = String.fromEnvironment('MATRIX_ROOM_ID');

    await client.checkHomeserver(
      Uri.parse(homeServer),
    );

    await client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    // TODO(unassigned): find non-deprecated solution
    // ignore: deprecated_member_use
    if (client.loginState == LoginState.loggedOut) {
      final loginResponse = await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: userName),
        password: password,
      );

      debugPrint('MatrixService userId ${loginResponse.userId}');
      debugPrint(
        'MatrixService loginResponse deviceId ${loginResponse.deviceId}',
      );
    }

    final joinRes = await client.joinRoom(roomId).onError((
      error,
      stackTrace,
    ) {
      debugPrint('MatrixService join error $error');
      return error.toString();
    });

    debugPrint('MatrixService joinRes $joinRes');
  }

  Future<void> loadArchive() async {
    final rooms = await client.loadArchive();
    debugPrint('Matrix $rooms');
  }

  Future<void> printUnverified() async {
    final unverified = client.unverifiedDevices;
    final keyVerification = await unverified.firstOrNull?.startVerification();
    debugPrint('Matrix keyVerification ${keyVerification?.qrCode}');
    debugPrint('Matrix unverified ${unverified.length} $unverified');
  }

  final Client client;

  final ConnectivityService _connectivityService = getIt<ConnectivityService>();
  final FgBgService _fgBgService = getIt<FgBgService>();
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  late final StreamSubscription<FGBGType> fgBgSubscription;

  void dispose() {
    fgBgSubscription.cancel();
  }

  Future<void> listen() async {
    try {
      client.onLoginStateChanged.stream.listen((LoginState loginState) {
        debugPrint('LoginState: $loginState');
      });

      client.onEvent.stream.listen((EventUpdate eventUpdate) {
        //debugPrint('New event update! $eventUpdate');
      });

      const roomId = String.fromEnvironment('MATRIX_ROOM_ID');

      final room = client.getRoomById(roomId);
      debugPrint('Matrix room $room');

      client.onRoomState.stream.listen((Event eventUpdate) async {
        debugPrint(
          'MatrixService onRoomState.stream.listen plaintextBody: ${eventUpdate.plaintextBody}',
        );

        // final t = await room?.getTimeline();
        // await t?.setReadMarker(
        //   eventId: eventUpdate.eventId,
        //   public: true,
        // );

        final attachmentMimetype = eventUpdate.attachmentMimetype;
        if (attachmentMimetype.isNotEmpty) {
          debugPrint('attachmentMimetype: $attachmentMimetype');
        }
      });

      // await client.checkHomeserver(
      //   Uri.parse(homeServer),
      // );
      //
      // final timeline = await room?.getTimeline(
      //   onInsert: (i) async {
      //     debugPrint('New message in timeline! $i');
      //   },
      // );
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> sendMatrixMsg(String msg) async {
    try {
      const roomId = String.fromEnvironment('MATRIX_ROOM_ID');
      final room = client.getRoomById(roomId);
      await room?.sendTextEvent(msg);
    } catch (e) {
      debugPrint('MATRIX: Error sending message: $e');
    }
  }

  Future<void> init() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncFlag);

    if (syncConfig != null && enableSyncOutbox) {
      debugPrint('OutboxService init $enableSyncOutbox');

      _connectivityService.connectedStream.listen((connected) {
        if (connected) {
        } else {}
      });

      _fgBgService.fgBgStream.listen((foreground) {
        if (foreground) {
          //restartRunner();
        }
      });
    }
  }

  Future<List<OutboxItem>> getNextItems() async {
    return _syncDatabase.oldestOutboxItems(10);
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    try {
      final vectorClockService = getIt<VectorClockService>();
      final hostHash = await vectorClockService.getHostHash();
      final host = await vectorClockService.getHost();
      final jsonString = json.encode(syncMessage);
      final docDir = getDocumentsDirectory();

      final commonFields = OutboxCompanion(
        status: Value(OutboxStatus.pending.index),
        message: Value(jsonString),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );

      if (syncMessage is SyncJournalEntity) {
        final journalEntity = syncMessage.journalEntity;
        File? attachment;
        final localCounter = journalEntity.meta.vectorClock?.vclock[host];

        journalEntity.maybeMap(
          journalAudio: (JournalAudio journalAudio) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment = File(AudioUtils.getAudioPath(journalAudio, docDir));
            }
          },
          journalImage: (JournalImage journalImage) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment = File(getFullImagePath(journalImage));
            }
          },
          orElse: () {},
        );

        final fileLength = attachment?.lengthSync() ?? 0;
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            filePath: Value(
              (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
            ),
            subject: Value('$hostHash:$localCounter'),
          ),
        );
      }

      if (syncMessage is SyncEntityDefinition) {
        final localCounter =
            syncMessage.entityDefinition.vectorClock?.vclock[host];

        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:$localCounter'),
          ),
        );
      }

      if (syncMessage is SyncEntryLink) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(subject: Value('$hostHash:link')),
        );
      }

      if (syncMessage is SyncTagEntity) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:tag'),
          ),
        );
      }
    } catch (exception, stackTrace) {
      debugPrint('enqueueMessage $exception \n$stackTrace');
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage',
        stackTrace: stackTrace,
      );
    }
  }
}
