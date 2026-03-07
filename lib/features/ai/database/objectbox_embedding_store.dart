import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';
import 'package:lotti/objectbox.g.dart';
import 'package:path/path.dart' as p;

/// Sidecar directory name for the ObjectBox embedding store.
const kObjectBoxEmbeddingsDirectoryName = 'objectbox_embeddings';

/// Short macOS application group ID required by ObjectBox in sandboxed apps.
///
/// ObjectBox uses POSIX semaphores for store coordination on macOS, and the
/// semaphore prefix must be an application-group identifier when App Sandbox
/// is enabled. The identifier is limited to 19 characters by ObjectBox.
const kMacOsObjectBoxApplicationGroup = 'SS586VG7L7.lottiobx';

/// ObjectBox-backed [EmbeddingStore] for vector embeddings and ANN search.
class ObjectBoxEmbeddingStore implements EmbeddingStore {
  ObjectBoxEmbeddingStore._(this._store)
    : _box = _store.box<EmbeddingChunkEntity>();

  final Store _store;
  final Box<EmbeddingChunkEntity> _box;

  static Future<ObjectBoxEmbeddingStore> open({
    required String documentsPath,
  }) async {
    final directoryPath = p.join(
      documentsPath,
      kObjectBoxEmbeddingsDirectoryName,
    );
    await Directory(directoryPath).create(recursive: true);

    final store = await openStore(
      directory: directoryPath,
      macosApplicationGroup: Platform.isMacOS
          ? kMacOsObjectBoxApplicationGroup
          : null,
    );
    return ObjectBoxEmbeddingStore._(store);
  }

  @override
  int get count => _box.count();

  @override
  void close() => _store.close();

  @override
  void deleteAll() {
    _store.runInTransaction(TxMode.write, _box.removeAll);
  }

  @override
  void deleteEntityEmbeddings(String entityId) {
    _store.runInTransaction(TxMode.write, () {
      _removeEntityEmbeddingsInCurrentTransaction(entityId);
    });
  }

  @override
  String? getContentHash(String entityId) {
    final query = _box
        .query(
          EmbeddingChunkEntity_.embeddingKey.equals(_embeddingKey(entityId, 0)),
        )
        .build();
    try {
      return query.findFirst()?.contentHash;
    } finally {
      query.close();
    }
  }

  @override
  bool hasEmbedding(String entityId) {
    final query =
        _box.query(EmbeddingChunkEntity_.entityId.equals(entityId)).build()
          ..limit = 1;
    try {
      return query.findFirst() != null;
    } finally {
      query.close();
    }
  }

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
    final createdAt = clock.now().toUtc();
    final entities = <EmbeddingChunkEntity>[
      for (var i = 0; i < embeddings.length; i++)
        EmbeddingChunkEntity(
          embeddingKey: _embeddingKey(entityId, i),
          entityId: entityId,
          chunkIndex: i,
          entityType: entityType,
          modelId: modelId,
          contentHash: contentHash,
          createdAt: createdAt,
          categoryId: categoryId,
          taskId: taskId,
          subtype: subtype,
          embedding: _validatedEmbedding(
            entityId: entityId,
            entityType: entityType,
            modelId: modelId,
            embedding: embeddings[i],
          ),
        ),
    ];

    _store.runInTransaction(TxMode.write, () {
      _removeEntityEmbeddingsInCurrentTransaction(entityId);

      if (entities.isNotEmpty) {
        _box.putMany(entities);
      }
    });
  }

  @override
  List<EmbeddingSearchResult> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  }) {
    _validateVectorLength(
      vector: queryVector,
      context: 'ObjectBoxEmbeddingStore.search()',
    );

    if (k <= 0) {
      return const [];
    }

    final hasCategoryFilter = categoryIds != null && categoryIds.isNotEmpty;
    final hasFilter = entityTypeFilter != null || hasCategoryFilter;
    final maxResultCount = hasFilter ? k * 3 : k;

    var condition = EmbeddingChunkEntity_.embedding.nearestNeighborsF32(
      queryVector,
      maxResultCount,
    );

    if (entityTypeFilter != null) {
      condition = condition.and(
        EmbeddingChunkEntity_.entityType.equals(entityTypeFilter),
      );
    }

    if (hasCategoryFilter) {
      condition = condition.and(
        EmbeddingChunkEntity_.categoryId.oneOf(categoryIds.toList()),
      );
    }

    final query = _box.query(condition).build()..limit = k;

    try {
      final hits = query.findWithScores();
      return hits
          .map(
            (hit) => EmbeddingSearchResult(
              entityId: hit.object.entityId,
              distance: hit.score,
              entityType: hit.object.entityType,
              chunkIndex: hit.object.chunkIndex,
              taskId: hit.object.taskId,
              subtype: hit.object.subtype,
            ),
          )
          .toList(growable: false);
    } finally {
      query.close();
    }
  }

  static String _embeddingKey(String entityId, int chunkIndex) =>
      '$entityId:$chunkIndex';

  void _removeEntityEmbeddingsInCurrentTransaction(String entityId) {
    final query = _box
        .query(EmbeddingChunkEntity_.entityId.equals(entityId))
        .build();
    try {
      final ids = query.findIds();
      if (ids.isNotEmpty) {
        _box.removeMany(ids);
      }
    } finally {
      query.close();
    }
  }

  Float32List _validatedEmbedding({
    required String entityId,
    required String entityType,
    required String modelId,
    required Float32List embedding,
  }) {
    _validateVectorLength(
      vector: embedding,
      context:
          'ObjectBoxEmbeddingStore.replaceEntityEmbeddings() '
          'for entityId=$entityId, entityType=$entityType, modelId=$modelId',
    );
    return embedding;
  }

  void _validateVectorLength({
    required Float32List vector,
    required String context,
  }) {
    if (vector.length != kEmbeddingDimensions) {
      throw ArgumentError(
        '$context: vector.length (${vector.length}) does not match '
        'kEmbeddingDimensions ($kEmbeddingDimensions)',
      );
    }
  }
}
