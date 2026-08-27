import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/logic/signals/signal_day_buckets.dart';
import 'package:lotti/logic/signals/signal_reader.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/time_service.dart';

/// Reads the journal into a [GoalSignalWindow] for one criteria tree —
/// the seam between the pure evaluator and the database (Phase A of
/// ADR 0054; the reader promised by the kickoff plan).
///
/// Semantics are deliberately borrowed, not reinvented:
///
/// - Quantitative day totals use the SAME per-type aggregation as the
///   health charts (`aggregateByType`): `cumulative_step_count` is a
///   running counter, so its day total is the day's max, not a sum.
///   Diverging here would make the goal agent disagree with the chart the
///   user is looking at.
/// - Habit days use the SAME latest-completion-per-day collapse as the
///   habits UI (`getHabitCompletionsByHabitId`), and only
///   [HabitCompletionType.success] counts toward a quota.
/// - Day keys re-stamp the LOCAL wall-clock date as midnight UTC
///   ([GoalWindow.dayUtc] over `meta.dateFrom`), matching the `ymd`
///   bucketing of `habits_controller` — a calendar-date key, not a
///   timezone conversion.
/// - Category-time leaves reuse Insights' category attribution and interval
///   union rules. Overlapping timers in one category count once, while an
///   optional daily time range clips the absolute spans in local time.
class GoalSignalReader {
  GoalSignalReader({
    required JournalDb journalDb,
    this._timeService,
  }) : _journalDb = journalDb,
       _signals = SignalReader(journalDb: journalDb);

  final JournalDb _journalDb;
  final SignalReader _signals;
  final TimeService? _timeService;

  /// Loads every signal series the [criteria] tree needs to be evaluated
  /// at [reference], covering the widest leaf window plus the short-term
  /// trend lookback. When [timeEntryEvidenceStart] is supplied, raw
  /// watched time-entry evidence extends back to that instant without widening
  /// the deterministic criterion's authored evaluation window. A completed
  /// historical period may supply [timeEntryEndExclusive] as the following
  /// local midnight; live periods default to clipping at [reference].
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
    bool includeTimeEntryEvidence = true,
    DateTime? timeEntryEvidenceStart,
    DateTime? timeEntryEndExclusive,
  }) async {
    final needs = _SignalNeeds()..collect(criteria);
    final rangeStart = _rangeStart(criteria, reference, shortTermDays);
    // Next local calendar midnight, by component construction: adding a
    // 24h Duration lands at 23:00 on a DST fall-back day and would drop
    // the final hour's entries from `date_to <= rangeEnd`.
    final rangeEnd = DateTime(
      reference.year,
      reference.month,
      reference.day + 1,
    );
    final requestedCategoryTimeEnd = timeEntryEndExclusive ?? reference;
    final categoryTimeEnd = requestedCategoryTimeEnd.isBefore(rangeEnd)
        ? requestedCategoryTimeEnd
        : rangeEnd;

    final quantitative = <String, Map<DateTime, num>>{};
    final quantitativeObservations = <String, List<GoalMetricObservation>>{};
    for (final dataType in needs.quantitativeTypes) {
      // The query intentionally reaches the next local midnight so completed
      // historical days retain their final hour. A live wake can receive a
      // row written after it captured [reference] while this await is in
      // flight, though. Clip once (`notAfter`) so deterministic aggregates
      // and the parallel exact series describe the same snapshot.
      final entities = await _signals.quantitativeEntities(
        type: dataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        notAfter: reference,
      );
      quantitative[dataType] = bucketQuantitativeByDay(entities, dataType);
      if (GoalHealthDataTypes.supported.contains(dataType)) {
        quantitativeObservations[dataType] = _rawQuantitativeObservations(
          entities,
          dataType,
        );
      }
    }

    final habits = <String, Map<DateTime, int>>{};
    final habitCompletions = <String, Map<DateTime, HabitCompletionType>>{};
    for (final habitId in needs.habitIds) {
      final entities = await _journalDb.getHabitCompletionsByHabitId(
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      final byDay = <DateTime, int>{};
      final completionsByDay = <DateTime, HabitCompletionType>{};
      for (final entity in entities) {
        entity.maybeMap(
          habitCompletion: (completion) {
            // The query already collapsed to the latest completion per
            // day (the habits-UI rule); only success feeds a quota.
            final completionType = completion.data.completionType;
            final day = GoalWindow.dayUtc(completion.data.dateFrom);
            if (completionType != null) {
              completionsByDay[day] = completionType;
            }
            if (completionType == HabitCompletionType.success) {
              byDay[day] = 1;
            }
          },
          orElse: () {},
        );
      }
      habits[habitId] = byDay;
      habitCompletions[habitId] = completionsByDay;
    }

    final measurables = <String, Map<DateTime, num>>{};
    final measurableEntryDaysById = <String, DateTime>{};
    for (final dataTypeId in needs.measurableTypeIds) {
      final entities = await _signals.measurableEntities(
        dataTypeId: dataTypeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      for (final entity in entities) {
        entity.maybeMap(
          measurement: (measurement) {
            measurableEntryDaysById[measurement.meta.id] = GoalWindow.dayUtc(
              measurement.data.dateFrom,
            );
          },
          orElse: () {},
        );
      }
      measurables[dataTypeId] = bucketMeasurableTotalsByDay(entities);
    }

    final categoryTime = <String, Map<DateTime, num>>{};
    final categoryTimeSessions = <String, List<GoalCategoryTimeSession>>{};
    DateTime? categoryTimeEvidenceStart;
    var hasActiveCategoryTimer = false;
    if (needs.categoryTimeCriteria.isNotEmpty) {
      final requestedEvidenceStart = timeEntryEvidenceStart ?? rangeStart;
      final evidenceStart = requestedEvidenceStart.isAfter(rangeEnd)
          ? rangeEnd
          : requestedEvidenceStart;
      if (includeTimeEntryEvidence) {
        categoryTimeEvidenceStart = evidenceStart;
      }
      final queryStart =
          includeTimeEntryEvidence && evidenceStart.isBefore(rangeStart)
          ? evidenceStart
          : rangeStart;
      final rows = await _journalDb.insightsTimeRows(
        start: queryStart,
        end: categoryTimeEnd,
      );
      final activeTimerRow = await _activeTimerRow(reference);
      if (activeTimerRow != null &&
          activeTimerRow.dateTo.isAfter(queryStart) &&
          activeTimerRow.dateFrom.isBefore(categoryTimeEnd)) {
        // The persisted row for a running timer has a stale zero-length end
        // and is normally absent from Insights. If it was saved while still
        // running, replace that stale prefix rather than duplicating the raw
        // evidence; interval union keeps deterministic totals honest either
        // way, but the model-facing session list must remain one session.
        rows
          ..removeWhere(
            (row) => row.entryId == activeTimerRow.entryId,
          )
          ..add(activeTimerRow)
          ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      }
      final watchedCategoryIds = {
        for (final criterion in needs.categoryTimeCriteria)
          criterion.categoryId,
      };
      hasActiveCategoryTimer =
          activeTimerRow != null &&
          watchedCategoryIds.contains(activeTimerRow.categoryId);
      if (includeTimeEntryEvidence) {
        for (final row in rows) {
          final categoryId = row.categoryId;
          final dateFrom = row.dateFrom.isBefore(evidenceStart)
              ? evidenceStart
              : row.dateFrom;
          final dateTo = row.dateTo.isAfter(categoryTimeEnd)
              ? categoryTimeEnd
              : row.dateTo;
          if (categoryId == null ||
              !watchedCategoryIds.contains(categoryId) ||
              !dateTo.isAfter(dateFrom)) {
            continue;
          }
          categoryTimeSessions
              .putIfAbsent(categoryId, () => [])
              .add(
                GoalCategoryTimeSession(
                  categoryId: categoryId,
                  dateFrom: dateFrom,
                  dateTo: dateTo,
                ),
              );
        }
        for (final sessions in categoryTimeSessions.values) {
          sessions.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        }
      }
      for (final criterion in needs.categoryTimeCriteria) {
        categoryTime[criterion.criterionId] = _bucketCategoryTime(
          rows: rows,
          criterion: criterion,
          rangeStart: rangeStart,
          rangeEnd: categoryTimeEnd,
        );
      }
    }

    final labelTime = <String, Map<DateTime, num>>{};
    final labelTimeEntries = <String, List<GoalLabelTimeEntryEvidence>>{};
    DateTime? labelTimeEvidenceStart;
    var hasActiveLabelTimer = false;
    if (needs.labelTimeCriteria.isNotEmpty) {
      final requestedEvidenceStart = timeEntryEvidenceStart ?? rangeStart;
      final evidenceStart = requestedEvidenceStart.isAfter(rangeEnd)
          ? rangeEnd
          : requestedEvidenceStart;
      if (includeTimeEntryEvidence) {
        labelTimeEvidenceStart = evidenceStart;
      }
      final queryStart =
          includeTimeEntryEvidence && evidenceStart.isBefore(rangeStart)
          ? evidenceStart
          : rangeStart;
      final watchedLabelIds = {
        for (final criterion in needs.labelTimeCriteria) criterion.labelId,
      };
      final rows = await _journalDb.goalLabelTimeRows(
        start: queryStart,
        end: categoryTimeEnd,
        labelIds: watchedLabelIds,
      );
      final activeRows = await _activeLabelTimeRows(
        reference,
        watchedLabelIds,
      );
      for (final activeRow in activeRows) {
        if (!activeRow.dateTo.isAfter(queryStart) ||
            !activeRow.dateFrom.isBefore(categoryTimeEnd)) {
          continue;
        }
        rows
          ..removeWhere(
            (row) =>
                row.entryId == activeRow.entryId &&
                row.labelId == activeRow.labelId,
          )
          ..add(activeRow);
      }
      rows.sort((a, b) {
        final byStart = a.dateFrom.compareTo(b.dateFrom);
        if (byStart != 0) return byStart;
        final byEntry = a.entryId.compareTo(b.entryId);
        return byEntry != 0 ? byEntry : a.labelId.compareTo(b.labelId);
      });
      hasActiveLabelTimer = activeRows.any(
        (row) => needs.labelTimeCriteria.any(
          (criterion) =>
              criterion.labelId == row.labelId &&
              (criterion.categoryId == null ||
                  criterion.categoryId == row.categoryId),
        ),
      );
      for (final criterion in needs.labelTimeCriteria) {
        final projection = _bucketLabelTime(
          rows: rows,
          criterion: criterion,
          aggregateStart: rangeStart,
          evidenceStart: evidenceStart,
          rangeEnd: categoryTimeEnd,
          includeEvidence: includeTimeEntryEvidence,
        );
        labelTime[criterion.criterionId] = projection.hoursByDay;
        if (projection.evidence.isNotEmpty) {
          labelTimeEntries[criterion.criterionId] = projection.evidence;
        }
      }
    }

    return GoalSignalWindow(
      quantitativeDailySums: quantitative,
      quantitativeObservationsByType: quantitativeObservations,
      habitSuccessesByDay: habits,
      habitCompletionsByDay: habitCompletions,
      measurableDailySums: measurables,
      measurableEntryDaysById: measurableEntryDaysById,
      categoryTimeDailyHours: categoryTime,
      categoryTimeSessionsByCategory: categoryTimeSessions,
      labelTimeDailyHours: labelTime,
      labelTimeEntriesByCriterion: labelTimeEntries,
      labelTimeEvidenceStart: labelTimeEvidenceStart,
      labelTimeEvidenceEnd:
          needs.labelTimeCriteria.isEmpty || !includeTimeEntryEvidence
          ? null
          : categoryTimeEnd,
      categoryTimeEvidenceStart: categoryTimeEvidenceStart,
      categoryTimeEvidenceEnd:
          needs.categoryTimeCriteria.isEmpty || !includeTimeEntryEvidence
          ? null
          : categoryTimeEnd,
      hasActiveCategoryTimer: hasActiveCategoryTimer,
      hasActiveLabelTimer: hasActiveLabelTimer,
    );
  }

  Future<InsightsTimeRowRecord?> _activeTimerRow(DateTime reference) async {
    final timeService = _timeService;
    final current = timeService?.getCurrent();
    if (current is! JournalEntry) return null;

    final needsPrivateFlag = current.meta.private == true;
    final showPrivate =
        !needsPrivateFlag || await _journalDb.getConfigFlag('private');
    if (current.meta.private == true && !showPrivate) return null;

    final resolvedCategory = await _journalDb.insightsTimeCategoryForEntry(
      current.meta.id,
    );
    final categoryId = resolvedCategory?.trim().isNotEmpty == true
        ? resolvedCategory
        : current.meta.categoryId;
    if (categoryId == null || categoryId.trim().isEmpty) return null;

    final persistedEnd = current.meta.dateTo;
    final dateTo = persistedEnd.isAfter(reference) ? persistedEnd : reference;
    return (
      entryId: current.meta.id,
      dateFrom: current.meta.dateFrom,
      dateTo: dateTo,
      categoryId: categoryId,
    );
  }

  Future<List<GoalLabelTimeRowRecord>> _activeLabelTimeRows(
    DateTime reference,
    Set<String> watchedLabelIds,
  ) async {
    final current = _timeService?.getCurrent();
    if (current is! JournalEntry) return const [];
    final matchingLabelIds =
        (current.meta.labelIds ?? const <String>[])
            .where(watchedLabelIds.contains)
            .toList()
          ..sort();
    if (matchingLabelIds.isEmpty) return const [];

    final needsPrivateFlag = current.meta.private == true;
    final showPrivate =
        !needsPrivateFlag || await _journalDb.getConfigFlag('private');
    if (current.meta.private == true && !showPrivate) return const [];

    final resolvedCategory = await _journalDb.insightsTimeCategoryForEntry(
      current.meta.id,
    );
    final categoryId = resolvedCategory?.trim().isNotEmpty == true
        ? resolvedCategory
        : current.meta.categoryId;
    final persistedEnd = current.meta.dateTo;
    final dateTo = persistedEnd.isAfter(reference) ? persistedEnd : reference;
    final entryText = current.entryText;
    final markdown = entryText?.markdown?.trim().isNotEmpty == true
        ? entryText!.markdown!.trim()
        : entryText?.plainText.trim();
    return [
      for (final labelId in matchingLabelIds)
        (
          entryId: current.meta.id,
          labelId: labelId,
          dateFrom: current.meta.dateFrom,
          dateTo: dateTo,
          categoryId: categoryId,
          markdown: markdown,
        ),
    ];
  }

  Map<DateTime, num> _bucketCategoryTime({
    required List<InsightsTimeRowRecord> rows,
    required GoalCriterionCategoryTime criterion,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final intervalsByDay = <DateTime, List<TimeInterval>>{};
    for (final row in rows) {
      if (row.categoryId != criterion.categoryId) continue;
      final start = row.dateFrom.isBefore(rangeStart)
          ? rangeStart
          : row.dateFrom;
      final end = row.dateTo.isAfter(rangeEnd) ? rangeEnd : row.dateTo;
      if (!end.isAfter(start)) continue;

      for (final segment in splitByLocalDay(start, end)) {
        final day = GoalWindow.dayUtc(segment.start);
        final clipped = _clipToDailyTimeRange(
          segment,
          criterion.dailyTimeRange,
        );
        if (clipped.isNotEmpty) {
          intervalsByDay.putIfAbsent(day, () => []).addAll(clipped);
        }
      }
    }

    final hoursByDay = <DateTime, num>{};
    for (final entry in intervalsByDay.entries) {
      final seconds = intervalSeconds(mergeIntervals(entry.value));
      if (seconds > 0) {
        hoursByDay[entry.key] = seconds / Duration.secondsPerHour;
      }
    }
    return hoursByDay;
  }

  ({
    Map<DateTime, num> hoursByDay,
    List<GoalLabelTimeEntryEvidence> evidence,
  })
  _bucketLabelTime({
    required List<GoalLabelTimeRowRecord> rows,
    required GoalCriterionLabelTime criterion,
    required DateTime aggregateStart,
    required DateTime evidenceStart,
    required DateTime rangeEnd,
    required bool includeEvidence,
  }) {
    final intervalsByDay = <DateTime, List<TimeInterval>>{};
    final evidence = <GoalLabelTimeEntryEvidence>[];
    for (final row in rows) {
      if (row.labelId != criterion.labelId ||
          (criterion.categoryId != null &&
              row.categoryId != criterion.categoryId)) {
        continue;
      }
      final evidenceRowStart = row.dateFrom.isBefore(evidenceStart)
          ? evidenceStart
          : row.dateFrom;
      final evidenceRowEnd = row.dateTo.isAfter(rangeEnd)
          ? rangeEnd
          : row.dateTo;
      if (!evidenceRowEnd.isAfter(evidenceRowStart)) continue;

      for (final segment in splitByLocalDay(evidenceRowStart, evidenceRowEnd)) {
        for (final clipped in _clipToDailyTimeRange(
          segment,
          criterion.dailyTimeRange,
        )) {
          if (includeEvidence) {
            evidence.add(
              GoalLabelTimeEntryEvidence(
                entryId: row.entryId,
                labelId: row.labelId,
                categoryId: row.categoryId,
                dateFrom: clipped.start,
                dateTo: clipped.end,
                markdown: row.markdown?.trim() ?? '',
              ),
            );
          }
          final aggregateSegmentStart = clipped.start.isBefore(aggregateStart)
              ? aggregateStart
              : clipped.start;
          if (!clipped.end.isAfter(aggregateSegmentStart)) continue;
          final day = GoalWindow.dayUtc(aggregateSegmentStart);
          intervalsByDay
              .putIfAbsent(day, () => [])
              .add(TimeInterval(aggregateSegmentStart, clipped.end));
        }
      }
    }
    evidence.sort((a, b) {
      final byStart = a.dateFrom.compareTo(b.dateFrom);
      if (byStart != 0) return byStart;
      return a.entryId.compareTo(b.entryId);
    });
    final hoursByDay = <DateTime, num>{};
    for (final entry in intervalsByDay.entries) {
      final seconds = intervalSeconds(mergeIntervals(entry.value));
      if (seconds > 0) {
        hoursByDay[entry.key] = seconds / Duration.secondsPerHour;
      }
    }
    return (hoursByDay: hoursByDay, evidence: evidence);
  }

  List<TimeInterval> _clipToDailyTimeRange(
    TimeInterval segment,
    GoalDailyTimeRange? timeRange,
  ) {
    if (timeRange == null) return [segment];
    final day = segment.start.isUtc
        ? DateTime.utc(
            segment.start.year,
            segment.start.month,
            segment.start.day,
          )
        : DateTime(
            segment.start.year,
            segment.start.month,
            segment.start.day,
          );
    final nextDay = nextLocalMidnight(day);
    final windows = timeRange.startMinute < timeRange.endMinute
        ? [
            (
              start: _atMinuteOfDay(day, timeRange.startMinute),
              end: _atMinuteOfDay(day, timeRange.endMinute),
            ),
          ]
        : [
            (start: day, end: _atMinuteOfDay(day, timeRange.endMinute)),
            (start: _atMinuteOfDay(day, timeRange.startMinute), end: nextDay),
          ];

    final clipped = <TimeInterval>[];
    for (final window in windows) {
      final start = segment.start.isAfter(window.start)
          ? segment.start
          : window.start;
      final end = segment.end.isBefore(window.end) ? segment.end : window.end;
      if (end.isAfter(start)) clipped.add(TimeInterval(start, end));
    }
    return clipped;
  }

  DateTime _atMinuteOfDay(DateTime day, int minute) => day.isUtc
      ? DateTime.utc(
          day.year,
          day.month,
          day.day,
          minute ~/ Duration.minutesPerHour,
          minute % Duration.minutesPerHour,
        )
      : DateTime(
          day.year,
          day.month,
          day.day,
          minute ~/ Duration.minutesPerHour,
          minute % Duration.minutesPerHour,
        );

  /// Preserves every quantitative journal sample before daily aggregation.
  /// Values use the same display normalization as [bucketQuantitativeByDay], and
  /// ordering matches its equal-timestamp entity-id tie break.
  List<GoalMetricObservation> _rawQuantitativeObservations(
    List<JournalEntity> entities,
    String dataType,
  ) {
    final multiplier = quantitativeDisplayMultiplier(dataType);
    final observations = <GoalMetricObservation>[];
    for (final entity in entities) {
      entity.maybeMap(
        quantitative: (quant) {
          observations.add(
            GoalMetricObservation(
              recordedAt: quant.data.dateFrom,
              value: quant.data.value * multiplier,
              tieBreaker: quant.meta.id,
            ),
          );
        },
        orElse: () {},
      );
    }
    observations.sort((a, b) {
      final byTime = a.recordedAt.compareTo(b.recordedAt);
      return byTime != 0 ? byTime : a.tieBreaker.compareTo(b.tieBreaker);
    });
    return observations;
  }

  /// Earliest day any leaf's period (or the short-term lookback, or the
  /// grace-period prior window) reaches back to, as a local date.
  DateTime _rangeStart(
    GoalCriterion criteria,
    DateTime reference,
    int shortTermDays,
  ) {
    var earliest = GoalWindow.dayUtc(
      reference,
    ).subtract(Duration(days: shortTermDays - 1));
    void visit(GoalCriterion criterion) {
      switch (criterion) {
        case GoalCriterionMetric(:final window) ||
            GoalCriterionMeasurable(:final window) ||
            GoalCriterionHabit(:final window) ||
            GoalCriterionCategoryTime(:final window) ||
            GoalCriterionLabelTime(:final window):
          // One extra period back so the policy's prior-attainment grace
          // check can be computed from the same window.
          final start = window.periodRange(reference).start;
          final length = window.lengthInDays(reference);
          final withPrior = start.subtract(Duration(days: length));
          if (withPrior.isBefore(earliest)) earliest = withPrior;
        case GoalCriterionAllOf(:final criteria) ||
            GoalCriterionAnyOf(:final criteria) ||
            GoalCriterionAtLeastCount(:final criteria):
          criteria.forEach(visit);
      }
    }

    visit(criteria);
    // Back to local wall-clock for the DB range query.
    return DateTime(earliest.year, earliest.month, earliest.day);
  }
}

/// Goal signals that should immediately run the deterministic evaluator.
///
/// Habit and measured-value writes are complete, bounded observations. A
/// category-time mutation is intentionally excluded because tracked sessions
/// can update frequently; those signals use [goalStaleSignalTriggerTokens].
Set<String> goalImmediateSignalTriggerTokens(GoalCriterion criteria) {
  final needs = _SignalNeeds()..collect(criteria);
  return {
    ...needs.quantitativeTypes,
    ...needs.habitIds,
    ...needs.measurableTypeIds,
  };
}

/// Goal signals that also invalidate model-facing evidence directly.
///
/// Category attribution changes are stale-only because they are high-volume.
/// Supported health samples remain on the immediate evaluation path and also
/// mark the report stale: a timestamp/backfill can change the exact series
/// without changing the daily aggregate persisted in the progress register.
Set<String> goalStaleSignalTriggerTokens(GoalCriterion criteria) {
  final needs = _SignalNeeds()..collect(criteria);
  return {
    ...needs.quantitativeTypes.intersection(GoalHealthDataTypes.supported),
    if (needs.categoryTimeCriteria.isNotEmpty) ...const {
      textEntryNotification,
      linkNotification,
      taskNotification,
      categoriesNotification,
      privateToggleNotification,
    },
    if (needs.labelTimeCriteria.isNotEmpty) ...const {
      textEntryNotification,
      linkNotification,
      taskNotification,
      categoriesNotification,
      labelUsageNotification,
      labelsNotification,
      privateToggleNotification,
    },
  };
}

class _SignalNeeds {
  final quantitativeTypes = <String>{};
  final habitIds = <String>{};
  final measurableTypeIds = <String>{};
  final categoryTimeCriteria = <GoalCriterionCategoryTime>[];
  final labelTimeCriteria = <GoalCriterionLabelTime>[];

  void collect(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionMetric(:final dataType):
        quantitativeTypes.add(dataType);
      case GoalCriterionHabit(:final habitId):
        habitIds.add(habitId);
      case GoalCriterionMeasurable(:final dataTypeId):
        measurableTypeIds.add(dataTypeId);
      case final GoalCriterionCategoryTime categoryTime:
        categoryTimeCriteria.add(categoryTime);
      case final GoalCriterionLabelTime labelTime:
        labelTimeCriteria.add(labelTime);
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(collect);
    }
  }
}
