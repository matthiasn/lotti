import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
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
          originatingHostId: Value(myHost),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      _loggingService.captureEvent(
        'recordSentEntry hostId=$hostId counter=$counter entryId=$entryId',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'recordSent',
      );
    }
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
  Future<List<({String hostId, int counter})>> recordReceivedEntry({
    required String entryId,
    required VectorClock vectorClock,
    required String originatingHostId,
  }) async {
    final gaps = <({String hostId, int counter})>[];
    final myHost = await _vectorClockService.getHost();
    final now = DateTime.now();

    // Update host activity for the originating host - they're online!
    await _syncDatabase.updateHostActivity(originatingHostId, now);

    // Check gaps for ALL hosts in the VC (except ourselves)
    for (final entry in vectorClock.vclock.entries) {
      final hostId = entry.key;
      final counter = entry.value;

      // Skip our own host
      if (hostId == myHost) continue;

      final lastSeen = await _syncDatabase.getLastCounterForHost(hostId);

      if (lastSeen != null && counter > lastSeen + 1) {
        // Gap detected! Mark all missing counters for this host
        for (var i = lastSeen + 1; i < counter; i++) {
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
        final wasMissing = existing != null &&
            (existing.status == SyncSequenceStatus.missing.index ||
                existing.status == SyncSequenceStatus.requested.index);

        final status = wasMissing
            ? SyncSequenceStatus.backfilled
            : SyncSequenceStatus.received;

        await _syncDatabase.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value(hostId),
            counter: Value(counter),
            entryId: Value(entryId),
            originatingHostId: Value(originatingHostId),
            status: Value(status.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        if (wasMissing) {
          _loggingService.captureEvent(
            'recordReceivedEntry: backfilled hostId=$hostId counter=$counter entryId=$entryId',
            domain: 'SYNC_SEQUENCE',
            subDomain: 'backfillArrived',
          );
        }
      } else {
        // For other hosts, just record we've observed this counter (no entryId)
        // This helps with gap detection on future messages
        final existing =
            await _syncDatabase.getEntryByHostAndCounter(hostId, counter);
        if (existing == null) {
          await _syncDatabase.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              originatingHostId: Value(originatingHostId),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }
    }

    if (gaps.isNotEmpty) {
      _loggingService.captureEvent(
        'recordReceivedEntry entryId=$entryId detected ${gaps.length} gaps',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'recordReceived',
      );
    }

    return gaps;
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
  Future<void> markAsRequested(
    List<({String hostId, int counter})> entries,
  ) async {
    for (final entry in entries) {
      await _syncDatabase.incrementRequestCount(entry.hostId, entry.counter);
    }
  }

  /// Handle a backfill response indicating the entry was deleted/purged.
  /// For successful backfills, the entry arrives via normal sync and
  /// [recordReceivedEntry] handles updating the status to backfilled.
  Future<void> handleBackfillResponse({
    required String hostId,
    required int counter,
    required bool deleted,
    String? entryId,
  }) async {
    if (!deleted) {
      // Non-deleted responses are no longer sent - the entry arrives via
      // normal sync and recordReceivedEntry handles the status update.
      // This path is kept for backwards compatibility with older clients.
      _loggingService.captureEvent(
        'handleBackfillResponse: ignoring non-deleted response hostId=$hostId counter=$counter',
        domain: 'SYNC_SEQUENCE',
        subDomain: 'backfillResponse',
      );
      return;
    }

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
  }

  /// Update status to backfilled when an entry arrives that was previously
  /// marked as missing. This is now also handled by [recordReceivedEntry],
  /// but this method can be called explicitly if needed.
  Future<void> markAsReceived({
    required String hostId,
    required int counter,
    required String entryId,
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
}
