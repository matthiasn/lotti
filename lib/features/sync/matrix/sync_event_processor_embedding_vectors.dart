part of 'sync_event_processor.dart';

/// Receiving `SyncMessage.embeddingVectors`: the attachment is resolved in
/// prepare, the version handed to the AI feature's sink in apply, and its
/// receipt recorded whatever the sink made of it (ADR 0149).
extension SyncEventProcessorEmbeddingVectors on SyncEventProcessor {
  /// The JSON of [msg]'s vectors attachment, or `null` for a tombstone and
  /// for a version sent without one (the sender's file was gone: an exact
  /// copy had already gone out, or a newer version had replaced it).
  ///
  /// Read from the attachment's descriptor, never from disk, so a receiver
  /// keeps no file per version. Throws [FileSystemException] while the
  /// descriptor has not arrived, so the queue retries.
  Future<String?> _resolveEmbeddingVectorsPayload(
    SyncEmbeddingVectors msg,
  ) async {
    final jsonPath = msg.jsonPath;
    final attachmentEventId = msg.attachmentEventId;
    if (msg.deleted || jsonPath == null || attachmentEventId == null) {
      return null;
    }
    final File file;
    try {
      file = _resolveJsonCandidateFile(jsonPath);
    } on FileSystemException {
      throw const UnrecoverableSyncPayloadException('embeddingVectors');
    }
    final fetched = await _fetchFromDescriptor(
      jsonPath: jsonPath,
      targetFile: file,
      typeName: 'embeddingVectors',
      attachmentEventId: attachmentEventId,
      writeToDisk: false,
    );
    if (fetched == null) {
      throw FileSystemException(
        'attachment descriptor not yet available for embeddingVectors',
        jsonPath,
      );
    }
    return fetched;
  }

  /// Hands [msg] to the sink, then records its receipt (and those of the
  /// versions it covers). A device that does not store vectors — the flags
  /// off, a platform without the pipeline — records the receipt alone; it
  /// catches up once it can store (ADR 0149).
  Future<void> _applyEmbeddingVectors({
    required SyncEmbeddingVectors msg,
    required String? payload,
  }) async {
    final vectors = embeddingVectors;
    final sink = vectors?.sink;
    if (sink == null && vectors != null && await vectors.awaitsPipeline) {
      // Retried, and past the retry cap kept as a skipped event that can be
      // retried again: the pipeline attaches moments after start.
      throw StateError('embedding pipeline not attached yet');
    }
    if (sink != null) {
      await sink.apply(
        IncomingEmbeddingVersion(
          register: embeddingRegisterOf(msg),
          payload: payload,
        ),
      );
    }
    await _recordReceivedEmbeddingVectors(msg);
  }

  Future<void> _recordReceivedEmbeddingVectors(
    SyncEmbeddingVectors msg,
  ) async {
    final sequenceLog = _sequenceLogService;
    if (sequenceLog == null) return;
    try {
      final gaps = await sequenceLog.recordReceivedEntry(
        entryId: msg.id,
        vectorClock: msg.vectorClock,
        originatingHostId: msg.originatingHostId,
        coveredVectorClocks: msg.coveredVectorClocks,
        payloadType: SyncSequencePayloadType.embeddingVectors,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.embeddingVectors.gapsDetected count=${gaps.length}',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.recordReceivedEmbeddingVectors',
      );
      rethrow;
    }
  }

  /// Tells the sink that a dependency of held versions was applied. Never
  /// throws: a failed re-check leaves the version held for the next one.
  Future<void> _notifyEmbeddingDependency(
    Future<void> Function(SyncedEmbeddingSink sink) notify,
  ) async {
    final sink = embeddingVectors?.sink;
    if (sink == null) return;
    try {
      await notify(sink);
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.embeddingVectors.recheck',
      );
    }
  }
}

/// The register version [msg] carries.
EmbeddingRegister embeddingRegisterOf(SyncEmbeddingVectors msg) =>
    EmbeddingRegister(
      entityId: msg.entityId,
      modelId: msg.modelId,
      entityType: msg.entityType,
      contentHash: msg.contentHash,
      vectorClock: msg.vectorClock,
      sourceVectorClock: msg.sourceVectorClock,
      deleted: msg.deleted,
      taskId: msg.taskId ?? '',
      subtype: msg.subtype ?? '',
      originatingHostId: msg.originatingHostId,
    );
