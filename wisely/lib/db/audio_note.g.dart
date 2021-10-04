// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioNote _$AudioNoteFromJson(Map<String, dynamic> json) => AudioNote(
      id: json['id'] as String,
      createdAt: json['createdAt'] as int,
      audioFile: json['audioFile'] as String,
      audioDirectory: json['audioDirectory'] as String,
      durationMilliseconds: json['durationMilliseconds'] as int,
      updatedAt: json['updatedAt'] as int?,
      transcript: json['transcript'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      vectorClock: json['vectorClock'] as String?,
    );

Map<String, dynamic> _$AudioNoteToJson(AudioNote instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt,
      'audioFile': instance.audioFile,
      'audioDirectory': instance.audioDirectory,
      'durationMilliseconds': instance.durationMilliseconds,
      'updatedAt': instance.updatedAt,
      'transcript': instance.transcript,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'vectorClock': instance.vectorClock,
    };
