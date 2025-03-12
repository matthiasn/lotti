// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AiInputTaskObjectImpl _$$AiInputTaskObjectImplFromJson(
        Map<String, dynamic> json) =>
    _$AiInputTaskObjectImpl(
      title: json['title'] as String,
      status: json['status'] as String,
      estimatedDuration: json['estimatedDuration'] as String,
      timeSpent: json['timeSpent'] as String,
      creationDate: DateTime.parse(json['creationDate'] as String),
      actionItems: (json['actionItems'] as List<dynamic>)
          .map((e) => AiActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      logEntries: (json['logEntries'] as List<dynamic>)
          .map((e) => AiInputLogEntryObject.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$AiInputTaskObjectImplToJson(
        _$AiInputTaskObjectImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'status': instance.status,
      'estimatedDuration': instance.estimatedDuration,
      'timeSpent': instance.timeSpent,
      'creationDate': instance.creationDate.toIso8601String(),
      'actionItems': instance.actionItems,
      'logEntries': instance.logEntries,
    };

_$AiActionItemImpl _$$AiActionItemImplFromJson(Map<String, dynamic> json) =>
    _$AiActionItemImpl(
      title: json['title'] as String,
      completed: json['completed'] as bool,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      completionDate: json['completionDate'] == null
          ? null
          : DateTime.parse(json['completionDate'] as String),
    );

Map<String, dynamic> _$$AiActionItemImplToJson(_$AiActionItemImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'completed': instance.completed,
      'deadline': instance.deadline?.toIso8601String(),
      'completionDate': instance.completionDate?.toIso8601String(),
    };

_$AiInputLogEntryObjectImpl _$$AiInputLogEntryObjectImplFromJson(
        Map<String, dynamic> json) =>
    _$AiInputLogEntryObjectImpl(
      creationTimestamp: DateTime.parse(json['creationTimestamp'] as String),
      loggedDuration: json['loggedDuration'] as String,
      text: json['text'] as String,
    );

Map<String, dynamic> _$$AiInputLogEntryObjectImplToJson(
        _$AiInputLogEntryObjectImpl instance) =>
    <String, dynamic>{
      'creationTimestamp': instance.creationTimestamp.toIso8601String(),
      'loggedDuration': instance.loggedDuration,
      'text': instance.text,
    };

_$AiInputActionItemsListImpl _$$AiInputActionItemsListImplFromJson(
        Map<String, dynamic> json) =>
    _$AiInputActionItemsListImpl(
      items: (json['items'] as List<dynamic>)
          .map((e) => AiActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$AiInputActionItemsListImplToJson(
        _$AiInputActionItemsListImpl instance) =>
    <String, dynamic>{
      'items': instance.items,
    };
