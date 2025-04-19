// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_inference_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CloudInferenceConfigImpl _$$CloudInferenceConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$CloudInferenceConfigImpl(
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      geminiApiKey: json['geminiApiKey'] as String,
    );

Map<String, dynamic> _$$CloudInferenceConfigImplToJson(
        _$CloudInferenceConfigImpl instance) =>
    <String, dynamic>{
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'geminiApiKey': instance.geminiApiKey,
    };
