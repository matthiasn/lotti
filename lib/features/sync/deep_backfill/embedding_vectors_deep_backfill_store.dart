import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_store.dart';
import 'package:lotti/features/sync/embedding_vectors/embedding_vectors_sync.dart';

/// Embedding-vector registers (ADR 0149), read from the vector store through
/// [EmbeddingVectorsSync]: one row per `<entityId>|<modelId>` this device
/// shared or received, tombstones included, listed and resent like a live
/// version.
///
/// The store is ObjectBox, not a Drift table, so rows are read whole and
/// filtered here; [changes] never fires, and the record count refreshes on
/// the page's own schedule. A device that does not store vectors — the
/// pipeline absent, or a flag off — takes no part.
class EmbeddingVectorsDeepBackfillStore extends DeepBackfillStore {
  EmbeddingVectorsDeepBackfillStore(this._vectors);

  final EmbeddingVectorsSync _vectors;

  @override
  SyncSequencePayloadType get payloadType =>
      SyncSequencePayloadType.embeddingVectors;

  @override
  Future<bool> participates() => _vectors.isSharing;

  @override
  Future<int> count() async => (await _vectors.sharedRegisters()).length;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  }) async => [
    for (final register in await _vectors.sharedRegisters())
      if (after == null || register.id.compareTo(after) > 0)
        (id: register.id, clock: register.vectorClock, agentIds: null),
  ].take(limit).toList();

  @override
  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  }) async => {
    for (final register in await _vectors.sharedRegisters())
      if ((start == null || register.id.compareTo(start) >= 0) &&
          (end == null || register.id.compareTo(end) < 0))
        register.id: register.vectorClock,
  };

  /// Sends the version each register holds now, with its chunks, or its
  /// tombstone.
  @override
  Future<int> enqueueCurrent(
    Set<String> ids, {
    required Set<String> withMedia,
  }) async {
    var sent = 0;
    for (final id in ids) {
      if (await _vectors.resend(id)) sent++;
    }
    return sent;
  }
}
