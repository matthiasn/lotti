import 'dart:async';
import 'dart:typed_data';

/// The fixed embedding dimension used by the current embedding model.
const kEmbeddingDimensions = 1024;

/// One hit from an [EmbeddingStore.search]: the matched entity (and chunk)
/// plus its [distance] to the query vector (smaller = more similar).
class EmbeddingSearchResult {
  const EmbeddingSearchResult({
    required this.entityId,
    required this.distance,
    required this.entityType,
    this.chunkIndex = 0,
    this.taskId = '',
    this.subtype = '',
  });

  final String entityId;
  final double distance;
  final String entityType;

  /// The zero-based chunk index within the source entity.
  ///
  /// For short content that fits in a single chunk this is 0.
  /// For chunked content this identifies which segment matched.
  final int chunkIndex;

  /// The task ID this embedding relates to, for direct lookup.
  ///
  /// Populated for agent report embeddings to link back to the parent task.
  /// Empty string when not applicable.
  final String taskId;

  /// The subtype of the embedding, e.g. agent template name.
  ///
  /// Used to distinguish between multiple agent reports for the same task.
  /// Empty string when not applicable.
  final String subtype;
}

/// Backend-neutral store for derived vector embeddings.
///
/// Implemented by the ObjectBox-backed stores (single-store and sharded) and
/// stubbed in tests. Entities are keyed by `entityId`; their content may be
/// split into multiple chunks, each a [kEmbeddingDimensions]-length vector. The
/// stored `contentHash` lets callers skip re-embedding unchanged content.
abstract class EmbeddingStore {
  /// Returns the content hash recorded for [entityId], or `null` if the entity
  /// has no embeddings. Used to detect whether content changed since the last
  /// embedding run so unchanged entities can be skipped.
  FutureOr<String?> getContentHash(String entityId);

  /// Returns the category ID stored for [entityId], or `null` if the entity
  /// is not in the store.
  FutureOr<String?> getCategoryId(String entityId);

  /// Moves all embedding chunks for [entityId] to the shard for
  /// [newCategoryId].
  ///
  /// Implementations that do not use sharding may simply update the stored
  /// `categoryId` field (or no-op).
  FutureOr<void> moveEntityToShard(String entityId, String newCategoryId);

  /// Moves embeddings for all agent reports linked to [taskId] to the shard
  /// for [newCategoryId].
  ///
  /// This cascades a category change from a task to its related reports.
  FutureOr<void> moveRelatedReportEmbeddings(
    String taskId,
    String newCategoryId,
  );

  /// Whether any embedding chunk exists for [entityId].
  FutureOr<bool> hasEmbedding(String entityId);

  /// Total number of embedding chunks across all entities.
  FutureOr<int> get count;

  /// Replaces all embedding chunks for [entityId] with [embeddings].
  ///
  /// Deletes any prior chunks for the entity first, so this is an upsert at the
  /// entity granularity. [contentHash] is stored alongside for change
  /// detection; [categoryId] selects the shard; [taskId] / [subtype] link
  /// agent-report embeddings back to their parent task.
  FutureOr<void> replaceEntityEmbeddings({
    required String entityId,
    required String entityType,
    required String modelId,
    required String contentHash,
    required List<Float32List> embeddings,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
  });

  /// Removes every embedding chunk for [entityId].
  FutureOr<void> deleteEntityEmbeddings(String entityId);

  /// Nearest-neighbour search for [queryVector].
  ///
  /// Returns up to [k] results ordered by ascending [EmbeddingSearchResult.distance].
  /// [entityTypeFilter] restricts to a single entity type; [categoryIds]
  /// restricts to specific shards/categories (null = all).
  FutureOr<List<EmbeddingSearchResult>> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  });

  /// Removes all embeddings from the store.
  FutureOr<void> deleteAll();

  /// Releases the underlying database resources.
  FutureOr<void> close();
}
