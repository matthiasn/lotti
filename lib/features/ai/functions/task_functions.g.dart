// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_functions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SetTaskLanguageResultImpl _$$SetTaskLanguageResultImplFromJson(
        Map<String, dynamic> json) =>
    _$SetTaskLanguageResultImpl(
      languageCode: json['languageCode'] as String,
      confidence:
          $enumDecode(_$LanguageDetectionConfidenceEnumMap, json['confidence']),
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$$SetTaskLanguageResultImplToJson(
        _$SetTaskLanguageResultImpl instance) =>
    <String, dynamic>{
      'languageCode': instance.languageCode,
      'confidence': _$LanguageDetectionConfidenceEnumMap[instance.confidence]!,
      'reason': instance.reason,
    };

const _$LanguageDetectionConfidenceEnumMap = {
  LanguageDetectionConfidence.high: 'high',
  LanguageDetectionConfidence.medium: 'medium',
  LanguageDetectionConfidence.low: 'low',
};
