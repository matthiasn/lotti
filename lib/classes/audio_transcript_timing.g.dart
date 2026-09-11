// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_transcript_timing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AudioTimedSegment _$AudioTimedSegmentFromJson(Map<String, dynamic> json) =>
    _AudioTimedSegment(
      text: json['text'] as String,
      startMilliseconds: (json['startMilliseconds'] as num).toInt(),
      endMilliseconds: (json['endMilliseconds'] as num).toInt(),
    );

Map<String, dynamic> _$AudioTimedSegmentToJson(_AudioTimedSegment instance) =>
    <String, dynamic>{
      'text': instance.text,
      'startMilliseconds': instance.startMilliseconds,
      'endMilliseconds': instance.endMilliseconds,
    };

_AudioTranscriptTiming _$AudioTranscriptTimingFromJson(
  Map<String, dynamic> json,
) => _AudioTranscriptTiming(
  createdAt: DateTime.parse(json['createdAt'] as String),
  audioSha256: json['audioSha256'] as String,
  sourceFingerprint: json['sourceFingerprint'] as String,
  sourceVersion: json['sourceVersion'] as String,
  providerId: json['providerId'] as String,
  model: json['model'] as String,
  segments: (json['segments'] as List<dynamic>)
      .map((e) => AudioTimedSegment.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AudioTranscriptTimingToJson(
  _AudioTranscriptTiming instance,
) => <String, dynamic>{
  'createdAt': instance.createdAt.toIso8601String(),
  'audioSha256': instance.audioSha256,
  'sourceFingerprint': instance.sourceFingerprint,
  'sourceVersion': instance.sourceVersion,
  'providerId': instance.providerId,
  'model': instance.model,
  'segments': instance.segments,
};
