// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_consumption_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiConsumptionEvent _$AiConsumptionEventFromJson(Map<String, dynamic> json) =>
    _AiConsumptionEvent(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      providerType: $enumDecode(
        _$InferenceProviderTypeEnumMap,
        json['providerType'],
      ),
      responseType: $enumDecode(
        _$AiConsumptionResponseTypeEnumMap,
        json['responseType'],
      ),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      parentId: json['parentId'] as String?,
      taskId: json['taskId'] as String?,
      categoryId: json['categoryId'] as String?,
      entryId: json['entryId'] as String?,
      agentId: json['agentId'] as String?,
      wakeRunKey: json['wakeRunKey'] as String?,
      threadId: json['threadId'] as String?,
      turnIndex: (json['turnIndex'] as num?)?.toInt(),
      promptId: json['promptId'] as String?,
      skillId: json['skillId'] as String?,
      configId: json['configId'] as String?,
      modelId: json['modelId'] as String?,
      providerModelId: json['providerModelId'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      inputTokens: (json['inputTokens'] as num?)?.toInt(),
      outputTokens: (json['outputTokens'] as num?)?.toInt(),
      cachedInputTokens: (json['cachedInputTokens'] as num?)?.toInt(),
      thoughtsTokens: (json['thoughtsTokens'] as num?)?.toInt(),
      totalTokens: (json['totalTokens'] as num?)?.toInt(),
      credits: (json['credits'] as num?)?.toDouble(),
      energyKwh: (json['energyKwh'] as num?)?.toDouble(),
      carbonGCo2: (json['carbonGCo2'] as num?)?.toDouble(),
      waterLiters: (json['waterLiters'] as num?)?.toDouble(),
      renewablePercent: (json['renewablePercent'] as num?)?.toDouble(),
      pue: (json['pue'] as num?)?.toDouble(),
      dataCenter: json['dataCenter'] as String?,
      upstreamProviderId: json['upstreamProviderId'] as String?,
    );

Map<String, dynamic> _$AiConsumptionEventToJson(
  _AiConsumptionEvent instance,
) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt.toIso8601String(),
  'providerType': _$InferenceProviderTypeEnumMap[instance.providerType]!,
  'responseType': _$AiConsumptionResponseTypeEnumMap[instance.responseType]!,
  'vectorClock': instance.vectorClock,
  'parentId': instance.parentId,
  'taskId': instance.taskId,
  'categoryId': instance.categoryId,
  'entryId': instance.entryId,
  'agentId': instance.agentId,
  'wakeRunKey': instance.wakeRunKey,
  'threadId': instance.threadId,
  'turnIndex': instance.turnIndex,
  'promptId': instance.promptId,
  'skillId': instance.skillId,
  'configId': instance.configId,
  'modelId': instance.modelId,
  'providerModelId': instance.providerModelId,
  'durationMs': instance.durationMs,
  'inputTokens': instance.inputTokens,
  'outputTokens': instance.outputTokens,
  'cachedInputTokens': instance.cachedInputTokens,
  'thoughtsTokens': instance.thoughtsTokens,
  'totalTokens': instance.totalTokens,
  'credits': instance.credits,
  'energyKwh': instance.energyKwh,
  'carbonGCo2': instance.carbonGCo2,
  'waterLiters': instance.waterLiters,
  'renewablePercent': instance.renewablePercent,
  'pue': instance.pue,
  'dataCenter': instance.dataCenter,
  'upstreamProviderId': instance.upstreamProviderId,
};

const _$InferenceProviderTypeEnumMap = {
  InferenceProviderType.alibaba: 'alibaba',
  InferenceProviderType.anthropic: 'anthropic',
  InferenceProviderType.gemini: 'gemini',
  InferenceProviderType.genericOpenAi: 'genericOpenAi',
  InferenceProviderType.melious: 'melious',
  InferenceProviderType.mistral: 'mistral',
  InferenceProviderType.mlxAudio: 'mlxAudio',
  InferenceProviderType.nebiusAiStudio: 'nebiusAiStudio',
  InferenceProviderType.omlx: 'omlx',
  InferenceProviderType.openAi: 'openAi',
  InferenceProviderType.openRouter: 'openRouter',
  InferenceProviderType.ollama: 'ollama',
  InferenceProviderType.voxtral: 'voxtral',
  InferenceProviderType.whisper: 'whisper',
};

const _$AiConsumptionResponseTypeEnumMap = {
  AiConsumptionResponseType.agentTurn: 'agentTurn',
  AiConsumptionResponseType.textGeneration: 'textGeneration',
  AiConsumptionResponseType.audioTranscription: 'audioTranscription',
  AiConsumptionResponseType.imageAnalysis: 'imageAnalysis',
  AiConsumptionResponseType.imageGeneration: 'imageGeneration',
  AiConsumptionResponseType.promptGeneration: 'promptGeneration',
};
