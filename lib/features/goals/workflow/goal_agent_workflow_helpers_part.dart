part of 'goal_agent_workflow.dart';

/// Durable outcomes from a goal wake's transactional output batch.
class GoalOutputPersistenceResult {
  const GoalOutputPersistenceResult({
    required this.attributionFinalized,
    required this.reportHeadAdvanced,
  });

  /// Whether report-backed AI attribution has a durable carrier.
  final bool attributionFinalized;

  /// Whether this wake replaced the report selected by the current head.
  final bool reportHeadAdvanced;
}

/// The pre-rounded aggregates a report's rolling standing must quote,
/// rendered exactly as the FACTS block carries them.
///
/// Metric leaves only. A habit result's `actual` is a completion count and a
/// composite's is a count of satisfied children, so requiring those would
/// match any stray digit rather than prove the aggregate was read. Every
/// evaluated model substitutes the LATEST reading for the mean on the
/// multi-series health goal — reporting 94 kg where FACTS say 95 — which is a
/// wrong number in front of the user, not a wording preference.
///
/// A window with no observations has no aggregate to quote, and an
/// insufficientData report should name the gap instead, so empty series are
/// skipped rather than forcing the model to invent a number.
List<String> goalRollingAggregateStrings(
  GoalCriterion criteria,
  Map<String, GoalCriterionResult> results,
) {
  final metricIds = <String>{};
  void walk(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionMetric(:final criterionId):
        metricIds.add(criterionId);
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(walk);
      case GoalCriterionHabit() ||
          GoalCriterionMeasurable() ||
          GoalCriterionCategoryTime() ||
          GoalCriterionLabelTime():
        break;
    }
  }

  walk(criteria);
  return [
    for (final id in metricIds)
      if (results[id] case final result?)
        if (result.sampleCount > 0)
          '${roundGoalAggregate(result.actual, against: result.target)}',
  ];
}

/// Near-duplicate dedupe key over the banner copy: the same words with
/// different presets are the same ad.
String goalBriefDigest(NudgeBrief brief) => sha1
    .convert(
      utf8.encode(
        [
          brief.headline,
          brief.tagline ?? '',
          brief.cta ?? '',
        ].join('\n').toLowerCase().trim(),
      ),
    )
    .toString();
Map<String, String> _withoutGoalBannerSnooze(
  Map<String, String> provenance,
) => {
  for (final entry in provenance.entries)
    if (entry.key != nudgeBannerSnoozedUntilKey &&
        entry.key != 'snoozeReason' &&
        entry.key != 'snoozedAt')
      entry.key: entry.value,
};

/// Applies the goal report sanitizer to every string in the structured
/// sections, including each `nextActions` entry.
///
/// The values arrive as model-authored prose, exactly like `content` and
/// `tldr`, and are rendered directly.
Map<String, Object?>? _sanitizeReportSections(Map<String, Object?>? sections) {
  if (sections == null) return null;
  return {
    for (final entry in sections.entries)
      entry.key: switch (entry.value) {
        final String text => sanitizeAgentReportText(
          text,
          stripBareIds: true,
        ),
        final List<Object?> items => [
          for (final item in items)
            if (item case final String text)
              sanitizeAgentReportText(text, stripBareIds: true)
            else
              item,
        ],
        final Object? other => other,
      },
  };
}

/// Test seam for [_sanitizeReportSections] — the sanitization contract is
/// worth pinning directly rather than only through a full wake.
@visibleForTesting
Map<String, Object?>? sanitizeReportSectionsForTest(
  Map<String, Object?>? sections,
) => _sanitizeReportSections(sections);
