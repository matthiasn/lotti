// coverage:ignore-file
import 'dart:typed_data';

import 'package:lotti/features/ai/database/entity_metadata_row.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';
import 'package:lotti/features/ai/database/objectbox_ops.dart';
import 'package:lotti/objectbox.g.dart';

/// Production [ObjectBoxOps] backed by a real ObjectBox [Store].
class RealObjectBoxOps implements ObjectBoxOps {
  RealObjectBoxOps(this._store) : _box = _store.box<EmbeddingChunkEntity>();

  final Store _store;
  final Box<EmbeddingChunkEntity> _box;

  @override
  int count() => _box.count();

  @override
  void close() => _store.close();

  @override
  void removeAll() => _box.removeAll();

  @override
  EmbeddingChunkEntity? findByEmbeddingKey(String embeddingKey) {
    final query = _box
        .query(EmbeddingChunkEntity_.embeddingKey.equals(embeddingKey))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  List<int> findIdsByEntityId(String entityId) {
    final query = _box
        .query(EmbeddingChunkEntity_.entityId.equals(entityId))
        .build();
    try {
      return query.findIds();
    } finally {
      query.close();
    }
  }

  @override
  EmbeddingChunkEntity? findFirstByEntityId(String entityId) {
    final query =
        _box.query(EmbeddingChunkEntity_.entityId.equals(entityId)).build()
          ..limit = 1;
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  List<EmbeddingChunkEntity> findEntitiesByEntityId(String entityId) {
    final query = _box
        .query(EmbeddingChunkEntity_.entityId.equals(entityId))
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  List<EntityMetadataRow> queryAllEntityMetadata() {
    // Use property queries to avoid loading 4KB embedding vectors per entity.
    final query = _box.query().build();
    try {
      final entityIds = query.property(EmbeddingChunkEntity_.entityId).find();
      final taskIds = query.property(EmbeddingChunkEntity_.taskId).find();

      return [
        for (var i = 0; i < entityIds.length; i++)
          EntityMetadataRow(entityId: entityIds[i], taskId: taskIds[i]),
      ];
    } finally {
      query.close();
    }
  }

  @override
  List<EmbeddingChunkEntity> findAllEntities() => _box.getAll();

  @override
  void putMany(List<EmbeddingChunkEntity> entities) => _box.putMany(entities);

  @override
  void removeMany(List<int> ids) => _box.removeMany(ids);

  @override
  List<EmbeddingSearchHit> nearestNeighborSearch({
    required Float32List queryVector,
    required int maxResults,
    required int limit,
    String? entityTypeFilter,
    List<String>? categoryIds,
  }) {
    var condition = EmbeddingChunkEntity_.embedding.nearestNeighborsF32(
      queryVector,
      maxResults,
    );

    if (entityTypeFilter != null) {
      condition = condition.and(
        EmbeddingChunkEntity_.entityType.equals(entityTypeFilter),
      );
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      condition = condition.and(
        EmbeddingChunkEntity_.categoryId.oneOf(categoryIds),
      );
    }

    final query = _box.query(condition).build()..limit = limit;

    try {
      return query
          .findWithScores()
          .map(
            (hit) => EmbeddingSearchHit(object: hit.object, score: hit.score),
          )
          .toList(growable: false);
    } finally {
      query.close();
    }
  }

  @override
  void runInWriteTransaction(void Function() action) {
    _store.runInTransaction(TxMode.write, action);
  }
}
