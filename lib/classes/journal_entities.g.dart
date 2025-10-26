// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Metadata _$MetadataFromJson(Map<String, dynamic> json) => _Metadata(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      categoryId: json['categoryId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      tagIds:
          (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      labelIds: (json['labelIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
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

Map<String, dynamic> _$MetadataToJson(_Metadata instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'categoryId': instance.categoryId,
      'tags': instance.tags,
      'tagIds': instance.tagIds,
      'labelIds': instance.labelIds,
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

_ImageData _$ImageDataFromJson(Map<String, dynamic> json) => _ImageData(
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      imageId: json['imageId'] as String,
      imageFile: json['imageFile'] as String,
      imageDirectory: json['imageDirectory'] as String,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ImageDataToJson(_ImageData instance) =>
    <String, dynamic>{
      'capturedAt': instance.capturedAt.toIso8601String(),
      'imageId': instance.imageId,
      'imageFile': instance.imageFile,
      'imageDirectory': instance.imageDirectory,
      'geolocation': instance.geolocation,
    };

_AudioData _$AudioDataFromJson(Map<String, dynamic> json) => _AudioData(
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

Map<String, dynamic> _$AudioDataToJson(_AudioData instance) =>
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

_AudioTranscript _$AudioTranscriptFromJson(Map<String, dynamic> json) =>
    _AudioTranscript(
      created: DateTime.parse(json['created'] as String),
      library: json['library'] as String,
      model: json['model'] as String,
      detectedLanguage: json['detectedLanguage'] as String,
      transcript: json['transcript'] as String,
      processingTime: json['processingTime'] == null
          ? null
          : Duration(microseconds: (json['processingTime'] as num).toInt()),
    );

Map<String, dynamic> _$AudioTranscriptToJson(_AudioTranscript instance) =>
    <String, dynamic>{
      'created': instance.created.toIso8601String(),
      'library': instance.library,
      'model': instance.model,
      'detectedLanguage': instance.detectedLanguage,
      'transcript': instance.transcript,
      'processingTime': instance.processingTime?.inMicroseconds,
    };

_SurveyData _$SurveyDataFromJson(Map<String, dynamic> json) => _SurveyData(
      taskResult:
          RPTaskResult.fromJson(json['taskResult'] as Map<String, dynamic>),
      scoreDefinitions: (json['scoreDefinitions'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toSet()),
      ),
      calculatedScores: Map<String, int>.from(json['calculatedScores'] as Map),
    );

Map<String, dynamic> _$SurveyDataToJson(_SurveyData instance) =>
    <String, dynamic>{
      'taskResult': instance.taskResult,
      'scoreDefinitions':
          instance.scoreDefinitions.map((k, e) => MapEntry(k, e.toList())),
      'calculatedScores': instance.calculatedScores,
    };

JournalEntry _$JournalEntryFromJson(Map<String, dynamic> json) => JournalEntry(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$JournalEntryToJson(JournalEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

JournalImage _$JournalImageFromJson(Map<String, dynamic> json) => JournalImage(
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

Map<String, dynamic> _$JournalImageToJson(JournalImage instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

JournalAudio _$JournalAudioFromJson(Map<String, dynamic> json) => JournalAudio(
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

Map<String, dynamic> _$JournalAudioToJson(JournalAudio instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
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

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

JournalEvent _$JournalEventFromJson(Map<String, dynamic> json) => JournalEvent(
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

Map<String, dynamic> _$JournalEventToJson(JournalEvent instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

ChecklistItem _$ChecklistItemFromJson(Map<String, dynamic> json) =>
    ChecklistItem(
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

Map<String, dynamic> _$ChecklistItemToJson(ChecklistItem instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

Checklist _$ChecklistFromJson(Map<String, dynamic> json) => Checklist(
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

Map<String, dynamic> _$ChecklistToJson(Checklist instance) => <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

QuantitativeEntry _$QuantitativeEntryFromJson(Map<String, dynamic> json) =>
    QuantitativeEntry(
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

Map<String, dynamic> _$QuantitativeEntryToJson(QuantitativeEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

MeasurementEntry _$MeasurementEntryFromJson(Map<String, dynamic> json) =>
    MeasurementEntry(
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

Map<String, dynamic> _$MeasurementEntryToJson(MeasurementEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

AiResponseEntry _$AiResponseEntryFromJson(Map<String, dynamic> json) =>
    AiResponseEntry(
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

Map<String, dynamic> _$AiResponseEntryToJson(AiResponseEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

WorkoutEntry _$WorkoutEntryFromJson(Map<String, dynamic> json) => WorkoutEntry(
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

Map<String, dynamic> _$WorkoutEntryToJson(WorkoutEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

HabitCompletionEntry _$HabitCompletionEntryFromJson(
        Map<String, dynamic> json) =>
    HabitCompletionEntry(
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

Map<String, dynamic> _$HabitCompletionEntryToJson(
        HabitCompletionEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

SurveyEntry _$SurveyEntryFromJson(Map<String, dynamic> json) => SurveyEntry(
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

Map<String, dynamic> _$SurveyEntryToJson(SurveyEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };
