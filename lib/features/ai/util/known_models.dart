/// Known model configurations for different inference providers.
///
/// This file contains predefined model configurations that are automatically
/// populated when a new inference provider is created. Each model includes
/// its provider-specific ID, capabilities, and a brief description.
///
/// The models are organized by provider:
/// - Gemini: Google's models with multi-modal capabilities
/// - Nebius: High-performance models for text and image tasks
/// - Ollama: Local models for text processing
/// - OpenAI: Advanced language and multimodal models
library;

import 'package:lotti/features/ai/model/ai_config.dart';

/// Represents a known model configuration that can be automatically
/// populated when creating a new inference provider.
class KnownModel {
  const KnownModel({
    required this.providerModelId,
    required this.name,
    required this.inputModalities,
    required this.outputModalities,
    required this.isReasoningModel,
    required this.description,
  });

  final String providerModelId;
  final String name;
  final List<Modality> inputModalities;
  final List<Modality> outputModalities;
  final bool isReasoningModel;
  final String description;

  /// Creates an AiConfigModel from this known model configuration
  AiConfigModel toAiConfigModel({
    required String id,
    required String inferenceProviderId,
  }) {
    return AiConfigModel(
      id: id,
      name: name,
      providerModelId: providerModelId,
      inferenceProviderId: inferenceProviderId,
      createdAt: DateTime.now(),
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
      description: description,
    );
  }
}

/// Known models for each inference provider type
const Map<InferenceProviderType, List<KnownModel>> knownModelsByProvider = {
  InferenceProviderType.gemini: geminiModels,
  InferenceProviderType.nebiusAiStudio: nebiusModels,
  InferenceProviderType.ollama: ollamaModels,
  InferenceProviderType.openAi: openaiModels,
};

/// Gemini models - Google's multimodal AI models
const List<KnownModel> geminiModels = [
  KnownModel(
    providerModelId: 'models/gemini-2.5-pro-preview-05-06',
    name: 'Gemini 2.5 Pro',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'Latest Gemini Pro with enhanced multimodal and reasoning capabilities',
  ),
  KnownModel(
    providerModelId: 'models/gemini-2.5-flash-preview-04-17',
    name: 'Gemini 2.5 Flash',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'Fast multimodal model with reasoning capabilities optimized for speed',
  ),
];

/// Nebius models - High-performance text and image models
const List<KnownModel> nebiusModels = [
  KnownModel(
    providerModelId: 'google/gemma-3-27b-it-fast',
    name: 'Gemma 3 27B',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description: 'Large language model with image understanding',
  ),
  KnownModel(
    providerModelId: 'deepseek-ai/DeepSeek-R1-fast',
    name: 'DeepSeek R1',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description: 'Advanced reasoning model for complex tasks',
  ),
];

/// Ollama models - Local models for privacy-focused processing
const List<KnownModel> ollamaModels = [
  KnownModel(
    providerModelId: 'gemma3:12b',
    name: 'Gemma 3 12B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description: 'Efficient local text model',
  ),
  KnownModel(
    providerModelId: 'deepseek-r1:14b',
    name: 'DeepSeek R1 14B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description: 'Local reasoning model for complex analysis',
  ),
];

/// OpenAI models - Advanced language and multimodal models
const List<KnownModel> openaiModels = [
  KnownModel(
    providerModelId: 'gpt-4',
    name: 'GPT-4',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description: 'Most capable model for complex reasoning and analysis',
  ),
  KnownModel(
    providerModelId: 'gpt-4-turbo',
    name: 'GPT-4 Turbo',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Latest GPT-4 model with vision capabilities and 128K context window',
  ),
  KnownModel(
    providerModelId: 'gpt-3.5-turbo',
    name: 'GPT-3.5 Turbo',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'Fast and efficient model with 16K context window for text-based tasks',
  ),
];

/// Generates a unique model ID based on provider ID and model ID
String generateModelId(String inferenceProviderId, String providerModelId) {
  // Create a deterministic ID by combining provider and model IDs
  final combined = '${inferenceProviderId}_$providerModelId';
  // Replace problematic characters for IDs
  return combined.replaceAll(RegExp(r'[/:\-.]'), '_').toLowerCase();
}
