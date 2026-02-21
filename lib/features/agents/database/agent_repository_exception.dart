/// Thrown when an `AgentRepository` operation violates an invariant, e.g.
/// inserting a wake-run or saga-op with a primary key that already exists.
class DuplicateInsertException implements Exception {
  const DuplicateInsertException(this.table, this.key, [this.cause]);

  /// The logical table name (e.g. `'wake_run_log'`, `'saga_log'`).
  final String table;

  /// The duplicate primary-key value that triggered the error.
  final String key;

  /// The underlying database error, if available.
  final Object? cause;

  @override
  String toString() =>
      'DuplicateInsertException: duplicate key "$key" in $table';
}
