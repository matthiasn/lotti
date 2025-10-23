import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

typedef MatrixMessageSentCallback = void Function(
  String eventId,
  SyncMessage message,
);

/// Handles Matrix message sending including attachments and logging.
class MatrixMessageSender {
  MatrixMessageSender({
    required LoggingService loggingService,
    required JournalDb journalDb,
    required Directory documentsDirectory,
    required SentEventRegistry sentEventRegistry,
  })  : _loggingService = loggingService,
        _journalDb = journalDb,
        _documentsDirectory = documentsDirectory,
        _sentEventRegistry = sentEventRegistry;

  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final Directory _documentsDirectory;
  final SentEventRegistry _sentEventRegistry;

  Directory get documentsDirectory => _documentsDirectory;
  SentEventRegistry get sentEventRegistry => _sentEventRegistry;

  /// Sends [message] to Matrix, ensuring that any event IDs emitted by the SDK
  /// are registered with [SentEventRegistry] so downstream timelines can
  /// suppress the echoed payload.
  Future<bool> sendMatrixMessage({
    required SyncMessage message,
    required MatrixMessageContext context,
    required MatrixMessageSentCallback onSent,
  }) async {
    if (context.unverifiedDevices.isNotEmpty) {
      _loggingService.captureException(
        'Unverified devices found',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }

    final room = context.syncRoom;
    final roomId = context.syncRoomId ?? room?.id;

    if (roomId == null) {
      _loggingService.captureEvent(
        configNotFound,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }

    if (room == null) {
      _loggingService.captureEvent(
        'Unable to send message: no room instance available for $roomId',
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

    try {
      // For journal entity messages, upload JSON (and attachments) first so
      // descriptors are available before the text event is processed.
      var outboundMessage = message;
      if (outboundMessage is SyncJournalEntity) {
        final normalized = await _sendJournalEntityPayload(
          room: room,
          message: outboundMessage,
        );
        if (normalized == null) {
          return false;
        }
        outboundMessage = normalized;
      }

      final encodedMessage = json.encode(outboundMessage);
      final eventId = await room.sendTextEvent(
        base64.encode(utf8.encode(encodedMessage)),
        msgtype: syncMessageType,
        parseCommands: false,
        parseMarkdown: false,
      );

      if (eventId == null) {
        _loggingService.captureEvent(
          'Failed sending text message to $room',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        );
        return false;
      }

      _loggingService.captureEvent(
        'sent text message to $room with event ID $eventId',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

      _sentEventRegistry.register(
        eventId,
        source: SentEventSource.text,
      );

      onSent(eventId, outboundMessage);
      return true;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _sendFile({
    required Room room,
    required String fullPath,
    required String relativePath,
  }) async {
    try {
      _loggingService.captureEvent(
        'trying to send $relativePath file message to $room',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

      final file = File(fullPath);
      final eventId = await room.sendFileEvent(
        MatrixFile(
          bytes: await file.readAsBytes(),
          name: p.basename(fullPath),
        ),
        extraContent: {'relativePath': relativePath},
      );

      if (eventId == null) {
        _loggingService.captureEvent(
          'Failed sending $relativePath file message to $room',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        );
        return false;
      }

      _loggingService.captureEvent(
        'sent $relativePath file message to $room, event ID $eventId',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

      _sentEventRegistry.register(
        eventId,
        source: SentEventSource.file,
      );
      return true;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<SyncJournalEntity?> _sendJournalEntityPayload({
    required Room room,
    required SyncJournalEntity message,
  }) async {
    final relativeJsonPath = p.joinAll(
      message.jsonPath.split('/').where((part) => part.isNotEmpty),
    );
    final jsonFullPath = p.join(_documentsDirectory.path, relativeJsonPath);

    final jsonSent = await _sendFile(
      room: room,
      fullPath: jsonFullPath,
      relativePath: message.jsonPath,
    );

    if (!jsonSent) {
      return null;
    }

    late final JournalEntity journalEntity;
    try {
      final jsonString = await File(jsonFullPath).readAsString();
      journalEntity = JournalEntity.fromJson(
        json.decode(jsonString) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.decode',
        stackTrace: stackTrace,
      );
      return null;
    }

    final shouldResendAttachments =
        await _journalDb.getConfigFlag(resendAttachments);

    var attachmentsOk = true;

    final messageVectorClock = message.vectorClock;
    final jsonVectorClock = journalEntity.meta.vectorClock;
    var outbound = message;
    if (messageVectorClock != null && jsonVectorClock != null) {
      final status = VectorClock.compare(jsonVectorClock, messageVectorClock);
      if (status != VclockStatus.equal) {
        outbound = message.copyWith(vectorClock: jsonVectorClock);
        _loggingService.captureEvent(
          'vectorClock mismatch; adopting json clock for ${message.jsonPath} json=${jsonVectorClock.vclock} message=${messageVectorClock.vclock} status=$status',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg.vclockAdjusted',
        );
      }
    } else if (jsonVectorClock != null && messageVectorClock == null) {
      outbound = message.copyWith(vectorClock: jsonVectorClock);
      _loggingService.captureEvent(
        'vectorClock absent on message but present in json for ${message.jsonPath}; adopting json clock ${jsonVectorClock.vclock}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.vclockAdjusted',
      );
    }

    await journalEntity.maybeMap(
      journalAudio: (JournalAudio journalAudio) async {
        if (shouldResendAttachments ||
            message.status == SyncEntryStatus.initial) {
          final audioPath = AudioUtils.getAudioPath(
            journalAudio,
            _documentsDirectory,
          );
          final sent = await _sendFile(
            room: room,
            fullPath: audioPath,
            relativePath: AudioUtils.getRelativeAudioPath(journalAudio),
          );
          attachmentsOk = attachmentsOk && sent;
        }
      },
      journalImage: (JournalImage journalImage) async {
        if (shouldResendAttachments ||
            message.status == SyncEntryStatus.initial) {
          final imagePath = getFullImagePath(
            journalImage,
            documentsDirectory: _documentsDirectory.path,
          );
          final sent = await _sendFile(
            room: room,
            fullPath: imagePath,
            relativePath: getRelativeImagePath(journalImage),
          );
          attachmentsOk = attachmentsOk && sent;
        }
      },
      orElse: () async {},
    );

    if (!attachmentsOk) {
      return null;
    }

    return outbound;
  }

  @visibleForTesting
  Future<SyncJournalEntity?> sendJournalEntityPayloadForTesting({
    required Room room,
    required SyncJournalEntity message,
  }) =>
      _sendJournalEntityPayload(room: room, message: message);
}

class MatrixMessageContext {
  const MatrixMessageContext({
    required this.syncRoomId,
    required this.syncRoom,
    required this.unverifiedDevices,
  });

  final String? syncRoomId;
  final Room? syncRoom;
  final List<DeviceKeys> unverifiedDevices;
}
