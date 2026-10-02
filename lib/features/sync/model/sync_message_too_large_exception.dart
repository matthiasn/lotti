/// The transport rejected a sync message because of its size.
///
/// The check is deterministic: the same payload fails the same way on every
/// attempt, so the outbox must not resend it verbatim. Thrown by the Matrix
/// sender for an inline event the SDK refuses (`EventTooLarge`, its 60 000-byte
/// request-body cap) and for a gzipped manifest above
/// `SyncTuning.outboxBundleMaxBytes`. `OutboxProcessor` drops a single send
/// that raises it and splits a bundle into single sends.
class SyncMessageTooLargeException implements Exception {
  const SyncMessageTooLargeException(this.detail);

  /// Which payload was too large and by how much, for the log line.
  final String detail;

  @override
  String toString() => 'SyncMessageTooLargeException: $detail';
}
