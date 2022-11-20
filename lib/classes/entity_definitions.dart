import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'entity_definitions.freezed.dart';
part 'entity_definitions.g.dart';

enum AggregationType { none, dailySum, dailyMax, dailyAvg, hourlySum }

enum HabitCompletionType { success, skip, fail }

@freezed
class HabitSchedule with _$HabitSchedule {
  factory HabitSchedule.daily({
    required int requiredCompletions,
    DateTime? showFrom,
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
class AutoCompleteRule with _$AutoCompleteRule {
  factory AutoCompleteRule.health({
    required String dataType,
    num? minimum,
    num? maximum,
    String? title,
  }) = AutoCompleteRuleHealth;

  factory AutoCompleteRule.workout({
    required String dataType,
    num? minimum,
    num? maximum,
    String? title,
  }) = AutoCompleteRuleWorkout;

  factory AutoCompleteRule.measurable({
    required String dataTypeId,
    num? minimum,
    num? maximum,
    String? title,
  }) = AutoCompleteRuleMeasurable;

  factory AutoCompleteRule.habit({
    required String habitId,
    String? title,
  }) = AutoCompleteRuleHabit;

  factory AutoCompleteRule.and({
    required List<AutoCompleteRule> rules,
    String? title,
  }) = AutoCompleteRuleAnd;

  factory AutoCompleteRule.or({
    required List<AutoCompleteRule> rules,
    String? title,
  }) = AutoCompleteRuleOr;

  factory AutoCompleteRule.multiple({
    required List<AutoCompleteRule> rules,
    required int successes,
    String? title,
  }) = AutoCompleteRuleMultiple;

  factory AutoCompleteRule.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleFromJson(json);
}

@freezed
class EntityDefinition with _$EntityDefinition {
  factory EntityDefinition.measurableDataType({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
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

  factory EntityDefinition.habit({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String description,
    required HabitSchedule habitSchedule,
    AutoCompleteRule? autoCompleteRule,
    String? version,
    required VectorClock? vectorClock,
    required bool active,
    required bool private,
    DateTime? activeFrom,
    DateTime? activeUntil,
    DateTime? deletedAt,
    String? defaultStoryId,
  }) = HabitDefinition;

  factory EntityDefinition.dashboard({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime lastReviewed,
    required String name,
    required String description,
    required List<DashboardItem> items,
    required String version,
    required VectorClock? vectorClock,
    required bool active,
    required bool private,
    DateTime? reviewAt,
    @Default(30) int days,
    DateTime? deletedAt,
  }) = DashboardDefinition;

  factory EntityDefinition.fromJson(Map<String, dynamic> json) =>
      _$EntityDefinitionFromJson(json);
}

@freezed
class MeasurementData with _$MeasurementData {
  factory MeasurementData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required String dataTypeId,
  }) = _MeasurementData;

  factory MeasurementData.fromJson(Map<String, dynamic> json) =>
      _$MeasurementDataFromJson(json);
}

@freezed
class WorkoutData with _$WorkoutData {
  factory WorkoutData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String id,
    required String workoutType,
    required num? energy,
    required num? distance,
    required String? source,
  }) = _WorkoutData;

  factory WorkoutData.fromJson(Map<String, dynamic> json) =>
      _$WorkoutDataFromJson(json);
}

@freezed
class HabitCompletionData with _$HabitCompletionData {
  factory HabitCompletionData({
    required DateTime dateFrom,
    required DateTime dateTo,
    HabitCompletionType? completionType,
    required String habitId,
  }) = _HabitCompletionData;

  factory HabitCompletionData.fromJson(Map<String, dynamic> json) =>
      _$HabitCompletionDataFromJson(json);
}

enum WorkoutValueType {
  duration,
  distance,
  energy,
}

@freezed
class DashboardItem with _$DashboardItem {
  factory DashboardItem.measurement({
    required String id,
    AggregationType? aggregationType,
  }) = DashboardMeasurementItem;

  factory DashboardItem.healthChart({
    required String color,
    required String healthType,
  }) = DashboardHealthItem;

  factory DashboardItem.workoutChart({
    required String workoutType,
    required String displayName,
    required String color,
    required WorkoutValueType valueType,
  }) = DashboardWorkoutItem;

  factory DashboardItem.habitChart({
    required String habitId,
  }) = DashboardHabitItem;

  factory DashboardItem.surveyChart({
    required Map<String, String> colorsByScoreKey,
    required String surveyType,
    required String surveyName,
  }) = DashboardSurveyItem;

  factory DashboardItem.storyTimeChart({
    required String storyTagId,
    required String color,
  }) = DashboardStoryTimeItem;

  factory DashboardItem.wildcardStoryTimeChart({
    required String storySubstring,
    required String color,
  }) = WildcardStoryTimeItem;

  factory DashboardItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardItemFromJson(json);
}
