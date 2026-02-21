// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_domain_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentIdentityEntity _$AgentIdentityEntityFromJson(Map<String, dynamic> json) =>
    AgentIdentityEntity(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      kind: json['kind'] as String,
      displayName: json['displayName'] as String,
      lifecycle: $enumDecode(_$AgentLifecycleEnumMap, json['lifecycle']),
      mode: $enumDecode(_$AgentInteractionModeEnumMap, json['mode']),
      allowedCategoryIds: (json['allowedCategoryIds'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      currentStateId: json['currentStateId'] as String,
      config: AgentConfig.fromJson(json['config'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      destroyedAt: json['destroyedAt'] == null
          ? null
          : DateTime.parse(json['destroyedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentIdentityEntityToJson(
        AgentIdentityEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'kind': instance.kind,
      'displayName': instance.displayName,
      'lifecycle': _$AgentLifecycleEnumMap[instance.lifecycle]!,
      'mode': _$AgentInteractionModeEnumMap[instance.mode]!,
      'allowedCategoryIds': instance.allowedCategoryIds.toList(),
      'currentStateId': instance.currentStateId,
      'config': instance.config,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'destroyedAt': instance.destroyedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

const _$AgentLifecycleEnumMap = {
  AgentLifecycle.created: 'created',
  AgentLifecycle.active: 'active',
  AgentLifecycle.dormant: 'dormant',
  AgentLifecycle.destroyed: 'destroyed',
};

const _$AgentInteractionModeEnumMap = {
  AgentInteractionMode.autonomous: 'autonomous',
  AgentInteractionMode.interactive: 'interactive',
  AgentInteractionMode.hybrid: 'hybrid',
};

AgentStateEntity _$AgentStateEntityFromJson(Map<String, dynamic> json) =>
    AgentStateEntity(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      revision: (json['revision'] as num).toInt(),
      slots: AgentSlots.fromJson(json['slots'] as Map<String, dynamic>),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      lastWakeAt: json['lastWakeAt'] == null
          ? null
          : DateTime.parse(json['lastWakeAt'] as String),
      nextWakeAt: json['nextWakeAt'] == null
          ? null
          : DateTime.parse(json['nextWakeAt'] as String),
      sleepUntil: json['sleepUntil'] == null
          ? null
          : DateTime.parse(json['sleepUntil'] as String),
      recentHeadMessageId: json['recentHeadMessageId'] as String?,
      latestSummaryMessageId: json['latestSummaryMessageId'] as String?,
      consecutiveFailureCount:
          (json['consecutiveFailureCount'] as num?)?.toInt() ?? 0,
      wakeCounter: (json['wakeCounter'] as num?)?.toInt() ?? 0,
      processedCounterByHost:
          (json['processedCounterByHost'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const {},
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentStateEntityToJson(AgentStateEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'revision': instance.revision,
      'slots': instance.slots,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'lastWakeAt': instance.lastWakeAt?.toIso8601String(),
      'nextWakeAt': instance.nextWakeAt?.toIso8601String(),
      'sleepUntil': instance.sleepUntil?.toIso8601String(),
      'recentHeadMessageId': instance.recentHeadMessageId,
      'latestSummaryMessageId': instance.latestSummaryMessageId,
      'consecutiveFailureCount': instance.consecutiveFailureCount,
      'wakeCounter': instance.wakeCounter,
      'processedCounterByHost': instance.processedCounterByHost,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

AgentMessageEntity _$AgentMessageEntityFromJson(Map<String, dynamic> json) =>
    AgentMessageEntity(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      threadId: json['threadId'] as String,
      kind: $enumDecode(_$AgentMessageKindEnumMap, json['kind']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      metadata: AgentMessageMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>),
      prevMessageId: json['prevMessageId'] as String?,
      contentEntryId: json['contentEntryId'] as String?,
      triggerSourceId: json['triggerSourceId'] as String?,
      summaryStartMessageId: json['summaryStartMessageId'] as String?,
      summaryEndMessageId: json['summaryEndMessageId'] as String?,
      summaryDepth: (json['summaryDepth'] as num?)?.toInt() ?? 0,
      tokensApprox: (json['tokensApprox'] as num?)?.toInt() ?? 0,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentMessageEntityToJson(AgentMessageEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'threadId': instance.threadId,
      'kind': _$AgentMessageKindEnumMap[instance.kind]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'metadata': instance.metadata,
      'prevMessageId': instance.prevMessageId,
      'contentEntryId': instance.contentEntryId,
      'triggerSourceId': instance.triggerSourceId,
      'summaryStartMessageId': instance.summaryStartMessageId,
      'summaryEndMessageId': instance.summaryEndMessageId,
      'summaryDepth': instance.summaryDepth,
      'tokensApprox': instance.tokensApprox,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

const _$AgentMessageKindEnumMap = {
  AgentMessageKind.observation: 'observation',
  AgentMessageKind.user: 'user',
  AgentMessageKind.thought: 'thought',
  AgentMessageKind.action: 'action',
  AgentMessageKind.toolResult: 'toolResult',
  AgentMessageKind.summary: 'summary',
  AgentMessageKind.system: 'system',
};

AgentMessagePayloadEntity _$AgentMessagePayloadEntityFromJson(
        Map<String, dynamic> json) =>
    AgentMessagePayloadEntity(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      content: json['content'] as Map<String, dynamic>,
      contentType: json['contentType'] as String? ?? 'application/json',
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentMessagePayloadEntityToJson(
        AgentMessagePayloadEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'createdAt': instance.createdAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'content': instance.content,
      'contentType': instance.contentType,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

AgentReportEntity _$AgentReportEntityFromJson(Map<String, dynamic> json) =>
    AgentReportEntity(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      scope: json['scope'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      content: json['content'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
      provenance: json['provenance'] as Map<String, dynamic>? ?? const {},
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentReportEntityToJson(AgentReportEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'scope': instance.scope,
      'createdAt': instance.createdAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'content': instance.content,
      'confidence': instance.confidence,
      'provenance': instance.provenance,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

AgentReportHeadEntity _$AgentReportHeadEntityFromJson(
        Map<String, dynamic> json) =>
    AgentReportHeadEntity(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      scope: json['scope'] as String,
      reportId: json['reportId'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentReportHeadEntityToJson(
        AgentReportHeadEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'scope': instance.scope,
      'reportId': instance.reportId,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

AgentUnknownEntity _$AgentUnknownEntityFromJson(Map<String, dynamic> json) =>
    AgentUnknownEntity(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentUnknownEntityToJson(AgentUnknownEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'createdAt': instance.createdAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };
