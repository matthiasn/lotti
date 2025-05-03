// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AiConfigInferenceProviderImpl _$$AiConfigInferenceProviderImplFromJson(
        Map<String, dynamic> json) =>
    _$AiConfigInferenceProviderImpl(
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
      description: json['description'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AiConfigInferenceProviderImplToJson(
        _$AiConfigInferenceProviderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'name': instance.name,
      'createdAt': instance.createdAt.toIso8601String(),
      'inferenceProviderType':
          _$InferenceProviderTypeEnumMap[instance.inferenceProviderType]!,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'description': instance.description,
      'runtimeType': instance.$type,
    };

const _$InferenceProviderTypeEnumMap = {
  InferenceProviderType.anthropic: 'anthropic',
  InferenceProviderType.gemini: 'gemini',
  InferenceProviderType.genericOpenAi: 'genericOpenAi',
  InferenceProviderType.nebiusAiStudio: 'nebiusAiStudio',
  InferenceProviderType.openAi: 'openAi',
  InferenceProviderType.openRouter: 'openRouter',
};

_$AiConfigModelImpl _$$AiConfigModelImplFromJson(Map<String, dynamic> json) =>
    _$AiConfigModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      inferenceProviderId: json['inferenceProviderId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      inputModalities: (json['inputModalities'] as List<dynamic>)
          .map((e) => $enumDecode(_$ModalityEnumMap, e))
          .toList(),
      outputModalities: (json['outputModalities'] as List<dynamic>)
          .map((e) => $enumDecode(_$ModalityEnumMap, e))
          .toList(),
      isReasoningModel: json['isReasoningModel'] as bool,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      description: json['description'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$AiConfigModelImplToJson(_$AiConfigModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'inferenceProviderId': instance.inferenceProviderId,
      'createdAt': instance.createdAt.toIso8601String(),
      'inputModalities':
          instance.inputModalities.map((e) => _$ModalityEnumMap[e]!).toList(),
      'outputModalities':
          instance.outputModalities.map((e) => _$ModalityEnumMap[e]!).toList(),
      'isReasoningModel': instance.isReasoningModel,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'description': instance.description,
      'runtimeType': instance.$type,
    };

const _$ModalityEnumMap = {
  Modality.text: 'text',
  Modality.audio: 'audio',
  Modality.image: 'image',
};

_$AiConfigPromptImpl _$$AiConfigPromptImplFromJson(Map<String, dynamic> json) =>
    _$AiConfigPromptImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      template: json['template'] as String,
      modelId: json['modelId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      useReasoning: json['useReasoning'] as bool,
      requiredInputData: (json['requiredInputData'] as List<dynamic>)
          .map((e) => $enumDecode(_$InputDataTypeEnumMap, e))
          .toList(),
      comment: json['comment'] as String?,
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

Map<String, dynamic> _$$AiConfigPromptImplToJson(
        _$AiConfigPromptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'template': instance.template,
      'modelId': instance.modelId,
      'createdAt': instance.createdAt.toIso8601String(),
      'useReasoning': instance.useReasoning,
      'requiredInputData': instance.requiredInputData
          .map((e) => _$InputDataTypeEnumMap[e]!)
          .toList(),
      'comment': instance.comment,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'description': instance.description,
      'defaultVariables': instance.defaultVariables,
      'category': instance.category,
      'runtimeType': instance.$type,
    };

const _$InputDataTypeEnumMap = {
  InputDataType.task: 'task',
  InputDataType.tasksList: 'tasksList',
  InputDataType.audioFiles: 'audioFiles',
  InputDataType.images: 'images',
};
