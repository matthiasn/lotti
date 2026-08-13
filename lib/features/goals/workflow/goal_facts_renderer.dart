import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

// The dismissal quiet window is the REST OF THE LOCAL CALENDAR DAY (see
// `GoalFactsRenderer.dismissalCooldownActive`): a rolling duration would
// let an evening dismissal silence the whole next day too, while "not
// today" matches how the user actually meant the gesture.

/// Ads younger than this count as `fresh` in FACTS, which is what blocks a
/// second ad in the same situation (policy row P6).
const goalAdFreshFor = Duration(hours: 48);

/// Minimum mean rating for a retired ad to be offered for zero-cost
/// re-run (policy row P13).
const goalReusableMinMeanRating = 4.0;

/// Maximum number of raw category sessions included in one model message.
/// The complete lifetime remains represented by the bounded summaries below.
const goalCategorySessionEvidenceLimit = 200;

/// Renders the deterministic FACTS block for one Phase B wake.
///
/// The output shape is EXACTLY the one the eval fixtures validated
/// model-against-model (`goal_agent_eval_fixtures.dart`): a labelled JSON
/// fence with `goal` / `evaluation` / optional raw `signals` / `reporting` /
/// `ads` / `personaTone` / `unansweredUserMessages` / `observations`
/// sections. Every verdict is pre-computed here — the prompt instructs the
/// model to restate, never derive, so this renderer is the single place the
/// model's worldview is assembled.
class GoalFactsRenderer {
  const GoalFactsRenderer();

  String render({
    required GoalSpecVersionEntity version,
    required GoalWakeFacts facts,
    required List<GoalProgressEntity> priorRegisters,
    required List<GoalNudgeEntity> nudges,
    List<String> observations = const [],
    List<String> unansweredUserMessages = const [],
    String? personaTonePreference,
  }) {
    final now = clock.now();
    final active = nudges
        .where((n) => n.status == GoalNudgeStatus.active)
        .toList();
    final priorAttainments = [
      for (final row in priorRegisters) row.attainment,
    ];
    final categorySessions = [
      for (final sessions in facts.categoryTimeSessionsByCategory.values)
        ...sessions,
    ]..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    final recentCategorySessions =
        categorySessions.length <= goalCategorySessionEvidenceLimit
        ? categorySessions
        : categorySessions.sublist(
            categorySessions.length - goalCategorySessionEvidenceLimit,
          );
    final metricCriteria = _metricCriteriaById(version.criteria);

    return _factsBlock({
      'generatedAt': now.toUtc().toIso8601String(),
      'localTime': {
        'iso8601': now.toIso8601String(),
        'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
        'timeZoneName': now.timeZoneName,
      },
      'goal': {
        'id': version.agentId,
        'statement': version.statement,
        'criteria': criterionJson(version.criteria),
      },
      'evaluation': {
        'criterionResults': [
          for (final result in facts.evaluation.results.values)
            _criterionResultJson(
              result: result,
              metric: metricCriteria[result.criterionId],
              facts: facts,
              now: now,
            ),
        ],
        'attainment': facts.evaluation.attainment,
        'trackStatus': facts.trackStatus.name,
        'dataCoverage': facts.evaluation.dataCoverage,
        'onTrackByTrend': facts.evaluation.onTrackByTrend,
        if (facts.evaluation.deficit != null)
          'daysToRecover': facts.evaluation.deficit,
        if (facts.evaluation.buffer != null)
          'bufferDays': facts.evaluation.buffer,
        if (facts.shortTermAttainment != null)
          'trailing3DayAttainment': facts.shortTermAttainment,
        'trendWorsening3PlusDays': trendWorsening(
          facts.evaluation.attainment,
          priorAttainments,
        ),
        'priorPeriodAttainments': priorAttainments,
      },
      if (facts.categoryTimeSessionsByCategory.isNotEmpty)
        'signals': {
          'categoryTimeEvidenceStart': facts.categoryTimeEvidenceStart
              ?.toIso8601String(),
          'categoryTimeEvidenceEnd': facts.categoryTimeEvidenceEnd
              ?.toIso8601String(),
          'categoryTimeSessionCount': categorySessions.length,
          'categoryTimeSessionsOmitted':
              categorySessions.length - recentCategorySessions.length,
          'categoryTimeLifetimeSummary': _categoryTimeLifetimeSummary(
            facts.categoryTimeSessionsByCategory,
          ),
          'categoryTimeSessions': [
            for (final session in recentCategorySessions)
              {
                'categoryId': session.categoryId,
                'startedAtLocal': session.dateFrom.toIso8601String(),
                'endedAtLocal': session.dateTo.toIso8601String(),
                'durationMinutes': _minutes(session.duration.inSeconds),
              },
          ],
          'interpretationPolicy':
              'lifetime summaries and recent session evidence may inform '
              'coaching patterns; they do not override deterministic '
              'criterion results',
        },
      'reporting': {
        'materialChangeSinceLastReport': facts.statusTransitioned,
        'lastReportStatus': facts.previousStatus?.name,
      },
      'ads': {
        'active': [
          for (final nudge in active) _activeAdJson(nudge, now),
        ],
        'reusableTopRated': [
          for (final nudge in reusableTopRated(nudges)) _reusableAdJson(nudge),
        ],
        'dismissalCooldownActive': dismissalCooldownActive(nudges, now),
      },
      'personaTone': {
        'default': 'gently humorous, never shaming',
        'userPreference': personaTonePreference,
      },
      'unansweredUserMessages': unansweredUserMessages,
      'observations': observations,
    });
  }

  Map<String, Object?> _criterionResultJson({
    required GoalCriterionResult result,
    required GoalCriterionMetric? metric,
    required GoalWakeFacts facts,
    required DateTime now,
  }) {
    final healthSeries = metric == null
        ? null
        : _healthSeriesJson(metric: metric, facts: facts, now: now);
    return {
      'criterionId': result.criterionId,
      'actual': result.actual,
      'target': result.target,
      'ratio': result.ratio,
      'satisfied': result.satisfied,
      'sampleCount': result.sampleCount,
      if (result.paceFeasible != null) 'paceFeasible': result.paceFeasible,
      // Rolling-window habit facts: days-to-recovery, and the buffer before
      // the count drops below target. The LLM may restate these but never
      // recomputes them.
      if (result.deficit != null) 'daysToRecover': result.deficit,
      if (result.buffer != null) 'bufferDays': result.buffer,
      if (result.projectedDaysToTarget != null)
        'projectedDaysToTarget': result.projectedDaysToTarget,
      'healthSeries': ?healthSeries,
    };
  }

  Map<String, Object?>? _healthSeriesJson({
    required GoalCriterionMetric metric,
    required GoalWakeFacts facts,
    required DateTime now,
  }) {
    if (!GoalHealthDataTypes.supported.contains(metric.dataType)) return null;
    final range = metric.window.periodRange(now);
    final candidates =
        facts.quantitativeObservationsByType[metric.dataType] ??
        const <GoalMetricObservation>[];
    final observations =
        <GoalMetricObservation>[
          for (final observation in candidates)
            if (!GoalWindow.dayUtc(
                  observation.recordedAt,
                ).isBefore(range.start) &&
                !GoalWindow.dayUtc(observation.recordedAt).isAfter(range.end) &&
                !observation.recordedAt.isAfter(now))
              observation,
        ]..sort((a, b) {
          final byTime = a.recordedAt.compareTo(b.recordedAt);
          return byTime != 0 ? byTime : a.tieBreaker.compareTo(b.tieBreaker);
        });
    final latest = observations.lastOrNull;
    return {
      'observations': [
        for (final observation in observations)
          {
            'recordedAt': observation.recordedAt.toIso8601String(),
            'value': observation.value,
          },
      ],
      if (latest != null)
        'latest': {
          'recordedAt': latest.recordedAt.toIso8601String(),
          'value': latest.value,
          'onTarget': _meetsTarget(
            latest.value,
            metric.target,
            metric.direction,
          ),
          'isToday':
              GoalWindow.dayUtc(latest.recordedAt) == GoalWindow.dayUtc(now),
        },
    };
  }

  Map<String, GoalCriterionMetric> _metricCriteriaById(
    GoalCriterion criteria,
  ) {
    final metrics = <String, GoalCriterionMetric>{};
    void visit(GoalCriterion criterion) {
      switch (criterion) {
        case final GoalCriterionMetric metric:
          metrics[metric.criterionId] = metric;
        case GoalCriterionAllOf(:final criteria) ||
            GoalCriterionAnyOf(:final criteria) ||
            GoalCriterionAtLeastCount(:final criteria):
          criteria.forEach(visit);
        case GoalCriterionHabit() ||
            GoalCriterionMeasurable() ||
            GoalCriterionCategoryTime():
      }
    }

    visit(criteria);
    return metrics;
  }

  bool _meetsTarget(num value, num target, GoalDirection direction) =>
      switch (direction) {
        GoalDirection.atLeast => value >= target,
        GoalDirection.atMost => value <= target,
      };

  List<Map<String, Object>> _categoryTimeLifetimeSummary(
    Map<String, List<GoalCategoryTimeSession>> sessionsByCategory,
  ) {
    final categoryIds = sessionsByCategory.keys.toList()..sort();
    return [
      for (final categoryId in categoryIds)
        _categorySummary(
          categoryId,
          sessionsByCategory[categoryId] ?? const [],
        ),
    ];
  }

  Map<String, Object> _categorySummary(
    String categoryId,
    List<GoalCategoryTimeSession> sessions,
  ) {
    final secondsByLocalHour = List<int>.filled(24, 0);
    final secondsByLocalWeekday = List<int>.filled(7, 0);
    final merged = mergeIntervals([
      for (final session in sessions)
        TimeInterval(session.dateFrom, session.dateTo),
    ]);
    var totalSeconds = 0;
    for (final interval in merged) {
      totalSeconds += interval.duration.inSeconds;
      var cursor = interval.start;
      while (cursor.isBefore(interval.end)) {
        final nextHour = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
          cursor.hour + 1,
        );
        final segmentEnd = nextHour.isBefore(interval.end)
            ? nextHour
            : interval.end;
        final seconds = segmentEnd.difference(cursor).inSeconds;
        secondsByLocalHour[cursor.hour] += seconds;
        secondsByLocalWeekday[cursor.weekday - DateTime.monday] += seconds;
        cursor = segmentEnd;
      }
    }
    return {
      'categoryId': categoryId,
      'sessionCount': sessions.length,
      'totalMinutes': _minutes(totalSeconds),
      'minutesByLocalHour': [
        for (final seconds in secondsByLocalHour) _minutes(seconds),
      ],
      'minutesByLocalWeekday': [
        for (final seconds in secondsByLocalWeekday) _minutes(seconds),
      ],
    };
  }

  double _minutes(int seconds) => seconds / Duration.secondsPerMinute;

  /// Worsening means: strictly declining attainment over today plus at
  /// least two prior periods (three data points, each below the one
  /// before it) — the FACTS key policy row P4 keys on.
  bool trendWorsening(double current, List<double> priorAttainments) {
    return goalTrendWorsening(current, priorAttainments);
  }

  /// A dismissal blocks all ad activity for the rest of that LOCAL
  /// calendar day — "not today", not a rolling 24h (which would let an
  /// evening dismissal silence the whole next day too). Calendar-day
  /// comparison via [GoalWindow.dayUtc], the repo's DST-safe day key.
  bool dismissalCooldownActive(List<GoalNudgeEntity> nudges, DateTime now) =>
      nudges.any(
        (n) =>
            n.dismissedAt != null &&
            // toLocal: the instant persists as UTC; "not today" means the
            // READING device's calendar day (older local-stamped rows
            // pass through toLocal unchanged).
            GoalWindow.dayUtc(n.dismissedAt!.toLocal()) ==
                GoalWindow.dayUtc(now),
      );

  /// Retired ads whose mean rating clears [goalReusableMinMeanRating],
  /// best first — the zero-cost reuse library of policy row P13. Skipped
  /// ratings don't count toward the mean; unrated ads are never offered.
  List<GoalNudgeEntity> reusableTopRated(List<GoalNudgeEntity> nudges) {
    final rated = <(GoalNudgeEntity, double)>[];
    for (final nudge in nudges) {
      if (nudge.status != GoalNudgeStatus.retired) continue;
      final ratings = [
        for (final r in nudge.ratings)
          if (r.rating != null) r.rating!,
      ];
      if (ratings.isEmpty) continue;
      final mean = ratings.reduce((a, b) => a + b) / ratings.length;
      if (mean >= goalReusableMinMeanRating) rated.add((nudge, mean));
    }
    rated.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final entry in rated) entry.$1];
  }

  Map<String, Object?> _activeAdJson(GoalNudgeEntity nudge, DateTime now) {
    final since = nudge.activatedAt ?? nudge.createdAt;
    final age = now.difference(since);
    return {
      'adId': nudge.id,
      'headline': nudge.brief.headline,
      'message': [
        nudge.brief.tagline,
        nudge.brief.cta,
      ].whereType<String>().join(' — '),
      'ageHours': age.inHours,
      'fresh': age < goalAdFreshFor,
      'markedStale': nudge.staleAt != null && !now.isBefore(nudge.staleAt!),
      'outcomeRecorded': nudge.ratings.any(
        (rating) => rating.activation == nudge.activationCount,
      ),
      'snoozedUntil': ?nudge.provenance['snoozedUntil'],
    };
  }

  Map<String, Object?> _reusableAdJson(GoalNudgeEntity nudge) {
    final ratings = [
      for (final r in nudge.ratings)
        if (r.rating != null) r.rating!,
    ];
    final mean = ratings.reduce((a, b) => a + b) / ratings.length;
    return {
      'adId': nudge.id,
      'bannerSummary': [
        nudge.brief.headline,
        nudge.brief.tagline,
      ].whereType<String>().join(' — '),
      'meanRating': double.parse(mean.toStringAsFixed(2)),
      'timesRun': nudge.activationCount,
    };
  }
}

/// A JSON rendering of the criteria tree, mirroring the eval fixtures'
/// vocabulary: leaves carry their window/target/direction, composites
/// nest their children under the combinator name.
Map<String, Object?> criterionJson(GoalCriterion criterion) =>
    switch (criterion) {
      GoalCriterionMetric() => {
        'criterionId': criterion.criterionId,
        if (criterion.title != null) 'title': criterion.title,
        'metric': criterion.dataType,
        'aggregation': criterion.aggregation.name,
        'window': _windowLabel(criterion.window),
        'target': criterion.target,
        'direction': criterion.direction.name,
      },
      GoalCriterionHabit() => {
        'criterionId': criterion.criterionId,
        if (criterion.title != null) 'title': criterion.title,
        'habit': criterion.habitId,
        'window': _windowLabel(criterion.window),
        'targetCount': criterion.targetCount,
      },
      GoalCriterionMeasurable() => {
        'criterionId': criterion.criterionId,
        if (criterion.title != null) 'title': criterion.title,
        'measurable': criterion.dataTypeId,
        'aggregation': criterion.aggregation.name,
        'window': _windowLabel(criterion.window),
        'target': criterion.target,
        'direction': criterion.direction.name,
      },
      GoalCriterionCategoryTime() => {
        'criterionId': criterion.criterionId,
        if (criterion.title != null) 'title': criterion.title,
        'categoryTime': criterion.categoryId,
        'aggregation': criterion.aggregation.name,
        'window': _windowLabel(criterion.window),
        'targetHours': criterion.targetHours,
        'direction': criterion.direction.name,
        if (criterion.dailyTimeRange case final range?)
          'dailyTimeRange': {
            'startMinute': range.startMinute,
            'endMinute': range.endMinute,
          },
        'evidence': 'tracked Lotti time entries only',
      },
      GoalCriterionAllOf() => {
        'criterionId': criterion.criterionId,
        if (criterion.title != null) 'title': criterion.title,
        'allOf': [for (final c in criterion.criteria) criterionJson(c)],
      },
      GoalCriterionAnyOf() => {
        'criterionId': criterion.criterionId,
        if (criterion.title != null) 'title': criterion.title,
        'anyOf': [for (final c in criterion.criteria) criterionJson(c)],
      },
      GoalCriterionAtLeastCount() => {
        'criterionId': criterion.criterionId,
        if (criterion.title != null) 'title': criterion.title,
        'atLeast': criterion.successes,
        'of': [for (final c in criterion.criteria) criterionJson(c)],
      },
    };

String _windowLabel(GoalWindow window) => switch (window) {
  GoalWindowDay() => 'day',
  GoalWindowRollingDays(:final count) => 'rolling $count days',
  GoalWindowCalendarWeek() => 'calendar week (Mon-Sun)',
  GoalWindowCalendarMonth() => 'calendar month',
};

String _factsBlock(Map<String, Object?> facts) =>
    'FACTS (deterministic, authoritative — restate, never recompute):\n'
    '```json\n${const JsonEncoder.withIndent('  ').convert(facts)}\n```';
