import 'package:collection/collection.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:meta/meta.dart';

/// What her reply to a time question charts: the days one
/// `summarize_logged_time` summed and the categories the turn could see.
///
/// The reply stores this, never the figures: the chart reads them again
/// when drawn, so private time stays hidden whenever private entries are.
@immutable
class FrontLoggedTimeChart {
  const FrontLoggedTimeChart({
    required this.range,
    required this.categoryIds,
    this.namedCategoryIds = const {},
  });

  final InsightsRange range;

  /// The turn's category scope; empty for every category.
  final Set<String> categoryIds;

  /// The categories the user named in the question; empty when none. When
  /// set, the chart shows these alone, every other category's time one
  /// unnamed "Other" slice — naming one category never names the rest.
  final Set<String> namedCategoryIds;

  Map<String, Object> toJson() => {
    'startDay': range.startDay,
    'endDayExclusive': range.endDayExclusive,
    'categoryIds': categoryIds.toList()..sort(),
    if (namedCategoryIds.isNotEmpty)
      'namedCategoryIds': namedCategoryIds.toList()..sort(),
  };

  /// Reads a stored chart; null for none or a shape this build does not know.
  static FrontLoggedTimeChart? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = json['startDay'];
    final end = json['endDayExclusive'];
    final ids = json['categoryIds'];
    final named = json['namedCategoryIds'] ?? const <Object?>[];
    if (start is! int ||
        end is! int ||
        start >= end ||
        ids is! List ||
        named is! List) {
      return null;
    }
    return FrontLoggedTimeChart(
      range: InsightsRange(startDay: start, endDayExclusive: end),
      categoryIds: ids.whereType<String>().toSet(),
      namedCategoryIds: named.whereType<String>().toSet(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FrontLoggedTimeChart &&
      other.range == range &&
      const SetEquality<String>().equals(other.categoryIds, categoryIds) &&
      const SetEquality<String>().equals(
        other.namedCategoryIds,
        namedCategoryIds,
      );

  @override
  int get hashCode => Object.hash(
    range,
    const SetEquality<String>().hash(categoryIds),
    const SetEquality<String>().hash(namedCategoryIds),
  );
}
