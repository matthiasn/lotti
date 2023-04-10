// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entity_definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DailyHabitSchedule _$$DailyHabitScheduleFromJson(Map<String, dynamic> json) =>
    _$DailyHabitSchedule(
      requiredCompletions: json['requiredCompletions'] as int,
      showFrom: json['showFrom'] == null
          ? null
          : DateTime.parse(json['showFrom'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DailyHabitScheduleToJson(
        _$DailyHabitSchedule instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'showFrom': instance.showFrom?.toIso8601String(),
      'runtimeType': instance.$type,
    };

_$WeeklyHabitSchedule _$$WeeklyHabitScheduleFromJson(
        Map<String, dynamic> json) =>
    _$WeeklyHabitSchedule(
      requiredCompletions: json['requiredCompletions'] as int,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$WeeklyHabitScheduleToJson(
        _$WeeklyHabitSchedule instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'runtimeType': instance.$type,
    };

_$MonthlyHabitSchedule _$$MonthlyHabitScheduleFromJson(
        Map<String, dynamic> json) =>
    _$MonthlyHabitSchedule(
      requiredCompletions: json['requiredCompletions'] as int,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$MonthlyHabitScheduleToJson(
        _$MonthlyHabitSchedule instance) =>
    <String, dynamic>{
      'requiredCompletions': instance.requiredCompletions,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleHealth _$$AutoCompleteRuleHealthFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleHealth(
      dataType: json['dataType'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleHealthToJson(
        _$AutoCompleteRuleHealth instance) =>
    <String, dynamic>{
      'dataType': instance.dataType,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleWorkout _$$AutoCompleteRuleWorkoutFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleWorkout(
      dataType: json['dataType'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleWorkoutToJson(
        _$AutoCompleteRuleWorkout instance) =>
    <String, dynamic>{
      'dataType': instance.dataType,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleMeasurable _$$AutoCompleteRuleMeasurableFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleMeasurable(
      dataTypeId: json['dataTypeId'] as String,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleMeasurableToJson(
        _$AutoCompleteRuleMeasurable instance) =>
    <String, dynamic>{
      'dataTypeId': instance.dataTypeId,
      'minimum': instance.minimum,
      'maximum': instance.maximum,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleHabit _$$AutoCompleteRuleHabitFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleHabit(
      habitId: json['habitId'] as String,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleHabitToJson(
        _$AutoCompleteRuleHabit instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleAnd _$$AutoCompleteRuleAndFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleAnd(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleAndToJson(
        _$AutoCompleteRuleAnd instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleOr _$$AutoCompleteRuleOrFromJson(Map<String, dynamic> json) =>
    _$AutoCompleteRuleOr(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleOrToJson(
        _$AutoCompleteRuleOr instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$AutoCompleteRuleMultiple _$$AutoCompleteRuleMultipleFromJson(
        Map<String, dynamic> json) =>
    _$AutoCompleteRuleMultiple(
      rules: (json['rules'] as List<dynamic>)
          .map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      successes: json['successes'] as int,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AutoCompleteRuleMultipleToJson(
        _$AutoCompleteRuleMultiple instance) =>
    <String, dynamic>{
      'rules': instance.rules,
      'successes': instance.successes,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

_$MeasurableDataType _$$MeasurableDataTypeFromJson(Map<String, dynamic> json) =>
    _$MeasurableDataType(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      displayName: json['displayName'] as String,
      description: json['description'] as String,
      unitName: json['unitName'] as String,
      version: json['version'] as int,
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

Map<String, dynamic> _$$MeasurableDataTypeToJson(
        _$MeasurableDataType instance) =>
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

_$CategoryDefinition _$$CategoryDefinitionFromJson(Map<String, dynamic> json) =>
    _$CategoryDefinition(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      name: json['name'] as String,
      color: json['color'] as String,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      private: json['private'] as bool,
      active: json['active'] as bool,
      categoryId: json['categoryId'] as String?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CategoryDefinitionToJson(
        _$CategoryDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'name': instance.name,
      'color': instance.color,
      'vectorClock': instance.vectorClock,
      'private': instance.private,
      'active': instance.active,
      'categoryId': instance.categoryId,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

_$HabitDefinition _$$HabitDefinitionFromJson(Map<String, dynamic> json) =>
    _$HabitDefinition(
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

Map<String, dynamic> _$$HabitDefinitionToJson(_$HabitDefinition instance) =>
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

_$DashboardDefinition _$$DashboardDefinitionFromJson(
        Map<String, dynamic> json) =>
    _$DashboardDefinition(
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
      days: json['days'] as int? ?? 30,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      categoryId: json['categoryId'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardDefinitionToJson(
        _$DashboardDefinition instance) =>
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

_$_MeasurementData _$$_MeasurementDataFromJson(Map<String, dynamic> json) =>
    _$_MeasurementData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      value: json['value'] as num,
      dataTypeId: json['dataTypeId'] as String,
    );

Map<String, dynamic> _$$_MeasurementDataToJson(_$_MeasurementData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'value': instance.value,
      'dataTypeId': instance.dataTypeId,
    };

_$_WorkoutData _$$_WorkoutDataFromJson(Map<String, dynamic> json) =>
    _$_WorkoutData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      id: json['id'] as String,
      workoutType: json['workoutType'] as String,
      energy: json['energy'] as num?,
      distance: json['distance'] as num?,
      source: json['source'] as String?,
    );

Map<String, dynamic> _$$_WorkoutDataToJson(_$_WorkoutData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'id': instance.id,
      'workoutType': instance.workoutType,
      'energy': instance.energy,
      'distance': instance.distance,
      'source': instance.source,
    };

_$_HabitCompletionData _$$_HabitCompletionDataFromJson(
        Map<String, dynamic> json) =>
    _$_HabitCompletionData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      habitId: json['habitId'] as String,
      completionType: $enumDecodeNullable(
          _$HabitCompletionTypeEnumMap, json['completionType']),
    );

Map<String, dynamic> _$$_HabitCompletionDataToJson(
        _$_HabitCompletionData instance) =>
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

_$DashboardMeasurementItem _$$DashboardMeasurementItemFromJson(
        Map<String, dynamic> json) =>
    _$DashboardMeasurementItem(
      id: json['id'] as String,
      aggregationType: $enumDecodeNullable(
          _$AggregationTypeEnumMap, json['aggregationType']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardMeasurementItemToJson(
        _$DashboardMeasurementItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'aggregationType': _$AggregationTypeEnumMap[instance.aggregationType],
      'runtimeType': instance.$type,
    };

_$DashboardHealthItem _$$DashboardHealthItemFromJson(
        Map<String, dynamic> json) =>
    _$DashboardHealthItem(
      color: json['color'] as String,
      healthType: json['healthType'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardHealthItemToJson(
        _$DashboardHealthItem instance) =>
    <String, dynamic>{
      'color': instance.color,
      'healthType': instance.healthType,
      'runtimeType': instance.$type,
    };

_$DashboardWorkoutItem _$$DashboardWorkoutItemFromJson(
        Map<String, dynamic> json) =>
    _$DashboardWorkoutItem(
      workoutType: json['workoutType'] as String,
      displayName: json['displayName'] as String,
      color: json['color'] as String,
      valueType: $enumDecode(_$WorkoutValueTypeEnumMap, json['valueType']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardWorkoutItemToJson(
        _$DashboardWorkoutItem instance) =>
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

_$DashboardHabitItem _$$DashboardHabitItemFromJson(Map<String, dynamic> json) =>
    _$DashboardHabitItem(
      habitId: json['habitId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardHabitItemToJson(
        _$DashboardHabitItem instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'runtimeType': instance.$type,
    };

_$DashboardSurveyItem _$$DashboardSurveyItemFromJson(
        Map<String, dynamic> json) =>
    _$DashboardSurveyItem(
      colorsByScoreKey:
          Map<String, String>.from(json['colorsByScoreKey'] as Map),
      surveyType: json['surveyType'] as String,
      surveyName: json['surveyName'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardSurveyItemToJson(
        _$DashboardSurveyItem instance) =>
    <String, dynamic>{
      'colorsByScoreKey': instance.colorsByScoreKey,
      'surveyType': instance.surveyType,
      'surveyName': instance.surveyName,
      'runtimeType': instance.$type,
    };

_$DashboardStoryTimeItem _$$DashboardStoryTimeItemFromJson(
        Map<String, dynamic> json) =>
    _$DashboardStoryTimeItem(
      storyTagId: json['storyTagId'] as String,
      color: json['color'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DashboardStoryTimeItemToJson(
        _$DashboardStoryTimeItem instance) =>
    <String, dynamic>{
      'storyTagId': instance.storyTagId,
      'color': instance.color,
      'runtimeType': instance.$type,
    };

_$WildcardStoryTimeItem _$$WildcardStoryTimeItemFromJson(
        Map<String, dynamic> json) =>
    _$WildcardStoryTimeItem(
      storySubstring: json['storySubstring'] as String,
      color: json['color'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$WildcardStoryTimeItemToJson(
        _$WildcardStoryTimeItem instance) =>
    <String, dynamic>{
      'storySubstring': instance.storySubstring,
      'color': instance.color,
      'runtimeType': instance.$type,
    };
