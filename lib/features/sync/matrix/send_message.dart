import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';

extension SendExtension on MatrixService {
  void incrementSentCount() {
    sentCount = sentCount + 1;
    messageCountsController.add(
      MatrixStats(
        messageCounts: messageCounts,
        sentCount: sentCount,
      ),
    );
  }

  /// Sends a Matrix message for cross-device state synchronization. Takes a
  /// [SyncMessage] and also requires the system's [MatrixService]. A room can
  /// optionally be specified, e.g. in testing. Otherwise, the service's `syncRoom`
  /// is used.
  /// Also updates some stats on sent message counts on the [MatrixService].
  /// The send function will terminate early (and thus refuse to send anything)
  /// when there are users with unverified device in the room.
  Future<void> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) async {
    final loggingDb = getIt<LoggingDb>();

    final msg = json.encode(syncMessage);
    final roomId = myRoomId ?? syncRoomId;

    if (getUnverifiedDevices().isNotEmpty) {
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

      final shouldResendAttachments =
          await getIt<JournalDb>().getConfigFlag(resendAttachments);

      await journalEntity.maybeMap(
        journalAudio: (JournalAudio journalAudio) async {
          if (shouldResendAttachments ||
              syncMessage.status == SyncEntryStatus.initial) {
            await sendFile(
              fullPath: AudioUtils.getAudioPath(
                journalAudio,
                docDir,
              ),
              relativePath: AudioUtils.getRelativeAudioPath(journalAudio),
            );
          }
        },
        journalImage: (JournalImage journalImage) async {
          if (shouldResendAttachments ||
              syncMessage.status == SyncEntryStatus.initial) {
            await sendFile(
              fullPath: getFullImagePath(journalImage),
              relativePath: getRelativeImagePath(journalImage),
            );
          }
        },
        orElse: () {},
      );
    }
  }

  /// Sends a file attachment to the sync room.
  Future<void> sendFile({
    required String fullPath,
    required String relativePath,
  }) async {
    final loggingDb = getIt<LoggingDb>()
      ..captureEvent(
        'trying to send $relativePath file message to $syncRoom',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

    final eventId = await syncRoom?.sendFileEvent(
      MatrixFile(
        bytes: await File(fullPath).readAsBytes(),
        name: fullPath,
      ),
      extraContent: {'relativePath': relativePath},
    );

    incrementSentCount();

    loggingDb.captureEvent(
      'sent $relativePath file message to $syncRoom, event ID $eventId',
      domain: 'MATRIX_SERVICE',
      subDomain: 'sendMatrixMsg',
    );
  }
}
