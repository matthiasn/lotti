/// Pure aggregation and rendering for the weekly rollup registers
/// (`week_rollup:<yyyy-MM-dd>`, ADR 0032 digest pooling).
///
/// A rollup is a deterministic pooled summary of one complete calendar week —
/// planned minutes per category, recorded minutes per category, and how many
/// days had a plan — computed from the same sources as the week context
/// (day-plan entities + recorded-time spans) and persisted so the coordinator
/// digest can see month-scale trends without re-reading a month of raw data.
library;

import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/week_context.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';

/// How many complete weeks of rollups the digest maintains and renders.
const recentWeekRollupCount = 4;

/// Key under which recorded time without a category buckets in the rollup
/// minute maps (JSON map keys cannot be null).
const uncategorizedRollupKey = '';

/// The pooled aggregates for one week, computed from that week's day plans
/// and recorded spans.
///
/// Pure: depends only on its arguments. Callers pass only entities/spans that
/// belong to the target week — this function sums, it does not window.
/// Dropped planned blocks are excluded, mirroring the week-context renderer.
/// Map keys are category ids ([uncategorizedRollupKey] for uncategorized
/// recorded time) in sorted order, so equal aggregates are byte-identical
/// when serialized — the change-detection contract `ensureWeekRollups` relies
/// on to skip no-op writes.
({
  int daysWithPlans,
  Map<String, int> plannedMinutesByCategory,
  Map<String, int> recordedMinutesByCategory,
})
computeWeekRollupAggregates({
  required List<DayPlanEntity> dayPlans,
  required List<RecordedSpan> recordedSpans,
}) {
  final planned = <String, int>{};
  final plannedDayIds = <String>{};
  for (final plan in dayPlans) {
    plannedDayIds.add(plan.dayId);
    for (final block in plan.data.plannedBlocks) {
      if (block.state == PlannedBlockState.dropped) continue;
      final minutes = block.endTime.difference(block.startTime).inMinutes;
      // A blank block category coincides with [uncategorizedRollupKey] and
      // buckets there by construction.
      planned.update(
        block.categoryId,
        (v) => v + minutes,
        ifAbsent: () => minutes,
      );
    }
  }
  final recorded = <String, int>{};
  for (final span in recordedSpans) {
    final minutes = span.duration.inMinutes;
    recorded.update(
      span.categoryId ?? uncategorizedRollupKey,
      (v) => v + minutes,
      ifAbsent: () => minutes,
    );
  }
  return (
    daysWithPlans: plannedDayIds.length,
    plannedMinutesByCategory: _sorted(planned),
    recordedMinutesByCategory: _sorted(recorded),
  );
}

/// Renders rollups as the `<recent_weeks>` JSON body: one object per week,
/// newest first, with minute maps re-keyed by resolved category display name
/// (sanitized; colliding names merge by summing) so the model reads names,
/// not ids. Returns null when [rollups] is empty so the section is omitted.
List<Map<String, Object?>>? renderRecentWeeksJson({
  required List<WeekRollupEntity> rollups,
  required String? Function(String categoryId) categoryName,
}) {
  if (rollups.isEmpty) return null;
  final ordered = [...rollups]
    ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  return [
    for (final rollup in ordered)
      {
        'weekStart': localDay(
          rollup.weekStart,
        ).toIso8601String().substring(0, 10),
        'daysWithPlans': rollup.daysWithPlans,
        if (rollup.plannedMinutesByCategory.isNotEmpty)
          'plannedMinutes': _byDisplayName(
            rollup.plannedMinutesByCategory,
            categoryName,
          ),
        if (rollup.recordedMinutesByCategory.isNotEmpty)
          'recordedMinutes': _byDisplayName(
            rollup.recordedMinutesByCategory,
            categoryName,
          ),
      },
  ];
}

Map<String, int> _byDisplayName(
  Map<String, int> byCategoryId,
  String? Function(String categoryId) categoryName,
) {
  final byName = <String, int>{};
  for (final entry in byCategoryId.entries) {
    final resolved = entry.key == uncategorizedRollupKey
        ? null
        : categoryName(entry.key);
    final name = resolved == null || resolved.trim().isEmpty
        ? (entry.key == uncategorizedRollupKey ? 'Uncategorized' : entry.key)
        : resolved;
    byName.update(
      collapseToSingleLine(name),
      (v) => v + entry.value,
      ifAbsent: () => entry.value,
    );
  }
  return _sorted(byName);
}

Map<String, int> _sorted(Map<String, int> map) => {
  for (final key in map.keys.toList()..sort()) key: map[key]!,
};
