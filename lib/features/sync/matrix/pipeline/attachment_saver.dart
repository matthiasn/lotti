// The download-and-save half of the ingestor — part of the
// attachment_ingestor library so it keeps access to the ingestor's
// private queue/cache state.
part of 'attachment_ingestor.dart';

extension _AttachmentSaver on AttachmentIngestor {
  /// Downloads and saves an attachment.
  ///
  /// For non-agent payloads, an existing non-empty local file is treated as
  /// up-to-date and download is skipped.
  /// For `agent_entities`/`agent_links`, downloads are always re-attempted to
  /// avoid stale reads (these files can be legitimately updated in-place).
  ///
  /// Returns `true` if a new file was written, `false` if skipped or failed.
  Future<bool> _saveAttachment({
    required Event event,
    required String relativePath,
    required DomainLogger logging,
  }) async {
    final docDir = documentsDirectory;
    if (docDir == null) {
      return false;
    }

    final attachmentMimetype = event.attachmentMimetype;
    if (attachmentMimetype.isEmpty) {
      return false;
    }

    // Cheap negative cache: we already observed the matrix SDK evict this
    // event's encrypted blob. Every subsequent attempt would throw the same
    // "File is no longer cached" error with no real work done, just noise.
    if (_cacheEvictedEventIds.contains(event.eventId)) {
      return false;
    }

    try {
      final file = _targetFile(relativePath);
      if (file == null) {
        logging.log(
          LogDomain.sync,
          'pathTraversal.blocked path=$relativePath',
          subDomain: 'attachment.save',
        );
        return false;
      }

      // Agent entities/links can be legitimately updated in-place (e.g.
      // ChangeSetEntity pending → resolved), so the file-exists
      // fast-path dedupe doesn't apply to them. Instead we do a causal
      // check: the event's content carries the sync payload's
      // `vectorClock`, and the callback-injected VC dominance check
      // tells us whether the local entity is already at least as new
      // as what this event advertises. If yes, the file on disk is
      // current and the download would produce identical bytes — skip.
      //
      // This is the receiver-side "newer VC exists, don't download"
      // path. Without it, a chatty sender that emits N sync events
      // per entity per minute (each bumping the VC but not necessarily
      // changing the persisted bytes) produces N downloads of a file
      // that's already correct on disk.
      final isAgentPayload = isAgentPayloadPath(relativePath);

      if (isAgentPayload && localVcDominates != null) {
        final incomingVc = _extractIncomingVectorClock(event);
        try {
          final dominates = await localVcDominates!(
            relativePath,
            incomingVc,
          );
          if (dominates) {
            if (verboseLogging) {
              logging.log(
                LogDomain.sync,
                'skip.localVcDominates path=$relativePath',
                subDomain: 'attachment.download.skip',
              );
            }
            return false;
          }
        } catch (e, st) {
          // Dominance check is an optimization; a failure must not
          // block the download. Log and fall through.
          logging.error(
            LogDomain.sync,
            e,
            stackTrace: st,
            subDomain: 'attachment.download.skip',
          );
        }
      }

      // Fast-path dedupe (non-agent only): if the file already exists and is
      // non-empty, skip re-downloading to avoid repeated writes and log spam.
      // Note: We don't validate the file's vector clock here because
      // SmartJournalEntityLoader.load() will do that validation and
      // re-download via DescriptorDownloader if the local file is stale.
      // ignore: avoid_slow_async_io
      if (!isAgentPayload && await file.exists()) {
        try {
          final len = await file.length();
          if (len > 0) {
            return false; // already present
          }
        } catch (_) {
          // If querying length fails, fall through to re-download.
        }
      }

      logging.log(
        LogDomain.sync,
        'downloading $relativePath',
        subDomain: 'attachment.download',
      );

      final matrixFile = await downloadAttachmentWithTimeout(
        event,
        pathForError: relativePath,
      );
      final downloadedBytes = matrixFile.bytes;
      if (downloadedBytes.isEmpty) {
        logging.log(
          LogDomain.sync,
          'emptyBytes path=$relativePath',
          subDomain: 'attachment.download',
        );
        return false;
      }

      final bytes = await decodeAttachmentBytes(
        event: event,
        downloadedBytes: downloadedBytes,
        relativePath: relativePath,
        logging: logging,
      );

      await atomicWriteBytes(
        bytes: bytes,
        filePath: file.path,
        logging: logging,
        subDomain: 'attachment.write',
      );

      logging.log(
        LogDomain.sync,
        'wrote file $relativePath bytes=${bytes.length}',
        subDomain: 'attachment.save',
      );
      return true;
    } catch (e, st) {
      // Matrix SDK's `Event._getCachedFile` throws with this message when
      // the event's cached file entry has been evicted. Record the event
      // id so we don't keep paying the exception-plus-stacktrace cost for
      // the rest of the replay wave. Downgrade to a plain info event —
      // the underlying condition is not actionable and self-recovers once
      // a newer event for the same path arrives.
      if (_isCacheEvictedError(e)) {
        _recordCacheEvictedEvent(event.eventId);
        logging.log(
          LogDomain.sync,
          'cacheEvicted path=$relativePath eventId=${event.eventId}',
          subDomain: 'attachment.save.cacheEvicted',
        );
        return false;
      }

      // Log but don't throw - SmartJournalEntityLoader can retry later
      if (e is FileSystemException && e.osError?.errorCode == 24) {
        final limits = readFileDescriptorLimits();
        logging.log(
          LogDomain.sync,
          'emfile path=$relativePath '
          'fd.soft=${limits?.soft ?? '?'} fd.hard=${limits?.hard ?? '?'}',
          subDomain: 'attachment.save.emfile',
          level: InsightLevel.warn,
        );
      }
      logging.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'attachment.save',
      );
      return false;
    }
  }

  static bool _isCacheEvictedError(Object e) {
    final message = e.toString();
    return message.contains('File is no longer cached');
  }

  void _recordCacheEvictedEvent(String eventId) {
    if (_cacheEvictedEventIds.add(eventId)) {
      while (_cacheEvictedEventIds.length > _handledAttachmentEventCapacity) {
        _cacheEvictedEventIds.remove(_cacheEvictedEventIds.first);
      }
    }
  }

  /// Pulls the vector clock out of the sync-payload body carried in the
  /// Matrix event's `text` field. Lotti sync messages are base64 JSON
  /// with a top-level `vectorClock` map (`{hostId: counter}`) present
  /// on `journalEntity` / `agentEntity` / `agentLink` payloads.
  ///
  /// Returns null when the body is missing, not base64 JSON, lacks a
  /// `vectorClock` field, or fails to parse. Callers treat null as
  /// "cannot prove local is current" and proceed with the download.
  static VectorClock? _extractIncomingVectorClock(Event event) {
    try {
      final txt = event.text;
      if (txt.isEmpty) return null;
      final decoded = utf8.decode(base64.decode(txt));
      final obj = json.decode(decoded);
      if (obj is! Map<String, dynamic>) return null;
      final raw = obj['vectorClock'];
      if (raw is! Map<String, dynamic>) return null;
      return VectorClock.fromJson(raw);
    } catch (_) {
      return null;
    }
  }
}
