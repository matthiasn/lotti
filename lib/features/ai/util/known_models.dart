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

import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

part 'known_models_data.dart';
part 'known_models_ftue.dart';

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
    this.supportsFunctionCalling = false,
    this.maxCompletionTokens,
  });

  final String providerModelId;
  final String name;
  final List<Modality> inputModalities;
  final List<Modality> outputModalities;
  final bool isReasoningModel;
  final String description;
  final bool supportsFunctionCalling;
  final int? maxCompletionTokens;

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
      supportsFunctionCalling: supportsFunctionCalling,
      description: description,
      maxCompletionTokens: maxCompletionTokens,
    );
  }
}

/// Known models for each inference provider type
const Map<InferenceProviderType, List<KnownModel>> knownModelsByProvider = {
  InferenceProviderType.alibaba: alibabaModels,
  InferenceProviderType.gemini: geminiModels,
  InferenceProviderType.mistral: mistralModels,
  InferenceProviderType.mlxAudio: mlxAudioModels,
  InferenceProviderType.nebiusAiStudio: nebiusModels,
  InferenceProviderType.ollama: ollamaModels,
  InferenceProviderType.openAi: openaiModels,
  InferenceProviderType.anthropic: anthropicModels,
  InferenceProviderType.openRouter: openRouterModels,
  InferenceProviderType.whisper: whisperModels,
  InferenceProviderType.voxtral: voxtralModels,
};

/// Canonical MLX Audio model identifiers used by the native Apple bridge.
const mlxAudioVoxtralRealtime4BitModelId =
    'mlx-community/Voxtral-Mini-4B-Realtime-2602-4bit';
const mlxAudioVoxtralRealtimeFp16ModelId =
    'mlx-community/Voxtral-Mini-4B-Realtime-2602-fp16';
const mlxAudioQwenAsrModelId = 'mlx-community/Qwen3-ASR-0.6B-8bit';
const mlxAudioQwenAsr17B4BitModelId = 'mlx-community/Qwen3-ASR-1.7B-4bit';
const mlxAudioQwenAsr17B8BitModelId = 'mlx-community/Qwen3-ASR-1.7B-8bit';
const String mlxAudioRecommendedSttModelId = mlxAudioQwenAsr17B8BitModelId;
const mlxAudioParakeetModelId = 'mlx-community/parakeet-tdt-0.6b-v3';
const mlxAudioDefaultTtsModelId = 'mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit';

/// Whether [providerModelId] is a Qwen3-ASR checkpoint converted for MLX Audio.
bool isMlxAudioQwenAsrModelId(String providerModelId) {
  final normalized = providerModelId.toLowerCase();
  return normalized.startsWith('mlx-community/qwen3-asr-');
}

/// Whether [model] can be offered as an MLX Audio speech-to-text install.
bool isMlxAudioSpeechToTextModel(AiConfigModel model) {
  return model.inputModalities.contains(Modality.audio) &&
      model.outputModalities.contains(Modality.text);
}

/// Generates a unique model ID based on provider ID and model ID
String generateModelId(String inferenceProviderId, String providerModelId) {
  // Create a deterministic ID by combining provider and model IDs
  final combined = '${inferenceProviderId}_$providerModelId';
  // Replace problematic characters for IDs
  return combined.replaceAll(RegExp(r'[/:\-.]'), '_').toLowerCase();
}
