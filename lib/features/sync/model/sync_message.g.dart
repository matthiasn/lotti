// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncJournalEntity _$SyncJournalEntityFromJson(Map<String, dynamic> json) =>
    SyncJournalEntity(
      id: json['id'] as String,
      jsonPath: json['jsonPath'] as String,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncJournalEntityToJson(SyncJournalEntity instance) =>
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

SyncEntityDefinition _$SyncEntityDefinitionFromJson(
        Map<String, dynamic> json) =>
    SyncEntityDefinition(
      entityDefinition: EntityDefinition.fromJson(
          json['entityDefinition'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncEntityDefinitionToJson(
        SyncEntityDefinition instance) =>
    <String, dynamic>{
      'entityDefinition': instance.entityDefinition,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

SyncTagEntity _$SyncTagEntityFromJson(Map<String, dynamic> json) =>
    SyncTagEntity(
      tagEntity: TagEntity.fromJson(json['tagEntity'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncTagEntityToJson(SyncTagEntity instance) =>
    <String, dynamic>{
      'tagEntity': instance.tagEntity,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

SyncEntryLink _$SyncEntryLinkFromJson(Map<String, dynamic> json) =>
    SyncEntryLink(
      entryLink: EntryLink.fromJson(json['entryLink'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncEntryLinkToJson(SyncEntryLink instance) =>
    <String, dynamic>{
      'entryLink': instance.entryLink,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

SyncAiConfig _$SyncAiConfigFromJson(Map<String, dynamic> json) => SyncAiConfig(
      aiConfig: AiConfig.fromJson(json['aiConfig'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncAiConfigToJson(SyncAiConfig instance) =>
    <String, dynamic>{
      'aiConfig': instance.aiConfig,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

SyncAiConfigDelete _$SyncAiConfigDeleteFromJson(Map<String, dynamic> json) =>
    SyncAiConfigDelete(
      id: json['id'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncAiConfigDeleteToJson(SyncAiConfigDelete instance) =>
    <String, dynamic>{
      'id': instance.id,
      'runtimeType': instance.$type,
    };

SyncThemingSelection _$SyncThemingSelectionFromJson(
        Map<String, dynamic> json) =>
    SyncThemingSelection(
      lightThemeName: json['lightThemeName'] as String,
      darkThemeName: json['darkThemeName'] as String,
      themeMode: json['themeMode'] as String,
      updatedAt: (json['updatedAt'] as num).toInt(),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncThemingSelectionToJson(
        SyncThemingSelection instance) =>
    <String, dynamic>{
      'lightThemeName': instance.lightThemeName,
      'darkThemeName': instance.darkThemeName,
      'themeMode': instance.themeMode,
      'updatedAt': instance.updatedAt,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };
