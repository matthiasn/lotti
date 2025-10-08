import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';

/// Handles Matrix message sending including attachments and logging.
class MatrixMessageSender {
  MatrixMessageSender({
    required LoggingService loggingService,
    required JournalDb journalDb,
    required Directory documentsDirectory,
  })  : _loggingService = loggingService,
        _journalDb = journalDb,
        _documentsDirectory = documentsDirectory;

  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final Directory _documentsDirectory;

  Future<bool> sendMatrixMessage({
    required SyncMessage message,
    required MatrixMessageContext context,
    String? roomIdOverride,
  }) async {
    final encodedMessage = json.encode(message);
    final roomId = roomIdOverride ?? context.syncRoomId;

    if (context.unverifiedDevices.isNotEmpty) {
      _loggingService.captureException(
        'Unverified devices found',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      throw Exception('Unverified Matrix devices found');
    }

    if (roomId == null) {
      _loggingService.captureEvent(
        configNotFound,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }

    _loggingService.captureEvent(
      'Sending message - using roomId: $roomId, '
      'syncRoomId: ${context.syncRoomId}, '
      'syncRoom.id: ${context.syncRoom?.id}, '
      'messageType: ${message.runtimeType}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'sendMatrixMsg',
    );

    await message.maybeMap(
      journalEntity: (SyncJournalEntity syncJournalEntity) async {
        final fullPath =
            '${_documentsDirectory.path}${syncJournalEntity.jsonPath}';
        await _sendFile(
          room: context.syncRoom,
          incrementSentCount: context.incrementSentCount,
          fullPath: fullPath,
          relativePath: syncJournalEntity.jsonPath,
        );
      },
      orElse: () async {},
    );

    final eventId = await context.syncRoom?.sendTextEvent(
      base64.encode(utf8.encode(encodedMessage)),
      msgtype: syncMessageType,
      parseCommands: false,
      parseMarkdown: false,
    );

    if (eventId == null) {
      throw Exception('Failed sending text message');
    }

    context.incrementSentCount();

    _loggingService.captureEvent(
      'sent text message to ${context.syncRoom} with event ID $eventId',
      domain: 'MATRIX_SERVICE',
      subDomain: 'sendMatrixMsg',
    );

    if (message is SyncJournalEntity) {
      final fullPath = '${_documentsDirectory.path}${message.jsonPath}';
      final jsonString = await File(fullPath).readAsString();
      final journalEntity = JournalEntity.fromJson(
        json.decode(jsonString) as Map<String, dynamic>,
      );

      final shouldResendAttachments =
          await _journalDb.getConfigFlag(resendAttachments);

      await journalEntity.maybeMap(
        journalAudio: (JournalAudio journalAudio) async {
          if (shouldResendAttachments ||
              message.status == SyncEntryStatus.initial) {
            await _sendFile(
              room: context.syncRoom,
              incrementSentCount: context.incrementSentCount,
              fullPath: AudioUtils.getAudioPath(
                journalAudio,
                _documentsDirectory,
              ),
              relativePath: AudioUtils.getRelativeAudioPath(journalAudio),
            );
          }
        },
        journalImage: (JournalImage journalImage) async {
          if (shouldResendAttachments ||
              message.status == SyncEntryStatus.initial) {
            await _sendFile(
              room: context.syncRoom,
              incrementSentCount: context.incrementSentCount,
              fullPath: getFullImagePath(
                journalImage,
                documentsDirectory: _documentsDirectory.path,
              ),
              relativePath: getRelativeImagePath(journalImage),
            );
          }
        },
        orElse: () async {},
      );
    }
    return true;
  }

  Future<void> _sendFile({
    required Room? room,
    required void Function() incrementSentCount,
    required String fullPath,
    required String relativePath,
  }) async {
    try {
      _loggingService.captureEvent(
        'trying to send $relativePath file message to $room',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

      final eventId = await room?.sendFileEvent(
        MatrixFile(
          bytes: await File(fullPath).readAsBytes(),
          name: fullPath,
        ),
        extraContent: {'relativePath': relativePath},
      );

      if (eventId == null) {
        throw Exception('Failed sending file');
      }

      incrementSentCount();

      _loggingService.captureEvent(
        'sent $relativePath file message to $room, event ID $eventId',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
        stackTrace: stackTrace,
      );
    }
  }
}

class MatrixMessageContext {
  MatrixMessageContext({
    required this.syncRoomId,
    required this.syncRoom,
    required this.unverifiedDevices,
    required this.incrementSentCount,
  });

  final String? syncRoomId;
  final Room? syncRoom;
  final List<DeviceKeys> unverifiedDevices;
  final void Function() incrementSentCount;
}
