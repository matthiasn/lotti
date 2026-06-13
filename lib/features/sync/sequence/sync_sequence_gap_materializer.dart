import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Large-gap materialization and covered-counter bookkeeping for the sync
/// sequence log — the heavy lifting behind the receive path.
class SyncSequenceGapMaterializer {
  SyncSequenceGapMaterializer({
    required this._syncDatabase,
    required this._cache,
    required this._tracer,
  });

  final SyncDatabase _syncDatabase;
  final SyncSequenceCache _cache;
  final SyncSequenceTracer _tracer;

  Future<int> materializeLargeGap({
    required String hostId,
    required int startCounter,
    required int endCounter,
    required int gapSize,
    required String originatingHostId,
    required DateTime now,
  }) async {
    if (gapSize >= SyncTuning.extremeGapWarningSize) {
      _tracer.trace(
        'extremeGapDetected hostId=$hostId gapSize=$gapSize '
        'start=$startCounter end=$endCounter '
        'chunkSize=${SyncTuning.gapMaterializationChunkSize}',
        subDomain: 'sequence.extremeGap',
      );
    }

    var insertedCount = 0;
    for (
      var chunkStart = startCounter;
      chunkStart <= endCounter;
      chunkStart += SyncTuning.gapMaterializationChunkSize
    ) {
      final chunkEnd = math.min(
        endCounter,
        chunkStart + SyncTuning.gapMaterializationChunkSize - 1,
      );
      final existingCounters = await _syncDatabase.getCountersForHostInRange(
        hostId,
        chunkStart,
        chunkEnd,
      );
      final missingEntries = <SyncSequenceLogCompanion>[];

      for (var counter = chunkStart; counter <= chunkEnd; counter++) {
        if (!existingCounters.contains(counter)) {
          missingEntries.add(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              originatingHostId: Value(originatingHostId),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }

      if (missingEntries.isNotEmpty) {
        insertedCount += missingEntries.length;
        await _syncDatabase.batchInsertSequenceEntries(missingEntries);
      }
    }

    return insertedCount;
  }

  List<VectorClock> filterCoveredVectorClocks(
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

  /// Mark counters from covered vector clocks as received.
  /// These are counters that were "spent" on superseded versions of the entry
  /// before the final version was sent.
  ///
  /// This method inserts records for covered counters even if they don't exist
  /// yet in the sequence log. This pre-emptively marks them as received before
  /// gap detection can mark them as missing, preventing unnecessary backfill
  /// requests for counters that were superseded before being sent.
  Future<void> markCoveredCountersAsReceived({
    required List<VectorClock> coveredVectorClocks,
    required String entryId,
    required SyncSequencePayloadType payloadType,
    required String myHost,
  }) async {
    final now = DateTime.now();
    var markedCount = 0;
    final affectedHosts = <String>{};

    for (final coveredClock in coveredVectorClocks) {
      for (final entry in coveredClock.vclock.entries) {
        final hostId = entry.key;
        final counter = entry.value;

        // Skip our own host
        if (hostId == myHost) continue;

        // Check if this counter already exists in the sequence log
        final existing = await _syncDatabase.getEntryByHostAndCounter(
          hostId,
          counter,
        );

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
          affectedHosts.add(hostId);
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
          affectedHosts.add(hostId);
          if (existing.status == SyncSequenceStatus.requested.index) {
            _tracer.trace(
              'recordReceivedEntry: requestedResolved (covered) hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
              subDomain: 'sequence.requestedResolved',
            );
          }
        }
        // If already received/backfilled, skip - don't downgrade status
      }
    }

    if (markedCount > 0) {
      // Invalidate the watermark cache for affected hosts so that subsequent
      // gap detection in the same recordReceivedEntry call sees the updated
      // contiguous watermark. Without this, the stale cached watermark causes
      // repeated gap detection events for counters that were just resolved.
      affectedHosts.forEach(_cache.invalidateCacheForHost);
      _tracer.trace(
        'markCoveredCountersAsReceived: marked $markedCount counters as received for entry=$entryId',
        subDomain: 'sequence.coveredClocks',
      );
    }
  }
}
