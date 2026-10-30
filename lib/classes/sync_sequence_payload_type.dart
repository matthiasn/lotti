/// Identifies what kind of payload a (hostId, counter) refers to in the
/// self-healing sync sequence log.
enum SyncSequencePayloadType {
  journalEntity,
  entryLink,
  agentEntity,
  agentLink,
  notification,
  notificationStateUpdate,

  // Appended last on purpose: the enum ordinal (`.index`) is persisted in the
  // sync sequence log (`sync_sequence_receiver.dart`), so existing values must
  // never be reordered — only new values may be added at the end.
  consumptionEvent,

  /// A version of an entity definition — category, label, habit, dashboard,
  /// measurable or speech dictionary entry. The id names the definition in
  /// whichever of their tables holds it.
  entityDefinition,

  /// A version or hard deletion of an AI configuration — inference provider,
  /// model, prompt, inference profile or skill (ADR 0136).
  aiConfig,

  /// A version or tombstone of an entry's embedding vectors under one model:
  /// the register `<entityId>|<modelId>`.
  embeddingVectors,
}
