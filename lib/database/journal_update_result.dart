/// Classification for why a journal update was skipped.
enum JournalUpdateSkipReason {
  /// Local data was newer or equal; incoming payload ignored.
  olderOrEqual,

  /// Update could not be applied because of a concurrent conflict.
  conflict,

  /// Update was withheld because overwrite was disabled.
  overwritePrevented,

  /// The expected base entity was missing (e.g., pruned or never replicated).
  missingBase,
}

extension JournalUpdateSkipReasonX on JournalUpdateSkipReason {
  static const Map<JournalUpdateSkipReason, String> _labels = {
    JournalUpdateSkipReason.olderOrEqual: 'older_or_equal',
    JournalUpdateSkipReason.conflict: 'conflict',
    JournalUpdateSkipReason.overwritePrevented: 'overwrite_prevented',
    JournalUpdateSkipReason.missingBase: 'missing_base',
  };

  /// String label suitable for logs/metrics.
  String get label => _labels[this]!;
}

/// Result returned from JournalDb.updateJournalEntity.
class JournalUpdateResult {
  const JournalUpdateResult._({
    required this.applied,
    this.skipReason,
    this.rowsWritten,
  });

  factory JournalUpdateResult.applied({int? rowsWritten}) =>
      JournalUpdateResult._(
        applied: true,
        rowsWritten: rowsWritten ?? 1,
      );

  factory JournalUpdateResult.skipped({
    required JournalUpdateSkipReason reason,
  }) =>
      JournalUpdateResult._(
        applied: false,
        skipReason: reason,
        rowsWritten: 0,
      );

  /// True when the incoming entity was applied (insert or update).
  final bool applied;

  /// Optional skip classification when the update was not applied.
  final JournalUpdateSkipReason? skipReason;

  /// Optional row-count-like signal for instrumentation. When [applied] is
  /// true, this defaults to 1 to indicate one entity persisted.
  final int? rowsWritten;

  /// Convenience getter mirroring existing semantics.
  bool get skipped => !applied;
}
