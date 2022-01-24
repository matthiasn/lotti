import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'entity_definitions.freezed.dart';
part 'entity_definitions.g.dart';

enum AggregationType { none, dailySum, dailyMax }

@freezed
class HabitSchedule with _$HabitSchedule {
  factory HabitSchedule.daily({
    required int requiredCompletions,
  }) = DailyHabitSchedule;

  factory HabitSchedule.weekly({
    required int requiredCompletions,
  }) = WeeklyHabitSchedule;

  factory HabitSchedule.monthly({
    required int requiredCompletions,
  }) = MonthlyHabitSchedule;

  factory HabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$HabitScheduleFromJson(json);
}

@freezed
class EntityDefinition with _$EntityDefinition {
  factory EntityDefinition.measurableDataType({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String displayName,
    required String description,
    required String unitName,
    required int version,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    bool? private,
    bool? favorite,
    AggregationType? aggregationType,
  }) = MeasurableDataType;

  factory EntityDefinition.tagDefinition({
    required String id,
    required String tag,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    bool? inactive,
  }) = TagDefinition;

  factory EntityDefinition.habitDefinition({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String description,
    required HabitSchedule habitSchedule,
    required String version,
    required DateTime activeFrom,
    required DateTime activeUntil,
    required VectorClock? vectorClock,
    required bool active,
    required bool private,
    DateTime? deletedAt,
  }) = HabitDefinition;

  factory EntityDefinition.fromJson(Map<String, dynamic> json) =>
      _$EntityDefinitionFromJson(json);
}

@freezed
class MeasurementData with _$MeasurementData {
  factory MeasurementData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required MeasurableDataType dataType,
  }) = _MeasurementData;

  factory MeasurementData.fromJson(Map<String, dynamic> json) =>
      _$MeasurementDataFromJson(json);
}

@freezed
class HabitCompletionData with _$HabitCompletionData {
  factory HabitCompletionData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required String habitId,
  }) = _HabitCompletionData;

  factory HabitCompletionData.fromJson(Map<String, dynamic> json) =>
      _$HabitCompletionDataFromJson(json);
}
