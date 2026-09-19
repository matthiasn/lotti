/// Lightweight projection of an embedding chunk entity used for index
/// rebuilds without loading the full embedding vector into memory.
typedef EntityMetadataRow = ({String entityId, String taskId});
