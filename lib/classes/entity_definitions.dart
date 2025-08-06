import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'entity_definitions.freezed.dart';
part 'entity_definitions.g.dart';

/// Custom JSON converter for CategoryIcon enum.
///
/// Handles serialization and deserialization of CategoryIcon values to/from JSON strings.
/// Returns null for invalid inputs and logs warnings in debug mode for troubleshooting.
class CategoryIconConverter implements JsonConverter<CategoryIcon?, String?> {
  const CategoryIconConverter();

  @override
  CategoryIcon? fromJson(String? json) => CategoryIconExtension.fromJson(json);

  @override
  String? toJson(CategoryIcon? icon) => icon?.toJson();
}

enum AggregationType { none, dailySum, dailyMax, dailyAvg, hourlySum }

enum HabitCompletionType { success, skip, fail, open }

@freezed
class HabitSchedule with _$HabitSchedule {
  const factory HabitSchedule.daily({
    required int requiredCompletions,
    DateTime? showFrom,
    DateTime? alertAtTime,
  }) = DailyHabitSchedule;

  const factory HabitSchedule.weekly({
    required int requiredCompletions,
  }) = WeeklyHabitSchedule;

  const factory HabitSchedule.monthly({
    required int requiredCompletions,
  }) = MonthlyHabitSchedule;

  factory HabitSchedule.fromJson(Map<String, dynamic> json) =>
      _$HabitScheduleFromJson(json);
}

@freezed
class AutoCompleteRule with _$AutoCompleteRule {
  const factory AutoCompleteRule.health({
    required String dataType,
    num? minimum,
    num? maximum,
    String? title,
  }) = AutoCompleteRuleHealth;

  const factory AutoCompleteRule.workout({
    required String dataType,
    num? minimum,
    num? maximum,
    String? title,
  }) = AutoCompleteRuleWorkout;

  const factory AutoCompleteRule.measurable({
    required String dataTypeId,
    num? minimum,
    num? maximum,
    String? title,
  }) = AutoCompleteRuleMeasurable;

  const factory AutoCompleteRule.habit({
    required String habitId,
    String? title,
  }) = AutoCompleteRuleHabit;

  const factory AutoCompleteRule.and({
    required List<AutoCompleteRule> rules,
    String? title,
  }) = AutoCompleteRuleAnd;

  const factory AutoCompleteRule.or({
    required List<AutoCompleteRule> rules,
    String? title,
  }) = AutoCompleteRuleOr;

  const factory AutoCompleteRule.multiple({
    required List<AutoCompleteRule> rules,
    required int successes,
    String? title,
  }) = AutoCompleteRuleMultiple;

  factory AutoCompleteRule.fromJson(Map<String, dynamic> json) =>
      _$AutoCompleteRuleFromJson(json);
}

@freezed
class EntityDefinition with _$EntityDefinition {
  const factory EntityDefinition.measurableDataType({
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
    String? categoryId,
    AggregationType? aggregationType,
  }) = MeasurableDataType;

  const factory EntityDefinition.categoryDefinition({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required VectorClock? vectorClock,
    required bool private,
    required bool active,
    bool? favorite,
    String? color,
    String? categoryId,
    DateTime? deletedAt,
    String? defaultLanguageCode,
    List<String>? allowedPromptIds,
    Map<AiResponseType, List<String>>? automaticPrompts,
    @CategoryIconConverter() CategoryIcon? icon,
  }) = CategoryDefinition;

  const factory EntityDefinition.habit({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String description,
    required HabitSchedule habitSchedule,
    required VectorClock? vectorClock,
    required bool active,
    required bool private,
    AutoCompleteRule? autoCompleteRule,
    String? version,
    DateTime? activeFrom,
    DateTime? activeUntil,
    DateTime? deletedAt,
    String? defaultStoryId,
    String? categoryId,
    String? dashboardId,
    bool? priority,
  }) = HabitDefinition;

  const factory EntityDefinition.dashboard({
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
    String? categoryId,
  }) = DashboardDefinition;

  factory EntityDefinition.fromJson(Map<String, dynamic> json) =>
      _$EntityDefinitionFromJson(json);
}

@freezed
class MeasurementData with _$MeasurementData {
  const factory MeasurementData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required String dataTypeId,
  }) = _MeasurementData;

  factory MeasurementData.fromJson(Map<String, dynamic> json) =>
      _$MeasurementDataFromJson(json);
}

@freezed
class AiResponseData with _$AiResponseData {
  const factory AiResponseData({
    required String model,
    required String systemMessage,
    required String prompt,
    required String thoughts,
    required String response,
    String? promptId,
    List<AiActionItem>? suggestedActionItems,
    AiResponseType? type,
    double? temperature,
  }) = _AiResponseData;

  factory AiResponseData.fromJson(Map<String, dynamic> json) =>
      _$AiResponseDataFromJson(json);
}

@freezed
class WorkoutData with _$WorkoutData {
  const factory WorkoutData({
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
  const factory HabitCompletionData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String habitId,
    HabitCompletionType? completionType,
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
  const factory DashboardItem.measurement({
    required String id,
    AggregationType? aggregationType,
  }) = DashboardMeasurementItem;

  const factory DashboardItem.healthChart({
    required String color,
    required String healthType,
  }) = DashboardHealthItem;

  const factory DashboardItem.workoutChart({
    required String workoutType,
    required String displayName,
    required String color,
    required WorkoutValueType valueType,
  }) = DashboardWorkoutItem;

  const factory DashboardItem.habitChart({
    required String habitId,
  }) = DashboardHabitItem;

  const factory DashboardItem.surveyChart({
    required Map<String, String> colorsByScoreKey,
    required String surveyType,
    required String surveyName,
  }) = DashboardSurveyItem;

  const factory DashboardItem.storyTimeChart({
    required String storyTagId,
    required String color,
  }) = DashboardStoryTimeItem;

  const factory DashboardItem.wildcardStoryTimeChart({
    required String storySubstring,
    required String color,
  }) = WildcardStoryTimeItem;

  factory DashboardItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardItemFromJson(json);
}
