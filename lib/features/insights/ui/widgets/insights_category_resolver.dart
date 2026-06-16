import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// Resolves series/table keys (category id, `null`, or the "Other"
/// sentinel) to display labels and raw color hexes.
///
/// Labels are resolved to plain strings at construction (in the page,
/// where `context.messages` is available) so chart/table widgets stay
/// dumb and trivially testable.
@immutable
class InsightsCategoryResolver {
  const InsightsCategoryResolver({
    required this.categoriesById,
    required this.uncategorizedLabel,
    required this.otherLabel,
    required this.deletedLabel,
  });

  final Map<String, CategoryDefinition> categoriesById;

  /// Label for the `null` key (entries without category attribution).
  final String uncategorizedLabel;

  /// Label for [kInsightsOtherCategoryKey] (top-N rollup).
  final String otherLabel;

  /// Label for ids whose category definition no longer exists — never
  /// render a raw UUID.
  final String deletedLabel;

  /// Display label for a series/table key: [uncategorizedLabel] for `null`,
  /// [otherLabel] for the rollup sentinel, the category name otherwise, and
  /// [deletedLabel] when the id has no live definition (never a raw UUID).
  String labelFor(String? key) {
    if (key == null) return uncategorizedLabel;
    if (key == kInsightsOtherCategoryKey) return otherLabel;
    return categoriesById[key]?.name ?? deletedLabel;
  }

  /// Raw CSS hex of the category color; `null` for uncategorized, the
  /// "Other" rollup, and deleted categories (neutral gray downstream).
  String? colorHexFor(String? key) {
    if (key == null || key == kInsightsOtherCategoryKey) return null;
    return categoriesById[key]?.color;
  }
}
