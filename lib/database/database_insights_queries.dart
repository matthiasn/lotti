part of 'database.dart';

/// One slim time row for the Insights time-analysis dashboard: the absolute
/// time span plus the resolved category id (`null` = uncategorized).
typedef InsightsTimeRowRecord = ({
  DateTime dateFrom,
  DateTime dateTo,
  String? categoryId,
});

/// Insights query surface for [JournalDb]: lean duration aggregation rows.
mixin _JournalDbInsightsQueries on _$JournalDb {
  /// Returns the time spans of all non-deleted `JournalEntry` rows
  /// overlapping `[start, end)`, with one row per entry and the category
  /// resolved with task-link precedence.
  ///
  /// Design notes (each guards against a measured failure mode):
  ///
  /// - **Slim projection.** Only `date_from`, `date_to`, and the resolved
  ///   category are read — never `serialized`. Deserializing 10k+ JSON
  ///   payloads is what would blow the dashboard's latency budget, not
  ///   SQLite.
  /// - **Integer-seconds arithmetic.** `date_from`/`date_to` are stored as
  ///   Unix seconds (Drift default). `julianday()` on those columns
  ///   returns NULL and silently drops every row — do not "simplify" the
  ///   duration guard to it.
  /// - **No join fan-out.** An entry can have multiple incoming links;
  ///   a plain LEFT JOIN on `linked_entries` would emit one row per link
  ///   and double-count durations. The correlated subquery picks exactly
  ///   one linked task deterministically.
  /// - **Category precedence.** The linked task's category wins over the
  ///   entry's own, matching `actualTimeBlocksForEntries` and the Daily OS
  ///   aggregation paths.
  /// - **Overlap predicate.** `date_to > :start AND date_from < :end`
  ///   keeps midnight-spanning entries at the window edges; the Dart
  ///   bucketizer clips them to the window.
  /// - **Type scope.** Only `JournalEntry` carries tracked time, mirroring
  ///   the shipped Daily OS time history (audio is excluded there to avoid
  ///   double-counting recordings made during a running timer).
  /// - **Private visibility.** Entries gate on the global `private` config
  ///   flag with the same idiom as `workEntriesInDateRange`: when private
  ///   mode is hidden, private entries' durations never reach the
  ///   dashboard. The linked-task subquery applies the same gate so a
  ///   hidden private task can't leak its category into attribution.
  Future<List<InsightsTimeRowRecord>> insightsTimeRows({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await customSelect(
      '''
        SELECT
          j.date_from AS date_from,
          j.date_to AS date_to,
          COALESCE(
            (
              SELECT t.category
              FROM linked_entries le
              INNER JOIN journal t ON t.id = le.from_id
              WHERE le.to_id = j.id
                AND COALESCE(le.hidden, FALSE) = FALSE
                AND t.type = 'Task'
                AND t.deleted = FALSE
                AND t.category != ''
                AND COALESCE(t.private, FALSE) IN
                  (FALSE, (SELECT status FROM config_flags
                           WHERE name = 'private'))
              ORDER BY t.date_from DESC, t.id
              LIMIT 1
            ),
            NULLIF(j.category, '')
          ) AS category_id
        FROM journal j
        WHERE j.type = 'JournalEntry'
          AND j.deleted = FALSE
          AND j.date_to > ?
          AND j.date_from < ?
          AND j.date_to > j.date_from
          AND COALESCE(j.private, FALSE) IN
            (FALSE, (SELECT status FROM config_flags WHERE name = 'private'))
        ORDER BY j.date_from
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {journal, linkedEntries, configFlags},
    ).get();

    return [
      for (final row in rows)
        (
          dateFrom: row.read<DateTime>('date_from'),
          dateTo: row.read<DateTime>('date_to'),
          categoryId: row.read<String?>('category_id'),
        ),
    ];
  }
}
