// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_audio_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DayAudioContext _$DayAudioContextFromJson(Map<String, dynamic> json) =>
    _DayAudioContext(
      dayId: json['dayId'] as String,
      planDate: DateTime.parse(json['planDate'] as String),
      recordingSessionId: json['recordingSessionId'] as String,
      activityEntryId: json['activityEntryId'] as String,
      processingJobId: json['processingJobId'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      intent: json['intent'] as String,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      originHostId: json['originHostId'] as String?,
      continuationOperationId: json['continuationOperationId'] as String?,
      baselineRevisionId: json['baselineRevisionId'] as String?,
    );

Map<String, dynamic> _$DayAudioContextToJson(_DayAudioContext instance) =>
    <String, dynamic>{
      'dayId': instance.dayId,
      'planDate': instance.planDate.toIso8601String(),
      'recordingSessionId': instance.recordingSessionId,
      'activityEntryId': instance.activityEntryId,
      'processingJobId': instance.processingJobId,
      'capturedAt': instance.capturedAt.toIso8601String(),
      'intent': instance.intent,
      'schemaVersion': instance.schemaVersion,
      'originHostId': instance.originHostId,
      'continuationOperationId': instance.continuationOperationId,
      'baselineRevisionId': instance.baselineRevisionId,
    };
