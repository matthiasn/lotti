// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskSuggestionNotification _$TaskSuggestionNotificationFromJson(
  Map<String, dynamic> json,
) => TaskSuggestionNotification(
  meta: NotificationMeta.fromJson(json['meta'] as Map<String, dynamic>),
  linkedTaskId: json['linkedTaskId'] as String,
  suggestionCount: (json['suggestionCount'] as num).toInt(),
  title: json['title'] as String,
  body: json['body'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$TaskSuggestionNotificationToJson(
  TaskSuggestionNotification instance,
) => <String, dynamic>{
  'meta': instance.meta,
  'linkedTaskId': instance.linkedTaskId,
  'suggestionCount': instance.suggestionCount,
  'title': instance.title,
  'body': instance.body,
  'runtimeType': instance.$type,
};

TaskOverdueNotification _$TaskOverdueNotificationFromJson(
  Map<String, dynamic> json,
) => TaskOverdueNotification(
  meta: NotificationMeta.fromJson(json['meta'] as Map<String, dynamic>),
  linkedTaskId: json['linkedTaskId'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$TaskOverdueNotificationToJson(
  TaskOverdueNotification instance,
) => <String, dynamic>{
  'meta': instance.meta,
  'linkedTaskId': instance.linkedTaskId,
  'title': instance.title,
  'body': instance.body,
  'runtimeType': instance.$type,
};

_NotificationMeta _$NotificationMetaFromJson(Map<String, dynamic> json) =>
    _NotificationMeta(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      scheduledFor: DateTime.parse(json['scheduledFor'] as String),
      vectorClock: VectorClock.fromJson(
        json['vectorClock'] as Map<String, dynamic>,
      ),
      originatingHostId: json['originatingHostId'] as String,
      seenAt: json['seenAt'] == null
          ? null
          : DateTime.parse(json['seenAt'] as String),
      actedOnAt: json['actedOnAt'] == null
          ? null
          : DateTime.parse(json['actedOnAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      category: json['category'] as String?,
    );

Map<String, dynamic> _$NotificationMetaToJson(_NotificationMeta instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'scheduledFor': instance.scheduledFor.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'originatingHostId': instance.originatingHostId,
      'seenAt': instance.seenAt?.toIso8601String(),
      'actedOnAt': instance.actedOnAt?.toIso8601String(),
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'category': instance.category,
    };
