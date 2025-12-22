import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
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
    VectorClockService? vectorClockService,
  })  : _loggingService = loggingService,
        _journalDb = journalDb,
        _documentsDirectory = documentsDirectory,
        _sentEventRegistry = sentEventRegistry,
        _vectorClockService = vectorClockService;

  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final Directory _documentsDirectory;
  final SentEventRegistry _sentEventRegistry;
  final VectorClockService? _vectorClockService;

  SentEventRegistry get sentEventRegistry => _sentEventRegistry;

  Future<SyncMessage> _ensureOriginatingHostId(
    SyncMessage message,
  ) async {
    if (_vectorClockService == null) return message;
    final host = await _vectorClockService!.getHost();
    if (host == null) return message;

    if (message is SyncJournalEntity && message.originatingHostId == null) {
      _loggingService.captureEvent(
        'originatingHostId filled for journalEntity id=${message.id} jsonPath=${message.jsonPath} host=$host',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.originatingHostId',
      );
      return message.copyWith(originatingHostId: host);
    }

    if (message is SyncEntryLink && message.originatingHostId == null) {
      _loggingService.captureEvent(
        'originatingHostId filled for entryLink id=${message.entryLink.id} '
        'from=${message.entryLink.fromId} to=${message.entryLink.toId} host=$host',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.originatingHostId',
      );
      return message.copyWith(originatingHostId: host);
    }

    return message;
  }

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
      var outboundMessage = await _ensureOriginatingHostId(message);
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
      if (outboundMessage is SyncEntryLink) {
        final covered = VectorClock.mergeUniqueClocks(
          [
            ...?outboundMessage.coveredVectorClocks,
            outboundMessage.entryLink.vectorClock,
          ],
        );
        outboundMessage = outboundMessage.copyWith(
          coveredVectorClocks: covered,
        );
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

      try {
        onSent(eventId, outboundMessage);
      } catch (error, stackTrace) {
        _loggingService
          ..captureEvent(
            'onSent callback threw for eventId=$eventId '
            'messageType=${outboundMessage.runtimeType}',
            domain: 'MATRIX_SERVICE',
            subDomain: 'matrix.message_sender.onSent',
          )
          ..captureException(
            error,
            domain: 'MATRIX_SERVICE',
            subDomain: 'matrix.message_sender.onSent',
            stackTrace: stackTrace,
          );
      }
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
    Uint8List? bytes,
  }) async {
    try {
      _loggingService.captureEvent(
        'trying to send $relativePath file message to $room',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );

      final fileBytes = bytes ?? await File(fullPath).readAsBytes();
      final eventId = await room.sendFileEvent(
        MatrixFile(
          bytes: fileBytes,
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

    late final Uint8List jsonBytes;
    try {
      jsonBytes = await File(jsonFullPath).readAsBytes();
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
        stackTrace: stackTrace,
      );
      return null;
    }

    final jsonSent = await _sendFile(
      room: room,
      fullPath: jsonFullPath,
      relativePath: message.jsonPath,
      bytes: jsonBytes,
    );

    if (!jsonSent) {
      return null;
    }

    late final JournalEntity journalEntity;
    try {
      final jsonString = utf8.decode(jsonBytes);
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
        final covered = VectorClock.mergeUniqueClocks(
          [
            ...?message.coveredVectorClocks,
            messageVectorClock,
            jsonVectorClock,
          ],
        );
        outbound = message.copyWith(
          vectorClock: jsonVectorClock,
          coveredVectorClocks: covered,
        );
        final coveredLog = covered?.map((vc) => vc.vclock).toList() ?? const [];
        _loggingService.captureEvent(
          'vectorClock mismatch; adopting json clock for ${message.jsonPath} '
          'json=${jsonVectorClock.vclock} message=${messageVectorClock.vclock} '
          'status=$status coveredClocks=${covered?.length ?? 0} covered=$coveredLog',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg.vclockAdjusted',
        );
      }
    } else if (jsonVectorClock != null && messageVectorClock == null) {
      final covered = VectorClock.mergeUniqueClocks(
        [
          ...?message.coveredVectorClocks,
          jsonVectorClock,
        ],
      );
      outbound = message.copyWith(
        vectorClock: jsonVectorClock,
        coveredVectorClocks: covered,
      );
      _loggingService.captureEvent(
        'vectorClock absent on message but present in json for ${message.jsonPath}; adopting json clock ${jsonVectorClock.vclock}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.vclockAdjusted',
      );
    }
    final ensuredCovered = VectorClock.mergeUniqueClocks(
      [
        ...?outbound.coveredVectorClocks,
        outbound.vectorClock,
      ],
    );
    if (ensuredCovered != outbound.coveredVectorClocks) {
      outbound = outbound.copyWith(coveredVectorClocks: ensuredCovered);
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
