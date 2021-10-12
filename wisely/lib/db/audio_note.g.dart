// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioNote _$AudioNoteFromJson(Map<String, dynamic> json) => AudioNote(
      id: json['id'] as String,
      timestamp: json['timestamp'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      timezone: json['timezone'] as String,
      audioFile: json['audioFile'] as String,
      audioDirectory: json['audioDirectory'] as String,
      duration: Duration(microseconds: json['duration'] as int),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      transcript: json['transcript'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AudioNoteToJson(AudioNote instance) => <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'audioFile': instance.audioFile,
      'audioDirectory': instance.audioDirectory,
      'duration': instance.duration.inMicroseconds,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'transcript': instance.transcript,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'vectorClock': instance.vectorClock,
    };
