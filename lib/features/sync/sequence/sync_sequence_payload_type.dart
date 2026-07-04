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
}
