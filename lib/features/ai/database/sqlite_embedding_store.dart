import 'dart:typed_data';

import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';

/// Adapter that exposes the current sqlite-vec backend via [EmbeddingStore].
class SqliteEmbeddingStore implements EmbeddingStore {
  SqliteEmbeddingStore(this._db);

  final EmbeddingsDb _db;

  @override
  int get count => _db.count;

  @override
  void close() => _db.close();

  @override
  void deleteAll() => _db.deleteAll();

  @override
  void deleteEntityEmbeddings(String entityId) =>
      _db.deleteEntityEmbeddings(entityId);

  @override
  String? getContentHash(String entityId) => _db.getContentHash(entityId);

  @override
  bool hasEmbedding(String entityId) => _db.hasEmbedding(entityId);

  @override
  void replaceEntityEmbeddings({
    required String entityId,
    required String entityType,
    required String modelId,
    required String contentHash,
    required List<Float32List> embeddings,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
  }) {
    _db.deleteEntityEmbeddings(entityId);
    for (var i = 0; i < embeddings.length; i++) {
      _db.upsertEmbedding(
        entityId: entityId,
        chunkIndex: i,
        entityType: entityType,
        modelId: modelId,
        embedding: embeddings[i],
        contentHash: contentHash,
        categoryId: categoryId,
        taskId: taskId,
        subtype: subtype,
      );
    }
  }

  @override
  List<EmbeddingSearchResult> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  }) {
    return _db.search(
      queryVector: queryVector,
      k: k,
      entityTypeFilter: entityTypeFilter,
      categoryIds: categoryIds,
    );
  }
}
