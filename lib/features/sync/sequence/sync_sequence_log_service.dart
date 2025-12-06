import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
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

  /// Handle a backfill response, updating the sequence log status.
  Future<void> handleBackfillResponse({
    required String hostId,
    required int counter,
    required bool deleted,
    String? entryId,
  }) async {
    final status =
        deleted ? SyncSequenceStatus.deleted : SyncSequenceStatus.backfilled;

    // If we got an entry ID, record it
    if (!deleted && entryId != null) {
      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          status: Value(status.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    } else {
      // Just update the status
      await _syncDatabase.updateSequenceStatus(hostId, counter, status);
    }

    _loggingService.captureEvent(
      'handleBackfillResponse hostId=$hostId counter=$counter deleted=$deleted entryId=$entryId',
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
}
