import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

typedef MatrixMessageSentCallback =
    void Function(
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
    DomainLogger? domainLogger,
  }) : _loggingService = loggingService,
       _journalDb = journalDb,
       _documentsDirectory = documentsDirectory,
       _sentEventRegistry = sentEventRegistry,
       _vectorClockService = vectorClockService,
       _domainLogger = domainLogger;

  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final Directory _documentsDirectory;
  final SentEventRegistry _sentEventRegistry;
  final VectorClockService? _vectorClockService;
  final DomainLogger? _domainLogger;

  SentEventRegistry get sentEventRegistry => _sentEventRegistry;

  void _trace(String message, {String? subDomain}) {
    _domainLogger?.log(
      LogDomains.sync,
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

    if (message is SyncAgentBundle) {
      final origin = message.originatingHostId ?? host;
      return message.copyWith(
        originatingHostId: origin,
        entities: [
          for (final child in message.entities)
            child.originatingHostId == null
                ? child.copyWith(originatingHostId: origin)
                : child,
        ],
        links: [
          for (final child in message.links)
            child.originatingHostId == null
                ? child.copyWith(originatingHostId: origin)
                : child,
        ],
      );
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
      _trace(
        'FAIL noRoomId type=${message.runtimeType}',
        subDomain: 'matrix.send.error',
      );
      _loggingService.captureEvent(
        configNotFound,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }

    if (room == null) {
      _trace(
        'FAIL noRoom roomId=$roomId type=${message.runtimeType}',
        subDomain: 'matrix.send.error',
      );
      _loggingService.captureEvent(
        'Unable to send message: no room instance available for $roomId',
        domain: 'MATRIX_SERVICE',
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
        _loggingService.captureEvent(
          'Failed sending text message to $room',
          domain: 'MATRIX_SERVICE',
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
      _trace(
        'EXCEPTION type=${message.runtimeType} '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
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
      final file = File(fullPath);
      // ignore: avoid_slow_async_io
      if (bytes == null && !await file.exists()) {
        _loggingService.captureEvent(
          'skipping missing file $relativePath (not found at $fullPath)',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        );
        return true;
      }

      final fileBytes = bytes ?? await file.readAsBytes();

      final shouldCompress =
          relativePath.toLowerCase().endsWith('.json') &&
          await _journalDb.getConfigFlag(useCompressedJsonAttachmentsFlag);
      final uploadBytes = shouldCompress
          ? await gzipEncodeBytes(fileBytes)
          : fileBytes;
      final baseName = p.basename(fullPath);
      final uploadName = shouldCompress ? '$baseName.gz' : baseName;
      final extraContent = <String, dynamic>{
        'relativePath': relativePath,
        if (shouldCompress) attachmentEncodingKey: attachmentEncodingGzip,
      };

      final eventId = await room.sendFileEvent(
        MatrixFile(bytes: uploadBytes, name: uploadName),
        extraContent: extraContent,
      );

      if (eventId == null) {
        _trace(
          'FAIL sendFileEvent returned null path=$relativePath '
          'bytes=${uploadBytes.length}',
          subDomain: 'matrix.send.error',
        );
        _loggingService.captureEvent(
          'Failed sending $relativePath file message to $room',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        );
        return false;
      }

      _sentEventRegistry.register(
        eventId,
        source: SentEventSource.file,
      );
      return true;
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION sendFile path=$relativePath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
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
      _trace(
        'EXCEPTION readJsonFile path=$jsonFullPath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
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

    final shouldResendAttachments = await _journalDb.getConfigFlag(
      resendAttachments,
    );

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
        logVectorClockAssignment(
          _loggingService,
          subDomain: 'send.adoptJson',
          action: 'assign',
          type: 'SyncJournalEntity',
          entryId: message.id,
          jsonPath: message.jsonPath,
          reason: 'json_mismatch',
          previous: messageVectorClock,
          assigned: jsonVectorClock,
          coveredVectorClocks: covered,
          extras: {'status': status},
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
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'send.adoptJson',
        action: 'assign',
        type: 'SyncJournalEntity',
        entryId: message.id,
        jsonPath: message.jsonPath,
        reason: 'message_missing',
        assigned: jsonVectorClock,
        coveredVectorClocks: covered,
      );
    }
    final ensuredCovered = VectorClock.mergeUniqueClocks(
      [
        ...?outbound.coveredVectorClocks,
        outbound.vectorClock,
      ],
    );
    if (ensuredCovered != outbound.coveredVectorClocks) {
      final currentClock = outbound.vectorClock;
      outbound = outbound.copyWith(coveredVectorClocks: ensuredCovered);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'send.ensureCovered',
        action: 'assign',
        type: 'SyncJournalEntity',
        entryId: outbound.id,
        jsonPath: outbound.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: currentClock,
        coveredVectorClocks: ensuredCovered,
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

  /// Builds the dequeue-time outbox bundle's manifest payload (envelope + DB
  /// content for each child), gzip-encodes it, and uploads the bytes as a
  /// single Matrix file event. Returns the stripped [SyncOutboxBundle] (i.e.
  /// `children` cleared, `jsonPath` set to the just-uploaded relative path)
  /// for the caller to send as the text envelope; returns `null` when the
  /// bundle is empty, exceeds the size cap, or the upload fails.
  ///
  /// The manifest is a single JSON document — the bundle never fans out into
  /// per-child file events. The receiver's `OutboxBundleUnpacker` resolves
  /// the manifest, materializes each child's payload to disk under its
  /// declared `jsonPath`, and dispatches each envelope through the existing
  /// per-type prepare pipeline.
  ///
  /// The database is the system of record for journal entities: this method
  /// fetches every child's `JournalEntity` from `JournalDb` in **one** bulk
  /// query (no N+1) and embeds the result inline in the manifest. Vector
  /// clocks are reconciled against the DB version exactly as
  /// [_sendJournalEntityPayload] does for individually-sent entities.
  ///
  /// Inline-payload children (`SyncEntryLink`, `SyncAiConfig`,
  /// `SyncAiConfigDelete`, `SyncEntityDefinition`, `SyncThemingSelection`,
  /// `SyncBackfillRequest`, `SyncBackfillResponse`) need no separate payload —
  /// the freezed envelope already carries everything. Agent envelopes
  /// (`SyncAgentEntity`, `SyncAgentLink`, `SyncAgentBundle`) keep their
  /// inline data fields populated by upstream writers, so they ride along in
  /// the envelope unchanged.
  Future<SyncOutboxBundle?> _sendOutboxBundlePayload({
    required Room room,
    required SyncOutboxBundle message,
  }) async {
    if (message.children.isEmpty) {
      _loggingService.captureEvent(
        'skipping empty outboxBundle send',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    // Defence in depth: never let a [SyncOutboxBundle.jsonPath] arriving
    // from outside this method drive arbitrary placement of the upload
    // metadata. We only honour paths that live under `/outbox_bundles/` and
    // do not contain a `..` segment; any other value (including values from
    // a tampered/corrupted Matrix payload) falls back to a freshly minted
    // UUID-based path and is logged.
    final candidatePath = message.jsonPath;
    final String relativePath;
    if (candidatePath == null || _isSafeOutboxBundlePath(candidatePath)) {
      relativePath = candidatePath ?? relativeOutboxBundlePath(uuid.v1());
    } else {
      _loggingService.captureEvent(
        'rejecting outboxBundle jsonPath outside /outbox_bundles/: '
        '$candidatePath — falling back to a fresh UUID path',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.outboxBundle.write',
      );
      relativePath = relativeOutboxBundlePath(uuid.v1());
    }

    // Bulk-load JournalEntity payloads referenced by the bundle's
    // [SyncJournalEntity] children in a single SQL `IN (…)` query. A naive
    // per-child fetch would issue [outboxBundleMaxSize] round-trips per
    // bundle; one batched call keeps the bundler's DB cost flat regardless
    // of bundle size.
    final journalEntityIds = <String>{
      for (final child in message.children)
        if (child is SyncJournalEntity) child.id,
    };
    final journalEntityById = journalEntityIds.isEmpty
        ? const <String, JournalEntity>{}
        : await _journalDb.journalEntityMapForIds(journalEntityIds);

    final host = await _vectorClockService?.getHost();

    final entries = <Map<String, dynamic>>[];
    for (final child in message.children) {
      final reconciled = _reconcileBundleChildEnvelope(
        child,
        host: host,
        journalEntityById: journalEntityById,
      );
      final record = <String, dynamic>{
        'envelope': reconciled.toJson(),
      };
      final payload = _loadBundleChildPayload(
        reconciled,
        journalEntityById: journalEntityById,
      );
      if (payload != null) {
        record['payload'] = payload;
      }
      entries.add(record);
    }

    final manifest = <String, dynamic>{
      'version': SyncTuning.outboxBundleManifestVersion,
      'entries': entries,
    };

    Uint8List gzipped;
    try {
      final manifestBytes = utf8.encode(json.encode(manifest));
      gzipped = await gzipEncodeBytes(manifestBytes);
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.outboxBundle.encode',
        stackTrace: stackTrace,
      );
      return null;
    }

    if (gzipped.length > SyncTuning.outboxBundleMaxBytes) {
      _loggingService.captureException(
        'outboxBundle exceeds max bytes: '
        'gzipped=${gzipped.length} '
        'max=${SyncTuning.outboxBundleMaxBytes} '
        'children=${message.children.length}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.outboxBundle.tooLarge',
      );
      return null;
    }

    final fileName = p.basename(
      relativePath.split('/').where((s) => s.isNotEmpty).last,
    );
    final extraContent = <String, dynamic>{
      'relativePath': relativePath,
      attachmentEncodingKey: attachmentEncodingGzip,
    };

    String? uploadEventId;
    try {
      uploadEventId = await room.sendFileEvent(
        MatrixFile(bytes: gzipped, name: fileName),
        extraContent: extraContent,
      );
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION outboxBundle.upload path=$relativePath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.outboxBundle.upload',
        stackTrace: stackTrace,
      );
      return null;
    }

    if (uploadEventId == null) {
      _trace(
        'FAIL outboxBundle.upload returned null path=$relativePath '
        'gzippedBytes=${gzipped.length}',
        subDomain: 'matrix.send.error',
      );
      _loggingService.captureEvent(
        'Failed sending outboxBundle file message to $room',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    _sentEventRegistry.register(uploadEventId, source: SentEventSource.file);

    return message.copyWith(
      jsonPath: relativePath,
      children: const [],
    );
  }

  /// Returns true when [relativePath] is a well-formed
  /// `/outbox_bundles/<id>.json.gz` path with no traversal segments. Used by
  /// [_sendOutboxBundlePayload] to gate which inbound `jsonPath` values are
  /// honoured for a freshly built bundle's metadata.
  static bool _isSafeOutboxBundlePath(String relativePath) {
    if (!relativePath.startsWith(outboxBundlesSegment)) return false;
    final segments = p.split(relativePath).where((s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '..' || s == '.')) return false;
    return true;
  }

  /// Brings a bundle child's envelope to the same state the per-message
  /// sender would produce: stamps `originatingHostId` from the local host
  /// service when missing, and reconciles a journal entity's vector clock
  /// against the DB's current copy. Mirrors the reconcile block in
  /// [_sendJournalEntityPayload].
  ///
  /// [journalEntityById] is the bulk-loaded map for this bundle; the helper
  /// never issues its own DB queries, so the per-child cost stays O(1).
  SyncMessage _reconcileBundleChildEnvelope(
    SyncMessage child, {
    required String? host,
    required Map<String, JournalEntity> journalEntityById,
  }) {
    if (child is SyncJournalEntity) {
      var reconciled = child;
      if (reconciled.originatingHostId == null && host != null) {
        reconciled = reconciled.copyWith(originatingHostId: host);
      }
      final entity = journalEntityById[reconciled.id];
      if (entity != null) {
        final messageVc = reconciled.vectorClock;
        final entityVc = entity.meta.vectorClock;
        if (messageVc != null && entityVc != null) {
          final status = VectorClock.compare(entityVc, messageVc);
          if (status != VclockStatus.equal) {
            final covered = VectorClock.mergeUniqueClocks([
              ...?reconciled.coveredVectorClocks,
              messageVc,
              entityVc,
            ]);
            reconciled = reconciled.copyWith(
              vectorClock: entityVc,
              coveredVectorClocks: covered,
            );
            logVectorClockAssignment(
              _loggingService,
              subDomain: 'send.outboxBundle.adoptDb',
              action: 'assign',
              type: 'SyncJournalEntity',
              entryId: reconciled.id,
              jsonPath: reconciled.jsonPath,
              reason: 'db_mismatch',
              previous: messageVc,
              assigned: entityVc,
              coveredVectorClocks: covered,
              extras: {'status': status},
            );
          }
        } else if (entityVc != null && messageVc == null) {
          final covered = VectorClock.mergeUniqueClocks([
            ...?reconciled.coveredVectorClocks,
            entityVc,
          ]);
          reconciled = reconciled.copyWith(
            vectorClock: entityVc,
            coveredVectorClocks: covered,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'send.outboxBundle.adoptDb',
            action: 'assign',
            type: 'SyncJournalEntity',
            entryId: reconciled.id,
            jsonPath: reconciled.jsonPath,
            reason: 'message_missing',
            assigned: entityVc,
            coveredVectorClocks: covered,
          );
        }
        final ensuredCovered = VectorClock.mergeUniqueClocks([
          ...?reconciled.coveredVectorClocks,
          reconciled.vectorClock,
        ]);
        if (ensuredCovered != reconciled.coveredVectorClocks) {
          final currentClock = reconciled.vectorClock;
          reconciled = reconciled.copyWith(coveredVectorClocks: ensuredCovered);
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'send.outboxBundle.ensureCovered',
            action: 'assign',
            type: 'SyncJournalEntity',
            entryId: reconciled.id,
            jsonPath: reconciled.jsonPath,
            reason: 'ensure_current_clock_covered',
            assigned: currentClock,
            coveredVectorClocks: ensuredCovered,
          );
        }
      }
      return reconciled;
    }

    if (child is SyncEntryLink &&
        child.originatingHostId == null &&
        host != null) {
      return child.copyWith(originatingHostId: host);
    }

    if (child is SyncAgentEntity &&
        child.originatingHostId == null &&
        host != null) {
      return child.copyWith(originatingHostId: host);
    }

    if (child is SyncAgentLink &&
        child.originatingHostId == null &&
        host != null) {
      return child.copyWith(originatingHostId: host);
    }

    if (child is SyncAgentBundle && host != null) {
      final origin = child.originatingHostId ?? host;
      return child.copyWith(
        originatingHostId: origin,
        entities: [
          for (final c in child.entities)
            c.originatingHostId == null
                ? c.copyWith(originatingHostId: origin)
                : c,
        ],
        links: [
          for (final c in child.links)
            c.originatingHostId == null
                ? c.copyWith(originatingHostId: origin)
                : c,
        ],
      );
    }

    return child;
  }

  /// Returns the body to inline alongside [child]'s envelope in the manifest,
  /// or null when the envelope already carries everything the receiver needs.
  /// Only [SyncJournalEntity] children require an inline payload; agent and
  /// inline-only families (entry link, ai config, theming, backfill) ride
  /// inside the envelope itself.
  Map<String, dynamic>? _loadBundleChildPayload(
    SyncMessage child, {
    required Map<String, JournalEntity> journalEntityById,
  }) {
    if (child is SyncJournalEntity) {
      final entity = journalEntityById[child.id];
      if (entity == null) {
        _loggingService.captureEvent(
          'outboxBundle child entity not found in DB id=${child.id} '
          'jsonPath=${child.jsonPath} — sending envelope only',
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg.outboxBundle.missingEntity',
        );
        return null;
      }
      return entity.toJson();
    }
    return null;
  }

  /// Enriches and uploads agent payload (entity or link).
  ///
  /// For legacy items (inline payload but no jsonPath), saves the payload to
  /// disk first. Then uploads the file and returns the message with jsonPath
  /// set. Agent entities and wake bundles are stripped (file-only, as they can
  /// be large); agent links are kept inline (small, like entry links) so
  /// receivers can use them immediately without waiting for the file download
  /// to complete.
  /// Returns the original [message] unchanged for non-agent types.
  /// Returns null on upload failure.
  Future<SyncMessage?> _enrichAndUploadAgentPayload({
    required Room room,
    required SyncMessage message,
  }) async {
    final String? inlineJson;
    final String? jsonPath;
    final String Function(String id)? pathBuilder;
    final String logLabel;

    switch (message) {
      case final SyncAgentEntity msg:
        inlineJson = msg.agentEntity != null
            ? json.encode(msg.agentEntity!.toJson())
            : null;
        jsonPath = msg.jsonPath;
        pathBuilder = relativeAgentEntityPath;
        logLabel = 'agentEntity';
      case final SyncAgentLink msg:
        inlineJson = msg.agentLink != null
            ? json.encode(msg.agentLink!.toJson())
            : null;
        jsonPath = msg.jsonPath;
        pathBuilder = relativeAgentLinkPath;
        logLabel = 'agentLink';
      case final SyncAgentBundle msg:
        inlineJson = msg.entities.isNotEmpty || msg.links.isNotEmpty
            ? json.encode(msg.copyWith(jsonPath: null).toJson())
            : null;
        jsonPath = msg.jsonPath;
        pathBuilder = relativeAgentBundlePath;
        logLabel = 'agentBundle';
      default:
        return message;
    }

    var enrichedPath = jsonPath;
    // Enrich legacy items that lack jsonPath but have inline payload
    if (enrichedPath == null && inlineJson != null) {
      final id = switch (message) {
        final SyncAgentEntity m => m.agentEntity!.id,
        final SyncAgentLink m => m.agentLink!.id,
        final SyncAgentBundle m => m.wakeRunKey,
        _ => throw StateError('unreachable'),
      };
      enrichedPath = pathBuilder(id);
      await _savePayloadToDisk(
        relativePath: enrichedPath,
        jsonPayload: inlineJson,
      );
    }

    if (enrichedPath == null) {
      _loggingService.captureEvent(
        'skipping $logLabel send: missing payload and jsonPath',
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    final uploaded = await _uploadAgentPayload(
      room: room,
      relativePath: enrichedPath,
      logLabel: logLabel,
    );
    if (!uploaded) return null;

    return switch (message) {
      // Agent entities can be large — strip inline, use file only.
      final SyncAgentEntity m => m.copyWith(
        jsonPath: enrichedPath,
        agentEntity: null,
      ),
      // Agent links are small (like entry links) — keep inline for
      // reliable sync, avoiding race conditions with file downloads.
      final SyncAgentLink m => m.copyWith(jsonPath: enrichedPath),
      // Bundles contain many child payloads — strip inline and use file only.
      final SyncAgentBundle m => m.copyWith(
        jsonPath: enrichedPath,
        entities: const [],
        links: const [],
      ),
      _ => throw StateError('unreachable'),
    };
  }

  /// Reads the JSON file at [relativePath] from disk and uploads it via
  /// [_sendFile]. Returns true on success, false on failure.
  Future<bool> _uploadAgentPayload({
    required Room room,
    required String relativePath,
    required String logLabel,
  }) async {
    final relativeJoined = p.joinAll(
      relativePath.split('/').where((part) => part.isNotEmpty),
    );
    final fullPath = p.join(_documentsDirectory.path, relativeJoined);

    late final Uint8List jsonBytes;
    try {
      jsonBytes = await File(fullPath).readAsBytes();
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'sendMatrixMsg.$logLabel',
        stackTrace: stackTrace,
      );
      return false;
    }

    return _sendFile(
      room: room,
      fullPath: fullPath,
      relativePath: relativePath,
      bytes: jsonBytes,
    );
  }

  /// Writes [jsonPayload] to disk at [relativePath] under the documents
  /// directory, creating parent directories as needed. Used to enrich legacy
  /// outbox items that lack a `jsonPath`.
  Future<void> _savePayloadToDisk({
    required String relativePath,
    required String jsonPayload,
  }) async {
    final relativeJoined = p.joinAll(
      relativePath.split('/').where((part) => part.isNotEmpty),
    );
    final fullPath = p.join(_documentsDirectory.path, relativeJoined);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonPayload);
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
