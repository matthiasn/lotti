import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_data.freezed.dart';
part 'rating_data.g.dart';

@freezed
abstract class RatingData with _$RatingData {
  const factory RatingData({
    /// The rated time entry's ID (denormalized for convenience).
    required String timeEntryId,

    /// Individual dimension ratings, each normalized to 0.0-1.0.
    required List<RatingDimension> dimensions,

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
  }) = _RatingDimension;

  factory RatingDimension.fromJson(Map<String, dynamic> json) =>
      _$RatingDimensionFromJson(json);
}
