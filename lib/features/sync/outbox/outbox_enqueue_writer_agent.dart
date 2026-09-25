part of 'outbox_enqueue_writer.dart';

/// Agent entity/link/payload enqueue and sent-record bookkeeping for
/// [OutboxEnqueueWriter]. Public extension so cross-library callers keep
/// invoking these on an [OutboxEnqueueWriter] instance.
extension OutboxEnqueueAgent on OutboxEnqueueWriter {
  // ---------------------------------------------------------------------------
  // Agent entity/link enqueue + sent-record bookkeeping
  // ---------------------------------------------------------------------------

  /// Enqueues an agent entity by writing its payload to disk and routing
  /// through [enqueueAgentPayload]. Skips (logs and returns) when the
  /// message carries no entity.
  Future<void> enqueueAgentEntity({
    required SyncAgentEntity msg,
    required OutboxCompanion commonFields,
  }) async {
    final entity = msg.agentEntity;
    if (entity == null) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip agentEntity is null',
        subDomain: 'enqueueMessage',
      );
      return;
    }
    return enqueueAgentPayload(
      id: entity.id,
      payloadJson: json.encode(entity.toJson()),
      relativePath: relativeAgentEntityPath(entity.id),
      enrichedMessage: msg.copyWith(
        jsonPath: relativeAgentEntityPath(entity.id),
      ),
      subjectPrefix: 'agentEntity',
      typeName: 'SyncAgentEntity',
      commonFields: commonFields,
      vectorClock: entity.vectorClock,
      payloadType: SyncSequencePayloadType.agentEntity,
    );
  }

  /// Enqueues an agent link by writing its payload to disk and routing through
  /// [enqueueAgentPayload]. Skips (logs and returns) when the message
  /// carries no link.
  Future<void> enqueueAgentLink({
    required SyncAgentLink msg,
    required OutboxCompanion commonFields,
  }) async {
    final link = msg.agentLink;
    if (link == null) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip agentLink is null',
        subDomain: 'enqueueMessage',
      );
      return;
    }
    return enqueueAgentPayload(
      id: link.id,
      payloadJson: json.encode(link.toJson()),
      relativePath: relativeAgentLinkPath(link.id),
      enrichedMessage: msg.copyWith(jsonPath: relativeAgentLinkPath(link.id)),
      subjectPrefix: 'agentLink',
      typeName: 'SyncAgentLink',
      commonFields: commonFields,
      vectorClock: link.vectorClock,
      payloadType: SyncSequencePayloadType.agentLink,
    );
  }

  /// Shared implementation for enqueuing agent entities and links.
  /// Saves [payloadJson] to disk and appends a row carrying
  /// [enrichedMessage] for this version. Rows are never merged; the processor
  /// collapses an id's pending rows when it sends (ADR 0086). Records sent
  /// entries in the sequence log when a [vectorClock] is provided.
  Future<void> enqueueAgentPayload({
    required String id,
    required String payloadJson,
    required String relativePath,
    required SyncMessage enrichedMessage,
    required String subjectPrefix,
    required String typeName,
    required OutboxCompanion commonFields,
    required VectorClock? vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    final relativeJoined = p.joinAll(
      relativePath.split('/').where((part) => part.isNotEmpty),
    );
    final docsRoot = p.normalize(_documentsDirectory.path);
    final fullPath = p.normalize(p.join(docsRoot, relativeJoined));
    final subject = '$subjectPrefix:$id';

    if (!p.isWithin(docsRoot, fullPath)) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip invalid agent payload path: $relativePath',
        subDomain: 'enqueueMessage',
      );
      return;
    }

    try {
      await _saveJson(fullPath, payloadJson);
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'enqueueMessage.saveAgentPayload',
      );
      // Fallback: enqueue with inline payload so the sender's legacy
      // enrichment path can write the file and upload on retry.
      await _syncDatabase.addOutboxItem(
        commonFields.copyWith(
          subject: Value(subject),
          outboxEntryId: Value(id),
        ),
      );
      return;
    }

    final outboxAgentJson = json.encode(enrichedMessage.toJson());
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(subject),
        message: Value(outboxAgentJson),
        outboxEntryId: Value(id),
        payloadSize: Value(utf8.encode(outboxAgentJson).length),
      ),
    );
    _logEnqueueSample(
      'enqueue type=$typeName subject=$subject',
      sampleKey: 'insert.$typeName',
    );

    // Record in sequence log for backfill support (self-healing sync)
    await recordAgentSent(
      entryId: id,
      vectorClock: vectorClock,
      payloadType: payloadType,
    );
  }

  /// Records an agent entity or link in the sequence log.
  Future<void> recordAgentSent({
    required String entryId,
    required VectorClock? vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    if (_sequenceLogService != null && vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          payloadType: payloadType,
        );
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'recordSent',
        );
      }
    }
  }

  /// Records a sent notification in the sequence log so peers can detect and
  /// backfill it if missed. No-op when no sequence-log service is wired;
  /// failures are logged and swallowed (the send itself still succeeds).
  Future<void> recordNotificationSent({
    required String entryId,
    required VectorClock vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    if (_sequenceLogService == null) return;
    try {
      await _sequenceLogService.recordSentEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        payloadType: payloadType,
      );
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'recordSent',
      );
    }
  }
}
