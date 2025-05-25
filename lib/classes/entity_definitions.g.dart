// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entity_definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DailyHabitScheduleImpl _$$DailyHabitScheduleImplFromJson(
        Map<String, dynamic> json) =>
    _$DailyHabitScheduleImpl(
      requiredCompletions: (json['requiredCompletions'] as num).toInt(),
      showFrom: json['showFrom'] == null
          ? null
          : DateTime.parse(json['showFrom'] as String),
      alertAtTime: json['alertAtTime'] == null
          ? null
          : DateTime.parse(json['alertAtTime'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DailyHabitScheduleImplToJson(
        _$DailyHabitScheduleImpl instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'showFrom': instance.showFrom?.toIso8601String(),
      'alertAtTime': instance.alertAtTime?.toIso8601String(),
      'runtimeType': instance.$type,
    };

_$WeeklyHabitScheduleImpl _$$WeeklyHabitScheduleImplFromJson(
        Map<String, dynamic> json) =>
    _$WeeklyHabitScheduleImpl(
      requiredCompletions: (json['requiredCompletions'] as num).toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$WeeklyHabitScheduleImplToJson(
        _$WeeklyHabitScheduleImpl instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'runtimeType': instance.$type,
    };

_$MonthlyHabitScheduleImpl _$$MonthlyHabitScheduleImplFromJson(
        Map<String, dynamic> json) =>
    _$MonthlyHabitScheduleImpl(
      requiredCompletions: (json['requiredCompletions'] as num).toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$MonthlyHabitScheduleImplToJson(
        _$MonthlyHabitScheduleImpl instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleHealthImpl _$$AutoCompleteRuleHealthImplFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleHealthImpl(
      dataType: json['dataType'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleHealthImplToJson(
        _$AutoCompleteRuleHealthImpl instance) =>
    <String, dynamic>{
      'dataType': instance.dataType,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleWorkoutImpl _$$AutoCompleteRuleWorkoutImplFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleWorkoutImpl(
      dataType: json['dataType'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleWorkoutImplToJson(
        _$AutoCompleteRuleWorkoutImpl instance) =>
    <String, dynamic>{
      'dataType': instance.dataType,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleMeasurableImpl _$$AutoCompleteRuleMeasurableImplFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleMeasurableImpl(
      dataTypeId: json['dataTypeId'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleMeasurableImplToJson(
        _$AutoCompleteRuleMeasurableImpl instance) =>
    <String, dynamic>{
      'dataTypeId': instance.dataTypeId,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleHabitImpl _$$AutoCompleteRuleHabitImplFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleHabitImpl(
      habitId: json['habitId'] as String,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleHabitImplToJson(
        _$AutoCompleteRuleHabitImpl instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleAndImpl _$$AutoCompleteRuleAndImplFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleAndImpl(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleAndImplToJson(
        _$AutoCompleteRuleAndImpl instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleOrImpl _$$AutoCompleteRuleOrImplFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleOrImpl(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleOrImplToJson(
        _$AutoCompleteRuleOrImpl instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleMultipleImpl _$$AutoCompleteRuleMultipleImplFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleMultipleImpl(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      successes: (json['successes'] as num).toInt(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleMultipleImplToJson(
        _$AutoCompleteRuleMultipleImpl instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'successes': instance.successes,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$MeasurableDataTypeImpl _$$MeasurableDataTypeImplFromJson(
        Map<String, dynamic> json) =>
    _$MeasurableDataTypeImpl(
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

Map<String, dynamic> _$$MeasurableDataTypeImplToJson(
        _$MeasurableDataTypeImpl instance) =>
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

_$CategoryDefinitionImpl _$$CategoryDefinitionImplFromJson(
        Map<String, dynamic> json) =>
    _$CategoryDefinitionImpl(
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
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CategoryDefinitionImplToJson(
        _$CategoryDefinitionImpl instance) =>
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
      'runtimeType': instance.$type,
    };

_$HabitDefinitionImpl _$$HabitDefinitionImplFromJson(
        Map<String, dynamic> json) =>
    _$HabitDefinitionImpl(
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

Map<String, dynamic> _$$HabitDefinitionImplToJson(
        _$HabitDefinitionImpl instance) =>
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

_$DashboardDefinitionImpl _$$DashboardDefinitionImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardDefinitionImpl(
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

Map<String, dynamic> _$$DashboardDefinitionImplToJson(
        _$DashboardDefinitionImpl instance) =>
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

_$MeasurementDataImpl _$$MeasurementDataImplFromJson(
        Map<String, dynamic> json) =>
    _$MeasurementDataImpl(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      value: json['value'] as num,
      dataTypeId: json['dataTypeId'] as String,
    );

Map<String, dynamic> _$$MeasurementDataImplToJson(
        _$MeasurementDataImpl instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'value': instance.value,
      'dataTypeId': instance.dataTypeId,
    };

_$AiResponseDataImpl _$$AiResponseDataImplFromJson(Map<String, dynamic> json) =>
    _$AiResponseDataImpl(
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

Map<String, dynamic> _$$AiResponseDataImplToJson(
        _$AiResponseDataImpl instance) =>
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

const _$AiResponseTypeEnumMap = {
  AiResponseType.actionItemSuggestions: 'ActionItemSuggestions',
  AiResponseType.taskSummary: 'TaskSummary',
  AiResponseType.imageAnalysis: 'ImageAnalysis',
  AiResponseType.audioTranscription: 'AudioTranscription',
};

_$WorkoutDataImpl _$$WorkoutDataImplFromJson(Map<String, dynamic> json) =>
    _$WorkoutDataImpl(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      id: json['id'] as String,
      workoutType: json['workoutType'] as String,
      energy: json['energy'] as num?,
      distance: json['distance'] as num?,
      source: json['source'] as String?,
    );

Map<String, dynamic> _$$WorkoutDataImplToJson(_$WorkoutDataImpl instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'id': instance.id,
      'workoutType': instance.workoutType,
      'energy': instance.energy,
      'distance': instance.distance,
      'source': instance.source,
    };

_$HabitCompletionDataImpl _$$HabitCompletionDataImplFromJson(
        Map<String, dynamic> json) =>
    _$HabitCompletionDataImpl(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      habitId: json['habitId'] as String,
      completionType: $enumDecodeNullable(
          _$HabitCompletionTypeEnumMap, json['completionType']),
    );

Map<String, dynamic> _$$HabitCompletionDataImplToJson(
        _$HabitCompletionDataImpl instance) =>
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

_$DashboardMeasurementItemImpl _$$DashboardMeasurementItemImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardMeasurementItemImpl(
      id: json['id'] as String,
      aggregationType: $enumDecodeNullable(
          _$AggregationTypeEnumMap, json['aggregationType']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardMeasurementItemImplToJson(
        _$DashboardMeasurementItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'aggregationType': _$AggregationTypeEnumMap[instance.aggregationType],
      'runtimeType': instance.$type,
    };

_$DashboardHealthItemImpl _$$DashboardHealthItemImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardHealthItemImpl(
      color: json['color'] as String,
      healthType: json['healthType'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardHealthItemImplToJson(
        _$DashboardHealthItemImpl instance) =>
    <String, dynamic>{
      'color': instance.color,
      'healthType': instance.healthType,
      'runtimeType': instance.$type,
    };

_$DashboardWorkoutItemImpl _$$DashboardWorkoutItemImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardWorkoutItemImpl(
      workoutType: json['workoutType'] as String,
      displayName: json['displayName'] as String,
      color: json['color'] as String,
      valueType: $enumDecode(_$WorkoutValueTypeEnumMap, json['valueType']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardWorkoutItemImplToJson(
        _$DashboardWorkoutItemImpl instance) =>
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

_$DashboardHabitItemImpl _$$DashboardHabitItemImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardHabitItemImpl(
      habitId: json['habitId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardHabitItemImplToJson(
        _$DashboardHabitItemImpl instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'runtimeType': instance.$type,
    };

_$DashboardSurveyItemImpl _$$DashboardSurveyItemImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardSurveyItemImpl(
      colorsByScoreKey:
          Map<String, String>.from(json['colorsByScoreKey'] as Map),
      surveyType: json['surveyType'] as String,
      surveyName: json['surveyName'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardSurveyItemImplToJson(
        _$DashboardSurveyItemImpl instance) =>
    <String, dynamic>{
      'colorsByScoreKey': instance.colorsByScoreKey,
      'surveyType': instance.surveyType,
      'surveyName': instance.surveyName,
      'runtimeType': instance.$type,
    };

_$DashboardStoryTimeItemImpl _$$DashboardStoryTimeItemImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardStoryTimeItemImpl(
      storyTagId: json['storyTagId'] as String,
      color: json['color'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardStoryTimeItemImplToJson(
        _$DashboardStoryTimeItemImpl instance) =>
    <String, dynamic>{
      'storyTagId': instance.storyTagId,
      'color': instance.color,
      'runtimeType': instance.$type,
    };

_$WildcardStoryTimeItemImpl _$$WildcardStoryTimeItemImplFromJson(
        Map<String, dynamic> json) =>
    _$WildcardStoryTimeItemImpl(
      storySubstring: json['storySubstring'] as String,
      color: json['color'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$WildcardStoryTimeItemImplToJson(
        _$WildcardStoryTimeItemImpl instance) =>
    <String, dynamic>{
      'storySubstring': instance.storySubstring,
      'color': instance.color,
      'runtimeType': instance.$type,
    };
