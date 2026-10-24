part of 'sync_event_processor.dart';

/// Download/decode failed before any local cache write was attempted.
class _SyncDescriptorFetchException extends FileSystemException {
  const _SyncDescriptorFetchException(super.message, super.path);
}

/// Descriptor-driven attachment fetching with in-flight deduplication —
/// shared by the agent payload resolution and the outbox bundle resolver.
extension _DescriptorCache on SyncEventProcessor {
  /// Rebuilds an exact descriptor after a restart or a missed file event.
  /// Unavailable descriptors request periodic recovery, even for aged rows.
  ///
  /// The lookup itself goes through [SyncDescriptorFetcher], so this runs
  /// without a live `Room` (ADR 0142, step 3): the fetcher answers from
  /// whichever isolate holds the Matrix client.
  Future<bool> _recoverMissingDescriptor(
    SyncEnvelope envelope,
    SyncMessage message,
    FileSystemException error,
  ) async {
    final (id, path) = switch (message) {
      SyncJournalEntity(:final attachmentEventId, :final jsonPath) => (
        attachmentEventId,
        jsonPath,
      ),
      SyncAgentEntity(:final attachmentEventId, :final jsonPath) => (
        attachmentEventId,
        jsonPath,
      ),
      SyncAgentLink(:final attachmentEventId, :final jsonPath) => (
        attachmentEventId,
        jsonPath,
      ),
      SyncNotification(:final attachmentEventId, :final jsonPath) => (
        attachmentEventId,
        jsonPath,
      ),
      SyncOutboxBundle(
        :final attachmentEventId,
        :final jsonPath,
      ) =>
        (attachmentEventId, jsonPath),
      SyncDeepBackfillInventory(:final attachmentEventId, :final jsonPath) ||
      SyncDeepBackfillRequest(:final attachmentEventId, :final jsonPath) => (
        attachmentEventId,
        jsonPath,
      ),
      _ => (null, null),
    };
    final index = _attachmentIndex;
    final trust = _syncEventTrust;
    final fetcher = _descriptorFetcher;
    if (id == null ||
        index == null ||
        trust == null ||
        fetcher == null ||
        error.path != path) {
      return false;
    }
    // Do not promote disk failures (including a bundled child's cache write)
    // into an unlimited descriptor retry merely because its parent has an ID.
    if (error is! _SyncDescriptorFetchException &&
        !error.message.startsWith('attachment descriptor not yet available')) {
      return false;
    }
    // Preparation already tried this exact descriptor. Its download may be
    // temporarily unavailable; keep the same periodic recovery contract.
    if (index.findByEventId(id) != null) {
      throw const PendingSyncDescriptorException();
    }
    try {
      final lookup = await fetcher.fetch(
        roomId: envelope.roomId,
        eventId: id,
      );
      final descriptor = lookup.descriptor;
      // The server answers an id lookup with whatever it holds; only a
      // descriptor encrypted by a trusted device may name the payload's JSON.
      if (descriptor != null &&
          descriptor.eventId == id &&
          descriptor.roomId == envelope.roomId &&
          await trust.admits(
            descriptor,
            subDomain: 'processor.resolve.descriptorTrust',
          )) {
        index.record(descriptor);
      }
      _trace(
        'descriptorLookup.result eventId=$id found=${descriptor != null} '
        'source=${lookup.source} type=${descriptor?.type} '
        'msgtype=${descriptor?.content['msgtype']} '
        'roomMatches=${descriptor?.roomId == envelope.roomId} '
        'hasRelativePath=${descriptor?.content['relativePath'] is String} '
        'indexed=${index.findByEventId(id) != null}',
        subDomain: 'processor.resolve.descriptorLookup',
      );
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.resolve.descriptorLookup',
      );
    }
    // Existing resolvers still validate the path and causal payload. A
    // concurrent observation may already have recorded this same event.
    if (index.findByEventId(id) != null) return true;
    throw const PendingSyncDescriptorException();
  }

  /// Fetches fresh JSON from the [AttachmentIndex] descriptor and writes it
  /// to [targetFile]. Returns the JSON string on success, or null if no
  /// descriptor is available (index missing or not initialized).
  ///
  /// When a descriptor IS found but download/decode fails, throws
  /// [FileSystemException] to prevent falling back to potentially stale
  /// disk data. Media the homeserver reports as `M_NOT_FOUND` throws
  /// [UnrecoverableSyncPayloadException] instead, so the envelope is skipped
  /// rather than retried forever.
  Future<String?> _fetchFromDescriptor({
    required String jsonPath,
    required File targetFile,
    required String typeName,
    String? attachmentEventId,
    bool writeToDisk = true,
  }) async {
    final index = _attachmentIndex;
    final fetcher = _attachmentFetcher;
    if (index == null || fetcher == null) return null;

    final indexKey = _buildAgentIndexKey(jsonPath);
    final descriptor = attachmentEventId == null
        ? index.find(indexKey)
        : index.findByEventId(attachmentEventId);
    if (descriptor == null) {
      _trace(
        '$typeName.descriptor.miss path=$jsonPath key=$indexKey '
        'eventId=${attachmentEventId ?? 'legacy'}',
        subDomain: 'processor.resolve',
      );
      return null;
    }

    if (attachmentEventId != null &&
        _buildAgentIndexKey(descriptor.relativePath) != indexKey) {
      throw UnrecoverableSyncPayloadException(typeName);
    }

    final dedupeKey =
        '$indexKey@${descriptor.eventId}@writeToDisk=$writeToDisk';
    final existing = _inFlightDescriptorFetches[dedupeKey];
    if (existing != null) {
      return existing;
    }

    final future = _runDescriptorFetch(
      jsonPath: jsonPath,
      targetFile: targetFile,
      typeName: typeName,
      descriptor: descriptor,
      fetcher: fetcher,
      writeToDisk: writeToDisk,
    );
    _inFlightDescriptorFetches[dedupeKey] = future;
    return future.whenComplete(() {
      _inFlightDescriptorFetches.remove(dedupeKey);
    });
  }

  Future<String?> _runDescriptorFetch({
    required String jsonPath,
    required File targetFile,
    required String typeName,
    required AttachmentDescriptor descriptor,
    required SyncAttachmentFetcher fetcher,
    required bool writeToDisk,
  }) async {
    final String jsonString;
    final int bytesLength;
    try {
      final downloadedBytes = await fetcher.download(
        descriptor,
        pathForError: jsonPath,
      );
      if (downloadedBytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      final bytes = await decodeAttachmentBytes(
        encoding: descriptor.encoding,
        downloadedBytes: downloadedBytes,
        relativePath: jsonPath,
        logging: _loggingService,
      );
      jsonString = utf8.decode(bytes);
      bytesLength = bytes.length;
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'resolve.$typeName.descriptorFetch',
      );
      // The homeserver no longer has the descriptor's media (purged or
      // expired). Retrying the same media cannot bring it back, so the
      // envelope is skipped instead of parked as a pending descriptor.
      if (e is MatrixException && e.errcode == 'M_NOT_FOUND') {
        throw UnrecoverableSyncPayloadException(typeName);
      }
      // The same bytes inflate past the limit on every attempt: retrying —
      // every 30 s for a day as a pending descriptor — would only re-run the
      // decode a bomb is designed to make expensive.
      if (e is AttachmentTooLargeException) {
        throw UnrecoverableSyncPayloadException(typeName);
      }
      // Descriptor was found but download/decode failed — throw to prevent
      // falling back to potentially stale disk data. The pipeline will retry.
      throw _SyncDescriptorFetchException(
        '$typeName descriptor fetch failed',
        jsonPath,
      );
    }
    // Local persistence failures retain their original error and bounded retry
    // policy; another descriptor lookup cannot repair the filesystem.
    if (writeToDisk) {
      await saveJson(targetFile.path, jsonString);
    }
    _trace(
      '$typeName.descriptor.fetched path=$jsonPath bytes=$bytesLength '
      'cached=$writeToDisk',
      subDomain: 'processor.resolve',
    );
    return jsonString;
  }
}
