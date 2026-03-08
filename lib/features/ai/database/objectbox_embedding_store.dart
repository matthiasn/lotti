import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';
import 'package:lotti/features/ai/database/objectbox_ops.dart';
import 'package:lotti/features/ai/database/real_objectbox_ops.dart'; // coverage:ignore-line
import 'package:lotti/objectbox.g.dart'; // coverage:ignore-line
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
  /// Creates an [ObjectBoxEmbeddingStore] backed by the given [ObjectBoxOps].
  ///
  /// Prefer the [open] factory for production use. This constructor is visible
  /// for testing with a mock [ObjectBoxOps].
  ObjectBoxEmbeddingStore(this._ops);

  final ObjectBoxOps _ops;

  /// Opens a production ObjectBox store at [documentsPath].
  // coverage:ignore-start
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
    return ObjectBoxEmbeddingStore(RealObjectBoxOps(store));
  }
  // coverage:ignore-end

  @override
  int get count => _ops.count();

  @override
  void close() => _ops.close();

  @override
  void deleteAll() {
    _ops.runInWriteTransaction(_ops.removeAll);
  }

  @override
  void deleteEntityEmbeddings(String entityId) {
    _ops.runInWriteTransaction(() {
      _removeEntityEmbeddingsInCurrentTransaction(entityId);
    });
  }

  @override
  String? getContentHash(String entityId) {
    return _ops.findByEmbeddingKey(_embeddingKey(entityId, 0))?.contentHash;
  }

  @override
  String? getCategoryId(String entityId) {
    return _ops.findFirstByEntityId(entityId)?.categoryId;
  }

  @override
  void moveEntityToShard(String entityId, String newCategoryId) {
    final chunks = _ops.findEntitiesByEntityId(entityId);
    if (chunks.isEmpty) return;

    for (final chunk in chunks) {
      chunk.categoryId = newCategoryId;
    }
    _ops.runInWriteTransaction(() => _ops.putMany(chunks));
  }

  @override
  void moveRelatedReportEmbeddings(String taskId, String newCategoryId) {
    // No-op in single-store mode — no efficient reverse task index.
    // The next backfill pass will correct report categoryIds.
  }

  @override
  bool hasEmbedding(String entityId) {
    return _ops.findFirstByEntityId(entityId) != null;
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

    _ops.runInWriteTransaction(() {
      _removeEntityEmbeddingsInCurrentTransaction(entityId);

      if (entities.isNotEmpty) {
        _ops.putMany(entities);
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

    final hits = _ops.nearestNeighborSearch(
      queryVector: queryVector,
      maxResults: maxResultCount,
      limit: k,
      entityTypeFilter: entityTypeFilter,
      categoryIds: hasCategoryFilter ? categoryIds.toList() : null,
    );

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
  }

  static String _embeddingKey(String entityId, int chunkIndex) =>
      '$entityId:$chunkIndex';

  void _removeEntityEmbeddingsInCurrentTransaction(String entityId) {
    final ids = _ops.findIdsByEntityId(entityId);
    if (ids.isNotEmpty) {
      _ops.removeMany(ids);
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
