part of 'matrix_message_sender.dart';

/// Outbox-bundle pipeline of [MatrixMessageSender].
extension MatrixBundleSender on MatrixMessageSender {
  /// Builds the dequeue-time outbox bundle's manifest payload (envelope + DB
  /// content for each child), gzip-encodes it, and uploads the bytes as a
  /// single Matrix file event. Returns the stripped [SyncOutboxBundle] (i.e.
  /// `children` cleared, `jsonPath` set to the just-uploaded relative path)
  /// for the caller to send as the text envelope; returns `null` when the
  /// bundle is empty, exceeds the size cap, or the upload fails.
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
  /// [_sendJournalEntityPayload] does for individually-sent entities.
  ///
  /// Inline-payload children (`SyncEntryLink`, `SyncAiConfig`,
  /// `SyncAiConfigDelete`, `SyncEntityDefinition`, `SyncThemingSelection`,
  /// `SyncBackfillRequest`, `SyncBackfillResponse`) need no separate payload —
  /// the freezed envelope already carries everything. Agent envelopes
  /// (`SyncAgentEntity`, `SyncAgentLink`) keep their inline data fields
  /// populated by upstream writers, so they ride along in the envelope
  /// unchanged.
  Future<SyncOutboxBundle?> _sendOutboxBundlePayload({
    required Room room,
    required SyncOutboxBundle message,
  }) async {
    if (message.children.isEmpty) {
      _loggingService.log(
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
      _loggingService.log(
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
        : await _journalDb.journalEntityMapForIds(journalEntityIds);

    final host = await _vectorClockService?.getHost();

    // Track journal-entity children whose DB row vanished between enqueue
    // and dequeue (rare, but possible if the entity was deleted locally
    // mid-flight). Silently dropping such children would let the bundle
    // ack while one entity never reaches peers — permanent data loss.
    // Failing the whole bundle drops to the existing retry path; once the
    // row caps out it ends up in `error` status so an operator can
    // investigate, exactly like a standalone send with a missing entity.
    final missingJournalEntityIds = <String>[];

    final entries = <Map<String, dynamic>>[];
    for (final child in message.children) {
      final reconciled = _reconcileBundleChildEnvelope(
        child,
        host: host,
        journalEntityById: journalEntityById,
      );
      final record = <String, dynamic>{
        'envelope': reconciled.toJson(),
      };
      if (reconciled is SyncJournalEntity) {
        final entity = journalEntityById[reconciled.id];
        if (entity == null) {
          missingJournalEntityIds.add(reconciled.id);
          continue;
        }
        record['payload'] = entity.toJson();
      }
      entries.add(record);
    }

    if (missingJournalEntityIds.isNotEmpty) {
      _loggingService.error(
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

    final manifest = <String, dynamic>{
      'version': SyncTuning.outboxBundleManifestVersion,
      'entries': entries,
    };

    Uint8List gzipped;
    try {
      // Run json.encode + utf8.encode + gzip on a worker isolate so a
      // bundle of up to [SyncTuning.outboxBundleMaxSize] entities does not
      // stall the UI thread for the duration of the encode pipeline.
      gzipped = await _gzipEncode(manifest);
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.outboxBundle.encode',
      );
      return null;
    }

    if (gzipped.length > SyncTuning.outboxBundleMaxBytes) {
      _loggingService.error(
        LogDomain.sync,
        'outboxBundle exceeds max bytes: '
        'gzipped=${gzipped.length} '
        'max=${SyncTuning.outboxBundleMaxBytes} '
        'children=${message.children.length}',
        subDomain: 'sendMatrixMsg.outboxBundle.tooLarge',
      );
      return null;
    }

    // Wire display name carries `.gz` to hint at the compressed bytes —
    // the canonical compression signal is still the encoding header. The
    // `relativePath` keeps the on-disk extension (`.json`) so the receiver's
    // post-decode cache file at the same path matches its content; mirrors
    // what `_sendFile` does for compressed agent payloads.
    final fileName =
        '${p.basename(relativePath.split('/').where((s) => s.isNotEmpty).last)}.gz';
    final extraContent = <String, dynamic>{
      'relativePath': relativePath,
      attachmentEncodingKey: attachmentEncodingGzip,
    };

    String? uploadEventId;
    try {
      uploadEventId = await room.sendFileEvent(
        MatrixFile(bytes: gzipped, name: fileName),
        extraContent: extraContent,
      );
    } catch (error, stackTrace) {
      _trace(
        'EXCEPTION outboxBundle.upload path=$relativePath '
        'error=${error.runtimeType}: $error',
        subDomain: 'matrix.send.error',
      );
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendMatrixMsg.outboxBundle.upload',
      );
      return null;
    }

    if (uploadEventId == null) {
      _trace(
        'FAIL outboxBundle.upload returned null path=$relativePath '
        'gzippedBytes=${gzipped.length}',
        subDomain: 'matrix.send.error',
      );
      _loggingService.log(
        LogDomain.sync,
        'Failed sending outboxBundle file message to $room',
        subDomain: 'sendMatrixMsg',
      );
      return null;
    }

    _sentEventRegistry.register(uploadEventId, source: SentEventSource.file);

    return message.copyWith(
      jsonPath: relativePath,
      children: const [],
    );
  }

  /// Returns true when [relativePath] is a well-formed
  /// `/outbox_bundles/<id>.json` path with no traversal segments. Used by
  /// [_sendOutboxBundlePayload] to gate which inbound `jsonPath` values are
  /// honoured for a freshly built bundle's metadata.
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
  /// [_sendJournalEntityPayload].
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
              _loggingService,
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
            _loggingService,
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
            _loggingService,
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
