// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entity_definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChecklistCorrectionExample _$ChecklistCorrectionExampleFromJson(
        Map<String, dynamic> json) =>
    _ChecklistCorrectionExample(
      before: json['before'] as String,
      after: json['after'] as String,
      capturedAt: json['capturedAt'] == null
          ? null
          : DateTime.parse(json['capturedAt'] as String),
    );

Map<String, dynamic> _$ChecklistCorrectionExampleToJson(
        _ChecklistCorrectionExample instance) =>
    <String, dynamic>{
      'before': instance.before,
      'after': instance.after,
      'capturedAt': instance.capturedAt?.toIso8601String(),
    };

DailyHabitSchedule _$DailyHabitScheduleFromJson(Map<String, dynamic> json) =>
    DailyHabitSchedule(
      requiredCompletions: (json['requiredCompletions'] as num).toInt(),
      showFrom: json['showFrom'] == null
          ? null
          : DateTime.parse(json['showFrom'] as String),
      alertAtTime: json['alertAtTime'] == null
          ? null
          : DateTime.parse(json['alertAtTime'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DailyHabitScheduleToJson(DailyHabitSchedule instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'showFrom': instance.showFrom?.toIso8601String(),
      'alertAtTime': instance.alertAtTime?.toIso8601String(),
      'runtimeType': instance.$type,
    };

WeeklyHabitSchedule _$WeeklyHabitScheduleFromJson(Map<String, dynamic> json) =>
    WeeklyHabitSchedule(
      requiredCompletions: (json['requiredCompletions'] as num).toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$WeeklyHabitScheduleToJson(
        WeeklyHabitSchedule instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'runtimeType': instance.$type,
    };

MonthlyHabitSchedule _$MonthlyHabitScheduleFromJson(
        Map<String, dynamic> json) =>
    MonthlyHabitSchedule(
      requiredCompletions: (json['requiredCompletions'] as num).toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$MonthlyHabitScheduleToJson(
        MonthlyHabitSchedule instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'runtimeType': instance.$type,
    };

AutoCompleteRuleHealth _$AutoCompleteRuleHealthFromJson(
        Map<String, dynamic> json) =>
    AutoCompleteRuleHealth(
      dataType: json['dataType'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AutoCompleteRuleHealthToJson(
        AutoCompleteRuleHealth instance) =>
    <String, dynamic>{
      'dataType': instance.dataType,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

AutoCompleteRuleWorkout _$AutoCompleteRuleWorkoutFromJson(
        Map<String, dynamic> json) =>
    AutoCompleteRuleWorkout(
      dataType: json['dataType'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AutoCompleteRuleWorkoutToJson(
        AutoCompleteRuleWorkout instance) =>
    <String, dynamic>{
      'dataType': instance.dataType,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

AutoCompleteRuleMeasurable _$AutoCompleteRuleMeasurableFromJson(
        Map<String, dynamic> json) =>
    AutoCompleteRuleMeasurable(
      dataTypeId: json['dataTypeId'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AutoCompleteRuleMeasurableToJson(
        AutoCompleteRuleMeasurable instance) =>
    <String, dynamic>{
      'dataTypeId': instance.dataTypeId,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

AutoCompleteRuleHabit _$AutoCompleteRuleHabitFromJson(
        Map<String, dynamic> json) =>
    AutoCompleteRuleHabit(
      habitId: json['habitId'] as String,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AutoCompleteRuleHabitToJson(
        AutoCompleteRuleHabit instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

AutoCompleteRuleAnd _$AutoCompleteRuleAndFromJson(Map<String, dynamic> json) =>
    AutoCompleteRuleAnd(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AutoCompleteRuleAndToJson(
        AutoCompleteRuleAnd instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

AutoCompleteRuleOr _$AutoCompleteRuleOrFromJson(Map<String, dynamic> json) =>
    AutoCompleteRuleOr(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AutoCompleteRuleOrToJson(AutoCompleteRuleOr instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

AutoCompleteRuleMultiple _$AutoCompleteRuleMultipleFromJson(
        Map<String, dynamic> json) =>
    AutoCompleteRuleMultiple(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      successes: (json['successes'] as num).toInt(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AutoCompleteRuleMultipleToJson(
        AutoCompleteRuleMultiple instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'successes': instance.successes,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

MeasurableDataType _$MeasurableDataTypeFromJson(Map<String, dynamic> json) =>
    MeasurableDataType(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      displayName: json['displayName'] as String,
      description: json['description'] as String,
      unitName: json['unitName'] as String,
      version: (json['version'] as num).toInt(),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      private: json['private'] as bool?,
      favorite: json['favorite'] as bool?,
      categoryId: json['categoryId'] as String?,
      aggregationType: $enumDecodeNullable(
          _$AggregationTypeEnumMap, json['aggregationType']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$MeasurableDataTypeToJson(MeasurableDataType instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'displayName': instance.displayName,
      'description': instance.description,
      'unitName': instance.unitName,
      'version': instance.version,
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'private': instance.private,
      'favorite': instance.favorite,
      'categoryId': instance.categoryId,
      'aggregationType': _$AggregationTypeEnumMap[instance.aggregationType],
      'runtimeType': instance.$type,
    };

const _$AggregationTypeEnumMap = {
  AggregationType.none: 'none',
  AggregationType.dailySum: 'dailySum',
  AggregationType.dailyMax: 'dailyMax',
  AggregationType.dailyAvg: 'dailyAvg',
  AggregationType.hourlySum: 'hourlySum',
};

CategoryDefinition _$CategoryDefinitionFromJson(Map<String, dynamic> json) =>
    CategoryDefinition(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      name: json['name'] as String,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      private: json['private'] as bool,
      active: json['active'] as bool,
      favorite: json['favorite'] as bool?,
      color: json['color'] as String?,
      categoryId: json['categoryId'] as String?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      defaultLanguageCode: json['defaultLanguageCode'] as String?,
      allowedPromptIds: (json['allowedPromptIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      automaticPrompts:
          (json['automaticPrompts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry($enumDecode(_$AiResponseTypeEnumMap, k),
            (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      icon: const CategoryIconConverter().fromJson(json['icon'] as String?),
      speechDictionary: (json['speechDictionary'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      correctionExamples: (json['correctionExamples'] as List<dynamic>?)
          ?.map((e) =>
              ChecklistCorrectionExample.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$CategoryDefinitionToJson(CategoryDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'name': instance.name,
      'vectorClock': instance.vectorClock,
      'private': instance.private,
      'active': instance.active,
      'favorite': instance.favorite,
      'color': instance.color,
      'categoryId': instance.categoryId,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'defaultLanguageCode': instance.defaultLanguageCode,
      'allowedPromptIds': instance.allowedPromptIds,
      'automaticPrompts': instance.automaticPrompts
          ?.map((k, e) => MapEntry(_$AiResponseTypeEnumMap[k]!, e)),
      'icon': const CategoryIconConverter().toJson(instance.icon),
      'speechDictionary': instance.speechDictionary,
      'correctionExamples': instance.correctionExamples,
      'runtimeType': instance.$type,
    };

const _$AiResponseTypeEnumMap = {
  AiResponseType.actionItemSuggestions: 'ActionItemSuggestions',
  AiResponseType.taskSummary: 'TaskSummary',
  AiResponseType.imageAnalysis: 'ImageAnalysis',
  AiResponseType.audioTranscription: 'AudioTranscription',
  AiResponseType.checklistUpdates: 'ChecklistUpdates',
  AiResponseType.promptGeneration: 'PromptGeneration',
};

LabelDefinition _$LabelDefinitionFromJson(Map<String, dynamic> json) =>
    LabelDefinition(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      name: json['name'] as String,
      color: json['color'] as String,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      description: json['description'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      applicableCategoryIds: (json['applicableCategoryIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      private: json['private'] as bool?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$LabelDefinitionToJson(LabelDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'name': instance.name,
      'color': instance.color,
      'vectorClock': instance.vectorClock,
      'description': instance.description,
      'sortOrder': instance.sortOrder,
      'applicableCategoryIds': instance.applicableCategoryIds,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'private': instance.private,
      'runtimeType': instance.$type,
    };

HabitDefinition _$HabitDefinitionFromJson(Map<String, dynamic> json) =>
    HabitDefinition(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      name: json['name'] as String,
      description: json['description'] as String,
      habitSchedule:
          HabitSchedule.fromJson(json['habitSchedule'] as Map<String, dynamic>),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      active: json['active'] as bool,
      private: json['private'] as bool,
      autoCompleteRule: json['autoCompleteRule'] == null
          ? null
          : AutoCompleteRule.fromJson(
              json['autoCompleteRule'] as Map<String, dynamic>),
      version: json['version'] as String?,
      activeFrom: json['activeFrom'] == null
          ? null
          : DateTime.parse(json['activeFrom'] as String),
      activeUntil: json['activeUntil'] == null
          ? null
          : DateTime.parse(json['activeUntil'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      defaultStoryId: json['defaultStoryId'] as String?,
      categoryId: json['categoryId'] as String?,
      dashboardId: json['dashboardId'] as String?,
      priority: json['priority'] as bool?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$HabitDefinitionToJson(HabitDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'name': instance.name,
      'description': instance.description,
      'habitSchedule': instance.habitSchedule,
      'vectorClock': instance.vectorClock,
      'active': instance.active,
      'private': instance.private,
      'autoCompleteRule': instance.autoCompleteRule,
      'version': instance.version,
      'activeFrom': instance.activeFrom?.toIso8601String(),
      'activeUntil': instance.activeUntil?.toIso8601String(),
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'defaultStoryId': instance.defaultStoryId,
      'categoryId': instance.categoryId,
      'dashboardId': instance.dashboardId,
      'priority': instance.priority,
      'runtimeType': instance.$type,
    };

DashboardDefinition _$DashboardDefinitionFromJson(Map<String, dynamic> json) =>
    DashboardDefinition(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastReviewed: DateTime.parse(json['lastReviewed'] as String),
      name: json['name'] as String,
      description: json['description'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => DashboardItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] as String,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      active: json['active'] as bool,
      private: json['private'] as bool,
      reviewAt: json['reviewAt'] == null
          ? null
          : DateTime.parse(json['reviewAt'] as String),
      days: (json['days'] as num?)?.toInt() ?? 30,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      categoryId: json['categoryId'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashboardDefinitionToJson(
        DashboardDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'lastReviewed': instance.lastReviewed.toIso8601String(),
      'name': instance.name,
      'description': instance.description,
      'items': instance.items,
      'version': instance.version,
      'vectorClock': instance.vectorClock,
      'active': instance.active,
      'private': instance.private,
      'reviewAt': instance.reviewAt?.toIso8601String(),
      'days': instance.days,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'categoryId': instance.categoryId,
      'runtimeType': instance.$type,
    };

_MeasurementData _$MeasurementDataFromJson(Map<String, dynamic> json) =>
    _MeasurementData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      value: json['value'] as num,
      dataTypeId: json['dataTypeId'] as String,
    );

Map<String, dynamic> _$MeasurementDataToJson(_MeasurementData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'value': instance.value,
      'dataTypeId': instance.dataTypeId,
    };

_AiResponseData _$AiResponseDataFromJson(Map<String, dynamic> json) =>
    _AiResponseData(
      model: json['model'] as String,
      systemMessage: json['systemMessage'] as String,
      prompt: json['prompt'] as String,
      thoughts: json['thoughts'] as String,
      response: json['response'] as String,
      promptId: json['promptId'] as String?,
      suggestedActionItems: (json['suggestedActionItems'] as List<dynamic>?)
          ?.map((e) => AiActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      type: $enumDecodeNullable(_$AiResponseTypeEnumMap, json['type']),
      temperature: (json['temperature'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$AiResponseDataToJson(_AiResponseData instance) =>
    <String, dynamic>{
      'model': instance.model,
      'systemMessage': instance.systemMessage,
      'prompt': instance.prompt,
      'thoughts': instance.thoughts,
      'response': instance.response,
      'promptId': instance.promptId,
      'suggestedActionItems': instance.suggestedActionItems,
      'type': _$AiResponseTypeEnumMap[instance.type],
      'temperature': instance.temperature,
    };

_WorkoutData _$WorkoutDataFromJson(Map<String, dynamic> json) => _WorkoutData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      id: json['id'] as String,
      workoutType: json['workoutType'] as String,
      energy: json['energy'] as num?,
      distance: json['distance'] as num?,
      source: json['source'] as String?,
    );

Map<String, dynamic> _$WorkoutDataToJson(_WorkoutData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'id': instance.id,
      'workoutType': instance.workoutType,
      'energy': instance.energy,
      'distance': instance.distance,
      'source': instance.source,
    };

_HabitCompletionData _$HabitCompletionDataFromJson(Map<String, dynamic> json) =>
    _HabitCompletionData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      habitId: json['habitId'] as String,
      completionType: $enumDecodeNullable(
          _$HabitCompletionTypeEnumMap, json['completionType']),
    );

Map<String, dynamic> _$HabitCompletionDataToJson(
        _HabitCompletionData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'habitId': instance.habitId,
      'completionType': _$HabitCompletionTypeEnumMap[instance.completionType],
    };

const _$HabitCompletionTypeEnumMap = {
  HabitCompletionType.success: 'success',
  HabitCompletionType.skip: 'skip',
  HabitCompletionType.fail: 'fail',
  HabitCompletionType.open: 'open',
};

DashboardMeasurementItem _$DashboardMeasurementItemFromJson(
        Map<String, dynamic> json) =>
    DashboardMeasurementItem(
      id: json['id'] as String,
      aggregationType: $enumDecodeNullable(
          _$AggregationTypeEnumMap, json['aggregationType']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashboardMeasurementItemToJson(
        DashboardMeasurementItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'aggregationType': _$AggregationTypeEnumMap[instance.aggregationType],
      'runtimeType': instance.$type,
    };

DashboardHealthItem _$DashboardHealthItemFromJson(Map<String, dynamic> json) =>
    DashboardHealthItem(
      color: json['color'] as String,
      healthType: json['healthType'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashboardHealthItemToJson(
        DashboardHealthItem instance) =>
    <String, dynamic>{
      'color': instance.color,
      'healthType': instance.healthType,
      'runtimeType': instance.$type,
    };

DashboardWorkoutItem _$DashboardWorkoutItemFromJson(
        Map<String, dynamic> json) =>
    DashboardWorkoutItem(
      workoutType: json['workoutType'] as String,
      displayName: json['displayName'] as String,
      color: json['color'] as String,
      valueType: $enumDecode(_$WorkoutValueTypeEnumMap, json['valueType']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashboardWorkoutItemToJson(
        DashboardWorkoutItem instance) =>
    <String, dynamic>{
      'workoutType': instance.workoutType,
      'displayName': instance.displayName,
      'color': instance.color,
      'valueType': _$WorkoutValueTypeEnumMap[instance.valueType]!,
      'runtimeType': instance.$type,
    };

const _$WorkoutValueTypeEnumMap = {
  WorkoutValueType.duration: 'duration',
  WorkoutValueType.distance: 'distance',
  WorkoutValueType.energy: 'energy',
};

DashboardHabitItem _$DashboardHabitItemFromJson(Map<String, dynamic> json) =>
    DashboardHabitItem(
      habitId: json['habitId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashboardHabitItemToJson(DashboardHabitItem instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'runtimeType': instance.$type,
    };

DashboardSurveyItem _$DashboardSurveyItemFromJson(Map<String, dynamic> json) =>
    DashboardSurveyItem(
      colorsByScoreKey:
          Map<String, String>.from(json['colorsByScoreKey'] as Map),
      surveyType: json['surveyType'] as String,
      surveyName: json['surveyName'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashboardSurveyItemToJson(
        DashboardSurveyItem instance) =>
    <String, dynamic>{
      'colorsByScoreKey': instance.colorsByScoreKey,
      'surveyType': instance.surveyType,
      'surveyName': instance.surveyName,
      'runtimeType': instance.$type,
    };

DashboardStoryTimeItem _$DashboardStoryTimeItemFromJson(
        Map<String, dynamic> json) =>
    DashboardStoryTimeItem(
      storyTagId: json['storyTagId'] as String,
      color: json['color'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashboardStoryTimeItemToJson(
        DashboardStoryTimeItem instance) =>
    <String, dynamic>{
      'storyTagId': instance.storyTagId,
      'color': instance.color,
      'runtimeType': instance.$type,
    };

WildcardStoryTimeItem _$WildcardStoryTimeItemFromJson(
        Map<String, dynamic> json) =>
    WildcardStoryTimeItem(
      storySubstring: json['storySubstring'] as String,
      color: json['color'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$WildcardStoryTimeItemToJson(
        WildcardStoryTimeItem instance) =>
    <String, dynamic>{
      'storySubstring': instance.storySubstring,
      'color': instance.color,
      'runtimeType': instance.$type,
    };
