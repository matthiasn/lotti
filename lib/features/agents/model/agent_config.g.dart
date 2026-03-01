// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentConfig _$AgentConfigFromJson(Map<String, dynamic> json) => _AgentConfig(
      maxTurnsPerWake: (json['maxTurnsPerWake'] as num?)?.toInt() ?? 5,
      modelId: json['modelId'] as String? ?? 'models/gemini-3-flash-preview',
      profileId: json['profileId'] as String?,
    );

Map<String, dynamic> _$AgentConfigToJson(_AgentConfig instance) =>
    <String, dynamic>{
      'maxTurnsPerWake': instance.maxTurnsPerWake,
      'modelId': instance.modelId,
      'profileId': instance.profileId,
    };

_AgentSlots _$AgentSlotsFromJson(Map<String, dynamic> json) => _AgentSlots(
      activeTaskId: json['activeTaskId'] as String?,
      activeTemplateId: json['activeTemplateId'] as String?,
      lastOneOnOneAt: json['lastOneOnOneAt'] == null
          ? null
          : DateTime.parse(json['lastOneOnOneAt'] as String),
      lastFeedbackScanAt: json['lastFeedbackScanAt'] == null
          ? null
          : DateTime.parse(json['lastFeedbackScanAt'] as String),
      feedbackWindowDays: (json['feedbackWindowDays'] as num?)?.toInt(),
      totalSessionsCompleted: (json['totalSessionsCompleted'] as num?)?.toInt(),
      recursionDepth: (json['recursionDepth'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AgentSlotsToJson(_AgentSlots instance) =>
    <String, dynamic>{
      'activeTaskId': instance.activeTaskId,
      'activeTemplateId': instance.activeTemplateId,
      'lastOneOnOneAt': instance.lastOneOnOneAt?.toIso8601String(),
      'lastFeedbackScanAt': instance.lastFeedbackScanAt?.toIso8601String(),
      'feedbackWindowDays': instance.feedbackWindowDays,
      'totalSessionsCompleted': instance.totalSessionsCompleted,
      'recursionDepth': instance.recursionDepth,
    };

_AgentMessageMetadata _$AgentMessageMetadataFromJson(
        Map<String, dynamic> json) =>
    _AgentMessageMetadata(
      runKey: json['runKey'] as String?,
      toolName: json['toolName'] as String?,
      operationId: json['operationId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      policyDenied: json['policyDenied'] as bool? ?? false,
      denialReason: json['denialReason'] as String?,
    );

Map<String, dynamic> _$AgentMessageMetadataToJson(
        _AgentMessageMetadata instance) =>
    <String, dynamic>{
      'runKey': instance.runKey,
      'toolName': instance.toolName,
      'operationId': instance.operationId,
      'errorMessage': instance.errorMessage,
      'policyDenied': instance.policyDenied,
      'denialReason': instance.denialReason,
    };
