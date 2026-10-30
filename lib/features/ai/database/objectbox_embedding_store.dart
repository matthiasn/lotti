import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';
import 'package:lotti/features/ai/database/objectbox_ops.dart';

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
  /// The caller owns construction and lifecycle of the backing [ObjectBoxOps].
  ObjectBoxEmbeddingStore(this._ops);

  final ObjectBoxOps _ops;

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
      _ops.removeRegister(entityId);
    });
  }

  @override
  void writeTombstone(EmbeddingRegister tombstone) {
    final row = registerToEntity(tombstone, updatedAt: clock.now().toUtc());
    _ops.runInWriteTransaction(() {
      _removeEntityEmbeddingsInCurrentTransaction(tombstone.entityId);
      _ops.putRegister(row);
    });
  }

  @override
  void putRegister(EmbeddingRegister register) {
    final row = registerToEntity(register, updatedAt: clock.now().toUtc());
    _ops.runInWriteTransaction(() => _ops.putRegister(row));
  }

  @override
  EmbeddingRegister? getRegister(String entityId) {
    final row = _ops.findRegister(entityId);
    return row == null ? null : registerFromEntity(row);
  }

  @override
  List<Float32List> chunkVectors(String entityId) {
    final chunks = _ops.findEntitiesByEntityId(entityId)
      ..sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));
    return [for (final chunk in chunks) chunk.embedding];
  }

  @override
  List<EmbeddingRegister> allRegisters() => [
    for (final row in _ops.findAllRegisters()) registerFromEntity(row),
  ];

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
    for (final reportId in agentReportIdsForTask(taskId)) {
      moveEntityToShard(reportId, newCategoryId);
    }
  }

  @override
  Set<String> agentReportIdsForTask(String taskId) => {
    for (final row in _ops.queryAllEntityMetadata())
      if (row.taskId == taskId) row.entityId,
  };

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
    EmbeddingRegister? register,
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
      if (register == null) {
        _ops.removeRegister(entityId);
      } else {
        _ops.putRegister(registerToEntity(register, updatedAt: createdAt));
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
            taskId: hit.object.taskId,
          ),
        )
        .toList(growable: false);
  }

  /// The ObjectBox row of [register], stamped [updatedAt].
  static EmbeddingRegisterEntity registerToEntity(
    EmbeddingRegister register, {
    required DateTime updatedAt,
  }) => EmbeddingRegisterEntity(
    registerId: register.id,
    entityId: register.entityId,
    modelId: register.modelId,
    entityType: register.entityType,
    vectorClock: _encodeClock(register.vectorClock),
    sourceVectorClock: _encodeClock(register.sourceVectorClock),
    contentHash: register.contentHash,
    deleted: register.deleted,
    taskId: register.taskId,
    subtype: register.subtype,
    originatingHostId: register.originatingHostId,
    updatedAt: updatedAt,
  );

  /// The register an ObjectBox [row] stores.
  static EmbeddingRegister registerFromEntity(EmbeddingRegisterEntity row) =>
      EmbeddingRegister(
        entityId: row.entityId,
        modelId: row.modelId,
        entityType: row.entityType,
        contentHash: row.contentHash,
        vectorClock: _decodeClock(row.vectorClock),
        sourceVectorClock: _decodeClock(row.sourceVectorClock),
        deleted: row.deleted,
        taskId: row.taskId,
        subtype: row.subtype,
        originatingHostId: row.originatingHostId,
      );

  static String _encodeClock(VectorClock? clock) =>
      clock == null ? '' : jsonEncode(clock.toJson());

  static VectorClock? _decodeClock(String json) => json.isEmpty
      ? null
      : VectorClock.fromJson(jsonDecode(json) as Map<String, dynamic>);

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
