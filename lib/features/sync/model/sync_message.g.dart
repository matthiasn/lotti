// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SyncJournalEntityImpl _$$SyncJournalEntityImplFromJson(
        Map<String, dynamic> json) =>
    _$SyncJournalEntityImpl(
      id: json['id'] as String,
      jsonPath: json['jsonPath'] as String,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncJournalEntityImplToJson(
        _$SyncJournalEntityImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jsonPath': instance.jsonPath,
      'vectorClock': instance.vectorClock,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

const _$SyncEntryStatusEnumMap = {
  SyncEntryStatus.initial: 'initial',
  SyncEntryStatus.update: 'update',
};

_$SyncEntityDefinitionImpl _$$SyncEntityDefinitionImplFromJson(
        Map<String, dynamic> json) =>
    _$SyncEntityDefinitionImpl(
      entityDefinition: EntityDefinition.fromJson(
          json['entityDefinition'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncEntityDefinitionImplToJson(
        _$SyncEntityDefinitionImpl instance) =>
    <String, dynamic>{
      'entityDefinition': instance.entityDefinition,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

_$SyncTagEntityImpl _$$SyncTagEntityImplFromJson(Map<String, dynamic> json) =>
    _$SyncTagEntityImpl(
      tagEntity: TagEntity.fromJson(json['tagEntity'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncTagEntityImplToJson(_$SyncTagEntityImpl instance) =>
    <String, dynamic>{
      'tagEntity': instance.tagEntity,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

_$SyncEntryLinkImpl _$$SyncEntryLinkImplFromJson(Map<String, dynamic> json) =>
    _$SyncEntryLinkImpl(
      entryLink: EntryLink.fromJson(json['entryLink'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncEntryLinkImplToJson(_$SyncEntryLinkImpl instance) =>
    <String, dynamic>{
      'entryLink': instance.entryLink,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };
