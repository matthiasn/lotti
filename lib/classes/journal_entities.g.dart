// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MetadataImpl _$$MetadataImplFromJson(Map<String, dynamic> json) =>
    _$MetadataImpl(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      categoryId: json['categoryId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      tagIds:
          (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      utcOffset: (json['utcOffset'] as num?)?.toInt(),
      timezone: json['timezone'] as String?,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      flag: $enumDecodeNullable(_$EntryFlagEnumMap, json['flag']),
      starred: json['starred'] as bool?,
      private: json['private'] as bool?,
    );

Map<String, dynamic> _$$MetadataImplToJson(_$MetadataImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'categoryId': instance.categoryId,
      'tags': instance.tags,
      'tagIds': instance.tagIds,
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'flag': _$EntryFlagEnumMap[instance.flag],
      'starred': instance.starred,
      'private': instance.private,
    };

const _$EntryFlagEnumMap = {
  EntryFlag.none: 'none',
  EntryFlag.import: 'import',
  EntryFlag.followUpNeeded: 'followUpNeeded',
};

_$ImageDataImpl _$$ImageDataImplFromJson(Map<String, dynamic> json) =>
    _$ImageDataImpl(
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      imageId: json['imageId'] as String,
      imageFile: json['imageFile'] as String,
      imageDirectory: json['imageDirectory'] as String,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ImageDataImplToJson(_$ImageDataImpl instance) =>
    <String, dynamic>{
      'capturedAt': instance.capturedAt.toIso8601String(),
      'imageId': instance.imageId,
      'imageFile': instance.imageFile,
      'imageDirectory': instance.imageDirectory,
      'geolocation': instance.geolocation,
    };

_$AudioDataImpl _$$AudioDataImplFromJson(Map<String, dynamic> json) =>
    _$AudioDataImpl(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      audioFile: json['audioFile'] as String,
      audioDirectory: json['audioDirectory'] as String,
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      autoTranscribeWasActive:
          json['autoTranscribeWasActive'] as bool? ?? false,
      language: json['language'] as String?,
      transcripts: (json['transcripts'] as List<dynamic>?)
          ?.map((e) => AudioTranscript.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$AudioDataImplToJson(_$AudioDataImpl instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'audioFile': instance.audioFile,
      'audioDirectory': instance.audioDirectory,
      'duration': instance.duration.inMicroseconds,
      'autoTranscribeWasActive': instance.autoTranscribeWasActive,
      'language': instance.language,
      'transcripts': instance.transcripts,
    };

_$AudioTranscriptImpl _$$AudioTranscriptImplFromJson(
        Map<String, dynamic> json) =>
    _$AudioTranscriptImpl(
      created: DateTime.parse(json['created'] as String),
      library: json['library'] as String,
      model: json['model'] as String,
      detectedLanguage: json['detectedLanguage'] as String,
      transcript: json['transcript'] as String,
      processingTime: json['processingTime'] == null
          ? null
          : Duration(microseconds: (json['processingTime'] as num).toInt()),
    );

Map<String, dynamic> _$$AudioTranscriptImplToJson(
        _$AudioTranscriptImpl instance) =>
    <String, dynamic>{
      'created': instance.created.toIso8601String(),
      'library': instance.library,
      'model': instance.model,
      'detectedLanguage': instance.detectedLanguage,
      'transcript': instance.transcript,
      'processingTime': instance.processingTime?.inMicroseconds,
    };

_$SurveyDataImpl _$$SurveyDataImplFromJson(Map<String, dynamic> json) =>
    _$SurveyDataImpl(
      taskResult:
          RPTaskResult.fromJson(json['taskResult'] as Map<String, dynamic>),
      scoreDefinitions: (json['scoreDefinitions'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toSet()),
      ),
      calculatedScores: Map<String, int>.from(json['calculatedScores'] as Map),
    );

Map<String, dynamic> _$$SurveyDataImplToJson(_$SurveyDataImpl instance) =>
    <String, dynamic>{
      'taskResult': instance.taskResult,
      'scoreDefinitions':
          instance.scoreDefinitions.map((k, e) => MapEntry(k, e.toList())),
      'calculatedScores': instance.calculatedScores,
    };

_$JournalEntryImpl _$$JournalEntryImplFromJson(Map<String, dynamic> json) =>
    _$JournalEntryImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$JournalEntryImplToJson(_$JournalEntryImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$JournalImageImpl _$$JournalImageImplFromJson(Map<String, dynamic> json) =>
    _$JournalImageImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: ImageData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$JournalImageImplToJson(_$JournalImageImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$JournalAudioImpl _$$JournalAudioImplFromJson(Map<String, dynamic> json) =>
    _$JournalAudioImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: AudioData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$JournalAudioImplToJson(_$JournalAudioImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$TaskImpl _$$TaskImplFromJson(Map<String, dynamic> json) => _$TaskImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: TaskData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$TaskImplToJson(_$TaskImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$JournalEventImpl _$$JournalEventImplFromJson(Map<String, dynamic> json) =>
    _$JournalEventImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: EventData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$JournalEventImplToJson(_$JournalEventImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$ChecklistItemImpl _$$ChecklistItemImplFromJson(Map<String, dynamic> json) =>
    _$ChecklistItemImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: ChecklistItemData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ChecklistItemImplToJson(_$ChecklistItemImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$ChecklistImpl _$$ChecklistImplFromJson(Map<String, dynamic> json) =>
    _$ChecklistImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: ChecklistData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ChecklistImplToJson(_$ChecklistImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$QuantitativeEntryImpl _$$QuantitativeEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$QuantitativeEntryImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: QuantitativeData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$QuantitativeEntryImplToJson(
        _$QuantitativeEntryImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$MeasurementEntryImpl _$$MeasurementEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$MeasurementEntryImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: MeasurementData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$MeasurementEntryImplToJson(
        _$MeasurementEntryImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$AiResponseEntryImpl _$$AiResponseEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$AiResponseEntryImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: AiResponseData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AiResponseEntryImplToJson(
        _$AiResponseEntryImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$WorkoutEntryImpl _$$WorkoutEntryImplFromJson(Map<String, dynamic> json) =>
    _$WorkoutEntryImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: WorkoutData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$WorkoutEntryImplToJson(_$WorkoutEntryImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$HabitCompletionEntryImpl _$$HabitCompletionEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$HabitCompletionEntryImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: HabitCompletionData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$HabitCompletionEntryImplToJson(
        _$HabitCompletionEntryImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$SurveyEntryImpl _$$SurveyEntryImplFromJson(Map<String, dynamic> json) =>
    _$SurveyEntryImpl(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      data: SurveyData.fromJson(json['data'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SurveyEntryImplToJson(_$SurveyEntryImpl instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };
