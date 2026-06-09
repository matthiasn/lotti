part of 'sync_sequence_log_service.dart';

mixin _SyncSeq4 on _SyncSequenceLogServiceBase {
  Future<int> retireExhaustedRequestedEntries({
    int maxRequestCount = 10,
    Duration grace = const Duration(minutes: 5),
  }) async {
    final count = await _syncDatabase.retireExhaustedRequestedEntries(
      maxRequestCount: maxRequestCount,
      grace: grace,
    );

    if (count > 0) {
      _lastCounterCache.clear();
      _materializedUpperBound.clear();
      _trace(
        'retireExhaustedRequestedEntries: retired $count entries to unresolvable',
        subDomain: 'sequence.retireExhausted',
      );
    }

    return count;
  }

  /// Age-based companion to [retireExhaustedRequestedEntries]. Retires
  /// any `missing`/`requested` row older than [amnestyWindow] regardless
  /// of `request_count` or `last_requested_at`.
  ///
  /// Closes the gap where a row can slip into `requested` via the
  /// backfill-response-hint path (which does not set
  /// `last_requested_at`) OR age out of the active backfill window
  /// ([SyncTuning.defaultBackfillMaxAge]) before accumulating enough
  /// requests to hit the exhaustion cap. Without this, such rows sit in
  /// a non-terminal status forever, blocking the contiguous watermark
  /// (see `getLastCounterForHost`) and causing every new event on the
  /// same host to re-emit the same gap range through gap detection.
  Future<int> retireAgedOutRequestedEntries({
    Duration amnestyWindow = const Duration(days: 7),
  }) async {
    final count = await _syncDatabase.retireAgedOutRequestedEntries(
      amnestyWindow: amnestyWindow,
    );

    if (count > 0) {
      _lastCounterCache.clear();
      _materializedUpperBound.clear();
      _trace(
        'retireAgedOutRequestedEntries: retired $count entries to unresolvable '
        '(amnestyWindow=${amnestyWindow.inDays}d)',
        subDomain: 'sequence.retireAgedOut',
      );
    }

    return count;
  }

  /// Get entry by host ID and counter (for responding to backfill requests).
  Future<SyncSequenceLogItem?> getEntryByHostAndCounter(
    String hostId,
    int counter,
  ) {
    return _syncDatabase.getEntryByHostAndCounter(hostId, counter);
  }

  /// Find the nearest covering entry for a host with counter >= [counter].
  /// Used when the exact counter is missing from the sequence log (superseded).
  Future<SyncSequenceLogItem?> getNearestCoveringEntry(
    String hostId,
    int counter,
  ) {
    return _syncDatabase.getNearestCoveringEntry(hostId, counter);
  }

  /// Get backfill statistics grouped by host.
  Future<BackfillStats> getBackfillStats() {
    return _syncDatabase.getBackfillStats();
  }

  /// Get missing entries with age and per-host limits for automatic backfill.
  /// This is used for bounded automatic backfill that only looks at recent gaps.
  ///
  /// [minAge] defers rows freshly flagged as missing — see
  /// [SyncDatabase.getMissingEntriesWithLimits] for the rationale.
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    Duration minAge = Duration.zero,
    int? maxPerHost,
    int offset = 0,
  }) {
    return _syncDatabase.getMissingEntriesWithLimits(
      limit: limit,
      maxRequestCount: maxRequestCount,
      maxAge: maxAge,
      minAge: minAge,
      maxPerHost: maxPerHost,
      offset: offset,
    );
  }

  /// Get entries with status 'requested' for re-requesting.
  /// These are entries that were requested but never received.
  Future<List<SyncSequenceLogItem>> getRequestedEntries({
    int limit = 50,
    int offset = 0,
  }) {
    return _syncDatabase.getRequestedEntries(limit: limit, offset: offset);
  }

  /// Reset request counts for specified entries to allow re-requesting.
  Future<void> resetRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    await _syncDatabase.resetRequestCounts(entries);

    _trace(
      'resetRequestCounts: reset ${entries.length} entries for re-request',
      subDomain: 'sequence.reRequest',
    );
  }

  /// Populate the sequence log from existing journal entries.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromJournal({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    entryStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: entryStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.journalEntity,
      label: 'populateFromJournal',
    );
  }

  /// Populate the sequence log from existing entry links.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromEntryLinks({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    linkStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: linkStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.entryLink,
      label: 'populateFromEntryLinks',
    );
  }

  /// Populate the sequence log from existing agent entities.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromAgentEntities({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    entityStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: entityStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.agentEntity,
      label: 'populateFromAgentEntities',
    );
  }

  /// Populate the sequence log from existing agent links.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromAgentLinks({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    linkStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: linkStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.agentLink,
      label: 'populateFromAgentLinks',
    );
  }

  /// Shared implementation for populating the sequence log from a paginated
  /// stream of records with vector clocks. Used by all four populate methods.
  Future<int> _populateFromStream({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    dataStream,
    required Future<int> Function() getTotalCount,
    required SyncSequencePayloadType payloadType,
    required String label,
    void Function(double progress)? onProgress,
  }) async {
    final total = await getTotalCount();
    var processed = 0;
    var populated = 0;
    final now = DateTime.now();

    // Cache of existing (hostId, counter) pairs to avoid duplicates
    final existingByHost = <String, Set<int>>{};

    await for (final batch in dataStream) {
      final toInsert = <SyncSequenceLogCompanion>[];

      for (final record in batch) {
        processed++;

        final vc = record.vectorClock;
        if (vc == null || vc.isEmpty) continue;

        // Find the originating host (the one with the highest counter).
        // Sort entries by host ID for deterministic tie-breaking.
        String? originatingHost;
        var maxCounter = -1;
        final sortedEntries = vc.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final e in sortedEntries) {
          if (e.value > maxCounter) {
            maxCounter = e.value;
            originatingHost = e.key;
          }
        }

        // Record entry for each host in the vector clock
        for (final vcEntry in vc.entries) {
          final hostId = vcEntry.key;
          final counter = vcEntry.value;

          // Lazily load existing counters for this host
          if (!existingByHost.containsKey(hostId)) {
            existingByHost[hostId] = await _syncDatabase.getCountersForHost(
              hostId,
            );
          }

          final existing = existingByHost[hostId]!;

          // Skip if already exists
          if (existing.contains(counter)) continue;

          // Mark as existing to avoid duplicates within this run
          existing.add(counter);

          toInsert.add(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              entryId: Value(record.id),
              payloadType: Value(payloadType.index),
              originatingHostId: Value(originatingHost ?? hostId),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }

      // Batch insert
      if (toInsert.isNotEmpty) {
        await _syncDatabase.batchInsertSequenceEntries(toInsert);
        populated += toInsert.length;
      }

      // Report progress after each batch
      if (onProgress != null && total > 0) {
        onProgress(processed / total);
      }
    }

    if (populated > 0) {
      _trace(
        '$label: added $populated sequence log entries',
        subDomain: 'sequence.populate',
      );
    }

    return populated;
  }

  Future<List<({String hostId, int counter})>> recordReceivedEntryLink({
    required String linkId,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
  }) {
    return recordReceivedEntry(
      entryId: linkId,
      vectorClock: vectorClock,
      originatingHostId: originatingHostId,
      coveredVectorClocks: coveredVectorClocks,
      payloadType: SyncSequencePayloadType.entryLink,
    );
  }
}
