part of 'database.dart';

/// Typed data reads for [JournalDb]: measurements, habit completions,
/// day plans, quantitative entries, workouts, and surveys.
mixin _JournalDbDataQueries on _$JournalDb, _JournalDbConfigFlags {
  Future<List<JournalEntity>> getMeasurementsByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await measurementsByType(type, rangeStart, rangeEnd).get();
    return res.map(fromDbEntity).toList();
  }

  /// Returns habit completions for [habitId] in the inclusive
  /// [rangeStart]/[rangeEnd] window.
  ///
  /// Raw database rows are converted to journal entities and collapsed with
  /// [latestHabitCompletionsByDay], so callers get one latest write per day
  /// instead of every stored completion row.
  Future<List<JournalEntity>> getHabitCompletionsByHabitId({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await habitCompletionsByHabitId(
      habitId,
      rangeStart,
      rangeEnd,
    ).get();
    return latestHabitCompletionsByDay(res.map(fromDbEntity));
  }

  /// Returns habit completions from [rangeStart] to now.
  ///
  /// The SQL ranks writes by the same last-write-wins contract as
  /// [latestHabitCompletionsByDay] and returns only the winning row per
  /// habit/day. This keeps the heatmap path from materialising every historic
  /// habit write when only one row per day can affect the result.
  Future<List<JournalEntity>> getHabitCompletionsInRange({
    required DateTime rangeStart,
  }) async {
    final rows = await customSelect(
      r'''
        SELECT *
        FROM (
          SELECT
            journal.*,
            ROW_NUMBER() OVER (
              PARTITION BY
                json_extract(serialized, '$.data.habitId'),
                date(date_from, 'unixepoch', 'localtime')
              ORDER BY
                updated_at DESC,
                created_at DESC,
                date_to DESC,
                id DESC
            ) AS rn
          FROM journal
          WHERE type = 'HabitCompletionEntry'
            AND private IN (
              0,
              (SELECT status FROM config_flags WHERE name = 'private')
            )
            AND date_from >= ?
            AND deleted = FALSE
        )
        WHERE rn = 1
        ORDER BY date_from ASC,
          json_extract(serialized, '$.data.habitId') ASC
      ''',
      variables: [Variable<DateTime>(rangeStart)],
      readsFrom: {journal, configFlags},
    ).get();

    return rows.map((row) => fromDbEntity(journal.map(row.data))).toList();
  }

  Future<DayPlanEntry?> getDayPlanById(String id) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => dayPlanById(id).get(),
      filtered: (s) => dayPlanByIdByPrivateStatuses(id, s).get(),
    );
    if (res.isEmpty) return null;
    return fromDbEntity(res.first) as DayPlanEntry;
  }

  /// Batch variant of [getDayPlanById]. Used by the coalescing layer in
  /// the day-plan repository so a prefetch window of N dates collapses
  /// into a single round-trip. Chunks inputs to stay under SQLite's
  /// default 999-variable limit even if a caller fans out far past the
  /// DailyOS prefetch window. Duplicate ids are removed before chunking
  /// so the `IN (…)` semantics of the original single-query form are
  /// preserved — otherwise dupes in different chunks would yield dupe
  /// rows.
  Future<List<DayPlanEntry>> getDayPlansByIds(Iterable<String> ids) async {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) return const [];
    final out = <DayPlanEntry>[];
    for (var i = 0; i < idList.length; i += _sqliteInListChunk) {
      final end = (i + _sqliteInListChunk).clamp(0, idList.length);
      final chunk = idList.sublist(i, end);
      final res = await _queryWithPrivateFilter(
        allPrivate: () => dayPlansByIds(chunk).get(),
        filtered: (s) => dayPlansByIdsByPrivateStatuses(chunk, s).get(),
      );
      out.addAll(res.map((e) => fromDbEntity(e) as DayPlanEntry));
    }
    return out;
  }

  Future<List<DayPlanEntry>> getDayPlansInRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => dayPlansInRange(rangeStart, rangeEnd).get(),
      filtered: (s) =>
          dayPlansInRangeByPrivateStatuses(rangeStart, rangeEnd, s).get(),
    );
    return res.map((e) => fromDbEntity(e) as DayPlanEntry).toList();
  }

  Future<List<JournalEntity>> getQuantitativeByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await quantitativeByType(type, rangeStart, rangeEnd).get();

    return res.map(fromDbEntity).toList();
  }

  Future<QuantitativeEntry?> latestQuantitativeByType(String type) async {
    final dbEntities = await latestQuantByType(type).get();
    if (dbEntities.isEmpty) {
      DevLogger.log(
        name: 'JournalDb',
        message: 'latestQuantitativeByType no result for $type',
      );
      return null;
    }
    return fromDbEntity(dbEntities.first) as QuantitativeEntry;
  }

  Future<WorkoutEntry?> latestWorkout() async {
    final dbEntities = await findLatestWorkout().get();
    if (dbEntities.isEmpty) {
      DevLogger.log(name: 'JournalDb', message: 'no workout found');
      return null;
    }
    return fromDbEntity(dbEntities.first) as WorkoutEntry;
  }

  Future<List<JournalEntity>> getSurveyCompletionsByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await surveysByType(type, rangeStart, rangeEnd).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getWorkouts({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await workouts(rangeStart, rangeEnd).get();
    return res.map(fromDbEntity).toList();
  }
}
