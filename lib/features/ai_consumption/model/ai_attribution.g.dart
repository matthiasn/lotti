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

_AiExecutorSnapshot _$AiExecutorSnapshotFromJson(Map<String, dynamic> json) =>
    _AiExecutorSnapshot(
      hostId: json['hostId'] as String,
      displayName: json['displayName'] as String,
      appVersion: json['appVersion'] as String?,
    );

Map<String, dynamic> _$AiExecutorSnapshotToJson(_AiExecutorSnapshot instance) =>
    <String, dynamic>{
      'hostId': instance.hostId,
      'displayName': instance.displayName,
      'appVersion': instance.appVersion,
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
};

_AiAttributionLink _$AiAttributionLinkFromJson(Map<String, dynamic> json) =>
    _AiAttributionLink(
      id: json['id'] as String,
      attributionId: json['attributionId'] as String,
      role: $enumDecode(_$AiAttributionLinkRoleEnumMap, json['role']),
      artifact: AiArtifactReference.fromJson(
        json['artifact'] as Map<String, dynamic>,
      ),
      contentDigest: json['contentDigest'] as String?,
    );

Map<String, dynamic> _$AiAttributionLinkToJson(_AiAttributionLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'attributionId': instance.attributionId,
      'role': _$AiAttributionLinkRoleEnumMap[instance.role]!,
      'artifact': instance.artifact,
      'contentDigest': instance.contentDigest,
    };

const _$AiAttributionLinkRoleEnumMap = {
  AiAttributionLinkRole.output: 'output',
  AiAttributionLinkRole.source: 'source',
  AiAttributionLinkRole.context: 'context',
};

_AiContentPart _$AiContentPartFromJson(Map<String, dynamic> json) =>
    _AiContentPart(
      type: $enumDecode(_$AiContentPartTypeEnumMap, json['type']),
      text: json['text'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'] as Map<String, dynamic>?,
      attachment: json['attachment'] == null
          ? null
          : AiArtifactReference.fromJson(
              json['attachment'] as Map<String, dynamic>,
            ),
      mediaType: json['mediaType'] as String?,
      sha256: json['sha256'] as String?,
      byteLength: (json['byteLength'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AiContentPartToJson(_AiContentPart instance) =>
    <String, dynamic>{
      'type': _$AiContentPartTypeEnumMap[instance.type]!,
      'text': instance.text,
      'name': instance.name,
      'arguments': instance.arguments,
      'attachment': instance.attachment,
      'mediaType': instance.mediaType,
      'sha256': instance.sha256,
      'byteLength': instance.byteLength,
    };

const _$AiContentPartTypeEnumMap = {
  AiContentPartType.text: 'text',
  AiContentPartType.toolCall: 'toolCall',
  AiContentPartType.toolResult: 'toolResult',
  AiContentPartType.attachmentReference: 'attachmentReference',
  AiContentPartType.omitted: 'omitted',
};

_AiInteractionPayload _$AiInteractionPayloadFromJson(
  Map<String, dynamic> json,
) => _AiInteractionPayload(
  id: json['id'] as String,
  interactionId: json['interactionId'] as String,
  request: (json['request'] as List<dynamic>)
      .map((e) => AiContentPart.fromJson(e as Map<String, dynamic>))
      .toList(),
  response: (json['response'] as List<dynamic>)
      .map((e) => AiContentPart.fromJson(e as Map<String, dynamic>))
      .toList(),
  parameters: json['parameters'] as Map<String, dynamic>,
  requestDigest: json['requestDigest'] as String,
  responseDigest: json['responseDigest'] as String,
  capturePolicy: $enumDecode(
    _$AiPayloadCapturePolicyEnumMap,
    json['capturePolicy'],
  ),
  privacyClassification: $enumDecode(
    _$AiPrivacyClassificationEnumMap,
    json['privacyClassification'],
  ),
  createdAt: DateTime.parse(json['createdAt'] as String),
  providerMetadata: json['providerMetadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$AiInteractionPayloadToJson(
  _AiInteractionPayload instance,
) => <String, dynamic>{
  'id': instance.id,
  'interactionId': instance.interactionId,
  'request': instance.request,
  'response': instance.response,
  'parameters': instance.parameters,
  'requestDigest': instance.requestDigest,
  'responseDigest': instance.responseDigest,
  'capturePolicy': _$AiPayloadCapturePolicyEnumMap[instance.capturePolicy]!,
  'privacyClassification':
      _$AiPrivacyClassificationEnumMap[instance.privacyClassification]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'providerMetadata': instance.providerMetadata,
};

const _$AiPayloadCapturePolicyEnumMap = {
  AiPayloadCapturePolicy.fullText: 'fullText',
  AiPayloadCapturePolicy.referenceOnly: 'referenceOnly',
  AiPayloadCapturePolicy.redacted: 'redacted',
  AiPayloadCapturePolicy.metadataOnly: 'metadataOnly',
};

const _$AiPrivacyClassificationEnumMap = {
  AiPrivacyClassification.standard: 'standard',
  AiPrivacyClassification.private: 'private',
  AiPrivacyClassification.mixed: 'mixed',
};

_AiInteractionCost _$AiInteractionCostFromJson(Map<String, dynamic> json) =>
    _AiInteractionCost(
      id: json['id'] as String,
      interactionId: json['interactionId'] as String,
      source: $enumDecode(_$AiCostSourceEnumMap, json['source']),
      assessedAt: DateTime.parse(json['assessedAt'] as String),
      originalAmountDecimal: json['originalAmountDecimal'] as String?,
      originalUnit: json['originalUnit'] as String?,
      reportingAmountMicros: (json['reportingAmountMicros'] as num?)?.toInt(),
      reportingCurrency: json['reportingCurrency'] as String?,
      supersedesCostId: json['supersedesCostId'] as String?,
      providerType: json['providerType'] as String?,
      billingAccountKey: json['billingAccountKey'] as String?,
      billingSource: json['billingSource'] as String?,
      externalRecordId: json['externalRecordId'] as String?,
      pricingSnapshot: json['pricingSnapshot'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AiInteractionCostToJson(_AiInteractionCost instance) =>
    <String, dynamic>{
      'id': instance.id,
      'interactionId': instance.interactionId,
      'source': _$AiCostSourceEnumMap[instance.source]!,
      'assessedAt': instance.assessedAt.toIso8601String(),
      'originalAmountDecimal': instance.originalAmountDecimal,
      'originalUnit': instance.originalUnit,
      'reportingAmountMicros': instance.reportingAmountMicros,
      'reportingCurrency': instance.reportingCurrency,
      'supersedesCostId': instance.supersedesCostId,
      'providerType': instance.providerType,
      'billingAccountKey': instance.billingAccountKey,
      'billingSource': instance.billingSource,
      'externalRecordId': instance.externalRecordId,
      'pricingSnapshot': instance.pricingSnapshot,
    };

const _$AiCostSourceEnumMap = {
  AiCostSource.externallyReconciled: 'externallyReconciled',
  AiCostSource.providerReported: 'providerReported',
  AiCostSource.legacyReported: 'legacyReported',
  AiCostSource.locallyEstimated: 'locallyEstimated',
  AiCostSource.localCompute: 'localCompute',
  AiCostSource.unknown: 'unknown',
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
      executor: AiExecutorSnapshot.fromJson(
        json['executor'] as Map<String, dynamic>,
      ),
      privacyClassification: $enumDecode(
        _$AiPrivacyClassificationEnumMap,
        json['privacyClassification'],
      ),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      links: (json['links'] as List<dynamic>)
          .map((e) => AiAttributionLink.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      'executor': instance.executor,
      'privacyClassification':
          _$AiPrivacyClassificationEnumMap[instance.privacyClassification]!,
      'startedAt': instance.startedAt.toIso8601String(),
      'completedAt': instance.completedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'links': instance.links,
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
  AiWorkStatus.abandoned: 'abandoned',
  AiWorkStatus.partial: 'partial',
};

_AiAttributionRecoveryCapsule _$AiAttributionRecoveryCapsuleFromJson(
  Map<String, dynamic> json,
) => _AiAttributionRecoveryCapsule(
  id: json['id'] as String,
  attributionId: json['attributionId'] as String,
  workType: $enumDecode(_$AiWorkTypeEnumMap, json['workType']),
  initiator: AiActorSnapshot.fromJson(
    json['initiator'] as Map<String, dynamic>,
  ),
  trigger: AiTriggerSnapshot.fromJson(json['trigger'] as Map<String, dynamic>),
  executor: AiExecutorSnapshot.fromJson(
    json['executor'] as Map<String, dynamic>,
  ),
  privacyClassification: $enumDecode(
    _$AiPrivacyClassificationEnumMap,
    json['privacyClassification'],
  ),
  startedAt: DateTime.parse(json['startedAt'] as String),
  intendedOutputs: (json['intendedOutputs'] as List<dynamic>)
      .map((e) => AiArtifactReference.fromJson(e as Map<String, dynamic>))
      .toList(),
  digestAlgorithm: json['digestAlgorithm'] as String? ?? 'sha256-v1',
  omittedReferenceCount: (json['omittedReferenceCount'] as num?)?.toInt() ?? 0,
  parentAttributionId: json['parentAttributionId'] as String?,
  taskId: json['taskId'] as String?,
  categoryId: json['categoryId'] as String?,
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$AiAttributionRecoveryCapsuleToJson(
  _AiAttributionRecoveryCapsule instance,
) => <String, dynamic>{
  'id': instance.id,
  'attributionId': instance.attributionId,
  'workType': _$AiWorkTypeEnumMap[instance.workType]!,
  'initiator': instance.initiator,
  'trigger': instance.trigger,
  'executor': instance.executor,
  'privacyClassification':
      _$AiPrivacyClassificationEnumMap[instance.privacyClassification]!,
  'startedAt': instance.startedAt.toIso8601String(),
  'intendedOutputs': instance.intendedOutputs,
  'digestAlgorithm': instance.digestAlgorithm,
  'omittedReferenceCount': instance.omittedReferenceCount,
  'parentAttributionId': instance.parentAttributionId,
  'taskId': instance.taskId,
  'categoryId': instance.categoryId,
  'schemaVersion': instance.schemaVersion,
};

_AiTerminalAttributionEnvelope _$AiTerminalAttributionEnvelopeFromJson(
  Map<String, dynamic> json,
) => _AiTerminalAttributionEnvelope(
  id: json['id'] as String,
  attribution: AiWorkAttribution.fromJson(
    json['attribution'] as Map<String, dynamic>,
  ),
  digestAlgorithm: json['digestAlgorithm'] as String? ?? 'sha256-v1',
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$AiTerminalAttributionEnvelopeToJson(
  _AiTerminalAttributionEnvelope instance,
) => <String, dynamic>{
  'id': instance.id,
  'attribution': instance.attribution,
  'digestAlgorithm': instance.digestAlgorithm,
  'schemaVersion': instance.schemaVersion,
};

_AiAttributionPendingSession _$AiAttributionPendingSessionFromJson(
  Map<String, dynamic> json,
) => _AiAttributionPendingSession(
  id: json['id'] as String,
  attributionId: json['attributionId'] as String,
  workType: $enumDecode(_$AiWorkTypeEnumMap, json['workType']),
  initiator: AiActorSnapshot.fromJson(
    json['initiator'] as Map<String, dynamic>,
  ),
  trigger: AiTriggerSnapshot.fromJson(json['trigger'] as Map<String, dynamic>),
  executor: AiExecutorSnapshot.fromJson(
    json['executor'] as Map<String, dynamic>,
  ),
  privacyClassification: $enumDecode(
    _$AiPrivacyClassificationEnumMap,
    json['privacyClassification'],
  ),
  phase: $enumDecode(_$AiAttributionPendingPhaseEnumMap, json['phase']),
  startedAt: DateTime.parse(json['startedAt'] as String),
  lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
  intendedOutputs: (json['intendedOutputs'] as List<dynamic>)
      .map((e) => AiArtifactReference.fromJson(e as Map<String, dynamic>))
      .toList(),
  sourceArtifacts:
      (json['sourceArtifacts'] as List<dynamic>?)
          ?.map((e) => AiArtifactReference.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AiArtifactReference>[],
  contextArtifacts:
      (json['contextArtifacts'] as List<dynamic>?)
          ?.map((e) => AiArtifactReference.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AiArtifactReference>[],
  interactionIds:
      (json['interactionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  parentAttributionId: json['parentAttributionId'] as String?,
  taskId: json['taskId'] as String?,
  categoryId: json['categoryId'] as String?,
  terminalAttributionId: json['terminalAttributionId'] as String?,
  errorCode: json['errorCode'] as String?,
);

Map<String, dynamic> _$AiAttributionPendingSessionToJson(
  _AiAttributionPendingSession instance,
) => <String, dynamic>{
  'id': instance.id,
  'attributionId': instance.attributionId,
  'workType': _$AiWorkTypeEnumMap[instance.workType]!,
  'initiator': instance.initiator,
  'trigger': instance.trigger,
  'executor': instance.executor,
  'privacyClassification':
      _$AiPrivacyClassificationEnumMap[instance.privacyClassification]!,
  'phase': _$AiAttributionPendingPhaseEnumMap[instance.phase]!,
  'startedAt': instance.startedAt.toIso8601String(),
  'lastUpdatedAt': instance.lastUpdatedAt.toIso8601String(),
  'intendedOutputs': instance.intendedOutputs,
  'sourceArtifacts': instance.sourceArtifacts,
  'contextArtifacts': instance.contextArtifacts,
  'interactionIds': instance.interactionIds,
  'parentAttributionId': instance.parentAttributionId,
  'taskId': instance.taskId,
  'categoryId': instance.categoryId,
  'terminalAttributionId': instance.terminalAttributionId,
  'errorCode': instance.errorCode,
};

const _$AiAttributionPendingPhaseEnumMap = {
  AiAttributionPendingPhase.prepared: 'prepared',
  AiAttributionPendingPhase.calling: 'calling',
  AiAttributionPendingPhase.evidenceDurable: 'evidenceDurable',
  AiAttributionPendingPhase.evidencePublished: 'evidencePublished',
  AiAttributionPendingPhase.outputPersisted: 'outputPersisted',
};
