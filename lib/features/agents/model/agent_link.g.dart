// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BasicAgentLink _$BasicAgentLinkFromJson(Map<String, dynamic> json) =>
    BasicAgentLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$BasicAgentLinkToJson(BasicAgentLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

AgentStateLink _$AgentStateLinkFromJson(Map<String, dynamic> json) =>
    AgentStateLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentStateLinkToJson(AgentStateLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

MessagePrevLink _$MessagePrevLinkFromJson(Map<String, dynamic> json) =>
    MessagePrevLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$MessagePrevLinkToJson(MessagePrevLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

MessagePayloadLink _$MessagePayloadLinkFromJson(Map<String, dynamic> json) =>
    MessagePayloadLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$MessagePayloadLinkToJson(MessagePayloadLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

ToolEffectLink _$ToolEffectLinkFromJson(Map<String, dynamic> json) =>
    ToolEffectLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ToolEffectLinkToJson(ToolEffectLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

AgentTaskLink _$AgentTaskLinkFromJson(Map<String, dynamic> json) =>
    AgentTaskLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$AgentTaskLinkToJson(AgentTaskLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };
