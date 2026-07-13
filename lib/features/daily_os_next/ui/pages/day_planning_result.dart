import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';

/// The outcome of a `showDayPlanningModal` interaction.
///
/// `showDayPlanningModal` previously returned `Future<void>`, so callers could
/// not tell a barrier/close dismissal apart from a completed flow. A `null`
/// result now means the user dismissed the modal (barrier tap, close button, or
/// a "looks good" with nothing to adapt); a non-null result means a real plan
/// landed.
sealed class DayPlanningResult {
  const DayPlanningResult();
}

/// A brand-new plan was drafted and persisted (the `DayPlanningCreate` flow
/// reached `DraftingPhase.ready` with a non-null draft).
final class DayPlanningCreated extends DayPlanningResult {
  const DayPlanningCreated({
    required this.draft,
    this.createdTaskIds = const [],
  });

  /// The persisted drafted plan.
  final DraftPlan draft;

  /// Task ids newly materialized by this drafting run from approved,
  /// previously-unlinked capture items. Empty when nothing new was created or
  /// when attribution could not be established. See [attributeCreatedTaskIds].
  final List<String> createdTaskIds;
}

/// An existing plan was adapted and persisted via the `DayPlanningAdapt`
/// (Refine) flow.
final class DayPlanningAdapted extends DayPlanningResult {
  const DayPlanningAdapted({required this.draft});

  /// The persisted adapted plan.
  final DraftPlan draft;
}

/// Attributes the task ids newly created by a drafting run.
///
/// A drafting wake calls `create_task_from_phrase` for approved capture items
/// that had no task yet, which stamps a [ParsedItem.matchedTaskId] onto the
/// item. So the newly-created tasks are exactly the approved, previously
/// unlinked capture items ([decidedCaptureItemIds]) whose re-read
/// [ParsedItem] now carries a `matchedTaskId`. A null→set transition on one of
/// those ids is attributable to this run.
///
/// The result preserves first-seen order and de-duplicates, so the same task
/// id surfaced by two capture items appears once.
List<String> attributeCreatedTaskIds({
  required List<String> decidedCaptureItemIds,
  required List<ParsedItem> reparsedItems,
}) {
  final decided = decidedCaptureItemIds.toSet();
  final createdTaskIds = <String>[];
  final seen = <String>{};
  for (final item in reparsedItems) {
    if (!decided.contains(item.id)) continue;
    final taskId = item.matchedTaskId;
    if (taskId == null) continue;
    if (seen.add(taskId)) createdTaskIds.add(taskId);
  }
  return createdTaskIds;
}
