// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentConfig _$AgentConfigFromJson(Map<String, dynamic> json) => _AgentConfig(
      maxTurnsPerWake: (json['maxTurnsPerWake'] as num?)?.toInt() ?? 5,
      modelId: json['modelId'] as String? ?? 'models/gemini-3-flash-preview',
    );

Map<String, dynamic> _$AgentConfigToJson(_AgentConfig instance) =>
    <String, dynamic>{
      'maxTurnsPerWake': instance.maxTurnsPerWake,
      'modelId': instance.modelId,
    };

_AgentSlots _$AgentSlotsFromJson(Map<String, dynamic> json) => _AgentSlots(
      activeTaskId: json['activeTaskId'] as String?,
    );

Map<String, dynamic> _$AgentSlotsToJson(_AgentSlots instance) =>
    <String, dynamic>{
      'activeTaskId': instance.activeTaskId,
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
