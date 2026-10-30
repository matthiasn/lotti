import 'package:lotti/classes/vector_clock.dart';
import 'package:meta/meta.dart';

/// The id of the register holding [entityId]'s vectors under [modelId].
String embeddingRegisterId(String entityId, String modelId) =>
    '$entityId|$modelId';

/// One version of an entry's vectors under one model: the synced register of
/// `SyncMessage.embeddingVectors`.
///
/// The unit is the entry, never the chunk: a version stands for the entry's
/// complete chunk set, and a [deleted] version (a tombstone) for none.
///
/// Two clocks, two jobs. [vectorClock] is the register's own history — sync
/// ordering, receipts, backfill — and is `null` for a version this device
/// wrote while sharing was off, which no peer has seen. [sourceVectorClock] is
/// the entry's clock when it was embedded: which text the vectors describe.
@immutable
class EmbeddingRegister {
  const EmbeddingRegister({
    required this.entityId,
    required this.modelId,
    required this.entityType,
    required this.contentHash,
    this.vectorClock,
    this.sourceVectorClock,
    this.deleted = false,
    this.taskId = '',
    this.subtype = '',
    this.originatingHostId = '',
  });

  factory EmbeddingRegister.fromJson(Map<String, dynamic> json) {
    VectorClock? clock(Object? value) => value == null
        ? null
        : VectorClock.fromJson(value as Map<String, dynamic>);
    return EmbeddingRegister(
      entityId: json['entityId'] as String,
      modelId: json['modelId'] as String,
      entityType: json['entityType'] as String,
      contentHash: json['contentHash'] as String,
      vectorClock: clock(json['vectorClock']),
      sourceVectorClock: clock(json['sourceVectorClock']),
      deleted: json['deleted'] as bool? ?? false,
      taskId: json['taskId'] as String? ?? '',
      subtype: json['subtype'] as String? ?? '',
      originatingHostId: json['originatingHostId'] as String? ?? '',
    );
  }

  final String entityId;
  final String modelId;
  final String entityType;

  /// The SHA-256 of the embedded text; empty for a tombstone.
  final String contentHash;
  final VectorClock? vectorClock;
  final VectorClock? sourceVectorClock;
  final bool deleted;

  /// The task an agent report belongs to; empty for a journal entry.
  final String taskId;
  final String subtype;

  /// The host that wrote this version; empty when it was never shared.
  final String originatingHostId;

  /// `<entityId>|<modelId>`.
  String get id => embeddingRegisterId(entityId, modelId);

  /// Whether [vectorClock] is set: a version peers can know about.
  bool get isShared => vectorClock != null;

  Map<String, dynamic> toJson() => {
    'entityId': entityId,
    'modelId': modelId,
    'entityType': entityType,
    'contentHash': contentHash,
    'vectorClock': vectorClock?.toJson(),
    'sourceVectorClock': sourceVectorClock?.toJson(),
    'deleted': deleted,
    'taskId': taskId,
    'subtype': subtype,
    'originatingHostId': originatingHostId,
  };

  EmbeddingRegister copyWith({
    VectorClock? vectorClock,
    String? originatingHostId,
  }) => EmbeddingRegister(
    entityId: entityId,
    modelId: modelId,
    entityType: entityType,
    contentHash: contentHash,
    vectorClock: vectorClock ?? this.vectorClock,
    sourceVectorClock: sourceVectorClock,
    deleted: deleted,
    taskId: taskId,
    subtype: subtype,
    originatingHostId: originatingHostId ?? this.originatingHostId,
  );

  @override
  bool operator ==(Object other) =>
      other is EmbeddingRegister &&
      other.entityId == entityId &&
      other.modelId == modelId &&
      other.entityType == entityType &&
      other.contentHash == contentHash &&
      other.vectorClock == vectorClock &&
      other.sourceVectorClock == sourceVectorClock &&
      other.deleted == deleted &&
      other.taskId == taskId &&
      other.subtype == subtype &&
      other.originatingHostId == originatingHostId;

  @override
  int get hashCode => Object.hash(
    entityId,
    modelId,
    entityType,
    contentHash,
    vectorClock,
    sourceVectorClock,
    deleted,
    taskId,
    subtype,
    originatingHostId,
  );

  @override
  String toString() =>
      'EmbeddingRegister($id, vc: $vectorClock, deleted: $deleted)';
}
