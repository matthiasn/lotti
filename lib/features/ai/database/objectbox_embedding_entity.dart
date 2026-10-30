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

/// The synced version of one entry's vectors under one model: the register
/// `<entityId>|<modelId>` of `SyncMessage.embeddingVectors`. Kept in the shard
/// that holds the entry's chunks, so a chunk set and the version it belongs to
/// are written in one transaction. A tombstone has no chunks and
/// [deleted] set.
@Entity()
class EmbeddingRegisterEntity {
  EmbeddingRegisterEntity({
    required this.registerId,
    required this.entityId,
    required this.modelId,
    required this.entityType,
    required this.vectorClock,
    required this.sourceVectorClock,
    required this.contentHash,
    required this.deleted,
    required this.taskId,
    required this.subtype,
    required this.originatingHostId,
    required this.updatedAt,
    this.id = 0,
  });

  @Id()
  int id;

  @Unique()
  String registerId;

  @Index()
  String entityId;

  String modelId;
  String entityType;

  /// The register's own clock, JSON; empty for a version never shared.
  String vectorClock;

  /// The entry's clock when it was embedded, JSON; empty when unknown.
  String sourceVectorClock;

  String contentHash;
  bool deleted;
  String taskId;
  String subtype;
  String originatingHostId;

  @Property(type: PropertyType.dateUtc)
  DateTime updatedAt;
}
