part of 'sync_db.dart';

/// Persistence of the deep-backfill requests this device waits on
/// ([DeepBackfillRequests]). The protocol lives in `DeepBackfillService`.
mixin _SyncDbDeepBackfill on _$SyncDatabase {
  /// The outstanding requests to [targetHostId] for [payloadType] records
  /// whose id lies in `[start, end)`; a null bound is unbounded.
  Future<List<DeepBackfillRequestItem>> deepBackfillRequestsInRange({
    required String targetHostId,
    required SyncSequencePayloadType payloadType,
    required String? start,
    required String? end,
  }) {
    final query = select(deepBackfillRequests)
      ..where(
        (t) =>
            t.targetHostId.equals(targetHostId) &
            t.payloadType.equals(payloadType.index),
      );
    if (start != null) {
      query.where((t) => t.entryId.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where((t) => t.entryId.isSmallerThanValue(end));
    }
    return query.get();
  }

  /// Records [requests] as outstanding, replacing an earlier row for the
  /// same advertiser and record.
  Future<void> recordDeepBackfillRequests(
    List<DeepBackfillRequestsCompanion> requests,
  ) async {
    if (requests.isEmpty) return;
    await batch(
      (batch) =>
          batch.insertAllOnConflictUpdate(deepBackfillRequests, requests),
    );
  }

  /// Forgets the outstanding requests to [targetHostId] for [entryIds].
  Future<void> removeDeepBackfillRequests({
    required String targetHostId,
    required SyncSequencePayloadType payloadType,
    required Set<String> entryIds,
  }) async {
    if (entryIds.isEmpty) return;
    final ids = entryIds.toList(growable: false);
    for (var i = 0; i < ids.length; i += _deepBackfillDeleteChunk) {
      final chunk = ids.sublist(
        i,
        i + _deepBackfillDeleteChunk > ids.length
            ? ids.length
            : i + _deepBackfillDeleteChunk,
      );
      await (delete(deepBackfillRequests)..where(
            (t) =>
                t.targetHostId.equals(targetHostId) &
                t.payloadType.equals(payloadType.index) &
                t.entryId.isIn(chunk),
          ))
          .go();
    }
  }
}

/// Ids per `DELETE ... IN (...)`, well under SQLite's variable limit.
const _deepBackfillDeleteChunk = 500;
