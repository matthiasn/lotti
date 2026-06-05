part of 'database.dart';

/// Due-date and day-agent task reads for [JournalDb]: tasks-due range
/// queries (with microtask coalescing shared across the DailyOS prefetch
/// window), day-agent status selects, and the `_selectTasksDue` hot path
/// pinned to `idx_journal_tasks_due_open`.
mixin _JournalDbTaskDueQueries on _$JournalDb, _JournalDbConfigFlags {
  /// Returns tasks that are due on or before the specified date.
  /// Excludes completed (DONE) and rejected (REJECTED) tasks.
  /// This includes both tasks due on the specified day and overdue tasks.
  Future<List<Task>> getTasksDueOnOrBefore(DateTime date) async {
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final privateStatuses = await _visiblePrivateStatuses();
    final superset = await _coalesceOpenTasksDueUpTo(endOfDay, privateStatuses);
    return _filterTasks(
      superset,
      endInclusive: endOfDay,
    );
  }

  /// Returns tasks that are due on the specified date only.
  /// Excludes completed (DONE) and rejected (REJECTED) tasks.
  /// Does NOT include overdue tasks from previous days.
  Future<List<Task>> getTasksDueOn(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final privateStatuses = await _visiblePrivateStatuses();
    final superset = await _coalesceOpenTasksDueUpTo(endOfDay, privateStatuses);
    return _filterTasks(
      superset,
      startInclusive: startOfDay,
      endInclusive: endOfDay,
    );
  }

  /// Returns open task-corpus rows for Daily OS day-agent matching.
  ///
  /// The day-agent prompt embeds a bounded corpus snapshot, so this query
  /// intentionally returns only active task states and honors the same private
  /// visibility gate as user-facing task lists.
  Future<List<Task>> getOpenTasksForDayAgentCorpus({
    Set<String> categoryIds = const {},
    int limit = 200,
  }) {
    return _selectTasksByStatusForDayAgent(
      statuses: const ['OPEN', 'GROOMED', 'IN PROGRESS', 'BLOCKED', 'ON HOLD'],
      categoryIds: categoryIds,
      limit: limit,
    );
  }

  /// Returns in-progress task rows for Daily OS reconcile decisions.
  Future<List<Task>> getInProgressTasks({
    Set<String> categoryIds = const {},
    int limit = 200,
  }) {
    return _selectTasksByStatusForDayAgent(
      statuses: const ['IN PROGRESS'],
      categoryIds: categoryIds,
      limit: limit,
    );
  }

  /// Returns missed recurring tasks for Daily OS reconcile decisions.
  ///
  /// The current task model does not yet persist recurrence metadata. Returning
  /// an empty list keeps the phase-2 query contract explicit without inventing
  /// a recurrence source that cannot be derived from stored task rows.
  Future<List<Task>> getMissedRecurringTasks({
    required DateTime asOf,
    int lookbackDays = 7,
    Set<String> categoryIds = const {},
  }) async {
    return const <Task>[];
  }

  Future<List<Task>> _selectTasksByStatusForDayAgent({
    required List<String> statuses,
    required Set<String> categoryIds,
    required int limit,
  }) async {
    if (statuses.isEmpty || limit <= 0) return const <Task>[];

    final privateStatuses = await _visiblePrivateStatuses();
    if (privateStatuses.isEmpty) return const <Task>[];
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);

    final variables = <Variable<Object>>[];
    final buffer = StringBuffer()
      ..write('SELECT * FROM journal ')
      ..write("WHERE type = 'Task' ")
      ..write('AND task = 1 ')
      ..write('AND deleted = FALSE ')
      ..write('AND task_status IN (');

    for (var i = 0; i < statuses.length; i++) {
      if (i > 0) buffer.write(', ');
      variables.add(Variable<String>(statuses[i]));
      buffer.write('?${variables.length}');
    }
    buffer.write(') ');

    if (!matchesAllPrivateStates) {
      buffer.write('AND private IN (');
      for (var i = 0; i < privateStatuses.length; i++) {
        if (i > 0) buffer.write(', ');
        variables.add(Variable<bool>(privateStatuses[i]));
        buffer.write('?${variables.length}');
      }
      buffer.write(') ');
    }

    if (categoryIds.isNotEmpty) {
      final sortedCategoryIds = categoryIds.toList()..sort();
      buffer.write('AND category IN (');
      for (var i = 0; i < sortedCategoryIds.length; i++) {
        if (i > 0) buffer.write(', ');
        variables.add(Variable<String>(sortedCategoryIds[i]));
        buffer.write('?${variables.length}');
      }
      buffer.write(') ');
    }

    variables.add(Variable<int>(limit));
    buffer
      ..write('ORDER BY due_at IS NULL ASC, due_at ASC, ')
      ..write('task_priority_rank ASC, date_from DESC, id ASC ')
      ..write('LIMIT ?${variables.length}');

    final rows = await customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {journal},
    ).asyncMap(journal.mapFromRow).get();

    return rows.map(fromDbEntity).whereType<Task>().toList(growable: false);
  }

  // Microtask-coalescing state for `_coalesceOpenTasksDueUpTo`.
  //
  // The DailyOS prefetch window fires `getTasksDueOn` / `getTasksDueOnOrBefore`
  // once per date in a synchronous sweep. Instead of N round-trips through
  // `_selectTasksDue`, we share the widest `due <= max(endOfDay)` superset
  // across the whole wave and let each caller filter its own range
  // client-side from the in-memory list.
  //
  // The coalescer is keyed by the private-status shape so that private-filter
  // changes mid-wave (very rare but theoretically possible) still produce a
  // correct batch per shape.
  final Map<String, _PendingDueWave> _pendingDueWaves = {};

  /// Single-shot query executed by the tasks-due coalescer. Extracted as a
  /// protected seam so tests can count round-trips and inject failures
  /// without depending on a query interceptor.
  @protected
  @visibleForTesting
  Future<List<Task>> runTasksDueFetch({
    required DateTime endInclusive,
    required List<bool> privateStatuses,
  }) async {
    final rows = await _selectTasksDue(
      endInclusive: endInclusive,
      privateStatuses: privateStatuses,
    );
    return rows.map(fromDbEntity).whereType<Task>().toList(growable: false);
  }

  Future<List<Task>> _coalesceOpenTasksDueUpTo(
    DateTime endInclusive,
    List<bool> privateStatuses,
  ) {
    final key = privateStatuses.join(',');
    final existing = _pendingDueWaves[key];
    if (existing != null) {
      // Extend the existing wave's upper bound so the superset covers the
      // latest caller as well. Filtering happens per caller, so a slightly
      // wider range is free.
      if (endInclusive.isAfter(existing.endInclusive)) {
        existing.endInclusive = endInclusive;
      }
      return existing.completer.future;
    }

    final wave = _PendingDueWave(
      endInclusive: endInclusive,
      privateStatuses: List<bool>.unmodifiable(privateStatuses),
    );
    _pendingDueWaves[key] = wave;
    scheduleMicrotask(() async {
      _pendingDueWaves.remove(key);
      try {
        final tasks = await runTasksDueFetch(
          endInclusive: wave.endInclusive,
          privateStatuses: wave.privateStatuses,
        );
        wave.completer.complete(tasks);
      } catch (error, stack) {
        wave.completer.completeError(error, stack);
      }
    });
    return wave.completer.future;
  }

  // Drift SQL doesn't support `INDEXED BY`, so keep the due-date hot path in
  // raw SQL to force the partial `idx_journal_tasks_due_open` on large
  // journal tables. The index is keyed on the denormalized `due_at` column
  // (added in v41), so the planner can stream `ORDER BY due_at ASC` from
  // the index without parsing JSON per row.
  //
  // The fallback path is preserved as belt-and-suspenders for one release.
  // With a real column the pin should always resolve, so any fallback
  // firing is a signal that the migration silently failed on a device and
  // we need to investigate via the warning log.
  Future<List<JournalDbEntity>> _selectTasksDue({
    required DateTime endInclusive,
    required List<bool> privateStatuses,
  }) async {
    Future<List<JournalDbEntity>> runQuery(String? indexedBy) {
      final variables = <Variable<Object>>[];
      final query = _buildSelectTasksDue(
        endInclusive: endInclusive,
        privateStatuses: privateStatuses,
        variables: variables,
        indexedBy: indexedBy,
      );
      return customSelect(
        query,
        variables: variables,
        readsFrom: {journal},
      ).asyncMap(journal.mapFromRow).get();
    }

    try {
      return await runQuery('idx_journal_tasks_due_open');
    } catch (e, stack) {
      // Fall back on any SQLITE_ERROR from the pinned query. Covers both
      // "no query solution" (pin can't be proven) and "no such index"
      // (partial missing). Drift may wrap `SqliteException` when running
      // in a background isolate, so match on the printed message as well
      // as the type. `beforeOpen` self-heals the partial index on next
      // launch.
      final isSqliteError =
          (e is SqliteException && e.resultCode == 1) ||
          e.toString().contains('SqliteException(1)');
      if (!isSqliteError) rethrow;
      DevLogger.error(
        name: 'JournalDb',
        message:
            '_selectTasksDue INDEXED BY rejected by SQLite — falling back '
            'to unpinned query. The v41 column-keyed index should always '
            'resolve, so this likely means the migration did not complete '
            'on this device.',
        error: e,
        stackTrace: stack,
      );
      return runQuery(null);
    }
  }

  String _buildSelectTasksDue({
    required DateTime endInclusive,
    required List<bool> privateStatuses,
    required List<Variable<Object>> variables,
    required String? indexedBy,
  }) {
    final buffer = StringBuffer()
      ..write('SELECT * FROM journal ')
      ..write(indexedBy != null ? 'INDEXED BY $indexedBy ' : '')
      ..write("WHERE type = 'Task' ")
      ..write('AND task = 1 ')
      ..write('AND deleted = FALSE ')
      ..write("AND task_status NOT IN ('DONE', 'REJECTED') ")
      ..write('AND due_at IS NOT NULL ');

    variables.add(Variable<DateTime>(endInclusive));
    buffer
      ..write('AND due_at <= ?${variables.length} ')
      ..write('AND private IN (');

    for (var i = 0; i < privateStatuses.length; i++) {
      if (i > 0) {
        buffer.write(', ');
      }
      variables.add(Variable<bool>(privateStatuses[i]));
      buffer.write('?${variables.length}');
    }

    buffer
      ..write(') ')
      ..write('ORDER BY due_at ASC');

    return buffer.toString();
  }
}

List<Task> _filterTasks(
  List<Task> superset, {
  required DateTime endInclusive,
  DateTime? startInclusive,
}) {
  return [
    for (final task in superset)
      if (task.data.due != null &&
          !task.data.due!.isAfter(endInclusive) &&
          (startInclusive == null || !task.data.due!.isBefore(startInclusive)))
        task,
  ];
}

/// In-flight coalescing wave for the open-task-due-date superset fetch.
/// Every caller in the same microtask wave that shares a private-status
/// shape joins the same wave; the wave issues a single `_selectTasksDue`
/// covering the widest `endInclusive` seen before the microtask fires.
class _PendingDueWave {
  _PendingDueWave({
    required this.endInclusive,
    required this.privateStatuses,
  });

  DateTime endInclusive;
  final List<bool> privateStatuses;
  final Completer<List<Task>> completer = Completer<List<Task>>.sync();
}
