/// Pure availability predicates for the day plan.
///
/// Categories are strictly opt-in: only categories whose
/// [CategoryDefinition.isAvailableForDayPlan] flag is explicitly `true` (and
/// which are active and not deleted) are offered for selection in the day
/// plan. Nothing is available by default.
///
/// Projects are tiered rather than binary: `active` projects form the
/// scheduled pool, while every other non-closed project (`open`,
/// `monitoring`, `onHold`) stays available at lower priority so that
/// something noticed along the way can still be planned. Closed projects
/// (`completed`, `archived`) are not available at all.
library;

import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';

/// Whether [category] may be offered for selection in the day plan.
///
/// Strict opt-in: `isAvailableForDayPlan == null` (never set, including all
/// categories synced before the flag existed) means NOT available.
bool isCategoryAvailableForDayPlan(CategoryDefinition category) {
  return category.active &&
      category.deletedAt == null &&
      (category.isAvailableForDayPlan ?? false);
}

/// The day-plan category universe: available categories sorted by name
/// (case-insensitive), mirroring `EntitiesCacheService.sortedCategories`
/// ordering.
List<CategoryDefinition> filterDayPlanCategories(
  Iterable<CategoryDefinition> categories,
) {
  return categories.where(isCategoryAvailableForDayPlan).toList()
    ..sortBy((category) => category.name.toLowerCase());
}

/// IDs of the categories available for day planning.
///
/// NOTE: an empty result means "no categories available" (strict opt-in).
/// Do NOT pass this to `AgentIdentity.allowedCategoryIds`, where an empty
/// set means allow-ALL.
Set<String> dayPlanAllowedCategoryIds(
  Iterable<CategoryDefinition> categories,
) {
  return categories
      .where(isCategoryAvailableForDayPlan)
      .map((category) => category.id)
      .toSet();
}

/// Day-plan priority tier of a project.
enum DayPlanProjectPriority {
  /// Time is actively scheduled — the default pool for day planning.
  scheduled,

  /// Not actively scheduled, but still open: when something comes up in
  /// such a project it can be planned — at lower priority than the
  /// scheduled pool.
  opportunistic,

  /// Closed — not available for day planning.
  unavailable,
}

/// Maps a project's status to its day-plan priority tier.
///
/// `active` is the only status with time actively scheduled. `open`
/// (not started), `monitoring` (parked until something comes up), and
/// `onHold` (deliberately paused) remain plannable at lower priority.
/// `completed` and `archived` are closed.
DayPlanProjectPriority dayPlanProjectPriority(ProjectData data) {
  return switch (data.status) {
    ProjectActive() => DayPlanProjectPriority.scheduled,
    ProjectOpen() ||
    ProjectMonitoring() ||
    ProjectOnHold() => DayPlanProjectPriority.opportunistic,
    ProjectCompleted() ||
    ProjectArchived() => DayPlanProjectPriority.unavailable,
  };
}

/// Whether a project with [data] may appear in the day plan at all
/// (at any priority).
bool isProjectAvailableForDayPlan(ProjectData data) {
  return dayPlanProjectPriority(data) != DayPlanProjectPriority.unavailable;
}

/// The day-plan project universe: available, non-deleted projects, with the
/// scheduled pool ordered before opportunistic ones (stable within a tier).
///
/// Single pass: each project's priority is computed once, then bucketed.
List<ProjectEntry> filterDayPlanProjects(Iterable<ProjectEntry> projects) {
  final scheduled = <ProjectEntry>[];
  final opportunistic = <ProjectEntry>[];
  for (final project in projects) {
    if (project.meta.deletedAt != null) continue;
    switch (dayPlanProjectPriority(project.data)) {
      case DayPlanProjectPriority.scheduled:
        scheduled.add(project);
      case DayPlanProjectPriority.opportunistic:
        opportunistic.add(project);
      case DayPlanProjectPriority.unavailable:
        // Closed projects are not offered for day planning.
        break;
    }
  }
  return [...scheduled, ...opportunistic];
}
