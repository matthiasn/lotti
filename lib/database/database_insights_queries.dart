part of 'database.dart';

/// One slim time row for the Insights time-analysis dashboard: the absolute
/// time span plus the resolved category id (`null` = uncategorized).
typedef InsightsTimeRowRecord = ({
  String entryId,
  DateTime dateFrom,
  DateTime dateTo,
  String? categoryId,
});

/// One slim tracked-time row selected by a watched label for goal evaluation.
///
/// `markdown` is extracted directly from the serialized journal payload so
/// goal-agent evidence keeps the entry's semantic structure without
/// deserializing unrelated time entries. Older plain-text-only entries fall
/// back to their `plainText` value at the query boundary.
typedef GoalLabelTimeRowRecord = ({
  String entryId,
  String labelId,
  DateTime dateFrom,
  DateTime dateTo,
  String? categoryId,
  String? markdown,
});

const _insightsResolvedCategorySql = '''
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
        AND COALESCE(t.private, FALSE) IN (FALSE, pf.visible)
      ORDER BY t.date_from DESC, t.id
      LIMIT 1
    ),
    NULLIF(j.category, '')
  )
''';

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
        WITH private_flag AS (
          SELECT COALESCE(
            (SELECT status FROM config_flags WHERE name = 'private'),
            FALSE
          ) AS visible
        )
        SELECT
          j.id AS entry_id,
          j.date_from AS date_from,
          j.date_to AS date_to,
          $_insightsResolvedCategorySql AS category_id
        FROM journal j INDEXED BY idx_journal_insights_time
        CROSS JOIN private_flag pf
        WHERE j.type = 'JournalEntry'
          AND j.deleted = FALSE
          AND j.date_to > ?
          AND j.date_from < ?
          AND j.date_to > j.date_from
          AND COALESCE(j.private, FALSE) IN (FALSE, pf.visible)
        ORDER BY j.date_from
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {journal, linkedEntries, configFlags},
    ).get();

    return [
      for (final row in rows)
        (
          entryId: row.read<String>('entry_id'),
          dateFrom: row.read<DateTime>('date_from'),
          dateTo: row.read<DateTime>('date_to'),
          categoryId: row.read<String?>('category_id'),
        ),
    ];
  }

  /// Returns tracked-time rows carrying any of [labelIds] in `[start, end)`.
  ///
  /// The projection shares Insights' privacy, duration, overlap, and linked
  /// task category-attribution rules. It joins through the normalized
  /// `labeled` table so renamed labels keep matching their stable ids and an
  /// entry carrying two watched labels can be evaluated independently by
  /// both criteria.
  Future<List<GoalLabelTimeRowRecord>> goalLabelTimeRows({
    required DateTime start,
    required DateTime end,
    required Set<String> labelIds,
  }) async {
    if (labelIds.isEmpty) return const [];
    final orderedLabelIds = labelIds.toList()..sort();
    final placeholders = List.filled(orderedLabelIds.length, '?').join(', ');
    final rows = await customSelect(
      '''
        WITH private_flag AS (
          SELECT COALESCE(
            (SELECT status FROM config_flags WHERE name = 'private'),
            FALSE
          ) AS visible
        )
        SELECT
          j.id AS entry_id,
          l.label_id AS label_id,
          j.date_from AS date_from,
          j.date_to AS date_to,
          $_insightsResolvedCategorySql AS category_id,
          COALESCE(
            json_extract(j.serialized, '\$.entryText.markdown'),
            json_extract(j.serialized, '\$.entryText.plainText')
          ) AS markdown
        FROM journal j INDEXED BY idx_journal_insights_time
        INNER JOIN labeled l ON l.journal_id = j.id
        CROSS JOIN private_flag pf
        WHERE j.type = 'JournalEntry'
          AND j.deleted = FALSE
          AND j.date_to > ?
          AND j.date_from < ?
          AND j.date_to > j.date_from
          AND COALESCE(j.private, FALSE) IN (FALSE, pf.visible)
          AND l.label_id IN ($placeholders)
        ORDER BY j.date_from, j.id, l.label_id
      ''',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        for (final labelId in orderedLabelIds) Variable<String>(labelId),
      ],
      readsFrom: {journal, labeled, linkedEntries, configFlags},
    ).get();

    return [
      for (final row in rows)
        (
          entryId: row.read<String>('entry_id'),
          labelId: row.read<String>('label_id'),
          dateFrom: row.read<DateTime>('date_from'),
          dateTo: row.read<DateTime>('date_to'),
          categoryId: row.read<String?>('category_id'),
          markdown: row.read<String?>('markdown'),
        ),
    ];
  }

  /// Resolves one time entry's category with the exact task-link precedence
  /// and privacy rules used by [insightsTimeRows]. Unlike the range query,
  /// this deliberately accepts a zero-duration entry so a live timer can be
  /// attributed before it has a persisted end time.
  Future<String?> insightsTimeCategoryForEntry(String entryId) async {
    final rows = await customSelect(
      '''
        WITH private_flag AS (
          SELECT COALESCE(
            (SELECT status FROM config_flags WHERE name = 'private'),
            FALSE
          ) AS visible
        )
        SELECT $_insightsResolvedCategorySql AS category_id
        FROM journal j
        CROSS JOIN private_flag pf
        WHERE j.id = ?
          AND j.type = 'JournalEntry'
          AND j.deleted = FALSE
          AND COALESCE(j.private, FALSE) IN (FALSE, pf.visible)
        LIMIT 1
      ''',
      variables: [Variable<String>(entryId)],
      readsFrom: {journal, linkedEntries, configFlags},
    ).get();
    return rows.isEmpty ? null : rows.single.read<String?>('category_id');
  }
}
