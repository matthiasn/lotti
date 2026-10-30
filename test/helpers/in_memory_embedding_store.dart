import 'dart:typed_data';

import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';

/// One entity's stored chunk set, as [InMemoryEmbeddingStore] keeps it.
class StoredEmbeddings {
  StoredEmbeddings({
    required this.entityType,
    required this.modelId,
    required this.contentHash,
    required this.chunks,
    required this.categoryId,
    required this.taskId,
    required this.subtype,
  });

  final String entityType;
  final String modelId;
  final String contentHash;
  final List<Float32List> chunks;
  String categoryId;
  final String taskId;
  final String subtype;
}

/// An [EmbeddingStore] held in maps, for tests about what a store ends up
/// holding — chunk sets and register versions — without ObjectBox. It
/// follows the contract of the real stores: a chunk set and its register are
/// replaced together, a deletion takes the register along, and a tombstone
/// replaces the chunks.
class InMemoryEmbeddingStore implements EmbeddingStore {
  final Map<String, StoredEmbeddings> chunks = {};
  final Map<String, EmbeddingRegister> registers = {};

  @override
  String? getContentHash(String entityId) => chunks[entityId]?.contentHash;

  @override
  String? getCategoryId(String entityId) => chunks[entityId]?.categoryId;

  @override
  void moveEntityToShard(String entityId, String newCategoryId) {
    chunks[entityId]?.categoryId = newCategoryId;
  }

  @override
  void moveRelatedReportEmbeddings(String taskId, String newCategoryId) {
    for (final row in chunks.values.where((row) => row.taskId == taskId)) {
      row.categoryId = newCategoryId;
    }
  }

  @override
  Set<String> agentReportIdsForTask(String taskId) => {
    for (final MapEntry(:key, :value) in chunks.entries)
      if (value.taskId == taskId) key,
  };

  @override
  bool hasEmbedding(String entityId) => chunks.containsKey(entityId);

  @override
  int get count => chunks.values.fold(0, (sum, row) => sum + row.chunks.length);

  @override
  EmbeddingRegister? getRegister(String entityId) => registers[entityId];

  @override
  List<Float32List> chunkVectors(String entityId) => [
    ...?chunks[entityId]?.chunks,
  ];

  @override
  List<EmbeddingRegister> allRegisters() => registers.values.toList();

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
    if (embeddings.isEmpty) {
      chunks.remove(entityId);
    } else {
      chunks[entityId] = StoredEmbeddings(
        entityType: entityType,
        modelId: modelId,
        contentHash: contentHash,
        chunks: embeddings,
        categoryId: categoryId,
        taskId: taskId,
        subtype: subtype,
      );
    }
    if (register == null) {
      registers.remove(entityId);
    } else {
      registers[entityId] = register;
    }
  }

  @override
  void deleteEntityEmbeddings(String entityId) {
    chunks.remove(entityId);
    registers.remove(entityId);
  }

  @override
  void putRegister(EmbeddingRegister register) {
    registers[register.entityId] = register;
  }

  @override
  void writeTombstone(EmbeddingRegister tombstone) {
    chunks.remove(tombstone.entityId);
    registers[tombstone.entityId] = tombstone;
  }

  @override
  List<EmbeddingSearchResult> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  }) => const [];

  @override
  void deleteAll() {
    chunks.clear();
    registers.clear();
  }

  @override
  void close() {}
}
