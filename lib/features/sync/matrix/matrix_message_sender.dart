import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

part 'matrix_bundle_sender.dart';
part 'matrix_payload_senders.dart';

typedef MatrixMessageSentCallback =
    void Function(
      String eventId,
      SyncMessage message,
    );

/// Handles Matrix message sending including attachments and logging.
class MatrixMessageSender {
  MatrixMessageSender({
    required this._loggingService,
    required this._journalDb,
    required this._documentsDirectory,
    required this._sentEventRegistry,
    this._vectorClockService,
    this._domainLogger,
    Future<Uint8List> Function(Object? jsonValue)? gzipEncode,
  }) : _gzipEncode = gzipEncode ?? gzipEncodeJson;

  final DomainLogger _loggingService;
  final JournalDb _journalDb;
  final Directory _documentsDirectory;
  final SentEventRegistry _sentEventRegistry;
  final VectorClockService? _vectorClockService;
  final DomainLogger? _domainLogger;

  /// Gzip+JSON encoder for outbox bundle manifests. Injectable so tests can
  /// exercise the encode-failure path; defaults to [gzipEncodeJson].
  final Future<Uint8List> Function(Object? jsonValue) _gzipEncode;

  SentEventRegistry get sentEventRegistry => _sentEventRegistry;

  void _trace(String message, {String? subDomain}) {
    _domainLogger?.log(
      LogDomain.sync,
      message,
      subDomain: subDomain ?? 'matrix.send',
    );
  }

  Future<SyncMessage> _ensureOriginatingHostId(
    SyncMessage message,
  ) async {
    if (_vectorClockService == null) return message;
    final host = await _vectorClockService.getHost();
    if (host == null) return message;

    if (message is SyncJournalEntity && message.originatingHostId == null) {
      _loggingService.log(
        LogDomain.sync,
        'originatingHostId filled for journalEntity id=${message.id} jsonPath=${message.jsonPath} host=$host',
        subDomain: 'sendMatrixMsg.originatingHostId',
      );
      return message.copyWith(originatingHostId: host);
    }

    if (message is SyncEntryLink && message.originatingHostId == null) {
      _loggingService.log(
        LogDomain.sync,
        'originatingHostId filled for entryLink id=${message.entryLink.id} '
        'from=${message.entryLink.fromId} to=${message.entryLink.toId} host=$host',
        subDomain: 'sendMatrixMsg.originatingHostId',
      );
      return message.copyWith(originatingHostId: host);
    }

    if (message is SyncNotification && message.originatingHostId.isEmpty) {
      _loggingService.log(
        LogDomain.sync,
        'originatingHostId filled for notification id=${message.id} '
        'jsonPath=${message.jsonPath} host=$host',
        subDomain: 'sendMatrixMsg.originatingHostId',
      );
      return message.copyWith(originatingHostId: host);
    }

    if (message is SyncNotificationStateUpdate &&
        message.originatingHostId.isEmpty) {
      _loggingService.log(
        LogDomain.sync,
        'originatingHostId filled for notificationStateUpdate '
        'id=${message.id} host=$host',
        subDomain: 'sendMatrixMsg.originatingHostId',
      );
      return message.copyWith(originatingHostId: host);
    }

    if (message is SyncConfigFlag && message.originatingHostId == null) {
      _loggingService.log(
        LogDomain.sync,
        'originatingHostId filled for configFlag '
        'name=${message.name} host=$host',
        subDomain: 'sendMatrixMsg.originatingHostId',
      );
      return message.copyWith(originatingHostId: host);
    }

    if (message is SyncOutboxBundle && message.originatingHostId == null) {
      // Stamp the dequeue-time outbox bundle so receivers can identify
      // self-echoes by host id and skip the manifest download/decode
      // entirely. Without this stamp, the outbox bundle envelope rides
      // through the wire with `originatingHostId == null` and every peer
      // (including the sender itself) ends up running the full
      // prepare-apply pipeline — wasting CPU on a payload that
      // vector-clock dedup will discard anyway.
      _loggingService.log(
        LogDomain.sync,
        'originatingHostId filled for outboxBundle '
        'jsonPath=${message.jsonPath} children=${message.children.length} '
        'host=$host',
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
      _trace(
        'FAIL unverifiedDevices=${context.unverifiedDevices.length} '
        'type=${message.runtimeType}',
        subDomain: 'matrix.send.error',
      );
      _loggingService.error(
        LogDomain.sync,
        'Unverified devices found',
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }

    final room = context.syncRoom;
    final roomId = context.syncRoomId ?? room?.id;

    if (roomId == null) {
      _trace(
        'FAIL noRoomId type=${message.runtimeType}',
        subDomain: 'matrix.send.error',
      );
      _loggingService.log(
        LogDomain.sync,
        configNotFound,
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }

    if (room == null) {
      _trace(
        'FAIL noRoom roomId=$roomId type=${message.runtimeType}',
        subDomain: 'matrix.send.error',
      );
      _loggingService.log(
        LogDomain.sync,
        'Unable to send message: no room instance available for $roomId',
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }

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
          _trace(
            'FAIL journalEntityPayload jsonPath=${outboundMessage.jsonPath} '
            'id=${outboundMessage.id}',
            subDomain: 'matrix.send.error',
          );
          return false;
        }
        outboundMessage = normalized;
      }
      if (outboundMessage is SyncNotification) {
        final normalized = await _sendNotificationPayload(
          room: room,
          message: outboundMessage,
        );
        if (normalized == null) {
          _trace(
            'FAIL notificationPayload jsonPath=${outboundMessage.jsonPath} '
            'id=${outboundMessage.id}',
            subDomain: 'matrix.send.error',
          );
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
      final agentResult = await _enrichAndUploadAgentPayload(
        room: room,
        message: outboundMessage,
      );
      if (agentResult == null) {
        _trace(
          'FAIL agentPayload type=${outboundMessage.runtimeType}',
          subDomain: 'matrix.send.error',
        );
        return false;
      }
      outboundMessage = agentResult;

      if (outboundMessage is SyncOutboxBundle) {
        // Bundle children skip the top-level `_ensureOriginatingHostId`
        // call above. Backfill each child individually so a journal entity
        // or entry link delivered inside a bundle still carries the same
        // originatingHostId metadata it would have if sent on its own —
        // sequence-tracking on the receiver side relies on it.
        final normalizedChildren = <SyncMessage>[];
        for (final child in outboundMessage.children) {
          normalizedChildren.add(await _ensureOriginatingHostId(child));
        }
        final normalizedBundle = outboundMessage.copyWith(
          children: normalizedChildren,
        );
        final stripped = await _sendOutboxBundlePayload(
          room: room,
          message: normalizedBundle,
        );
        if (stripped == null) {
          _trace(
            'FAIL outboxBundlePayload children=${normalizedBundle.children.length}',
            subDomain: 'matrix.send.error',
          );
          return false;
        }
        outboundMessage = stripped;
      }

      final encodedMessage = json.encode(outboundMessage);
      final encodedBytes = utf8.encode(encodedMessage);
      final b64Message = base64.encode(encodedBytes);
      final eventId = await room.sendTextEvent(
        b64Message,
        msgtype: syncMessageType,
        parseCommands: false,
        parseMarkdown: false,
      );

      if (eventId == null) {
        _trace(
          'FAIL sendTextEvent returned null '
          'type=${outboundMessage.runtimeType} '
          'jsonBytes=${encodedBytes.length} b64Bytes=${b64Message.length}',
          subDomain: 'matrix.send.error',
        );
        _loggingService.log(
          LogDomain.sync,
          'Failed sending text message to $room',
          subDomain: 'sendMatrixMsg',
        );
        return false;
      }

      _sentEventRegistry.register(
        eventId,
        source: SentEventSource.text,
      );

      try {
        onSent(eventId, outboundMessage);
      } catch (error, stackTrace) {
        _loggingService
          ..log(
            LogDomain.sync,
            'onSent callback threw for eventId=$eventId '
            'messageType=${outboundMessage.runtimeType}',
            subDomain: 'matrix.message_sender.onSent',
          )
          ..error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'matrix.message_sender.onSent',
          );
      }
      return true;
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION type=${message.runtimeType} '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }
  }

  @visibleForTesting
  Future<SyncJournalEntity?> sendJournalEntityPayloadForTesting({
    required Room room,
    required SyncJournalEntity message,
  }) => _sendJournalEntityPayload(room: room, message: message);

  @visibleForTesting
  Future<SyncMessage?> enrichAndUploadAgentPayloadForTesting({
    required Room room,
    required SyncMessage message,
  }) => _enrichAndUploadAgentPayload(room: room, message: message);

  @visibleForTesting
  Future<SyncOutboxBundle?> sendOutboxBundlePayloadForTesting({
    required Room room,
    required SyncOutboxBundle message,
  }) => _sendOutboxBundlePayload(room: room, message: message);

  @visibleForTesting
  Future<SyncMessage> ensureOriginatingHostIdForTesting(
    SyncMessage message,
  ) => _ensureOriginatingHostId(message);

  @visibleForTesting
  Future<SyncNotification?> sendNotificationPayloadForTesting({
    required Room room,
    required SyncNotification message,
  }) => _sendNotificationPayload(room: room, message: message);
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
