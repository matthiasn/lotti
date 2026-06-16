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
}
