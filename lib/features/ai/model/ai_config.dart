import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_config.freezed.dart';
part 'ai_config.g.dart';

enum InferenceProviderType {
  anthropic,
  gemini,
  genericOpenAi,
  nebiusAiStudio,
  openAi,
  openRouter,
}

enum Modality {
  text,
  audio,
  image,
}

/// Defines the types of additional input data a prompt might require.
enum InputDataType {
  task,
  tasksList,
  audioFiles,
  images,
}

@freezed
class AiConfig with _$AiConfig {
  const factory AiConfig.inferenceProvider({
    required String id,
    required String baseUrl,
    required String apiKey,
    required String name,
    required DateTime createdAt,
    required InferenceProviderType inferenceProviderType,
    DateTime? updatedAt,
    String? description,
  }) = AiConfigInferenceProvider;

  const factory AiConfig.model({
    required String id,
    required String name,
    required String inferenceProviderId,
    required DateTime createdAt,
    required List<Modality> inputModalities,
    required List<Modality> outputModalities,
    required bool isReasoningModel,
    DateTime? updatedAt,
    String? description,
  }) = AiConfigModel;

  const factory AiConfig.prompt({
    required String id,
    required String name,
    required String template,
    required String modelId,
    required DateTime createdAt,
    required bool useReasoning,
    required List<InputDataType> requiredInputData,
    String? comment,
    DateTime? updatedAt,
    String? description,
    Map<String, String>? defaultVariables,
    String? category,
  }) = AiConfigPrompt;

  factory AiConfig.fromJson(Map<String, dynamic> json) =>
      _$AiConfigFromJson(json);
}
