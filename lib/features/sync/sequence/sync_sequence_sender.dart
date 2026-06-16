import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Records entries that THIS device sends, so it can answer backfill requests
/// from peers.
///
/// Writes only our own host's counters into the sequence log and keeps the
/// shared last-sent LRU in [SyncSequenceCache] consistent with each write so a
/// subsequent `getLastSentVectorClockForEntry` does not race back to the DB
/// for a value we already know.
class SyncSequenceSender {
  SyncSequenceSender({
    required this._syncDatabase,
    required this._vectorClockService,
    required this._cache,
    required this._tracer,
  });

  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  final SyncSequenceCache _cache;
  final SyncSequenceTracer _tracer;

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

      // Keep the cache consistent with the write we just issued so a
      // subsequent `getLastSentVectorClockForEntry` does not race back to
      // the DB for a value we already know.
      final cacheKey = _cache.lastSentCacheKey(hostId, entryId);
      final previous = _cache.getLastSent(cacheKey);
      if (previous == null || counter > previous) {
        _cache.touchLastSentCache(cacheKey, counter);
      }

      _tracer.trace(
        'recordSentEntry type=$payloadType hostId=$hostId counter=$counter entryId=$entryId',
        subDomain: 'sequence.recordSent',
      );
    }
  }

  /// Records a sent entry link in the sequence log (as
  /// [SyncSequencePayloadType.entryLink]) so peers can detect and backfill it
  /// if missed. Convenience wrapper over `recordSentEntry`.
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
}
