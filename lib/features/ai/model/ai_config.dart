import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/state/consts.dart';

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
    required String providerModelId,
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
    required String systemMessage,
    required String userMessage,
    required String defaultModelId,
    required List<String> modelIds,
    required DateTime createdAt,
    required bool useReasoning,
    required List<InputDataType> requiredInputData,
    required AiResponseType aiResponseType,
    String? comment,
    DateTime? updatedAt,
    String? description,
    Map<String, String>? defaultVariables,
    String? category,
  }) = AiConfigPrompt;

  factory AiConfig.fromJson(Map<String, dynamic> json) =>
      _$AiConfigFromJson(json);
}

enum AiConfigType {
  inferenceProvider,
  prompt,
  model,
}

/// Checks if a given [AiConfigModel] meets the requirements specified by a [AiConfigPrompt].
///
/// Requirements checked:
/// 1. Reasoning Capability: If the prompt requires reasoning (`useReasoning` = true),
///    the model must also be a reasoning model (`isReasoningModel` = true).
/// 2. Input Modalities: For every `InputDataType` listed in the prompt's
///    `requiredInputData`, the model must support the corresponding input `Modality`.
///
/// Returns `true` if the model satisfies all prompt requirements, `false` otherwise.
bool isModelSuitableForPrompt({
  required AiConfigModel model,
  required AiConfigPrompt prompt,
}) {
  // 1. Check Reasoning Capability Requirement
  if (prompt.useReasoning && !model.isReasoningModel) {
    // Prompt requires reasoning, but the model does not support it.
    return false;
  }

  // 2. Check Required Input Modalities
  if (prompt.requiredInputData.isNotEmpty) {
    // Use a Set for efficient lookups of the model's supported modalities
    final supportedModalities = model.inputModalities.toSet();

    for (final requiredType in prompt.requiredInputData) {
      final requiredModality = switch (requiredType) {
        InputDataType.task => Modality.text,
        InputDataType.tasksList => Modality.text,
        InputDataType.audioFiles => Modality.audio,
        InputDataType.images => Modality.image,
      };

      // Check if the model supports the required modality for this data type
      if (!supportedModalities.contains(requiredModality)) {
        // Model lacks a required input modality.
        return false;
      }
    }
  }

  // If all checks passed, the model is suitable.
  return true;
}
