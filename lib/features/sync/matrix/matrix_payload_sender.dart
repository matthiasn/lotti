import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart'
    show MatrixMessageSender;
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/media/entry_media.dart';
import 'package:lotti/features/sync/model/sync_attachment_policy.dart';
import 'package:lotti/features/sync/model/sync_message_too_large_exception.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;

part 'matrix_payload_sender_notifications.dart';

typedef _FileSendResult = ({String? eventId, bool succeeded});

/// Attachment/file and outbox-bundle payload uploads for
/// [MatrixMessageSender].
///
/// Extracted into a standalone collaborator (previously two part-file
/// extensions) so the sender file stays under the size limit. The owning
/// sender constructs one of these from its own dependencies and delegates the
/// per-payload upload work to it; the sender keeps the wire envelope logic.
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
    final result = await _sendFile(
      room: room,
      fullPath: fullPath,
      relativePath: relativePath,
      bytes: bytes,
    );
    return result.succeeded;
  }

  Future<_FileSendResult> _sendFile({
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
        return (eventId: null, succeeded: true);
      }

      final fileBytes = bytes ?? await file.readAsBytes();

      final shouldCompress = relativePath.toLowerCase().endsWith('.json');
      if (shouldCompress &&
          fileBytes.length > SyncTuning.maxDecodedAttachmentBytes) {
        // Every receiver would refuse to inflate it; the same file is the
        // same size on every attempt, so this is permanent, not retryable.
        throw SyncMessageTooLargeException(
          'file $relativePath bytes=${fileBytes.length} '
          'max=${SyncTuning.maxDecodedAttachmentBytes}',
        );
      }
      final uploadBytes = shouldCompress
          ? await gzipEncodeBytes(fileBytes)
          : fileBytes;
      final baseName = p.basename(fullPath);
      final uploadName = shouldCompress ? '$baseName.gz' : baseName;
      final extraContent = <String, dynamic>{
        'relativePath': relativePath,
        if (shouldCompress) attachmentEncodingKey: attachmentEncodingGzip,
      };

      final eventId = await _sendVerifiedFile(
        room,
        MatrixFile(bytes: uploadBytes, name: uploadName),
        extraContent,
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
        return (eventId: null, succeeded: false);
      }

      sentEventRegistry.register(eventId);
      return (eventId: eventId, succeeded: true);
    } on SyncMessageTooLargeException {
      // Permanent: the outbox drops it instead of retrying the same bytes.
      rethrow;
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
      return (eventId: null, succeeded: false);
    }
  }

  /// Verifies the immutable wire descriptor before another message references
  /// it. An SDK upload can return an event id whose decrypted content is empty;
  /// acknowledging that upload would strand its payload on every receiver.
  Future<String?> _sendVerifiedFile(
    Room room,
    MatrixFile file,
    Map<String, dynamic> extraContent,
  ) async {
    final eventId = await room.sendFileEvent(file, extraContent: extraContent);
    if (eventId == null) return null;
    // The SDK cache may contain the intended local echo, rather than what was
    // actually encrypted and stored. Always read the exact server event.
    final remote = await room.client
        .getOneRoomEvent(room.id, eventId)
        .timeout(SyncTuning.attachmentDownloadTimeout);
    if (remote.eventId != eventId ||
        (remote.roomId != null && remote.roomId != room.id)) {
      throw StateError('Uploaded attachment event identity mismatch');
    }
    var descriptor = Event.fromMatrixEvent(remote, room);
    if (descriptor.type == EventTypes.Encrypted) {
      final encryption = room.client.encryption;
      if (encryption == null) {
        throw StateError('Uploaded attachment encryption is unavailable');
      }
      descriptor = await encryption
          .decryptRoomEvent(descriptor)
          .timeout(SyncTuning.attachmentDownloadTimeout);
    }
    final content = descriptor.content;
    final encryptedFile = content['file'];
    final url = encryptedFile is Map ? encryptedFile['url'] : content['url'];
    if (descriptor.type != EventTypes.Message ||
        content['msgtype'] != file.msgType ||
        content['relativePath'] != extraContent['relativePath'] ||
        content[attachmentEncodingKey] != extraContent[attachmentEncodingKey] ||
        (content.containsKey('file') &&
            !_hasValidEncryptedFileMetadata(encryptedFile)) ||
        url is! String ||
        !_hasValidMxcUri(url)) {
      throw StateError('Uploaded attachment descriptor is unusable');
    }
    return eventId;
  }

  /// Requires a server name and one media ID, without URI normalization hiding
  /// malformed paths. Uri parsing also rejects invalid bracketed IPv6 hosts.
  static bool _hasValidMxcUri(String value) =>
      RegExp(
        r'^mxc://(?:[A-Za-z0-9.-]+|\[[0-9A-Fa-f:.]+\])'
        r'(?::[0-9]+)?/[A-Za-z0-9_-]+$',
      ).hasMatch(value) &&
      Uri.tryParse(value) != null;

  /// Checks the v2 encryption metadata emitted by our SDK before acknowledging
  /// its upload. The ciphertext bytes and their hash are not downloaded here.
  static bool _hasValidEncryptedFileMetadata(Object? value) {
    if (value is! Map || value['v'] != 'v2') return false;
    final key = value['key'];
    final hashes = value['hashes'];
    if (key is! Map || hashes is! Map) return false;
    final operations = key['key_ops'];
    return key['alg'] == 'A256CTR' &&
        key['kty'] == 'oct' &&
        key['ext'] == true &&
        operations is List &&
        operations.every((operation) => operation is String) &&
        operations.contains('encrypt') &&
        operations.contains('decrypt') &&
        _hasBase64ByteLength(key['k'], 32) &&
        _hasBase64ByteLength(value['iv'], 16) &&
        _hasBase64ByteLength(hashes['sha256'], 32);
  }

  static bool _hasBase64ByteLength(Object? value, int expectedLength) {
    if (value is! String) return false;
    try {
      // normalize accepts the SDK's unpadded base64 and base64url forms.
      return base64.decode(base64.normalize(value)).length == expectedLength;
    } on FormatException {
      // Do not propagate a decoding error containing key/IV material to logs.
      return false;
    }
  }

  /// The entry's stored row. It must cover the queued version and every
  /// covered clock: a payload older than what was queued would cover a
  /// counter it does not carry (ADR 0086). Otherwise the send fails and the
  /// outbox retries it.
  Future<JournalEntity> _readJournalPayload(
    SyncJournalEntity message,
  ) async {
    final entities = await journalDb.journalEntityMapForIdsIncludingDeleted([
      message.id,
    ]);
    final entity = entities[message.id];
    if (entity == null) {
      throw StateError('No payload for queued journal entry ${message.id}');
    }
    if (_coversQueued(entity.meta.vectorClock, message)) return entity;
    // A deep-backfill answer or push may name a concurrent version the entry
    // keeps as an open conflict rather than as its row: serve exactly that
    // version. Such a message failed on every attempt before, so nothing the
    // app queued otherwise takes this branch.
    final queued = message.vectorClock;
    if (queued != null) {
      final conflict = await journalDb.openConflictVersion(message.id, queued);
      if (conflict != null) return conflict;
    }
    throw StateError('Database payload does not cover queued version');
  }

  bool _coversQueued(VectorClock? payloadClock, SyncJournalEntity message) {
    for (final queuedClock in [
      message.vectorClock,
      ...?message.coveredVectorClocks,
    ]) {
      if (queuedClock == null) continue;
      if (payloadClock == null ||
          !{
            VclockStatus.equal,
            VclockStatus.a_gt_b,
          }.contains(VectorClock.compare(payloadClock, queuedClock))) {
        return false;
      }
    }
    return true;
  }

  Future<SyncJournalEntity?> sendJournalEntityPayload({
    required Room room,
    required SyncJournalEntity message,
  }) async {
    final relativeJsonPath = p.joinAll(
      message.jsonPath.split('/').where((part) => part.isNotEmpty),
    );
    final jsonFullPath = p.join(documentsDirectory.path, relativeJsonPath);

    late final JournalEntity journalEntity;
    try {
      journalEntity = await _readJournalPayload(message);
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION readJournalPayload id=${message.id} '
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

    final jsonUpload = await _sendFile(
      room: room,
      fullPath: jsonFullPath,
      relativePath: message.jsonPath,
      bytes: Uint8List.fromList(
        utf8.encode(jsonEncode(journalEntity.toJson())),
      ),
    );

    final attachmentEventId = jsonUpload.eventId;
    if (!jsonUpload.succeeded || attachmentEventId == null) {
      return null;
    }

    final sendAttachments = shouldSendJournalAttachments(
      status: message.status,
      includeAttachments: message.includeAttachments,
      resendAttachmentsFlag: await journalDb.getConfigFlag(resendAttachments),
    );

    var attachmentsOk = true;

    final messageVectorClock = message.vectorClock;
    final jsonVectorClock = journalEntity.meta.vectorClock;
    var outbound = message.copyWith(attachmentEventId: attachmentEventId);
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
        outbound = outbound.copyWith(
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
      outbound = outbound.copyWith(
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

    final media = sendAttachments
        ? entryMedia(journalEntity, documentsDirectory: documentsDirectory)
        : null;
    if (media != null) {
      final sent = await sendFile(
        room: room,
        fullPath: media.file.path,
        relativePath: media.relativePath,
      );
      attachmentsOk = attachmentsOk && sent;
    }

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
  /// bundle is empty or the upload fails, and throws
  /// [SyncMessageTooLargeException] when the manifest exceeds the size cap.
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
        : await journalDb.journalEntityMapForIdsIncludingDeleted(
            journalEntityIds,
          );

    final host = await vectorClockService?.getHost();

    // A child whose queued version the row does not cover names a concurrent
    // version the entry keeps as an open conflict (a deep-backfill answer or
    // push): serve exactly that version, as a standalone send does, instead
    // of adopting the row's clock. Only such children cost a lookup.
    final conflictVersionAt = <int, JournalEntity>{};
    for (var index = 0; index < message.children.length; index++) {
      final child = message.children[index];
      if (child is! SyncJournalEntity) continue;
      final row = journalEntityById[child.id];
      final queued = child.vectorClock;
      if (row == null ||
          queued == null ||
          _coversQueued(row.meta.vectorClock, child)) {
        continue;
      }
      final conflict = await journalDb.openConflictVersion(child.id, queued);
      if (conflict != null) conflictVersionAt[index] = conflict;
    }

    // Track journal-entity children whose DB row was hard-purged between
    // enqueue and dequeue. Soft-deleted rows are deliberately included above
    // because their tombstones must sync. Silently dropping a hard-missing
    // child would let the bundle
    // ack while one entity never reaches peers — permanent data loss.
    // Failing the whole bundle drops to the existing retry path; once the
    // row caps out it ends up in `error` status so an operator can
    // investigate, exactly like a standalone send with a missing entity.
    final missingJournalEntityIds = <String>[];

    final entries = <Map<String, dynamic>>[];
    final journalChildren = <SyncJournalEntity>[];
    for (var index = 0; index < message.children.length; index++) {
      final child = message.children[index];
      final conflict = conflictVersionAt[index];
      final reconciled = conflict != null && child is SyncJournalEntity
          ? (child.originatingHostId == null && host != null
                ? child.copyWith(originatingHostId: host)
                : child)
          : _reconcileBundleChildEnvelope(
              child,
              host: host,
              journalEntityById: journalEntityById,
            );
      final record = <String, dynamic>{
        'envelope': reconciled.toJson(),
      };
      if (reconciled is SyncJournalEntity) {
        final entity = conflict ?? journalEntityById[reconciled.id];
        if (entity == null) {
          missingJournalEntityIds.add(reconciled.id);
          continue;
        }
        record['payload'] = entity.toJson();
        journalChildren.add(reconciled);
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

    // Defence in depth for the bundling boundary. Rows carrying media are
    // supposed to be excluded from bundles at claim time (`filePath != null`
    // makes a row travel alone), so this loop is normally a no-op. Should a
    // media-bearing child slip through anyway — a row enqueued by an older
    // build before the attachment decision moved to enqueue time, say — the
    // manifest alone would leave the peer with an unrenderable entry. Upload
    // the blobs rather than silently dropping them.
    if (!await _sendBundleChildAttachments(
      room: room,
      children: journalChildren,
      journalEntityById: journalEntityById,
    )) {
      return null;
    }

    final manifest = <String, dynamic>{
      'version': SyncTuning.outboxBundleManifestVersion,
      'entries': entries,
    };

    final uploadEventId = await _uploadGzippedJson(
      room: room,
      relativePath: relativePath,
      document: manifest,
      label: 'outboxBundle',
      detail: 'children=${message.children.length}',
    );
    if (uploadEventId == null) return null;

    return message.copyWith(
      jsonPath: relativePath,
      attachmentEventId: uploadEventId,
      children: const [],
    );
  }

  /// Gzips [document], uploads it as a verified file event under
  /// [relativePath] and registers the event as sent. Returns the event id,
  /// or null after logging when encoding or the upload fails. Throws
  /// [SyncMessageTooLargeException] when the gzipped document exceeds
  /// [SyncTuning.outboxBundleMaxBytes]. [label] names the payload in log
  /// sub-domains and in that exception; [detail] describes it there.
  Future<String?> _uploadGzippedJson({
    required Room room,
    required String relativePath,
    required Map<String, dynamic> document,
    required String label,
    required String detail,
  }) async {
    Uint8List gzipped;
    try {
      // Run json.encode + utf8.encode + gzip on a worker isolate so a
      // large document (a bundle of up to [SyncTuning.outboxBundleMaxSize]
      // entities, a deep-backfill batch) does not stall the UI thread.
      gzipped = await gzipEncode(document);
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.$label.encode',
      );
      return null;
    }

    if (gzipped.length > SyncTuning.outboxBundleMaxBytes) {
      // The same document gzips to the same size on every attempt: retrying
      // cannot help, so the outbox gets a typed signal rather than `null`.
      throw SyncMessageTooLargeException(
        '$label gzipped=${gzipped.length} '
        'max=${SyncTuning.outboxBundleMaxBytes} $detail',
      );
    }
    // Receivers refuse to inflate past this limit, so a document that
    // compresses under the wire cap but would inflate beyond it is just as
    // undeliverable — the outbox falls back to its smaller parts.
    final decodedLength = gzipDecodedLength(gzipped);
    if (decodedLength > SyncTuning.maxDecodedAttachmentBytes) {
      throw SyncMessageTooLargeException(
        '$label decoded=$decodedLength '
        'max=${SyncTuning.maxDecodedAttachmentBytes} $detail',
      );
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
      uploadEventId = await _sendVerifiedFile(
        room,
        MatrixFile(bytes: gzipped, name: fileName),
        extraContent,
      );
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION $label.upload path=$relativePath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.$label.upload',
      );
      return null;
    }

    if (uploadEventId == null) {
      _trace(
        'FAIL $label.upload returned null path=$relativePath '
        'gzippedBytes=${gzipped.length}',
        subDomain: 'matrix.send.error',
      );
      loggingService.log(
        LogDomain.sync,
        'Failed sending $label file message to $room',
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    sentEventRegistry.register(uploadEventId);
    return uploadEventId;
  }

  /// Moves the record lists of a deep-backfill inventory or request into a
  /// gzipped attachment and returns the envelope that names it, its lists
  /// emptied. A batch of thousands of records would not fit a Matrix text
  /// event; inside an outbox bundle the lists ride inline instead, in the
  /// bundle's own gzipped manifest, so this runs only for a message sent on
  /// its own. Returns [message] unchanged for any other type, and null when
  /// the upload fails. Throws [SyncMessageTooLargeException] when the
  /// gzipped lists exceed `SyncTuning.outboxBundleMaxBytes`.
  Future<SyncMessage?> sendDeepBackfillPayload({
    required Room room,
    required SyncMessage message,
  }) async {
    final Map<String, dynamic> document;
    final String detail;
    switch (message) {
      case SyncDeepBackfillInventory(
        :final records,
        :final conflicts,
        :final unclocked,
        :final unclockedMediaSizes,
      ):
        document = {
          'records': [for (final r in records) r.toJson()],
          'conflicts': [for (final c in conflicts) c.toJson()],
          'unclocked': unclocked,
          'unclockedMediaSizes': unclockedMediaSizes,
        };
        detail =
            'records=${records.length} conflicts=${conflicts.length} '
            'unclocked=${unclocked.length}';
      case SyncDeepBackfillRequest(:final records):
        document = {
          'records': [for (final r in records) r.toJson()],
        };
        detail = 'records=${records.length}';
      default:
        return message;
    }
    final relativePath = relativeDeepBackfillPath(uuid.v1());
    final eventId = await _uploadGzippedJson(
      room: room,
      relativePath: relativePath,
      document: document,
      label: 'deepBackfill',
      detail: detail,
    );
    if (eventId == null) return null;
    return switch (message) {
      final SyncDeepBackfillInventory m => m.copyWith(
        jsonPath: relativePath,
        attachmentEventId: eventId,
        records: const [],
        conflicts: const [],
        unclocked: const [],
        unclockedMediaSizes: const {},
      ),
      final SyncDeepBackfillRequest m => m.copyWith(
        jsonPath: relativePath,
        attachmentEventId: eventId,
        records: const [],
      ),
      _ => message,
    };
  }

  /// Uploads the media blob of any bundle child whose payload asks for it,
  /// returning false when an upload fails so the caller can fail the whole
  /// bundle into the standard retry path.
  ///
  /// Children that carry no media, or whose payload sends JSON only (the
  /// overwhelmingly common case — an ordinary edit), cost one policy check and
  /// no I/O. A missing file on disk is not a failure: [sendFile] logs and
  /// reports success, so a rotten local blob cannot wedge the bundle in a
  /// retry loop.
  Future<bool> _sendBundleChildAttachments({
    required Room room,
    required List<SyncJournalEntity> children,
    required Map<String, JournalEntity> journalEntityById,
  }) async {
    if (children.isEmpty) return true;

    bool? resendFlag;
    for (final child in children) {
      // The type test and the path resolution are one step (entryMedia), so
      // there is no unreachable "has media but is neither" branch to carry.
      final entity = journalEntityById[child.id];
      final media = entity == null
          ? null
          : entryMedia(entity, documentsDirectory: documentsDirectory);
      if (media == null) continue;

      // Read the flag lazily: bundles are text-only in the normal case, so
      // most sends never need it.
      resendFlag ??= await journalDb.getConfigFlag(resendAttachments);
      if (!shouldSendJournalAttachments(
        status: child.status,
        includeAttachments: child.includeAttachments,
        resendAttachmentsFlag: resendFlag,
      )) {
        continue;
      }

      loggingService.log(
        LogDomain.sync,
        'outboxBundle child carries media id=${child.id} — uploading the '
        'blob alongside the manifest',
        subDomain: 'sendMatrixMsg.outboxBundle.attachment',
      );

      final sent = await sendFile(
        room: room,
        fullPath: media.file.path,
        relativePath: media.relativePath,
      );
      if (!sent) return false;
    }
    return true;
  }

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
