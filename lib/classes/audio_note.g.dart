// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AudioNoteImpl _$$AudioNoteImplFromJson(Map<String, dynamic> json) =>
    _$AudioNoteImpl(
      createdAt: DateTime.parse(json['createdAt'] as String),
      audioFile: json['audioFile'] as String,
      audioDirectory: json['audioDirectory'] as String,
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
    );

Map<String, dynamic> _$$AudioNoteImplToJson(_$AudioNoteImpl instance) =>
    <String, dynamic>{
      'createdAt': instance.createdAt.toIso8601String(),
      'audioFile': instance.audioFile,
      'audioDirectory': instance.audioDirectory,
      'duration': instance.duration.inMicroseconds,
    };
