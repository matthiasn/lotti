/// Lightweight projection of an embedding chunk entity used for index
/// rebuilds without loading the full embedding vector into memory.
class EntityMetadataRow {
  const EntityMetadataRow({required this.entityId, required this.taskId});

  final String entityId;
  final String taskId;
}
