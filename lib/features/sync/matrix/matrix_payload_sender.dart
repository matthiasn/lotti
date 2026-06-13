import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart'
    show MatrixMessageSender;
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

/// Attachment/file and outbox-bundle payload uploads for
/// [MatrixMessageSender].
///
/// Extracted into a standalone collaborator (previously two part-file
/// extensions) so the sender file stays under the size limit. The owning
/// sender constructs one of these from its own dependencies and delegates the
/// per-payload upload work to it; the sender keeps the wire envelope logic and
/// its public/`@visibleForTesting` API. Every method here was a private helper
/// on the sender, so none of it is part of the sender's mocked surface.
class MatrixPayloadSender {
  MatrixPayloadSender({
    required this.loggingService,
    required this.journalDb,
    required this.documentsDirectory,
    required this.sentEventRegistry,
    this.vectorClockService,
    this.domainLogger,
    Future<Uint8List> Function(Object? jsonValue)? gzipEncode,
  }) : gzipEncode = gzipEncode ?? gzipEncodeJson;

  final DomainLogger loggingService;
  final JournalDb journalDb;
  final Directory documentsDirectory;
  final SentEventRegistry sentEventRegistry;
  final VectorClockService? vectorClockService;
  final DomainLogger? domainLogger;

  /// Gzip+JSON encoder for outbox bundle manifests. Injectable so tests can
  /// exercise the encode-failure path; defaults to [gzipEncodeJson].
  final Future<Uint8List> Function(Object? jsonValue) gzipEncode;

  void _trace(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomain.sync,
      message,
      subDomain: subDomain ?? 'matrix.send',
    );
  }

  Future<bool> sendFile({
    required Room room,
    required String fullPath,
    required String relativePath,
    Uint8List? bytes,
  }) async {
    try {
      final file = File(fullPath);
      // ignore: avoid_slow_async_io
      if (bytes == null && !await file.exists()) {
        loggingService.log(
          LogDomain.sync,
          'skipping missing file $relativePath (not found at $fullPath)',
          subDomain: 'sendMatrixMsg',
        );
        return true;
      }

      final fileBytes = bytes ?? await file.readAsBytes();

      final shouldCompress = relativePath.toLowerCase().endsWith('.json');
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
        loggingService.log(
          LogDomain.sync,
          'Failed sending $relativePath file message to $room',
          subDomain: 'sendMatrixMsg',
        );
        return false;
      }

      sentEventRegistry.register(
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
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg',
      );
      return false;
    }
  }

  Future<SyncJournalEntity?> sendJournalEntityPayload({
    required Room room,
    required SyncJournalEntity message,
  }) async {
    final relativeJsonPath = p.joinAll(
      message.jsonPath.split('/').where((part) => part.isNotEmpty),
    );
    final jsonFullPath = p.join(documentsDirectory.path, relativeJsonPath);

    late final Uint8List jsonBytes;
    try {
      jsonBytes = await File(jsonFullPath).readAsBytes();
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION readJsonFile path=$jsonFullPath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    final jsonSent = await sendFile(
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
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.decode',
      );
      return null;
    }

    final shouldResendAttachments = await journalDb.getConfigFlag(
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
          loggingService,
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
        loggingService,
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
        loggingService,
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
            documentsDirectory,
          );
          final sent = await sendFile(
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
            documentsDirectory: documentsDirectory.path,
          );
          final sent = await sendFile(
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

  Future<SyncNotification?> sendNotificationPayload({
    required Room room,
    required SyncNotification message,
  }) async {
    final relativeJsonPath = p.joinAll(
      message.jsonPath.split('/').where((part) => part.isNotEmpty),
    );
    final jsonFullPath = p.join(documentsDirectory.path, relativeJsonPath);

    late final Uint8List jsonBytes;
    try {
      jsonBytes = await File(jsonFullPath).readAsBytes();
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION readNotificationJsonFile path=$jsonFullPath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.notification',
      );
      return null;
    }

    final jsonSent = await sendFile(
      room: room,
      fullPath: jsonFullPath,
      relativePath: message.jsonPath,
      bytes: jsonBytes,
    );
    if (!jsonSent) return null;

    late final NotificationEntity notification;
    try {
      notification = NotificationEntity.fromJson(
        json.decode(utf8.decode(jsonBytes)) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.notification.decode',
      );
      return null;
    }

    var outbound = message;
    final jsonVectorClock = notification.meta.vectorClock;
    final status = VectorClock.compare(jsonVectorClock, message.vectorClock);
    if (status != VclockStatus.equal) {
      final covered = VectorClock.mergeUniqueClocks([
        ...?message.coveredVectorClocks,
        message.vectorClock,
        jsonVectorClock,
      ]);
      outbound = message.copyWith(
        vectorClock: jsonVectorClock,
        coveredVectorClocks: covered,
      );
      logVectorClockAssignment(
        loggingService,
        subDomain: 'send.notification.adoptJson',
        action: 'assign',
        type: 'SyncNotification',
        entryId: message.id,
        jsonPath: message.jsonPath,
        reason: 'json_mismatch',
        previous: message.vectorClock,
        assigned: jsonVectorClock,
        coveredVectorClocks: covered,
        extras: {'status': status},
      );
    }

    final ensuredCovered = VectorClock.mergeUniqueClocks([
      ...?outbound.coveredVectorClocks,
      outbound.vectorClock,
    ]);
    if (ensuredCovered != outbound.coveredVectorClocks) {
      final currentClock = outbound.vectorClock;
      outbound = outbound.copyWith(coveredVectorClocks: ensuredCovered);
      logVectorClockAssignment(
        loggingService,
        subDomain: 'send.notification.ensureCovered',
        action: 'assign',
        type: 'SyncNotification',
        entryId: outbound.id,
        jsonPath: outbound.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: currentClock,
        coveredVectorClocks: ensuredCovered,
      );
    }

    return outbound;
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
  Future<SyncMessage?> enrichAndUploadAgentPayload({
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
      default:
        return message;
    }

    var enrichedPath = jsonPath;
    // Enrich legacy items that lack jsonPath but have inline payload
    if (enrichedPath == null && inlineJson != null) {
      final id = switch (message) {
        final SyncAgentEntity m => m.agentEntity!.id,
        final SyncAgentLink m => m.agentLink!.id,
        _ => throw StateError('unreachable'),
      };
      enrichedPath = pathBuilder(id);
      await _savePayloadToDisk(
        relativePath: enrichedPath,
        jsonPayload: inlineJson,
      );
    }

    if (enrichedPath == null) {
      loggingService.log(
        LogDomain.sync,
        'skipping $logLabel send: missing payload and jsonPath',
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
      _ => throw StateError('unreachable'),
    };
  }

  /// Reads the JSON file at [relativePath] from disk and uploads it via
  /// [sendFile]. Returns true on success, false on failure.
  Future<bool> _uploadAgentPayload({
    required Room room,
    required String relativePath,
    required String logLabel,
  }) async {
    final relativeJoined = p.joinAll(
      relativePath.split('/').where((part) => part.isNotEmpty),
    );
    final fullPath = p.join(documentsDirectory.path, relativeJoined);

    late final Uint8List jsonBytes;
    try {
      jsonBytes = await File(fullPath).readAsBytes();
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.$logLabel',
      );
      return false;
    }

    return sendFile(
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
    final fullPath = p.join(documentsDirectory.path, relativeJoined);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonPayload);
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
  /// [sendJournalEntityPayload] does for individually-sent entities.
  ///
  /// Inline-payload children (`SyncEntryLink`, `SyncAiConfig`,
  /// `SyncAiConfigDelete`, `SyncEntityDefinition`, `SyncThemingSelection`,
  /// `SyncBackfillRequest`, `SyncBackfillResponse`) need no separate payload —
  /// the freezed envelope already carries everything. Agent envelopes
  /// (`SyncAgentEntity`, `SyncAgentLink`) keep their inline data fields
  /// populated by upstream writers, so they ride along in the envelope
  /// unchanged.
  Future<SyncOutboxBundle?> sendOutboxBundlePayload({
    required Room room,
    required SyncOutboxBundle message,
  }) async {
    if (message.children.isEmpty) {
      loggingService.log(
        LogDomain.sync,
        'skipping empty outboxBundle send',
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
      loggingService.log(
        LogDomain.sync,
        'rejecting outboxBundle jsonPath outside /outbox_bundles/: '
        '$candidatePath — falling back to a fresh UUID path',
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
        : await journalDb.journalEntityMapForIds(journalEntityIds);

    final host = await vectorClockService?.getHost();

    // Track journal-entity children whose DB row vanished between enqueue
    // and dequeue (rare, but possible if the entity was deleted locally
    // mid-flight). Silently dropping such children would let the bundle
    // ack while one entity never reaches peers — permanent data loss.
    // Failing the whole bundle drops to the existing retry path; once the
    // row caps out it ends up in `error` status so an operator can
    // investigate, exactly like a standalone send with a missing entity.
    final missingJournalEntityIds = <String>[];

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
      if (reconciled is SyncJournalEntity) {
        final entity = journalEntityById[reconciled.id];
        if (entity == null) {
          missingJournalEntityIds.add(reconciled.id);
          continue;
        }
        record['payload'] = entity.toJson();
      }
      entries.add(record);
    }

    if (missingJournalEntityIds.isNotEmpty) {
      loggingService.error(
        LogDomain.sync,
        'outboxBundle aborting: '
        '${missingJournalEntityIds.length} journal entity '
        'payload(s) missing from DB '
        '(ids=$missingJournalEntityIds) — '
        'failing the bundle so the row stays pending and the standard '
        'retry/cap path surfaces the rotten entry instead of silently '
        'dropping it from the manifest',
        subDomain: 'sendMatrixMsg.outboxBundle.missingEntity',
      );
      return null;
    }

    final manifest = <String, dynamic>{
      'version': SyncTuning.outboxBundleManifestVersion,
      'entries': entries,
    };

    Uint8List gzipped;
    try {
      // Run json.encode + utf8.encode + gzip on a worker isolate so a
      // bundle of up to [SyncTuning.outboxBundleMaxSize] entities does not
      // stall the UI thread for the duration of the encode pipeline.
      gzipped = await gzipEncode(manifest);
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.outboxBundle.encode',
      );
      return null;
    }

    if (gzipped.length > SyncTuning.outboxBundleMaxBytes) {
      loggingService.error(
        LogDomain.sync,
        'outboxBundle exceeds max bytes: '
        'gzipped=${gzipped.length} '
        'max=${SyncTuning.outboxBundleMaxBytes} '
        'children=${message.children.length}',
        subDomain: 'sendMatrixMsg.outboxBundle.tooLarge',
      );
      return null;
    }

    // Wire display name carries `.gz` to hint at the compressed bytes —
    // the canonical compression signal is still the encoding header. The
    // `relativePath` keeps the on-disk extension (`.json`) so the receiver's
    // post-decode cache file at the same path matches its content; mirrors
    // what `sendFile` does for compressed agent payloads.
    final fileName =
        '${p.basename(relativePath.split('/').where((s) => s.isNotEmpty).last)}.gz';
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
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.outboxBundle.upload',
      );
      return null;
    }

    if (uploadEventId == null) {
      _trace(
        'FAIL outboxBundle.upload returned null path=$relativePath '
        'gzippedBytes=${gzipped.length}',
        subDomain: 'matrix.send.error',
      );
      loggingService.log(
        LogDomain.sync,
        'Failed sending outboxBundle file message to $room',
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    sentEventRegistry.register(uploadEventId, source: SentEventSource.file);

    return message.copyWith(
      jsonPath: relativePath,
      children: const [],
    );
  }

  /// Returns true when [relativePath] is a well-formed
  /// `/outbox_bundles/<id>.json` path with no traversal segments. Used by
  /// [sendOutboxBundlePayload] to gate which inbound `jsonPath` values are
  /// honoured for a freshly built bundle's metadata.
  /// Test seam for the path-safety predicate guarding bundle child reads.
  @visibleForTesting
  static bool debugIsSafeOutboxBundlePath(String relativePath) =>
      _isSafeOutboxBundlePath(relativePath);

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
  /// [sendJournalEntityPayload].
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
              loggingService,
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
            loggingService,
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
            loggingService,
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

    if (child is SyncEntryLink) {
      // Mirror the standalone entry-link send path in `sendMatrixMessage`:
      // the link's own vector clock must be folded into
      // `coveredVectorClocks` before dispatch, otherwise bundled and
      // unbundled deliveries produce divergent sequence metadata and
      // `recordReceivedEntryLink` cannot do gap detection consistently.
      final covered = VectorClock.mergeUniqueClocks([
        ...?child.coveredVectorClocks,
        child.entryLink.vectorClock,
      ]);
      final originating = child.originatingHostId ?? host;
      if (covered == child.coveredVectorClocks &&
          originating == child.originatingHostId) {
        return child;
      }
      return child.copyWith(
        originatingHostId: originating,
        coveredVectorClocks: covered,
      );
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

    if (child is SyncNotificationStateUpdate &&
        child.originatingHostId.isEmpty &&
        host != null) {
      return child.copyWith(originatingHostId: host);
    }

    if (child is SyncConfigFlag &&
        child.originatingHostId == null &&
        host != null) {
      return child.copyWith(originatingHostId: host);
    }

    return child;
  }
}
