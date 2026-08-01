/// Pure availability predicates for the day plan.
///
/// Categories are strictly opt-in: only categories whose
/// [CategoryDefinition.isAvailableForDayPlan] flag is explicitly `true` (and
/// which are active and not deleted) are offered for selection in the day
/// plan. Nothing is available by default.
///
library;

import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';

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
