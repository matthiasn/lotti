part of 'sync_event_processor.dart';

/// Descriptor-driven attachment fetching with in-flight deduplication —
/// shared by the agent payload resolution and the outbox bundle resolver.
extension _DescriptorCache on SyncEventProcessor {
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
      final jsonString = utf8.decode(bytes);
      if (writeToDisk) {
        await saveJson(targetFile.path, jsonString);
      }
      _trace(
        '$typeName.descriptor.fetched path=$jsonPath bytes=${bytes.length} '
        'cached=$writeToDisk',
        subDomain: 'processor.resolve',
      );
      return jsonString;
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'resolve.$typeName.descriptorFetch',
      );
      // Descriptor was found but download/decode failed — throw to prevent
      // falling back to potentially stale disk data. The pipeline will retry.
      throw FileSystemException(
        '$typeName descriptor fetch failed',
        jsonPath,
      );
    }
  }
}
