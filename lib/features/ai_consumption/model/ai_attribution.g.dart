// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_attribution.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiActorSnapshot _$AiActorSnapshotFromJson(Map<String, dynamic> json) =>
    _AiActorSnapshot(
      type: $enumDecode(_$AiActorTypeEnumMap, json['type']),
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      humanPrincipalId: json['humanPrincipalId'] as String?,
    );

Map<String, dynamic> _$AiActorSnapshotToJson(_AiActorSnapshot instance) =>
    <String, dynamic>{
      'type': _$AiActorTypeEnumMap[instance.type]!,
      'id': instance.id,
      'displayName': instance.displayName,
      'humanPrincipalId': instance.humanPrincipalId,
    };

const _$AiActorTypeEnumMap = {
  AiActorType.human: 'human',
  AiActorType.agent: 'agent',
  AiActorType.automation: 'automation',
  AiActorType.system: 'system',
};

_AiTriggerSnapshot _$AiTriggerSnapshotFromJson(Map<String, dynamic> json) =>
    _AiTriggerSnapshot(
      type: $enumDecode(_$AiTriggerTypeEnumMap, json['type']),
      skillId: json['skillId'] as String?,
      promptId: json['promptId'] as String?,
      profileId: json['profileId'] as String?,
      agentId: json['agentId'] as String?,
      wakeRunKey: json['wakeRunKey'] as String?,
      automationRuleId: json['automationRuleId'] as String?,
    );

Map<String, dynamic> _$AiTriggerSnapshotToJson(_AiTriggerSnapshot instance) =>
    <String, dynamic>{
      'type': _$AiTriggerTypeEnumMap[instance.type]!,
      'skillId': instance.skillId,
      'promptId': instance.promptId,
      'profileId': instance.profileId,
      'agentId': instance.agentId,
      'wakeRunKey': instance.wakeRunKey,
      'automationRuleId': instance.automationRuleId,
    };

const _$AiTriggerTypeEnumMap = {
  AiTriggerType.manual: 'manual',
  AiTriggerType.automatic: 'automatic',
  AiTriggerType.scheduled: 'scheduled',
  AiTriggerType.synced: 'synced',
  AiTriggerType.agentTool: 'agentTool',
  AiTriggerType.migration: 'migration',
};

_AiArtifactReference _$AiArtifactReferenceFromJson(Map<String, dynamic> json) =>
    _AiArtifactReference(
      type: $enumDecode(_$AiArtifactTypeEnumMap, json['type']),
      id: json['id'] as String,
      subId: json['subId'] as String?,
    );

Map<String, dynamic> _$AiArtifactReferenceToJson(
  _AiArtifactReference instance,
) => <String, dynamic>{
  'type': _$AiArtifactTypeEnumMap[instance.type]!,
  'id': instance.id,
  'subId': instance.subId,
};

const _$AiArtifactTypeEnumMap = {
  AiArtifactType.journalEntry: 'journalEntry',
  AiArtifactType.journalAiResponse: 'journalAiResponse',
  AiArtifactType.journalImage: 'journalImage',
  AiArtifactType.journalAudio: 'journalAudio',
  AiArtifactType.agentReport: 'agentReport',
  AiArtifactType.agentMessage: 'agentMessage',
  AiArtifactType.embeddingVector: 'embeddingVector',
};

_AiWorkAttribution _$AiWorkAttributionFromJson(Map<String, dynamic> json) =>
    _AiWorkAttribution(
      id: json['id'] as String,
      workType: $enumDecode(_$AiWorkTypeEnumMap, json['workType']),
      status: $enumDecode(_$AiWorkStatusEnumMap, json['status']),
      initiator: AiActorSnapshot.fromJson(
        json['initiator'] as Map<String, dynamic>,
      ),
      trigger: AiTriggerSnapshot.fromJson(
        json['trigger'] as Map<String, dynamic>,
      ),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      parentAttributionId: json['parentAttributionId'] as String?,
      taskId: json['taskId'] as String?,
      categoryId: json['categoryId'] as String?,
      primaryOutput: json['primaryOutput'] == null
          ? null
          : AiArtifactReference.fromJson(
              json['primaryOutput'] as Map<String, dynamic>,
            ),
      errorCode: json['errorCode'] as String?,
      errorSummary: json['errorSummary'] as String?,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$AiWorkAttributionToJson(_AiWorkAttribution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workType': _$AiWorkTypeEnumMap[instance.workType]!,
      'status': _$AiWorkStatusEnumMap[instance.status]!,
      'initiator': instance.initiator,
      'trigger': instance.trigger,
      'startedAt': instance.startedAt.toIso8601String(),
      'completedAt': instance.completedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'parentAttributionId': instance.parentAttributionId,
      'taskId': instance.taskId,
      'categoryId': instance.categoryId,
      'primaryOutput': instance.primaryOutput,
      'errorCode': instance.errorCode,
      'errorSummary': instance.errorSummary,
      'schemaVersion': instance.schemaVersion,
    };

const _$AiWorkTypeEnumMap = {
  AiWorkType.codingPrompt: 'codingPrompt',
  AiWorkType.textGeneration: 'textGeneration',
  AiWorkType.imageGeneration: 'imageGeneration',
  AiWorkType.imageAnalysis: 'imageAnalysis',
  AiWorkType.audioTranscription: 'audioTranscription',
  AiWorkType.agentReport: 'agentReport',
  AiWorkType.embeddingIndexing: 'embeddingIndexing',
  AiWorkType.internalInference: 'internalInference',
};

const _$AiWorkStatusEnumMap = {
  AiWorkStatus.succeeded: 'succeeded',
  AiWorkStatus.failed: 'failed',
  AiWorkStatus.cancelled: 'cancelled',
  AiWorkStatus.partial: 'partial',
};

_AiAttributionSession _$AiAttributionSessionFromJson(
  Map<String, dynamic> json,
) => _AiAttributionSession(
  id: json['id'] as String,
  workType: $enumDecode(_$AiWorkTypeEnumMap, json['workType']),
  initiator: AiActorSnapshot.fromJson(
    json['initiator'] as Map<String, dynamic>,
  ),
  trigger: AiTriggerSnapshot.fromJson(json['trigger'] as Map<String, dynamic>),
  startedAt: DateTime.parse(json['startedAt'] as String),
  intendedOutputs:
      (json['intendedOutputs'] as List<dynamic>?)
          ?.map((e) => AiArtifactReference.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AiArtifactReference>[],
  parentAttributionId: json['parentAttributionId'] as String?,
  taskId: json['taskId'] as String?,
  categoryId: json['categoryId'] as String?,
);

Map<String, dynamic> _$AiAttributionSessionToJson(
  _AiAttributionSession instance,
) => <String, dynamic>{
  'id': instance.id,
  'workType': _$AiWorkTypeEnumMap[instance.workType]!,
  'initiator': instance.initiator,
  'trigger': instance.trigger,
  'startedAt': instance.startedAt.toIso8601String(),
  'intendedOutputs': instance.intendedOutputs,
  'parentAttributionId': instance.parentAttributionId,
  'taskId': instance.taskId,
  'categoryId': instance.categoryId,
};
