import 'dart:async';
import 'dart:typed_data';

import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_embedder.dart';

/// The fixed embedding dimension used by the current embedding model.
const int kEmbeddingDimensions = GemmaEmbedder.dimensions;

/// One hit from an [EmbeddingStore.search]: the matched entity (and chunk)
/// plus its [distance] to the query vector (smaller = more similar).
class EmbeddingSearchResult {
  const EmbeddingSearchResult({
    required this.entityId,
    required this.distance,
    required this.entityType,
    this.taskId = '',
  });

  final String entityId;
  final double distance;
  final String entityType;

  /// The task ID this embedding relates to, for direct lookup.
  ///
  /// Populated for agent report embeddings to link back to the parent task.
  /// Empty string when not applicable.
  final String taskId;
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

  /// The agent reports embedded for [taskId], by entity id.
  FutureOr<Set<String>> agentReportIdsForTask(String taskId);

  /// Whether any embedding chunk exists for [entityId].
  FutureOr<bool> hasEmbedding(String entityId);

  /// Total number of embedding chunks across all entities.
  FutureOr<int> get count;

  /// The stored version of [entityId]'s register, tombstones included, or
  /// `null` when the entity has none.
  FutureOr<EmbeddingRegister?> getRegister(String entityId);

  /// The stored chunk vectors of [entityId], in chunk order; empty when it
  /// has none. What a resent version carries.
  FutureOr<List<Float32List>> chunkVectors(String entityId);

  /// Every stored register, tombstones included: what deep backfill, the
  /// sequence-log population and Add Device walk.
  FutureOr<List<EmbeddingRegister>> allRegisters();

  /// Replaces all embedding chunks for [entityId] with [embeddings].
  ///
  /// Deletes any prior chunks for the entity first, so this is an upsert at the
  /// entity granularity. [contentHash] is stored alongside for change
  /// detection; [categoryId] selects the shard; [taskId] / [subtype] link
  /// agent-report embeddings back to their parent task.
  ///
  /// [register] is the version this chunk set belongs to, `null` for none.
  /// It is written in the same transaction as the chunks, so a chunk set is
  /// never stored beside the version of another one.
  FutureOr<void> replaceEntityEmbeddings({
    required String entityId,
    required String entityType,
    required String modelId,
    required String contentHash,
    required List<Float32List> embeddings,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
    EmbeddingRegister? register,
  });

  /// Removes every embedding chunk for [entityId], and its register.
  FutureOr<void> deleteEntityEmbeddings(String entityId);

  /// Replaces the register row of [register]'s entity and leaves its chunks
  /// as they are: a version that kept its chunk set but merged another
  /// version's clock.
  FutureOr<void> putRegister(EmbeddingRegister register);

  /// Removes every embedding chunk for the register's entity and stores
  /// [tombstone] in their place: the version that says the entry has no
  /// vectors, kept so a delayed copy of an older live version is dominated
  /// by it.
  FutureOr<void> writeTombstone(EmbeddingRegister tombstone);

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

  /// Removes all embeddings and registers from the store.
  FutureOr<void> deleteAll();

  /// Releases the underlying database resources.
  FutureOr<void> close();
}
