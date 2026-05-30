part of 'sync_event_processor.dart';

/// Prepare- and apply-phase handlers for journal-entity and entry-link sync
/// messages. Extension methods on [SyncEventProcessor] so they share private
/// state (the dedup cache, sequence log service, update notifications) with
/// the orchestrator declared in the part-parent library.
extension _JournalHandlers on SyncEventProcessor {
  /// Upserts every embedded entry link and returns the count that
  /// actually wrote a row.
  ///
  /// Set [rethrowOnError] when this runs inside a transaction whose
  /// commit must be conditional on every link succeeding — e.g. the
  /// journal-entity apply path, where the entity row + its embedded
  /// links need to land atomically. Without rethrow, a single
  /// `upsertEntryLink` failure would be logged and the loop would
  /// continue, then the transaction would commit the entity *with*
  /// only some of its links; later redelivery of the same event
  /// resolves to the duplicate path and never retries the missing
  /// upserts.
  ///
  /// Default `false` preserves the legacy behaviour for callers that
  /// process links *outside* a transaction (best-effort delivery), so
  /// a poison link does not block unrelated work.
  Future<int> _processEmbeddedEntryLinks({
    required List<EntryLink>? entryLinks,
    required JournalDb journalDb,
    bool rethrowOnError = false,
  }) async {
    var processedLinksCount = 0;
    if (entryLinks == null || entryLinks.isEmpty) {
      return processedLinksCount;
    }
    final affectedIds = <String>{};
    for (final link in entryLinks) {
      try {
        final linkRows = await journalDb.upsertEntryLink(link);
        if (linkRows > 0) {
          processedLinksCount++;
          _trace(
            'apply entryLink.embedded from=${link.fromId} to=${link.toId} rows=$linkRows',
            subDomain: 'processor.apply.entryLink.embedded',
          );
        }
        affectedIds.addAll({link.fromId, link.toId});
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'apply.entryLink.embedded',
        );
        if (rethrowOnError) rethrow;
      }
    }
    if (affectedIds.isNotEmpty) {
      _updateNotifications.notify(affectedIds, fromSync: true);
    }
    return processedLinksCount;
  }

  Future<SyncApplyDiagnostics?> _maybeSkipSupersededStaleDescriptor({
    required Event event,
    required SyncJournalEntity syncMessage,
    required JournalDb journalDb,
    required List<EntryLink>? entryLinks,
  }) async {
    final incomingVc = syncMessage.vectorClock;
    if (incomingVc == null) {
      return null;
    }
    JournalEntity? existing;
    try {
      existing = await journalDb.journalEntityById(syncMessage.id);
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'apply.staleDescriptor.lookup',
      );
      return null;
    }
    final existingVc = existing?.meta.vectorClock;
    if (existingVc == null) {
      return null;
    }
    VclockStatus status;
    try {
      status = VectorClock.compare(existingVc, incomingVc);
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'apply.staleDescriptor.compare',
      );
      return null;
    }
    if (status != VclockStatus.a_gt_b && status != VclockStatus.equal) {
      return null;
    }

    // `rethrowOnError: true` so a failed link upsert here propagates out
    // before we record the entry as processed below. Otherwise redelivery
    // of this event would go down the duplicate path and never retry the
    // missing link — the entity is stale-skipped, but its links are still
    // load-bearing for the local apply (category color lookups, etc.).
    final processedLinksCount = await _processEmbeddedEntryLinks(
      entryLinks: entryLinks,
      journalDb: journalDb,
      rethrowOnError: true,
    );

    final diag = SyncApplyDiagnostics(
      eventId: event.eventId,
      payloadType: 'journalEntity',
      vectorClock: incomingVc.toJson(),
      conflictStatus: status.toString(),
      applied: false,
      skipReason: JournalUpdateSkipReason.olderOrEqual,
    );
    _trace(
      'apply journalEntity skipped staleDescriptor eventId=${event.eventId} id=${syncMessage.id} status=${diag.conflictStatus} embeddedLinks=$processedLinksCount/${entryLinks?.length ?? 0}',
      subDomain: 'processor.apply',
    );

    if (_sequenceLogService != null && syncMessage.originatingHostId != null) {
      try {
        final gaps = await _sequenceLogService.recordReceivedEntry(
          entryId: syncMessage.id,
          vectorClock: incomingVc,
          originatingHostId: syncMessage.originatingHostId!,
          coveredVectorClocks: syncMessage.coveredVectorClocks,
          jsonPath: syncMessage.jsonPath,
        );
        if (gaps.isNotEmpty) {
          _trace(
            'apply.gapsDetected count=${gaps.length} for entity=${syncMessage.id}',
            subDomain: 'processor.gapDetection',
          );
        }
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'recordReceived',
        );
      }
    }

    _dedupCache.markProcessed(syncMessage.id, incomingVc);
    return diag;
  }

  /// Stale-descriptor [FileSystemException]s are caught and carried into the
  /// apply phase: the supersession check needs the writer transaction, so
  /// apply decides whether to skip the event or rethrow for retry.
  Future<PreparedSyncEvent> _prepareJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
  }) async {
    if (_dedupCache.isDuplicate(syncMessage.id, syncMessage.vectorClock)) {
      return PreparedSyncEvent._(
        event: event,
        syncMessage: syncMessage,
        isDuplicateJournalEntity: true,
      );
    }

    try {
      final journalEntity = await _journalEntityLoader.load(
        jsonPath: syncMessage.jsonPath,
        incomingVectorClock: syncMessage.vectorClock,
      );
      return PreparedSyncEvent._(
        event: event,
        syncMessage: syncMessage,
        journalEntity: journalEntity,
      );
    } on FileSystemException catch (error, stackTrace) {
      if (_isStaleDescriptorError(error)) {
        // Carry the error forward so apply can first check whether the local
        // version already dominates the incoming one (in which case the
        // event is skipped) or must be retried later (rethrown from apply).
        return PreparedSyncEvent._(
          event: event,
          syncMessage: syncMessage,
          deferredStaleDescriptorError: error,
        );
      }
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'SyncEventProcessor.missingAttachment',
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Apply-phase handlers (pure DB, no attachment I/O)
  // ---------------------------------------------------------------------------

  /// Applies an already-[PreparedSyncEvent] to local stores. Runs entirely in
  /// the writer transaction — it must not do attachment I/O.
  Future<SyncApplyDiagnostics?> _applyJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
    required JournalEntity? preloaded,
    required bool isDuplicate,
    required FileSystemException? deferredStaleError,
    required JournalDb journalDb,
  }) async {
    if (deferredStaleError != null) {
      final skipped = await _maybeSkipSupersededStaleDescriptor(
        event: event,
        syncMessage: syncMessage,
        journalDb: journalDb,
        entryLinks: syncMessage.entryLinks,
      );
      if (skipped != null) {
        return skipped;
      }
      // Not superseded — log and rethrow for retry.
      _loggingService.error(
        LogDomain.sync,
        deferredStaleError,
        subDomain: 'SyncEventProcessor.missingAttachment',
      );
      throw deferredStaleError;
    }

    if (isDuplicate) {
      return _recordDuplicateJournalEntity(
        event: event,
        syncMessage: syncMessage,
      );
    }

    // preloaded must be non-null when we reach this branch.
    return _persistJournalEntity(
      event: event,
      syncMessage: syncMessage,
      journalEntity: preloaded!,
      journalDb: journalDb,
    );
  }

  /// Records the duplicate in the sequence log so `resolvePendingHints` still
  /// runs; the duplicate detection itself lives in the prepare phase.
  Future<SyncApplyDiagnostics?> _recordDuplicateJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
  }) async {
    // Even for duplicates, record in the sequence log so that
    // resolvePendingHints runs. Without this, backfill hints (from
    // BackfillResponse messages) are never resolved because the entity
    // already exists locally with the same VC, but the pending
    // (hostId, counter) → payloadId mapping was never verified.
    if (_sequenceLogService != null &&
        syncMessage.vectorClock != null &&
        syncMessage.originatingHostId != null) {
      try {
        await _sequenceLogService.recordReceivedEntry(
          entryId: syncMessage.id,
          vectorClock: syncMessage.vectorClock!,
          originatingHostId: syncMessage.originatingHostId!,
          coveredVectorClocks: syncMessage.coveredVectorClocks,
          jsonPath: syncMessage.jsonPath,
        );
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'duplicateRecord',
        );
      }
    }

    final diag = SyncApplyDiagnostics(
      eventId: event.eventId,
      payloadType: 'journalEntity',
      vectorClock: syncMessage.vectorClock?.toJson(),
      conflictStatus: VclockStatus.equal.toString(),
      applied: false,
      skipReason: JournalUpdateSkipReason.olderOrEqual,
    );
    _trace(
      'apply journalEntity skipped duplicate eventId=${event.eventId} '
      'id=${syncMessage.id}',
      subDomain: 'processor.apply',
    );
    return diag;
  }

  /// Persists a pre-resolved journal entity and its embedded links. The
  /// [journalEntity] argument was already loaded by the prepare phase, so
  /// this runs entirely in the writer transaction.
  Future<SyncApplyDiagnostics?> _persistJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
    required JournalEntity journalEntity,
    required JournalDb journalDb,
  }) async {
    final entryLinks = syncMessage.entryLinks;

    // (1) PRE-READ — runs *outside* any journal transaction.
    //
    // `applyObserver` only consumes this for diagnostics, and the read
    // is served by the entity-by-id coalescer which can join an
    // in-flight wave. Holding the journal writer lock while waiting on
    // a queued read was one of the worst contention sources in the
    // super-slow log; the wrap had been added unconditionally by the
    // queue adapter, so this read was effectively serialized behind
    // every prior concurrent reader. Now this happens before we open
    // the inner write transaction.
    var predictedStatus = VclockStatus.b_gt_a;
    if (applyObserver != null) {
      try {
        final existing = await journalDb.journalEntityById(
          journalEntity.meta.id,
        );
        final vcA = existing?.meta.vectorClock;
        final vcB0 = journalEntity.meta.vectorClock;
        if (vcA != null && vcB0 != null) {
          predictedStatus = VectorClock.compare(vcA, vcB0);
        }
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'apply.predictVectorClock',
        );
        predictedStatus = VclockStatus.b_gt_a;
      }
    }

    // (2) WRITE — narrow journal transaction wrapping ONLY the writes
    //     that need to succeed-or-fail together. The queue adapter no
    //     longer wraps `SyncJournalEntity` from the outside (see
    //     `_writesJournalDb` in queue_apply_adapter.dart), so this is
    //     the *only* journal writer-lock acquisition for this apply.
    //     Cross-DB awaits (sync-sequence log) and the second
    //     entry-exists read both run *after* this commits, freeing the
    //     writer lock for unrelated readers.
    final vcB = journalEntity.meta.vectorClock;
    final JournalUpdateResult updateResult;
    final int processedLinksCount;
    try {
      final tx = await journalDb.transaction(() async {
        final result = await journalDb.updateJournalEntity(journalEntity);
        // Process embedded entry links regardless of journal entity
        // application status. EntryLinks have their own vector clock
        // for conflict resolution via upsertEntryLink(). This ensures
        // links are established even when the entity itself is skipped
        // (e.g., local version is newer), preventing gray calendar
        // entries that rely on links for category color lookup.
        // `rethrowOnError: true` so a failed `upsertEntryLink` aborts
        // the enclosing transaction. Without that, the entity row
        // would commit with only a partial link set, and the next
        // redelivery of this event resolves to the duplicate path —
        // those missing links would never be retried.
        final processed = await _processEmbeddedEntryLinks(
          entryLinks: entryLinks,
          journalDb: journalDb,
          rethrowOnError: true,
        );
        return (result, processed);
      });
      updateResult = tx.$1;
      processedLinksCount = tx.$2;
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'apply.persistJournalEntity',
      );
      rethrow;
    }
    final rows = updateResult.rowsWritten ?? 0;

    final diag = SyncApplyDiagnostics(
      eventId: event.eventId,
      payloadType: 'journalEntity',
      vectorClock: vcB?.toJson(),
      conflictStatus: predictedStatus.toString(),
      applied: updateResult.applied,
      skipReason: updateResult.skipReason,
    );
    _trace(
      'apply journalEntity eventId=${event.eventId} id=${journalEntity.meta.id} '
      'rowsWritten=$rows applied=${updateResult.applied} '
      'skip=${updateResult.skipReason?.label ?? 'none'} '
      'status=${diag.conflictStatus} '
      'embeddedLinks=$processedLinksCount/${entryLinks?.length ?? 0}',
      subDomain: 'processor.apply',
    );
    _dedupCache.markProcessed(
      journalEntity.meta.id,
      vcB ?? syncMessage.vectorClock,
    );
    _updateNotifications.notify(
      {...journalEntity.affectedIds, labelUsageNotification},
      fromSync: true,
    );

    // (3) POST — sequence-log gap detection. Writes to *sync_db* (a
    //     separate SQLite database), so it cannot be atomic with the
    //     journal write in the first place; pulling it out of the
    //     journal transaction loses no consistency we ever had. Gap
    //     detection re-runs on next launch, so a crash between (2)
    //     and (3) is recoverable.
    if (_sequenceLogService != null &&
        syncMessage.vectorClock != null &&
        syncMessage.originatingHostId != null) {
      final entryExistsInJournal =
          updateResult.applied ||
          await journalDb.journalEntityById(journalEntity.meta.id) != null;
      if (entryExistsInJournal) {
        try {
          final gaps = await _sequenceLogService.recordReceivedEntry(
            entryId: journalEntity.meta.id,
            vectorClock: syncMessage.vectorClock!,
            originatingHostId: syncMessage.originatingHostId!,
            coveredVectorClocks: syncMessage.coveredVectorClocks,
            jsonPath: syncMessage.jsonPath,
          );
          if (gaps.isNotEmpty) {
            _trace(
              'apply.gapsDetected count=${gaps.length} '
              'for entity=${journalEntity.meta.id}',
              subDomain: 'processor.gapDetection',
            );
          }
        } catch (e, st) {
          _loggingService.error(
            LogDomain.sync,
            e,
            stackTrace: st,
            subDomain: 'recordReceived',
          );
        }
      }
    }

    return diag;
  }

  /// Handles a SyncEntryLink message.
  Future<SyncApplyDiagnostics?> _handleEntryLink({
    required Event event,
    required SyncEntryLink syncMessage,
    required JournalDb journalDb,
  }) async {
    final entryLink = syncMessage.entryLink;
    final originatingHostId = syncMessage.originatingHostId;
    final coveredVectorClocks = syncMessage.coveredVectorClocks;

    final rows = await journalDb.upsertEntryLink(entryLink);
    try {
      if (rows > 0) {
        _trace(
          'apply entryLink from=${entryLink.fromId} to=${entryLink.toId} '
          'rows=$rows',
          subDomain: 'processor.apply.entryLink',
        );
      }
    } catch (_) {
      // best-effort logging only
    }

    // Surface DB-apply diagnostics to the pipeline when available
    if (applyObserver != null) {
      try {
        final diag = SyncApplyDiagnostics(
          eventId: event.eventId,
          payloadType: 'entryLink',
          vectorClock: null,
          conflictStatus: rows == 0 ? 'entryLink.noop' : 'applied',
          applied: rows > 0,
          skipReason: rows > 0 ? null : JournalUpdateSkipReason.olderOrEqual,
        );
        applyObserver!.call(diag);
      } catch (_) {
        // best-effort only
      }
    }
    _updateNotifications.notify(
      {entryLink.fromId, entryLink.toId},
      fromSync: true,
    );

    // Record in sequence log for gap detection (self-healing sync)
    if (_sequenceLogService != null &&
        entryLink.vectorClock != null &&
        originatingHostId != null) {
      final linkExists =
          rows > 0 || await journalDb.entryLinkById(entryLink.id) != null;
      if (linkExists) {
        try {
          final gaps = await _sequenceLogService.recordReceivedEntryLink(
            linkId: entryLink.id,
            vectorClock: entryLink.vectorClock!,
            originatingHostId: originatingHostId,
            coveredVectorClocks: coveredVectorClocks,
          );
          if (gaps.isNotEmpty) {
            _trace(
              'apply.entryLink.gapsDetected count=${gaps.length} '
              'for link=${entryLink.id}',
              subDomain: 'processor.gapDetection',
            );
          }
        } catch (e, st) {
          _loggingService.error(
            LogDomain.sync,
            e,
            stackTrace: st,
            subDomain: 'recordReceived',
          );
        }
      }
    }
    return null;
  }
}
