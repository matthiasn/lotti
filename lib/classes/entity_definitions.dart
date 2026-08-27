import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'entity_definitions.freezed.dart';
part 'entity_definitions.g.dart';

/// Represents a user correction to a checklist item title.
/// Captured when users manually edit titles to fix transcription/spelling errors.
@freezed
abstract class ChecklistCorrectionExample with _$ChecklistCorrectionExample {
  const factory ChecklistCorrectionExample({
    /// The original (incorrect) text before correction.
    required String before,

    /// The corrected (correct) text after user edit.
    required String after,

    /// When this correction was captured.
    DateTime? capturedAt,
  }) = _ChecklistCorrectionExample;

  factory ChecklistCorrectionExample.fromJson(Map<String, dynamic> json) =>
      _$ChecklistCorrectionExampleFromJson(json);
}

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

/// Origin of a habit completion entry.
enum HabitCompletionSource {
  /// Recorded by the user from the habits page or completion sheet.
  manual,

  /// Written by the auto-completion engine from recorded signals.
  auto,
}

@freezed
sealed class HabitSchedule with _$HabitSchedule {
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
sealed class AutoCompleteRule with _$AutoCompleteRule {
  const factory AutoCompleteRule.health({
    required String dataType,
    num? minimum,
    num? maximum,
    String? title,
  }) = AutoCompleteRuleHealth;

  /// A workout of [dataType] (the raw `workoutType` string as imported from
  /// Apple Health / Health Connect). With [valueType] set, [minimum] and
  /// [maximum] apply to that value of the day's workouts (minutes, km, kcal);
  /// with [valueType] null the rule is satisfied by any workout of that type.
  const factory AutoCompleteRule.workout({
    required String dataType,
    num? minimum,
    num? maximum,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    WorkoutValueType? valueType,
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
sealed class EntityDefinition with _$EntityDefinition {
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
    @CategoryIconConverter() CategoryIcon? icon,
    List<String>? speechDictionary,
    List<ChecklistCorrectionExample>? correctionExamples,

    /// Default inference profile ID for new tasks in this category.
    /// Enables speech-to-text and image analysis immediately on task creation.
    String? defaultProfileId,

    /// Opt-in switch for running inference automatically in this category —
    /// auto-transcription of new audio and auto-analysis of new images.
    /// Selecting a profile alone is NOT consent: profiles ship with automated
    /// skill assignments, so without this flag choosing one would silently
    /// start spending tokens. Nullable for JSON backward compatibility, and an
    /// absent key ⇒ `null` ⇒ **off**, including for categories that already
    /// had a profile before this flag existed.
    bool? automaticInferenceEnabled,

    /// Default agent template ID for new tasks in this category.
    /// An agent is auto-created from this template when a task is created.
    String? defaultTemplateId,

    /// Seed value for `AgentConfig.automaticUpdatesEnabled` on task agents
    /// created in this category — whether their agent wakes automatically
    /// when the task changes, rather than only when asked.
    ///
    /// This is a starting value, not a live gate: the per-task switch on the
    /// AI summary card stays authoritative afterwards, so turning this on
    /// later does not reach back into tasks that already exist. Independent
    /// of `automaticInferenceEnabled` — switching wakes off leaves automatic
    /// transcription and image analysis running.
    ///
    /// Nullable for JSON backward compatibility (absent key ⇒ `null` ⇒ off),
    /// which is the value `createTaskAgent` hardcoded before this existed.
    bool? automaticAgentWakesEnabled,

    /// Default event-agent template ID for new events in this category.
    /// An event agent is auto-created from this template when an event is
    /// created. Independent of `defaultTemplateId` so enabling task agents
    /// does not implicitly spawn event agents. Nullable for JSON backward
    /// compatibility (absent key ⇒ `null` ⇒ no event agent).
    String? defaultEventTemplateId,

    /// Opt-in switch making this category available for day planning.
    /// Categories are NOT available by default — only categories with this
    /// flag set to `true` are offered for selection in the day plan.
    /// Nullable for JSON backward compatibility with already-synced
    /// categories (absent key ⇒ `null` ⇒ not available).
    bool? isAvailableForDayPlan,
  }) = CategoryDefinition;

  const factory EntityDefinition.labelDefinition({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String color,
    required VectorClock? vectorClock,
    String? description,
    int? sortOrder,
    List<String>? applicableCategoryIds,
    DateTime? deletedAt,
    bool? private,
  }) = LabelDefinition;

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
    @Deprecated('Tags concept removed — kept for JSON backward compatibility')
    String? defaultStoryId,
    String? categoryId,
    String? dashboardId,
    bool? priority,

    /// Whether an auto-completion derived from [autoCompleteRule] raises a
    /// notification. Defaults to true so habits created before the field
    /// existed keep the documented behaviour.
    @Default(true) bool autoCompleteNotify,
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

extension CategoryAutomation on CategoryDefinition {
  /// Automatic inference is opt-in, so an unset preference is off. Categories
  /// that predate the switch — including ones with an inference profile
  /// already selected — never run inference on their own until the user turns
  /// this on.
  bool get automaticInferenceEnabledEffective =>
      automaticInferenceEnabled ?? false;

  /// Automatic agent wakes are opt-in too, so an unset preference is off —
  /// the value `TaskAgentService.createTaskAgent` hardcoded before the
  /// category could express a preference, so upgrading changes nothing.
  bool get automaticAgentWakesEnabledEffective =>
      automaticAgentWakesEnabled ?? false;
}

@freezed
abstract class MeasurementData with _$MeasurementData {
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
abstract class AiResponseData with _$AiResponseData {
  const factory AiResponseData({
    required String model,
    required String systemMessage,
    required String prompt,
    required String thoughts,
    required String response,
    String? promptId,
    // ID of the [AiConfigSkill] that produced this response, when the
    // response was generated through the skill path (rather than the legacy
    // prompt path). Lets the UI distinguish between sibling skills that share
    // the same [AiResponseType] (e.g. coding-prompt, design-prompt, and
    // research-prompt all use [AiResponseType.promptGeneration]).
    String? skillId,
    List<AiActionItem>? suggestedActionItems,
    AiResponseType? type,

    /// Single-sentence summary of [response], for surfaces that have room for
    /// one line — the collapsed audio card is the first.
    ///
    /// Written from a pinned tool call's typed arguments, never parsed out of
    /// [response]. Null for every response type that does not publish tiers
    /// and for entries synced from a client that predates them, so readers
    /// need their own fallback rather than treating it as guaranteed.
    String? oneLiner,

    /// One-to-three-sentence summary of [response], shown where a card is
    /// collapsed but not reduced to a single line. Same provenance and same
    /// nullability caveat as [oneLiner].
    String? tldr,
    double? temperature,
    // Usage statistics (nullable for backward compatibility)
    int? inputTokens,
    int? outputTokens,
    int? thoughtsTokens,
    int? cachedInputTokens,
    // Processing duration in milliseconds
    int? durationMs,
    AiWorkAttribution? aiAttribution,
  }) = _AiResponseData;

  factory AiResponseData.fromJson(Map<String, dynamic> json) =>
      _$AiResponseDataFromJson(json);
}

@freezed
abstract class WorkoutData with _$WorkoutData {
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
abstract class HabitCompletionData with _$HabitCompletionData {
  const factory HabitCompletionData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String habitId,
    HabitCompletionType? completionType,

    /// Who produced this completion. Manual entries always outrank auto ones
    /// for the same day; missing in entries written before the field existed.
    @Default(HabitCompletionSource.manual)
    @JsonKey(unknownEnumValue: HabitCompletionSource.manual)
    HabitCompletionSource source,

    /// For [HabitCompletionSource.auto]: which rule leaf fired, e.g. the
    /// measurable name and value, as shown on the habit row.
    String? autoCompleteReason,
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
sealed class DashboardItem with _$DashboardItem {
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

  factory DashboardItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardItemFromJson(json);
}
