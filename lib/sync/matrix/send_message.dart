import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/consts.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/matrix/stats.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';

/// Sends a Matrix message for cross-device state synchronization. Takes a
/// [SyncMessage] and also requires the system's [MatrixService]. A room can
/// optionally be specified, e.g. in testing. Otherwise, the service's `syncRoom`
/// is used.
/// Also updates some stats on sent message counts on the [service].
/// The send function will terminate early (and thus refuse to send anything)
/// when there are users with unverified device in the room.
Future<void> sendMessage(
  SyncMessage syncMessage, {
  required MatrixService service,
  required String? myRoomId,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final msg = json.encode(syncMessage);
    final syncRoom = service.syncRoom;
    final roomId =
        myRoomId ?? service.syncRoomId ?? service.matrixConfig?.roomId;

    void incrementSentCount() {
      service.sentCount = service.sentCount + 1;
      service.messageCountsController.add(
        MatrixStats(
          messageCounts: service.messageCounts,
          sentCount: service.sentCount,
        ),
      );
    }

    if (service.getUnverifiedDevices().isNotEmpty) {
      loggingDb.captureException(
        'Unverified devices found',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return;
    }

    if (roomId == null) {
      loggingDb.captureEvent(
        configNotFound,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return;
    }

    loggingDb.captureEvent(
      'trying to send text message to $syncRoom',
      domain: 'MATRIX_SERVICE',
      subDomain: 'sendMatrixMsg',
    );

    final eventId = await syncRoom?.sendTextEvent(
      base64.encode(utf8.encode(msg)),
      msgtype: syncMessageType,
      parseCommands: false,
      parseMarkdown: false,
    );

    incrementSentCount();

    loggingDb.captureEvent(
      'sent text message to $syncRoom with event ID $eventId',
      domain: 'MATRIX_SERVICE',
      subDomain: 'sendMatrixMsg',
    );

    final docDir = getDocumentsDirectory();

    if (syncMessage is SyncJournalEntity) {
      final journalEntity = syncMessage.journalEntity;

      await journalEntity.maybeMap(
        journalAudio: (JournalAudio journalAudio) async {
          if (syncMessage.status == SyncEntryStatus.initial) {
            final relativePath = AudioUtils.getRelativeAudioPath(journalAudio);
            final fullPath = AudioUtils.getAudioPath(journalAudio, docDir);
            final bytes = await File(fullPath).readAsBytes();

            loggingDb.captureEvent(
              'trying to send $relativePath file message to $syncRoom',
              domain: 'MATRIX_SERVICE',
              subDomain: 'sendMatrixMsg',
            );
            final eventId = await syncRoom?.sendFileEvent(
              MatrixFile(
                bytes: bytes,
                name: fullPath,
              ),
              extraContent: {
                'relativePath': relativePath,
              },
            );
            incrementSentCount();

            loggingDb.captureEvent(
              'sent $relativePath file message to $syncRoom, event ID $eventId',
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

            loggingDb.captureEvent(
              'trying to send $relativePath file message to $syncRoom',
              domain: 'MATRIX_SERVICE',
              subDomain: 'sendMatrixMsg',
            );

            final eventId = await syncRoom?.sendFileEvent(
              MatrixFile(
                bytes: bytes,
                name: fullPath,
              ),
              extraContent: {
                'relativePath': relativePath,
              },
            );

            incrementSentCount();

            loggingDb.captureEvent(
              'sent $relativePath file message to $syncRoom, event ID $eventId',
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
    loggingDb.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'sendMatrixMsg',
      stackTrace: stackTrace,
    );
  }
}
