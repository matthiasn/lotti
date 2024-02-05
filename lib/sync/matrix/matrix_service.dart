import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/inbox/save_attachments.dart';
import 'package:lotti/utils/audio_utils.dart';
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
            final db = HiveCollectionsDatabase(
              'lotti_sync',
              '${dir.path}/matrix/',
            );
            await db.open();
            return db;
          },
        ) {
    login().then((value) => printUnverified()).then((value) => listen());
  }

  Future<void> login() async {
    try {
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
  final LoggingDb _loggingDb = getIt<LoggingDb>();

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
        // debugPrint(
        //   'MatrixService onRoomState.stream.listen plaintextBody: ${eventUpdate.plaintextBody}',
        // );

        // final t = await room?.getTimeline();
        // await t?.setReadMarker(
        //   eventId: eventUpdate.eventId,
        //   public: true,
        // );

        try {
          final attachmentMimetype = eventUpdate.attachmentMimetype;
          if (attachmentMimetype.isNotEmpty) {
            final relativePath = eventUpdate.content['relativePath'];
            final matrixFile = await eventUpdate.downloadAndDecryptAttachment();
            final docDir = getDocumentsDirectory();
            await writeToFile(matrixFile.bytes, '${docDir.path}$relativePath');
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
      });
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
      const roomId = String.fromEnvironment('MATRIX_ROOM_ID');
      final room = client.getRoomById(roomId);
      await room?.sendTextEvent(base64.encode(utf8.encode(msg)));

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
              await room?.sendFileEvent(
                MatrixFile(
                  bytes: bytes,
                  name: fullPath,
                ),
                extraContent: {
                  'relativePath': relativePath,
                },
              );
            }
          },
          journalImage: (JournalImage journalImage) async {
            if (syncMessage.status == SyncEntryStatus.initial) {
              final relativePath = getRelativeImagePath(journalImage);
              final fullPath = getFullImagePath(journalImage);
              final bytes = await File(fullPath).readAsBytes();
              await room?.sendFileEvent(
                MatrixFile(
                  bytes: bytes,
                  name: fullPath,
                ),
                extraContent: {
                  'relativePath': relativePath,
                },
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
}
