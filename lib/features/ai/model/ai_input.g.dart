// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiInputTaskObject _$AiInputTaskObjectFromJson(Map<String, dynamic> json) =>
    _AiInputTaskObject(
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
      languageCode: json['languageCode'] as String?,
    );

Map<String, dynamic> _$AiInputTaskObjectToJson(_AiInputTaskObject instance) =>
    <String, dynamic>{
      'title': instance.title,
      'status': instance.status,
      'estimatedDuration': instance.estimatedDuration,
      'timeSpent': instance.timeSpent,
      'creationDate': instance.creationDate.toIso8601String(),
      'actionItems': instance.actionItems,
      'logEntries': instance.logEntries,
      'languageCode': instance.languageCode,
    };

_AiActionItem _$AiActionItemFromJson(Map<String, dynamic> json) =>
    _AiActionItem(
      title: json['title'] as String,
      completed: json['completed'] as bool,
      id: json['id'] as String?,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      completionDate: json['completionDate'] == null
          ? null
          : DateTime.parse(json['completionDate'] as String),
    );

Map<String, dynamic> _$AiActionItemToJson(_AiActionItem instance) =>
    <String, dynamic>{
      'title': instance.title,
      'completed': instance.completed,
      'id': instance.id,
      'deadline': instance.deadline?.toIso8601String(),
      'completionDate': instance.completionDate?.toIso8601String(),
    };

_AiInputLogEntryObject _$AiInputLogEntryObjectFromJson(
        Map<String, dynamic> json) =>
    _AiInputLogEntryObject(
      creationTimestamp: DateTime.parse(json['creationTimestamp'] as String),
      loggedDuration: json['loggedDuration'] as String,
      text: json['text'] as String,
      audioTranscript: json['audioTranscript'] as String?,
      transcriptLanguage: json['transcriptLanguage'] as String?,
      entryType: json['entryType'] as String?,
    );

Map<String, dynamic> _$AiInputLogEntryObjectToJson(
        _AiInputLogEntryObject instance) =>
    <String, dynamic>{
      'creationTimestamp': instance.creationTimestamp.toIso8601String(),
      'loggedDuration': instance.loggedDuration,
      'text': instance.text,
      'audioTranscript': instance.audioTranscript,
      'transcriptLanguage': instance.transcriptLanguage,
      'entryType': instance.entryType,
    };

_AiInputActionItemsList _$AiInputActionItemsListFromJson(
        Map<String, dynamic> json) =>
    _AiInputActionItemsList(
      items: (json['items'] as List<dynamic>)
          .map((e) => AiActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AiInputActionItemsListToJson(
        _AiInputActionItemsList instance) =>
    <String, dynamic>{
      'items': instance.items,
    };

_AiLinkedTaskContext _$AiLinkedTaskContextFromJson(Map<String, dynamic> json) =>
    _AiLinkedTaskContext(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      statusSince: DateTime.parse(json['statusSince'] as String),
      priority: json['priority'] as String,
      estimate: json['estimate'] as String,
      timeSpent: json['timeSpent'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      labels: (json['labels'] as List<dynamic>)
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      languageCode: json['languageCode'] as String?,
      latestSummary: json['latestSummary'] as String?,
    );

Map<String, dynamic> _$AiLinkedTaskContextToJson(
        _AiLinkedTaskContext instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'status': instance.status,
      'statusSince': instance.statusSince.toIso8601String(),
      'priority': instance.priority,
      'estimate': instance.estimate,
      'timeSpent': instance.timeSpent,
      'createdAt': instance.createdAt.toIso8601String(),
      'labels': instance.labels,
      'languageCode': instance.languageCode,
      'latestSummary': instance.latestSummary,
    };
