import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Service for managing the sync sequence log, which tracks received entries
/// by (hostId, counter) pairs to detect gaps and enable backfill requests.
class SyncSequenceLogService {
  SyncSequenceLogService({
    required SyncDatabase syncDatabase,
    required VectorClockService vectorClockService,
    required LoggingService loggingService,
  })  : _syncDatabase = syncDatabase,
        _vectorClockService = vectorClockService,
        _loggingService = loggingService;

  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  final LoggingService _loggingService;

  /// Record an entry being sent by this device.
  /// This allows us to respond to backfill requests from other devices.
  Future<void> recordSentEntry({
    required String entryId,
    required VectorClock vectorClock,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    final myHost = await _vectorClockService.getHost();

    for (final entry in vectorClock.vclock.entries) {
      final hostId = entry.key;
      final counter = entry.value;

      // Only record entries for our own host when sending
      if (hostId != myHost) continue;

      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(payloadType.index),
          originatingHostId: Value(myHost),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      _loggingService.captureEvent(
        'recordSentEntry type=$payloadType hostId=$hostId counter=$counter entryId=$entryId',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'recordSent',
      );
    }
  }

  Future<void> recordSentEntryLink({
    required String linkId,
    required VectorClock vectorClock,
  }) async {
    await recordSentEntry(
      entryId: linkId,
      vectorClock: vectorClock,
      payloadType: SyncSequencePayloadType.entryLink,
    );
  }

  /// Record a received entry and detect gaps in the sequence.
  /// Returns a list of detected gaps as (hostId, counter) records.
  ///
  /// The [originatingHostId] identifies which host created/modified this entry.
  /// This must be provided by the sender in the sync message.
  ///
  /// Gap detection is performed for ALL hosts in the vector clock (except our
  /// own host). This allows us to detect missing entries even from hosts other
  /// than the originator - the VC tells us what counters exist.
  ///
  /// Only the originating host's counter is recorded with the entryId.
  /// Other hosts' counters are tracked for gap detection only.
  ///
  /// [coveredVectorClocks] contains vector clocks for this payload, including
  /// superseded outbox entries and the current vector clock. The current vector
  /// clock is ignored when pre-marking covered counters to avoid suppressing
  /// genuine gap detection for the payload itself.
  Future<List<({String hostId, int counter})>> recordReceivedEntry({
    required String entryId,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    final gaps = <({String hostId, int counter})>[];
    final myHost = await _vectorClockService.getHost();
    final now = DateTime.now();

    // Update host activity for the originating host - they're online!
    await _syncDatabase.updateHostActivity(originatingHostId, now);

    // IMPORTANT: Process covered vector clocks BEFORE gap detection.
    // This prevents false positives: covered counters are pre-emptively marked
    // as received, so gap detection (which checks `existing == null`) will
    // skip them instead of incorrectly marking them as missing.
    final filteredCovered =
        _filterCoveredVectorClocks(coveredVectorClocks, vectorClock);
    if (filteredCovered.isNotEmpty && myHost != null) {
      await _markCoveredCountersAsReceived(
        coveredVectorClocks: filteredCovered,
        entryId: entryId,
        payloadType: payloadType,
        myHost: myHost,
      );
    }

    // Check gaps for ALL hosts in the VC (except ourselves)
    for (final entry in vectorClock.vclock.entries) {
      final hostId = entry.key;
      final counter = entry.value;

      // Skip our own host
      if (hostId == myHost) continue;

      // Only detect gaps for hosts that have been seen "online" (i.e., have
      // sent us a message directly). This prevents false positive gaps for
      // hosts we've never communicated with - we may see their counters in
      // vector clocks from other hosts, but we can't know if entries are
      // actually missing without having established communication with them.
      // The originating host is always considered online (we just updated
      // their activity above).
      //
      // Note: We still record the sequence entry for offline hosts (below),
      // just skip gap detection. This allows us to respond to backfill
      // requests later if the host comes online.
      final hostLastOnline = await _syncDatabase.getHostLastSeen(hostId);
      final shouldDetectGaps =
          hostLastOnline != null || hostId == originatingHostId;

      if (!shouldDetectGaps) {
        _loggingService.captureEvent(
          'skipGapDetection hostId=$hostId counter=$counter - host never seen online',
          domain: 'SYNC_SEQUENCE',
          subDomain: 'skipGap',
        );
      }

      final lastSeen = await _syncDatabase.getLastCounterForHost(hostId);

      if (shouldDetectGaps && lastSeen != null && counter > lastSeen + 1) {
        // Gap detected! Mark missing counters for this host
        final gapSize = counter - lastSeen - 1;

        // Limit gap size to prevent explosion of missing entries
        // when sequence log is corrupted or entries are deleted
        if (gapSize > SyncTuning.maxGapSize) {
          _loggingService.captureEvent(
            'largeGapDetected hostId=$hostId gapSize=$gapSize (lastSeen=$lastSeen, counter=$counter) - limiting to ${SyncTuning.maxGapSize} entries',
            domain: 'SYNC_SEQUENCE',
            subDomain: 'largeGap',
          );
        }

        // Only create missing entries for the most recent portion of the gap
        // This prioritizes recent entries which are more likely to be resolvable
        final startCounter = gapSize > SyncTuning.maxGapSize
            ? counter - SyncTuning.maxGapSize
            : lastSeen + 1;

        for (var i = startCounter; i < counter; i++) {
          gaps.add((hostId: hostId, counter: i));

          // Check if we already have this entry
          final existing =
              await _syncDatabase.getEntryByHostAndCounter(hostId, i);
          if (existing == null) {
            await _syncDatabase.recordSequenceEntry(
              SyncSequenceLogCompanion(
                hostId: Value(hostId),
                counter: Value(i),
                originatingHostId: Value(originatingHostId),
                status: Value(SyncSequenceStatus.missing.index),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

            _loggingService.captureEvent(
              'gapDetected hostId=$hostId counter=$i (last seen: $lastSeen, observed: $counter) from=$originatingHostId',
              domain: 'SYNC_SEQUENCE',
              subDomain: 'gapDetected',
            );
          }
        }
      }

      // For the originator, record the actual entry with entryId
      if (hostId == originatingHostId) {
        final existing =
            await _syncDatabase.getEntryByHostAndCounter(hostId, counter);

        // Determine the new status:
        // - If already received/backfilled → keep existing status (don't downgrade)
        // - If we explicitly requested this entry → backfilled (request fulfilled)
        // - If it was missing but not yet requested → received (arrived via normal sync)
        // - Otherwise → received
        final SyncSequenceStatus status;
        if (existing != null &&
            (existing.status == SyncSequenceStatus.received.index ||
                existing.status == SyncSequenceStatus.backfilled.index)) {
          // Already received or backfilled - keep the existing status
          status = SyncSequenceStatus.values[existing.status];
        } else if (existing != null &&
            existing.status == SyncSequenceStatus.requested.index) {
          // Explicitly requested - mark as backfilled
          status = SyncSequenceStatus.backfilled;
        } else {
          // New entry or was missing - mark as received
          status = SyncSequenceStatus.received;
        }

        await _syncDatabase.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value(hostId),
            counter: Value(counter),
            entryId: Value(entryId),
            payloadType: Value(payloadType.index),
            originatingHostId: Value(originatingHostId),
            status: Value(status.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        if (status == SyncSequenceStatus.backfilled &&
            existing?.status == SyncSequenceStatus.requested.index) {
          _loggingService
            ..captureEvent(
              'recordReceivedEntry: backfilled hostId=$hostId counter=$counter entryId=$entryId',
              domain: 'SYNC_SEQUENCE',
              subDomain: 'backfillArrived',
            )
            ..captureEvent(
              'recordReceivedEntry: requestedResolved hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
              domain: 'SYNC_SEQUENCE',
              subDomain: 'requestedResolved',
            );
        }
      } else {
        // For other hosts in the VC, also record with entryId.
        // This is crucial because:
        // 1. It allows us to respond to backfill requests for any counter in the VC
        // 2. It updates missing/requested entries when we receive a newer version
        //    of an entry that includes this (host, counter) in its VC
        final existing =
            await _syncDatabase.getEntryByHostAndCounter(hostId, counter);

        // Determine the new status (same logic as for originator)
        final SyncSequenceStatus status;
        if (existing != null &&
            (existing.status == SyncSequenceStatus.received.index ||
                existing.status == SyncSequenceStatus.backfilled.index)) {
          // Already received or backfilled - keep the existing status
          status = SyncSequenceStatus.values[existing.status];
        } else if (existing != null &&
            existing.status == SyncSequenceStatus.requested.index) {
          // Explicitly requested - mark as backfilled
          status = SyncSequenceStatus.backfilled;
        } else {
          // New entry or was missing - mark as received
          status = SyncSequenceStatus.received;
        }

        // Always upsert (insert or update) with entryId
        await _syncDatabase.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value(hostId),
            counter: Value(counter),
            entryId: Value(entryId),
            payloadType: Value(payloadType.index),
            originatingHostId: Value(originatingHostId),
            status: Value(status.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        if (status == SyncSequenceStatus.backfilled &&
            existing?.status == SyncSequenceStatus.requested.index) {
          _loggingService
            ..captureEvent(
              'recordReceivedEntry: backfilled (non-originator) hostId=$hostId counter=$counter entryId=$entryId',
              domain: 'SYNC_SEQUENCE',
              subDomain: 'backfillArrived',
            )
            ..captureEvent(
              'recordReceivedEntry: requestedResolved (non-originator) hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
              domain: 'SYNC_SEQUENCE',
              subDomain: 'requestedResolved',
            );
        }
      }
    }

    if (gaps.isNotEmpty) {
      _loggingService.captureEvent(
        'recordReceivedEntry type=$payloadType entryId=$entryId detected ${gaps.length} gaps',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'recordReceived',
      );
    }

    // After processing the VC, check for any pending backfill hints.
    // This handles the case where a BackfillResponse arrived before the
    // actual entry. The hint contains the entryId, and now that we have
    // the entry, we can verify and mark it as backfilled.
    await resolvePendingHints(
      payloadType: payloadType,
      payloadId: entryId,
      payloadVectorClock: vectorClock,
    );

    // Note: Covered vector clocks are processed at the START of this method,
    // BEFORE gap detection, to prevent false positives.

    return gaps;
  }

  List<VectorClock> _filterCoveredVectorClocks(
    List<VectorClock>? coveredVectorClocks,
    VectorClock current,
  ) {
    if (coveredVectorClocks == null || coveredVectorClocks.isEmpty) {
      return const [];
    }
    final filtered = <VectorClock>[];
    for (final clock in coveredVectorClocks) {
      final isCurrent =
          VectorClock.compare(clock, current) == VclockStatus.equal;
      if (!isCurrent) {
        filtered.add(clock);
      }
    }
    return filtered;
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

  /// Mark counters from covered vector clocks as received.
  /// These are counters that were "spent" on superseded versions of the entry
  /// before the final version was sent.
  ///
  /// This method inserts records for covered counters even if they don't exist
  /// yet in the sequence log. This pre-emptively marks them as received before
  /// gap detection can mark them as missing, preventing unnecessary backfill
  /// requests for counters that were superseded before being sent.
  Future<void> _markCoveredCountersAsReceived({
    required List<VectorClock> coveredVectorClocks,
    required String entryId,
    required SyncSequencePayloadType payloadType,
    required String myHost,
  }) async {
    final now = DateTime.now();
    var markedCount = 0;

    for (final coveredClock in coveredVectorClocks) {
      for (final entry in coveredClock.vclock.entries) {
        final hostId = entry.key;
        final counter = entry.value;

        // Skip our own host
        if (hostId == myHost) continue;

        // Check if this counter already exists in the sequence log
        final existing =
            await _syncDatabase.getEntryByHostAndCounter(hostId, counter);

        // Insert or update record for covered counter:
        // - If doesn't exist: insert as received (pre-empt gap detection)
        // - If exists with missing/requested: update to received
        // - If exists with received/backfilled: skip (don't downgrade)
        if (existing == null) {
          // Counter doesn't exist - insert as received to pre-empt gap detection
          await _syncDatabase.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              entryId: Value(entryId),
              payloadType: Value(payloadType.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
          markedCount++;
        } else if (existing.status == SyncSequenceStatus.missing.index ||
            existing.status == SyncSequenceStatus.requested.index) {
          // Existing record with missing/requested - update to received
          await _syncDatabase.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              entryId: Value(entryId),
              payloadType: Value(payloadType.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(existing.createdAt),
              updatedAt: Value(now),
            ),
          );
          markedCount++;
          if (existing.status == SyncSequenceStatus.requested.index) {
            _loggingService.captureEvent(
              'recordReceivedEntry: requestedResolved (covered) hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
              domain: 'SYNC_SEQUENCE',
              subDomain: 'requestedResolved',
            );
          }
        }
        // If already received/backfilled, skip - don't downgrade status
      }
    }

    if (markedCount > 0) {
      _loggingService.captureEvent(
        'markCoveredCountersAsReceived: marked $markedCount counters as received for entry=$entryId',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'coveredClocks',
      );
    }
  }

  /// Get entries marked as missing or requested that haven't exceeded
  /// the maximum request count, for sending backfill requests.
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
  }) {
    return _syncDatabase.getMissingEntries(
      limit: limit,
      maxRequestCount: maxRequestCount,
    );
  }

  /// Get missing entries that should be requested, filtering out entries
  /// where we've already requested since the host was last seen.
  /// This prevents wasteful requests to hosts that haven't been online.
  Future<List<SyncSequenceLogItem>> getMissingEntriesForActiveHosts({
    int limit = 50,
    int maxRequestCount = 10,
  }) {
    return _syncDatabase.getMissingEntriesForActiveHosts(
      limit: limit,
      maxRequestCount: maxRequestCount,
    );
  }

  /// Mark entries as requested and increment their request count.
  /// Uses batch operations for efficiency.
  Future<void> markAsRequested(
    List<({String hostId, int counter})> entries,
  ) async {
    await _syncDatabase.batchIncrementRequestCounts(entries);
  }

  /// Handle a backfill response from another device.
  ///
  /// For deleted responses: marks the entry as deleted (cannot be backfilled).
  ///
  /// For unresolvable responses: marks the entry as unresolvable - the
  /// originating host confirmed it cannot resolve its own counter (e.g., it
  /// was superseded before being recorded).
  ///
  /// For non-deleted responses: stores the entryId as a "hint" mapping
  /// (hostId, counter) → entryId. The actual status update to "backfilled"
  /// happens only when we verify the entry exists locally - either via
  /// [verifyAndMarkBackfilled] or when the entry arrives via normal sync.
  ///
  /// This two-phase approach ensures we don't mark entries as backfilled
  /// until we actually have the data locally.
  Future<void> handleBackfillResponse({
    required String hostId,
    required int counter,
    required bool deleted,
    bool unresolvable = false,
    String? entryId,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    if (deleted) {
      // Mark as deleted - the entry was purged and cannot be backfilled
      await _syncDatabase.updateSequenceStatus(
        hostId,
        counter,
        SyncSequenceStatus.deleted,
      );

      _loggingService.captureEvent(
        'handleBackfillResponse hostId=$hostId counter=$counter deleted=true',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillResponse',
      );
      return;
    }

    if (unresolvable) {
      // Mark as unresolvable - the originating host cannot resolve its own
      // counter. This is permanent; the entry will never be backfilled.
      await _syncDatabase.updateSequenceStatus(
        hostId,
        counter,
        SyncSequenceStatus.unresolvable,
      );

      _loggingService.captureEvent(
        'handleBackfillResponse hostId=$hostId counter=$counter unresolvable=true',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillResponse',
      );
      return;
    }

    // Non-deleted response: store the entryId hint without changing status.
    // The actual backfill confirmation happens when we verify the entry exists.
    final existing =
        await _syncDatabase.getEntryByHostAndCounter(hostId, counter);

    if (existing == null) {
      // Entry doesn't exist in our log - insert with entryId hint and mark
      // as "requested" since we're receiving a response to a backfill request.
      // The actual backfilled status is set when we verify the entry exists.
      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(payloadType.index),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      _loggingService.captureEvent(
        'handleBackfillResponse: stored hint hostId=$hostId counter=$counter entryId=$entryId (new entry)',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillHint',
      );
      return;
    }

    // Don't overwrite already received/backfilled/deleted entries
    if (existing.status == SyncSequenceStatus.received.index ||
        existing.status == SyncSequenceStatus.backfilled.index ||
        existing.status == SyncSequenceStatus.deleted.index) {
      _loggingService.captureEvent(
        'handleBackfillResponse: entry already has status=${SyncSequenceStatus.values[existing.status]} hostId=$hostId counter=$counter',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillResponse',
      );
      return;
    }

    // Store the entryId hint on the existing missing/requested entry.
    // Don't change status yet - that happens when we verify the entry exists.
    final now = DateTime.now();
    await _syncDatabase.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value(entryId),
        payloadType: Value(payloadType.index),
        // Keep existing status - don't mark as backfilled yet
        status: Value(existing.status),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    _loggingService.captureEvent(
      'handleBackfillResponse: stored hint hostId=$hostId counter=$counter entryId=$entryId (status=${SyncSequenceStatus.values[existing.status]})',
      domain: 'SYNC_SEQUENCE',
      subDomain: 'backfillHint',
    );
  }

  /// Verify that we have an entry locally and its VC covers the requested
  /// (hostId, counter), then mark as backfilled.
  ///
  /// Returns true if verified and marked as backfilled.
  Future<bool> verifyAndMarkBackfilled({
    required String hostId,
    required int counter,
    required String entryId,
    required VectorClock entryVectorClock,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    // Verify the entry's VC covers the requested (hostId, counter)
    final vcCounter = entryVectorClock.vclock[hostId];
    if (vcCounter == null || vcCounter < counter) {
      _loggingService.captureEvent(
        'verifyAndMarkBackfilled: entry $entryId VC does not cover $hostId:$counter (vc[$hostId]=$vcCounter)',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillVerify',
      );
      return false;
    }

    // Look up the sequence log entry
    final existing =
        await _syncDatabase.getEntryByHostAndCounter(hostId, counter);

    if (existing == null ||
        (existing.status != SyncSequenceStatus.missing.index &&
            existing.status != SyncSequenceStatus.requested.index)) {
      // Already processed or doesn't exist
      return false;
    }

    // Mark as backfilled
    final now = DateTime.now();
    await _syncDatabase.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value(entryId),
        payloadType: Value(payloadType.index),
        status: Value(SyncSequenceStatus.backfilled.index),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    _loggingService.captureEvent(
      'verifyAndMarkBackfilled: confirmed hostId=$hostId counter=$counter entryId=$entryId',
      domain: 'SYNC_SEQUENCE',
      subDomain: 'backfillVerified',
    );
    return true;
  }

  /// Resolve any pending backfill hints for the given entryId.
  /// Called after receiving an entry via sync to check if it resolves
  /// any pending (hostId, counter) requests.
  Future<int> resolvePendingHints({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
    required VectorClock payloadVectorClock,
  }) async {
    final pendingEntries = await _syncDatabase.getPendingEntriesByPayloadId(
      payloadType: payloadType,
      payloadId: payloadId,
    );

    var resolved = 0;
    for (final pending in pendingEntries) {
      final verified = await verifyAndMarkBackfilled(
        hostId: pending.hostId,
        counter: pending.counter,
        entryId: payloadId,
        entryVectorClock: payloadVectorClock,
        payloadType: payloadType,
      );
      if (verified) {
        resolved++;
      }
    }

    if (resolved > 0) {
      _loggingService.captureEvent(
        'resolvePendingHints: resolved $resolved pending entries for type=$payloadType id=$payloadId',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillResolved',
      );
    }

    return resolved;
  }

  /// Update status to backfilled when an entry arrives that was previously
  /// marked as missing. This is now also handled by [recordReceivedEntry],
  /// but this method can be called explicitly if needed.
  Future<void> markAsReceived({
    required String hostId,
    required int counter,
    required String entryId,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    final existing =
        await _syncDatabase.getEntryByHostAndCounter(hostId, counter);

    if (existing != null &&
        (existing.status == SyncSequenceStatus.missing.index ||
            existing.status == SyncSequenceStatus.requested.index)) {
      // Previously missing entry has now arrived
      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(payloadType.index),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      _loggingService.captureEvent(
        'markAsReceived hostId=$hostId counter=$counter entryId=$entryId (was missing)',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillArrived',
      );
    }
  }

  /// Get entry by host ID and counter (for responding to backfill requests).
  Future<SyncSequenceLogItem?> getEntryByHostAndCounter(
    String hostId,
    int counter,
  ) {
    return _syncDatabase.getEntryByHostAndCounter(hostId, counter);
  }

  /// Watch the count of missing entries for UI display.
  Stream<int> watchMissingCount() {
    return _syncDatabase.watchMissingCount();
  }

  /// Get backfill statistics grouped by host.
  Future<BackfillStats> getBackfillStats() {
    return _syncDatabase.getBackfillStats();
  }

  /// Get missing entries with age and per-host limits for automatic backfill.
  /// This is used for bounded automatic backfill that only looks at recent gaps.
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    int? maxPerHost,
  }) {
    return _syncDatabase.getMissingEntriesWithLimits(
      limit: limit,
      maxRequestCount: maxRequestCount,
      maxAge: maxAge,
      maxPerHost: maxPerHost,
    );
  }

  /// Get entries with status 'requested' for re-requesting.
  /// These are entries that were requested but never received.
  Future<List<SyncSequenceLogItem>> getRequestedEntries({
    int limit = 50,
  }) {
    return _syncDatabase.getRequestedEntries(limit: limit);
  }

  /// Reset request counts for specified entries to allow re-requesting.
  Future<void> resetRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    await _syncDatabase.resetRequestCounts(entries);

    _loggingService.captureEvent(
      'resetRequestCounts: reset ${entries.length} entries for re-request',
      domain: 'SYNC_SEQUENCE',
      subDomain: 'reRequest',
    );
  }

  /// Populate the sequence log from existing journal entries.
  /// This is used to backfill the sequence log for entries that were
  /// created before the sequence log feature was added.
  ///
  /// This method streams journal entries in batches and records their vector
  /// clocks in the sequence log. Records entries for ALL hosts in each entry's
  /// vector clock so any device with the entry can respond to backfill requests.
  ///
  /// [onProgress] is called with progress from 0.0 to 1.0 as entries are
  /// processed.
  ///
  /// Returns the number of entries populated.
  Future<int> populateFromJournal({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
        entryStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) async {
    final total = await getTotalCount();
    var processed = 0;
    var populated = 0;
    final now = DateTime.now();

    // Cache of existing (hostId, counter) pairs to avoid duplicates
    // We'll populate this lazily per-host as we encounter them
    final existingByHost = <String, Set<int>>{};

    await for (final batch in entryStream) {
      final toInsert = <SyncSequenceLogCompanion>[];

      for (final entry in batch) {
        processed++;

        final vc = entry.vectorClock;
        if (vc == null || vc.isEmpty) continue;

        // Find the originating host (the one with the highest counter,
        // which is typically the creator of this specific entry version)
        String? originatingHost;
        var maxCounter = 0;
        for (final e in vc.entries) {
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
            existingByHost[hostId] =
                await _syncDatabase.getCountersForHost(hostId);
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
              entryId: Value(entry.id),
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
      _loggingService.captureEvent(
        'populateFromJournal: added $populated sequence log entries',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'populate',
      );
    }

    return populated;
  }

  /// Populate the sequence log from existing entry links.
  /// This is used to backfill the sequence log for entry links that were
  /// created before the sequence log feature was added, or to resolve
  /// "ghost missing" counters that correspond to EntryLink operations.
  ///
  /// This method streams entry links in batches and records their vector
  /// clocks in the sequence log with [SyncSequencePayloadType.entryLink].
  /// Records entries for ALL hosts in each link's vector clock so any device
  /// with the link can respond to backfill requests.
  ///
  /// [onProgress] is called with progress from 0.0 to 1.0 as links are
  /// processed.
  ///
  /// Returns the number of entries populated.
  Future<int> populateFromEntryLinks({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
        linkStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) async {
    final total = await getTotalCount();
    var processed = 0;
    var populated = 0;
    final now = DateTime.now();

    // Cache of existing (hostId, counter) pairs to avoid duplicates
    // We'll populate this lazily per-host as we encounter them
    final existingByHost = <String, Set<int>>{};

    await for (final batch in linkStream) {
      final toInsert = <SyncSequenceLogCompanion>[];

      for (final link in batch) {
        processed++;

        final vc = link.vectorClock;
        if (vc == null || vc.isEmpty) continue;

        // Find the originating host (the one with the highest counter,
        // which is typically the creator of this specific link version).
        // Sort entries by host ID first to ensure deterministic tie-breaking
        // when multiple hosts have the same max counter.
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
            existingByHost[hostId] =
                await _syncDatabase.getCountersForHost(hostId);
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
              entryId: Value(link.id),
              payloadType: Value(SyncSequencePayloadType.entryLink.index),
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
      _loggingService.captureEvent(
        'populateFromEntryLinks: added $populated sequence log entries',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'populate',
      );
    }

    return populated;
  }
}
