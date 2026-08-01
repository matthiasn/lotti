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

  /// Latest habit completion per habit/day since [rangeStart], projected to
  /// the three fields consumers actually read.
  ///
  /// Returns one winning row per habit/day under a last-write-wins contract,
  /// without ever putting the `serialized` payload on the wire.
  ///
  /// That payload is the cost. The 2026-06/07 slow-query logs put the
  /// full-entity version at 636 ms average, while the SQL measures ~29 ms on a
  /// comparable 10,000-row / 1,460-result data set. The difference is ~20
  /// columns per row, including the fat JSON blob, crossing the isolate port —
  /// which the interceptor measures, because it wraps the executor on the
  /// calling side. Decoding those blobs into `JournalEntity` then costs the
  /// *calling* isolate more work on top, outside the measurement.
  ///
  /// The day comes from the **serialized** `meta.dateFrom`, not the
  /// `date_from` column. They are the same instant, but not the same wall
  /// clock: the column is stored as a Unix epoch and reconstructed in the
  /// reader's zone, while `meta.dateFrom` is a naive local timestamp that keeps
  /// the wall clock it was recorded with. A completion entered at 23:30 in
  /// Berlin and later read in Auckland reconstructs from the column as 11:30
  /// the *next* day — moving it between heatmap cells, "completed today"
  /// buckets and streak windows. The consumers previously read
  /// `meta.dateFrom`, and still do.
  ///
  /// Ranking is unaffected: `PARTITION BY`/`ORDER BY` still use the indexed
  /// column, exactly as before.
  ///
  /// See `docs/perf/2026-08-01_slow-queries-investigation.md`.
  Future<List<HabitCompletionRecord>> getHabitCompletionRecordsInRange({
    required DateTime rangeStart,
  }) async {
    final rows = await customSelect(
      r'''
        SELECT habit_id, recorded_at, completion_type
        FROM (
          SELECT
            json_extract(serialized, '$.data.habitId') AS habit_id,
            json_extract(serialized, '$.meta.dateFrom') AS recorded_at,
            journal.date_from AS date_from,
            json_extract(serialized, '$.data.completionType') AS completion_type,
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
        ORDER BY date_from ASC, habit_id ASC
      ''',
      variables: [Variable<DateTime>(rangeStart)],
      readsFrom: {journal, configFlags},
    ).get();

    // Both projected fields come from `json_extract`, so a row whose payload is
    // missing `data.habitId` or `meta.dateFrom` yields NULL rather than
    // failing the query. Such a row cannot be placed on the heatmap at all, so
    // it is skipped — same principle as an unrecognised completion type: one
    // malformed row must not take out every habit's history.
    final records = <HabitCompletionRecord>[];
    for (final row in rows) {
      final habitId = row.readNullable<String>('habit_id');
      final recordedAt = row.readNullable<String>('recorded_at');
      if (habitId == null || recordedAt == null) continue;
      final dateFrom = DateTime.tryParse(recordedAt);
      if (dateFrom == null) continue;
      records.add(
        HabitCompletionRecord(
          habitId: habitId,
          dateFrom: dateFrom,
          completionType: _habitCompletionTypeFromDb(
            row.readNullable<String>('completion_type'),
          ),
        ),
      );
    }
    return records;
  }

  /// Maps the serialized enum name back to [HabitCompletionType].
  ///
  /// An unknown value decodes to `null` rather than throwing, so one completion
  /// type synced from a newer peer cannot take out the whole heatmap.
  ///
  /// `null` is not a synonym for success. It is the same value legacy entries
  /// written before the field existed already carry, and the consumers treat it
  /// as **recorded, and streak-extending, but not a success**: it lands in
  /// `allByDay` and `habitSuccessDays`, and in the heatmap's denominator, while
  /// staying out of `successfulByDay`, `successfulToday` and the heatmap's
  /// success numerator. An unknown type therefore closes the habit for the day
  /// without counting toward its success rate.
  ///
  /// That split is pre-existing behaviour for legacy `null`s, not something
  /// this projection introduced. Giving unknown types their own sentinel with
  /// defined semantics is a product decision, not a read-path one.
  static HabitCompletionType? _habitCompletionTypeFromDb(String? value) {
    if (value == null) return null;
    for (final type in HabitCompletionType.values) {
      if (type.name == value) return type;
    }
    return null;
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
