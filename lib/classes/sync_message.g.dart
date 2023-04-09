// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SyncJournalEntity _$$SyncJournalEntityFromJson(Map<String, dynamic> json) =>
    _$SyncJournalEntity(
      journalEntity:
          JournalEntity.fromJson(json['journalEntity'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncJournalEntityToJson(_$SyncJournalEntity instance) =>
    <String, dynamic>{
      'journalEntity': instance.journalEntity,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

const _$SyncEntryStatusEnumMap = {
  SyncEntryStatus.initial: 'initial',
  SyncEntryStatus.update: 'update',
};

_$SyncEntityDefinition _$$SyncEntityDefinitionFromJson(
        Map<String, dynamic> json) =>
    _$SyncEntityDefinition(
      entityDefinition: EntityDefinition.fromJson(
          json['entityDefinition'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncEntityDefinitionToJson(
        _$SyncEntityDefinition instance) =>
    <String, dynamic>{
      'entityDefinition': instance.entityDefinition,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

_$SyncTagEntity _$$SyncTagEntityFromJson(Map<String, dynamic> json) =>
    _$SyncTagEntity(
      tagEntity: TagEntity.fromJson(json['tagEntity'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncTagEntityToJson(_$SyncTagEntity instance) =>
    <String, dynamic>{
      'tagEntity': instance.tagEntity,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

_$SyncEntryLink _$$SyncEntryLinkFromJson(Map<String, dynamic> json) =>
    _$SyncEntryLink(
      entryLink: EntryLink.fromJson(json['entryLink'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SyncEntryLinkToJson(_$SyncEntryLink instance) =>
    <String, dynamic>{
      'entryLink': instance.entryLink,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };
