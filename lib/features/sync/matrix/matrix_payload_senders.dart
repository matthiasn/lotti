part of 'matrix_message_sender.dart';

/// Attachment/file payload senders of [MatrixMessageSender]: file
/// upload, journal-entity, notification, and agent payloads. All
/// members are library-private; the class-side ForTesting wrappers
/// remain the public seams.
extension MatrixPayloadSenders on MatrixMessageSender {
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
        _loggingService.log(
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
        _loggingService.log(
          LogDomain.sync,
          'Failed sending $relativePath file message to $room',
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
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg',
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
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg',
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
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.decode',
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

  Future<SyncNotification?> _sendNotificationPayload({
    required Room room,
    required SyncNotification message,
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
        'EXCEPTION readNotificationJsonFile path=$jsonFullPath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.notification',
      );
      return null;
    }

    final jsonSent = await _sendFile(
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
      _loggingService.error(
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
        _loggingService,
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
        _loggingService,
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
      _loggingService.log(
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
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.$logLabel',
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
}
