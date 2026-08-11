import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';

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

/// Renders the deterministic FACTS block for one Phase B wake.
///
/// The output shape is EXACTLY the one the eval fixtures validated
/// model-against-model (`goal_agent_eval_fixtures.dart`): a labelled JSON
/// fence with `goal` / `evaluation` / `reporting` / `ads` / `personaTone`
/// / `unansweredUserMessages` / `observations` sections. Every number is
/// pre-computed here — the prompt instructs the model to restate, never
/// derive, so this renderer is the single place the model's worldview is
/// assembled.
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
            {
              'criterionId': result.criterionId,
              'actual': result.actual,
              'target': result.target,
              'ratio': result.ratio,
              'satisfied': result.satisfied,
              'sampleCount': result.sampleCount,
              if (result.paceFeasible != null)
                'paceFeasible': result.paceFeasible,
              // Rolling-window habit facts: days-to-recovery, and the buffer
              // before the count drops below target. The LLM may restate
              // these but never recomputes them.
              if (result.deficit != null) 'daysToRecover': result.deficit,
              if (result.buffer != null) 'bufferDays': result.buffer,
            },
        ],
        'attainment': facts.evaluation.attainment,
        'trackStatus': facts.trackStatus.name,
        'dataCoverage': facts.evaluation.dataCoverage,
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
        'metric': criterion.dataType,
        'aggregation': criterion.aggregation.name,
        'window': _windowLabel(criterion.window),
        'target': criterion.target,
        'direction': criterion.direction.name,
      },
      GoalCriterionHabit() => {
        'criterionId': criterion.criterionId,
        'habit': criterion.habitId,
        'window': _windowLabel(criterion.window),
        'targetCount': criterion.targetCount,
      },
      GoalCriterionMeasurable() => {
        'criterionId': criterion.criterionId,
        'measurable': criterion.dataTypeId,
        'aggregation': criterion.aggregation.name,
        'window': _windowLabel(criterion.window),
        'target': criterion.target,
        'direction': criterion.direction.name,
      },
      GoalCriterionAllOf() => {
        'criterionId': criterion.criterionId,
        'allOf': [for (final c in criterion.criteria) criterionJson(c)],
      },
      GoalCriterionAnyOf() => {
        'criterionId': criterion.criterionId,
        'anyOf': [for (final c in criterion.criteria) criterionJson(c)],
      },
      GoalCriterionAtLeastCount() => {
        'criterionId': criterion.criterionId,
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
