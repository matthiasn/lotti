/// Status of individual outbox items in the sync queue.
/// Used by SyncDatabase and outbox-related components.
enum OutboxStatus {
  pending,
  sent,
  error,
  sending,
}

/// Priority levels for outbox entries. Lower index = higher priority.
/// Stored as integer in the database for natural ORDER BY ASC.
enum OutboxPriority {
  /// User-created actions (journal entries, entry links).
  high, // index=0
  /// Agent actions, backfill, theming.
  normal, // index=1
  /// Bulk resync, entity definitions, tags, AI config.
  low, // index=2
}
