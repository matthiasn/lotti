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
  Future<bool> _recoverMissingDescriptor(
    Event envelope,
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
      _ => (null, null),
    };
    final index = _attachmentIndex;
    if (id == null || index == null || error.path != path) return false;
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
      var descriptor = await envelope.room
          .getEventById(id)
          .timeout(SyncTuning.attachmentDownloadTimeout);
      descriptor = await _decryptDescriptor(descriptor, envelope.room);
      var source = 'cacheOrServer';
      // The SDK returns a cached event without consulting the server. An
      // incomplete cached plaintext event otherwise makes every retry return
      // the same unusable descriptor, even when the server has the file event.
      final relativePath = descriptor?.content['relativePath'];
      if (descriptor?.type == EventTypes.Message &&
          (relativePath is! String || relativePath.isEmpty)) {
        final remote = await envelope.room.client
            .getOneRoomEvent(envelope.room.id, id)
            .timeout(SyncTuning.attachmentDownloadTimeout);
        // Event.fromMatrixEvent assigns the supplied room, so validate the
        // wire room before conversion. The room-scoped API may omit room_id.
        descriptor =
            remote.eventId == id &&
                (remote.roomId == null || remote.roomId == envelope.roomId)
            ? Event.fromMatrixEvent(remote, envelope.room)
            : null;
        descriptor = await _decryptDescriptor(descriptor, envelope.room);
        source = 'server';
      }
      if (descriptor != null &&
          descriptor.eventId == id &&
          descriptor.roomId == envelope.roomId) {
        index.record(descriptor);
      }
      _trace(
        'descriptorLookup.result eventId=$id found=${descriptor != null} '
        'source=$source type=${descriptor?.type} '
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

  /// The SDK decrypts server results, but cached events may still be ciphertext
  /// when their key arrives later. Apply the same decryption to either source.
  Future<Event?> _decryptDescriptor(Event? descriptor, Room room) async {
    if (descriptor?.type != EventTypes.Encrypted) return descriptor;
    final encryption = room.client.encryption;
    return encryption == null
        ? descriptor
        : encryption
              .decryptRoomEvent(descriptor!)
              .timeout(SyncTuning.attachmentDownloadTimeout);
  }

  /// Fetches fresh JSON from the [AttachmentIndex] descriptor and writes it
  /// to [targetFile]. Returns the JSON string on success, or null if no
  /// descriptor is available (index missing or not initialized).
  ///
  /// When a descriptor IS found but download/decode fails, throws
  /// [FileSystemException] to prevent falling back to potentially stale
  /// disk data.
  Future<String?> _fetchFromDescriptor({
    required String jsonPath,
    required File targetFile,
    required String typeName,
    String? attachmentEventId,
    bool writeToDisk = true,
  }) async {
    final index = _attachmentIndex;
    if (index == null) return null;

    final indexKey = _buildAgentIndexKey(jsonPath);
    final descriptorEvent = attachmentEventId == null
        ? index.find(indexKey)
        : index.findByEventId(attachmentEventId);
    if (descriptorEvent == null) {
      _trace(
        '$typeName.descriptor.miss path=$jsonPath key=$indexKey '
        'eventId=${attachmentEventId ?? 'legacy'}',
        subDomain: 'processor.resolve',
      );
      return null;
    }

    if (attachmentEventId != null) {
      final descriptorPath = descriptorEvent.content['relativePath'];
      if (descriptorPath is! String ||
          _buildAgentIndexKey(descriptorPath) != indexKey) {
        throw UnrecoverableSyncPayloadException(typeName);
      }
    }

    final dedupeKey =
        '$indexKey@${descriptorEvent.eventId}@writeToDisk=$writeToDisk';
    final existing = _inFlightDescriptorFetches[dedupeKey];
    if (existing != null) {
      return existing;
    }

    final future = _runDescriptorFetch(
      jsonPath: jsonPath,
      targetFile: targetFile,
      typeName: typeName,
      descriptorEvent: descriptorEvent,
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
    required Event descriptorEvent,
    required bool writeToDisk,
  }) async {
    final String jsonString;
    final int bytesLength;
    try {
      final matrixFile = await downloadAttachmentWithTimeout(
        descriptorEvent,
        pathForError: jsonPath,
      );
      final downloadedBytes = matrixFile.bytes;
      if (downloadedBytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      final bytes = await decodeAttachmentBytes(
        event: descriptorEvent,
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
