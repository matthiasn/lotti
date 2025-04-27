// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AiConfigApiKeyImpl _$$AiConfigApiKeyImplFromJson(Map<String, dynamic> json) =>
    _$AiConfigApiKeyImpl(
      id: json['id'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      inferenceProviderType: $enumDecode(
          _$InferenceProviderTypeEnumMap, json['inferenceProviderType']),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      comment: json['comment'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AiConfigApiKeyImplToJson(
        _$AiConfigApiKeyImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'name': instance.name,
      'createdAt': instance.createdAt.toIso8601String(),
      'inferenceProviderType':
          _$InferenceProviderTypeEnumMap[instance.inferenceProviderType]!,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'comment': instance.comment,
      'runtimeType': instance.$type,
    };

const _$InferenceProviderTypeEnumMap = {
  InferenceProviderType.anthropic: 'anthropic',
  InferenceProviderType.gemini: 'gemini',
  InferenceProviderType.genericOpenAi: 'genericOpenAi',
  InferenceProviderType.openAi: 'openAi',
};

_$AiConfigPromptTemplateImpl _$$AiConfigPromptTemplateImplFromJson(
        Map<String, dynamic> json) =>
    _$AiConfigPromptTemplateImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      template: json['template'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      description: json['description'] as String?,
      defaultVariables:
          (json['defaultVariables'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      category: json['category'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AiConfigPromptTemplateImplToJson(
        _$AiConfigPromptTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'template': instance.template,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'description': instance.description,
      'defaultVariables': instance.defaultVariables,
      'category': instance.category,
      'runtimeType': instance.$type,
    };
