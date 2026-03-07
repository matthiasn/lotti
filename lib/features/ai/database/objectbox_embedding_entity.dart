// coverage:ignore-file
import 'dart:typed_data';

import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class EmbeddingChunkEntity {
  EmbeddingChunkEntity({
    required this.embeddingKey,
    required this.entityId,
    required this.chunkIndex,
    required this.entityType,
    required this.modelId,
    required this.contentHash,
    required this.createdAt,
    required this.categoryId,
    required this.taskId,
    required this.subtype,
    required this.embedding,
    this.id = 0,
  });

  @Id()
  int id;

  @Unique()
  String embeddingKey;

  @Index()
  String entityId;

  int chunkIndex;

  @Index()
  String entityType;

  String modelId;
  String contentHash;

  @Property(type: PropertyType.dateUtc)
  DateTime createdAt;

  @Index()
  String categoryId;

  @Index()
  String taskId;

  @Index()
  String subtype;

  @Property(type: PropertyType.floatVector)
  @HnswIndex(
    dimensions: kEmbeddingDimensions,
    distanceType: VectorDistanceType.cosine,
    neighborsPerNode: 30,
    indexingSearchCount: 200,
  )
  Float32List embedding;
}
