import 'dart:async';
import 'dart:typed_data';

/// The fixed embedding dimension used by the current embedding model.
const kEmbeddingDimensions = 1024;

/// Result of a vector similarity search.
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
abstract class EmbeddingStore {
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

  FutureOr<bool> hasEmbedding(String entityId);

  FutureOr<int> get count;

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

  FutureOr<void> deleteEntityEmbeddings(String entityId);

  FutureOr<List<EmbeddingSearchResult>> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  });

  FutureOr<void> deleteAll();

  FutureOr<void> close();
}
