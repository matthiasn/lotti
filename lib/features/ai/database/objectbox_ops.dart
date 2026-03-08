import 'dart:typed_data';

import 'package:lotti/features/ai/database/entity_metadata_row.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';

/// Thin abstraction over ObjectBox Store/Box/Query operations.
///
/// Production code uses `RealObjectBoxOps` which wraps the native ObjectBox
/// library. Tests use a mock implementation to avoid needing the native lib.
abstract class ObjectBoxOps {
  /// Returns the total number of stored entities.
  int count();

  /// Closes the underlying store.
  void close();

  /// Removes all entities.
  void removeAll();

  /// Finds an entity by its unique embedding key (entityId:chunkIndex).
  EmbeddingChunkEntity? findByEmbeddingKey(String embeddingKey);

  /// Returns the ObjectBox IDs of all entities matching [entityId].
  List<int> findIdsByEntityId(String entityId);

  /// Returns the first entity matching [entityId], or null.
  EmbeddingChunkEntity? findFirstByEntityId(String entityId);

  /// Returns all chunk entities matching [entityId] (full objects including
  /// vectors). Used for shard-to-shard moves.
  List<EmbeddingChunkEntity> findEntitiesByEntityId(String entityId);

  /// Returns lightweight entityId+taskId metadata for every stored entity.
  ///
  /// Uses property queries to avoid loading the full embedding vectors,
  /// keeping memory usage low during startup index rebuilds.
  List<EntityMetadataRow> queryAllEntityMetadata();

  /// Returns all stored entities (full objects including vectors).
  ///
  /// Used for one-time migration. Prefer [queryAllEntityMetadata] for
  /// lightweight index rebuilds.
  List<EmbeddingChunkEntity> findAllEntities();

  /// Inserts or updates multiple entities.
  void putMany(List<EmbeddingChunkEntity> entities);

  /// Removes entities by their ObjectBox IDs.
  void removeMany(List<int> ids);

  /// Performs a nearest-neighbor search on the embedding vector.
  List<EmbeddingSearchHit> nearestNeighborSearch({
    required Float32List queryVector,
    required int maxResults,
    required int limit,
    String? entityTypeFilter,
    List<String>? categoryIds,
  });

  /// Executes [action] inside a write transaction.
  void runInWriteTransaction(void Function() action);
}

/// A search hit from [ObjectBoxOps.nearestNeighborSearch].
class EmbeddingSearchHit {
  EmbeddingSearchHit({required this.object, required this.score});

  final EmbeddingChunkEntity object;
  final double score;
}
