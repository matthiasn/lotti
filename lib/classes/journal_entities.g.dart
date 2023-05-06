// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Metadata _$$_MetadataFromJson(Map<String, dynamic> json) => _$_Metadata(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      tagIds:
          (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      utcOffset: json['utcOffset'] as int?,
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

Map<String, dynamic> _$$_MetadataToJson(_$_Metadata instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
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

_$_ImageData _$$_ImageDataFromJson(Map<String, dynamic> json) => _$_ImageData(
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      imageId: json['imageId'] as String,
      imageFile: json['imageFile'] as String,
      imageDirectory: json['imageDirectory'] as String,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$_ImageDataToJson(_$_ImageData instance) =>
    <String, dynamic>{
      'capturedAt': instance.capturedAt.toIso8601String(),
      'imageId': instance.imageId,
      'imageFile': instance.imageFile,
      'imageDirectory': instance.imageDirectory,
      'geolocation': instance.geolocation,
    };

_$_AudioData _$$_AudioDataFromJson(Map<String, dynamic> json) => _$_AudioData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      audioFile: json['audioFile'] as String,
      audioDirectory: json['audioDirectory'] as String,
      duration: Duration(microseconds: json['duration'] as int),
      transcripts: (json['transcripts'] as List<dynamic>?)
          ?.map((e) => AudioTranscript.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_AudioDataToJson(_$_AudioData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'audioFile': instance.audioFile,
      'audioDirectory': instance.audioDirectory,
      'duration': instance.duration.inMicroseconds,
      'transcripts': instance.transcripts,
    };

_$_AudioTranscript _$$_AudioTranscriptFromJson(Map<String, dynamic> json) =>
    _$_AudioTranscript(
      created: DateTime.parse(json['created'] as String),
      library: json['library'] as String,
      model: json['model'] as String,
      detectedLanguage: json['detectedLanguage'] as String,
      transcript: json['transcript'] as String,
    );

Map<String, dynamic> _$$_AudioTranscriptToJson(_$_AudioTranscript instance) =>
    <String, dynamic>{
      'created': instance.created.toIso8601String(),
      'library': instance.library,
      'model': instance.model,
      'detectedLanguage': instance.detectedLanguage,
      'transcript': instance.transcript,
    };

_$_SurveyData _$$_SurveyDataFromJson(Map<String, dynamic> json) =>
    _$_SurveyData(
      taskResult:
          RPTaskResult.fromJson(json['taskResult'] as Map<String, dynamic>),
      scoreDefinitions: (json['scoreDefinitions'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toSet()),
      ),
      calculatedScores: Map<String, int>.from(json['calculatedScores'] as Map),
    );

Map<String, dynamic> _$$_SurveyDataToJson(_$_SurveyData instance) =>
    <String, dynamic>{
      'taskResult': instance.taskResult,
      'scoreDefinitions':
          instance.scoreDefinitions.map((k, e) => MapEntry(k, e.toList())),
      'calculatedScores': instance.calculatedScores,
    };

_$JournalEntry _$$JournalEntryFromJson(Map<String, dynamic> json) =>
    _$JournalEntry(
      meta: Metadata.fromJson(json['meta'] as Map<String, dynamic>),
      entryText: json['entryText'] == null
          ? null
          : EntryText.fromJson(json['entryText'] as Map<String, dynamic>),
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$JournalEntryToJson(_$JournalEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$JournalImage _$$JournalImageFromJson(Map<String, dynamic> json) =>
    _$JournalImage(
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

Map<String, dynamic> _$$JournalImageToJson(_$JournalImage instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$JournalAudio _$$JournalAudioFromJson(Map<String, dynamic> json) =>
    _$JournalAudio(
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

Map<String, dynamic> _$$JournalAudioToJson(_$JournalAudio instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$Task _$$TaskFromJson(Map<String, dynamic> json) => _$Task(
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

Map<String, dynamic> _$$TaskToJson(_$Task instance) => <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$QuantitativeEntry _$$QuantitativeEntryFromJson(Map<String, dynamic> json) =>
    _$QuantitativeEntry(
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

Map<String, dynamic> _$$QuantitativeEntryToJson(_$QuantitativeEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$MeasurementEntry _$$MeasurementEntryFromJson(Map<String, dynamic> json) =>
    _$MeasurementEntry(
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

Map<String, dynamic> _$$MeasurementEntryToJson(_$MeasurementEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$WorkoutEntry _$$WorkoutEntryFromJson(Map<String, dynamic> json) =>
    _$WorkoutEntry(
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

Map<String, dynamic> _$$WorkoutEntryToJson(_$WorkoutEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$HabitCompletionEntry _$$HabitCompletionEntryFromJson(
        Map<String, dynamic> json) =>
    _$HabitCompletionEntry(
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

Map<String, dynamic> _$$HabitCompletionEntryToJson(
        _$HabitCompletionEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$SurveyEntry _$$SurveyEntryFromJson(Map<String, dynamic> json) =>
    _$SurveyEntry(
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

Map<String, dynamic> _$$SurveyEntryToJson(_$SurveyEntry instance) =>
    <String, dynamic>{
      'meta': instance.meta,
      'data': instance.data,
      'entryText': instance.entryText,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };
