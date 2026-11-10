import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// One category's share of a day's plan.
typedef DayCategoryTotal = ({DayAgentCategory category, int minutes});

/// Per-category planned minutes for [draft], largest first.
///
/// Dropped blocks are left out — they no longer claim any of the day. Totals
/// are keyed by category id, so two blocks of the same category add up even
/// when their category objects differ in name or colour; the last block's
/// category is the one reported.
///
/// This is the one source the day page reads planned time from, so the
/// capacity figures and the per-category breakdown can never disagree (a
/// plan's stored `scheduledMinutes` can drift from the blocks it renders).
List<DayCategoryTotal> categoryTotalsFor(DraftPlan draft) {
  final totals = <String, DayCategoryTotal>{};
  for (final block in draft.blocks) {
    if (block.state == TimeBlockState.dropped) continue;
    final key = block.category.id;
    final existing = totals[key];
    totals[key] = (
      category: block.category,
      minutes: (existing?.minutes ?? 0) + block.duration.inMinutes,
    );
  }
  return totals.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
}

/// Per-category recorded minutes for [blocks], largest first — the recorded
/// day in the same shape [categoryTotalsFor] gives the plan, so the two can
/// be drawn alike. Keyed by category id; the last block's category is the
/// one reported.
List<DayCategoryTotal> recordedTotalsFor(List<TimeBlock> blocks) {
  final totals = <String, DayCategoryTotal>{};
  for (final block in blocks) {
    final key = block.category.id;
    totals[key] = (
      category: block.category,
      minutes: (totals[key]?.minutes ?? 0) + block.duration.inMinutes,
    );
  }
  return totals.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
}
