import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_data.freezed.dart';
part 'rating_data.g.dart';

@freezed
abstract class RatingData with _$RatingData {
  const factory RatingData({
    /// The rated entity's ID. For session ratings this is the time entry ID.
    /// For day ratings it will be the DayPlanEntry ID, for task ratings
    /// the Task ID. JSON key remains 'timeEntryId' for wire compatibility.
    @JsonKey(name: 'timeEntryId') required String targetId,

    /// Individual dimension ratings, each normalized to 0.0-1.0.
    required List<RatingDimension> dimensions,

    /// Identifies which question catalog was used to produce this rating.
    /// Enables multiple distinct ratings per target entity (e.g. a task
    /// rated at start vs completion, or a day rated morning vs evening).
    /// The invariant is: at most one rating per (targetId, catalogId).
    @Default('session') String catalogId,

    /// Schema version for the rating dimensions.
    /// Increment when adding/removing/reordering questions.
    @Default(1) int schemaVersion,

    /// Optional free-text note about the session.
    String? note,
  }) = _RatingData;
  const RatingData._();

  factory RatingData.fromJson(Map<String, dynamic> json) =>
      _$RatingDataFromJson(json);

  /// Looks up a dimension by [key] and returns its value, or null.
  double? dimensionValue(String key) {
    for (final dim in dimensions) {
      if (dim.key == key) return dim.value;
    }
    return null;
  }
}

@freezed
abstract class RatingDimension with _$RatingDimension {
  const factory RatingDimension({
    /// Stable key for this dimension (e.g., "productivity", "energy",
    /// "focus", "challenge_skill").
    required String key,

    /// Normalized value between 0.0 and 1.0.
    required double value,

    /// The localized question text shown to the user at time of rating.
    /// Captured in whatever language the user had active.
    String? question,

    /// English semantic description of what this dimension measures and
    /// how to interpret the 0-1 scale. Intended for LLM consumption so
    /// it can determine "good" vs "bad" outcomes without a schema lookup.
    /// Example: "Measures subjective productivity. 0.0 = completely
    /// unproductive, 1.0 = peak productivity."
    String? description,

    /// Input type used to collect this answer ('tapBar', 'segmented',
    /// 'boolean'). Allows the UI and LLMs to interpret the value.
    String? inputType,

    /// Labels for segmented/categorical options (e.g. ["Too easy",
    /// "Just right", "Too challenging"]). Present only when
    /// [inputType] is 'segmented'.
    List<String>? optionLabels,
  }) = _RatingDimension;

  factory RatingDimension.fromJson(Map<String, dynamic> json) =>
      _$RatingDimensionFromJson(json);
}
