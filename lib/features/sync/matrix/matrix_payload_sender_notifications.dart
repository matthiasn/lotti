part of 'matrix_payload_sender.dart';

/// Notification and agent payload encoding for [MatrixPayloadSender].
///
/// A public extension (not a private one) because [MatrixMessageSender]
/// in a sibling library delegates [sendNotificationPayload] and
/// [enrichAndUploadAgentPayload] to these methods; the two private helpers
/// stay library-private.
extension MatrixPayloadSenderNotifications on MatrixPayloadSender {
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

    final jsonUpload = await _sendFile(
      room: room,
      fullPath: jsonFullPath,
      relativePath: message.jsonPath,
      bytes: jsonBytes,
    );
    final attachmentEventId = jsonUpload.eventId;
    if (!jsonUpload.succeeded || attachmentEventId == null) return null;

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

    var outbound = message.copyWith(attachmentEventId: attachmentEventId);
    final jsonVectorClock = notification.meta.vectorClock;
    final status = VectorClock.compare(jsonVectorClock, message.vectorClock);
    if (status != VclockStatus.equal) {
      final covered = VectorClock.mergeUniqueClocks([
        ...?message.coveredVectorClocks,
        message.vectorClock,
        jsonVectorClock,
      ]);
      outbound = outbound.copyWith(
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
    // A sidecar this send had to rebuild is deleted again once it is up: the
    // row was queued for an entity retention or a hard delete already
    // reclaimed, so leaving the file behind would silently undo that
    // reclamation and keep deleted agent data readable on disk.
    var restoredForThisSend = false;
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
    } else if (enrichedPath != null &&
        inlineJson != null &&
        !_payloadExists(enrichedPath)) {
      restoredForThisSend = true;
      // The path is declared but the file is gone. Sidecar reclamation can
      // take a file while a row referencing it is still queued — a hard
      // delete and a pending send race by design — and without this the
      // upload fails on a read that can never succeed, so the row retries
      // until it ages out. The row still carries the payload inline, so
      // rewrite the file rather than failing the send.
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
      inlineJson: inlineJson,
    );
    // Clean up whether or not the upload succeeded. On failure the row is
    // retried, and the retry would find the file already present, leave
    // `restoredForThisSend` false, and never remove it — so a single failed
    // attempt would permanently undo the reclamation.
    if (restoredForThisSend) {
      await _deletePayloadFromDisk(enrichedPath);
    }
    if (uploaded == null) return null;

    return switch (message) {
      // Agent entities can be large — strip inline, use file only.
      final SyncAgentEntity m => m.copyWith(
        jsonPath: enrichedPath,
        attachmentEventId: uploaded,
        agentEntity: null,
      ),
      // Agent links are small (like entry links) — keep inline for
      // reliable sync, avoiding race conditions with file downloads.
      final SyncAgentLink m => m.copyWith(
        jsonPath: enrichedPath,
        attachmentEventId: uploaded,
      ),
      _ => throw StateError('unreachable'),
    };
  }

  /// Reads the JSON file at [relativePath] from disk and uploads it via
  /// [_sendFile]. Returns the exact attachment event id on success.
  Future<String?> _uploadAgentPayload({
    required Room room,
    required String relativePath,
    required String logLabel,
    required String? inlineJson,
  }) async {
    final fullPath = _resolveSidecarPath(relativePath);
    if (fullPath == null) {
      loggingService.log(
        LogDomain.sync,
        'refusing $logLabel send: jsonPath escapes the documents directory',
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    late final Uint8List jsonBytes;
    try {
      jsonBytes = inlineJson == null
          ? await File(fullPath).readAsBytes()
          : Uint8List.fromList(utf8.encode(inlineJson));
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.$logLabel',
      );
      return null;
    }

    final upload = await _sendFile(
      room: room,
      fullPath: fullPath,
      relativePath: relativePath,
      bytes: jsonBytes,
    );
    return upload.succeeded ? upload.eventId : null;
  }

  /// Removes a sidecar this send rebuilt, so restoring it for the upload does
  /// not resurrect a file reclamation deleted. Best-effort: the send already
  /// succeeded and a failure here must not fail it.
  Future<void> _deletePayloadFromDisk(String relativePath) async {
    try {
      final full = _resolveSidecarPath(relativePath);
      if (full == null) return;
      final file = File(full);
      if (file.existsSync()) file.deleteSync();
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg',
      );
    }
  }

  /// Resolves a sidecar path under the documents directory, or null when it
  /// would escape it.
  ///
  /// `jsonPath` arrives on synced messages, so it is untrusted. `joinAll`
  /// drops empty segments but keeps `..`, so a crafted path would otherwise
  /// resolve outside the documents directory — and these helpers read, write
  /// and delete through it.
  String? _resolveSidecarPath(String relativePath) {
    final segments = relativePath
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (segments.contains('..')) return null;
    final full = p.normalize(
      p.join(documentsDirectory.path, p.joinAll(segments)),
    );
    if (!p.isWithin(documentsDirectory.path, full)) return null;
    return full;
  }

  /// Whether the sidecar at [relativePath] is still on disk.
  bool _payloadExists(String relativePath) {
    final full = _resolveSidecarPath(relativePath);
    return full != null && File(full).existsSync();
  }

  /// Writes a payload to disk under the documents directory, creating parent
  /// directories as needed. Used to enrich legacy outbox items that lack a
  /// `jsonPath`, and to restore a sidecar reclamation removed while a row
  /// referencing it was still queued.
  Future<void> _savePayloadToDisk({
    required String relativePath,
    required String jsonPayload,
  }) async {
    final fullPath = _resolveSidecarPath(relativePath);
    if (fullPath == null) {
      loggingService.log(
        LogDomain.sync,
        'refusing to write a sidecar outside the documents directory',
        subDomain: 'sendMatrixMsg',
      );
      return;
    }
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    // Write-then-rename. A process kill or a failure part-way through
    // `writeAsString` would otherwise leave a truncated sidecar in place, and
    // the retry's existence check would accept it and upload the corrupt
    // bytes — after which the inline payload is stripped and the good copy is
    // gone. A rename is atomic, so the destination is either absent or whole.
    final staged = File('$fullPath.tmp');
    await staged.writeAsString(jsonPayload, flush: true);
    await staged.rename(file.path);
  }
}
