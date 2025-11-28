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
  InferenceProviderType.gemini: geminiModels,
  InferenceProviderType.gemma3n: gemma3nModels,
  InferenceProviderType.nebiusAiStudio: nebiusModels,
  InferenceProviderType.ollama: ollamaModels,
  InferenceProviderType.openAi: openaiModels,
  InferenceProviderType.genericOpenAi: genericOpenAiModels,
  InferenceProviderType.anthropic: anthropicModels,
  InferenceProviderType.openRouter: openRouterModels,
  InferenceProviderType.whisper: whisperModels,
};

/// Gemma 3n models - Local multimodal AI models with audio transcription
///
/// These models run locally using the Gemma 3n service and provide both text generation
/// and audio transcription capabilities. They don't require internet connectivity or API keys,
/// making them suitable for privacy-focused applications.
///
/// Note: Users must download these models using the service's model pull endpoint
/// before they can be used in the application.
const List<KnownModel> gemma3nModels = [
  KnownModel(
    providerModelId: 'google/gemma-3n-E2B-it',
    name: 'Gemma 3n E2B',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Local multimodal model with audio transcription capabilities. '
        'Efficient 2B parameter variant optimized for audio-to-text tasks and general conversation.',
  ),
  KnownModel(
    providerModelId: 'google/gemma-3n-E4B-it',
    name: 'Gemma 3n E4B',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Local multimodal model with enhanced audio transcription capabilities. '
        'Larger 4B parameter variant providing improved accuracy for audio-to-text tasks.',
  ),
];

/// Gemini models - Google's multimodal AI models
const List<KnownModel> geminiModels = [
  KnownModel(
    providerModelId: 'models/gemini-3-pro-preview',
    name: 'Gemini 3 Pro Preview',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Latest Gemini 3 with breakthrough reasoning and state-of-the-art multimodal capabilities',
  ),
  KnownModel(
    providerModelId: 'models/gemini-2.5-pro',
    name: 'Gemini 2.5 Pro',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Latest Gemini Pro with enhanced multimodal and reasoning capabilities',
  ),
  KnownModel(
    providerModelId: 'models/gemini-2.5-flash',
    name: 'Gemini 2.5 Flash',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Fast multimodal model with reasoning capabilities optimized for speed',
  ),
  KnownModel(
    providerModelId: 'models/gemini-2.0-flash',
    name: 'Gemini 2.0 Flash',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'Fast & legacy multimodal model without reasoning capabilities optimized for speed',
  ),
];

/// Nebius models - High-performance text and image models
const List<KnownModel> nebiusModels = [
  KnownModel(
    providerModelId: 'openai/gpt-oss-20b',
    name: 'Nebius gpt-oss 20B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'State-of-the-art open weights model from OpenAI, small variant.',
  ),
  KnownModel(
    providerModelId: 'openai/gpt-oss-120b',
    name: 'Nebius gpt-oss 120B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'State-of-the-art open weights model from OpenAI, large variant.',
  ),
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
  KnownModel(
    providerModelId: 'Qwen/Qwen3-235B-A22B',
    name: 'Qwen3 235B A22B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Qwen3 is the latest generation of large language models in Qwen '
        'series, offering a comprehensive suite of dense and mixture-of-experts '
        '(MoE) models.',
  ),
];

/// Ollama models - Local models for privacy-focused processing
///
/// These models run locally using Ollama and provide privacy-focused AI capabilities.
/// They don't require internet connectivity or API keys, making them suitable for
/// sensitive data processing.
///
/// Note: Users must install these models locally using `ollama pull <model_name>`
/// before they can be used in the application.
const List<KnownModel> ollamaModels = [
  KnownModel(
    providerModelId: 'gemma3:4b',
    name: 'Gemma 3 4B',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Efficient local text & image model, great for image analysis. '
        'Requires approximately 4GB RAM and provides good performance for most tasks.',
  ),
  KnownModel(
    providerModelId: 'gpt-oss:20b',
    name: 'Ollama gpt-oss 20B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'State-of-the-art open weights model from OpenAI, small variant.',
  ),
  KnownModel(
    providerModelId: 'gpt-oss:120b',
    name: 'Ollama gpt-oss 120B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'State-of-the-art open weights model from OpenAI, large variant.',
  ),
  KnownModel(
    providerModelId: 'gemma3:12b',
    name: 'Gemma 3 12B',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description: 'Larger local text & image model with improved capabilities. '
        'Requires approximately 12GB RAM for optimal performance.',
  ),
  KnownModel(
    providerModelId: 'gemma3:12b-it-qat',
    name: 'Gemma 3 12B QAT',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Quantized version of Gemma 3 12B with smaller memory footprint. '
        'Requires approximately 8GB RAM while maintaining good performance.',
  ),
  KnownModel(
    providerModelId: 'deepseek-r1:8b',
    name: 'DeepSeek R1 8B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Local reasoning model for complex analysis tasks. '
        'Provides advanced reasoning capabilities.',
  ),
  KnownModel(
    providerModelId: 'qwen3:8b',
    name: 'Qwen3 8B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Qwen3 is the latest generation of large language models in Qwen '
        'series, offering a comprehensive suite of dense and mixture-of-experts '
        '(MoE) models.',
  ),
];

/// OpenAI models - Advanced language and multimodal models
const List<KnownModel> openaiModels = [
  KnownModel(
    providerModelId: 'gpt-4.1-2025-04-14',
    name: 'GPT-4.1',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description: 'Flagship GPT model for complex tasks',
  ),
  KnownModel(
    providerModelId: 'o3-2025-04-16',
    name: 'o3',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Our most powerful reasoning model',
  ),
  KnownModel(
    providerModelId: 'o4-mini-2025-04-16',
    name: 'o4-mini',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Faster, more affordable reasoning model',
  ),
];

/// Anthropic models - Advanced language and multimodal models
const List<KnownModel> anthropicModels = [
  KnownModel(
    providerModelId: 'claude-opus-4-20250514',
    name: 'Claude Opus 4',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Highest level of intelligence and capability',
    maxCompletionTokens: 2000,
  ),
  KnownModel(
    providerModelId: 'claude-sonnet-4-20250514',
    name: 'Claude Sonnet 4',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'High intelligence and balanced performance',
    maxCompletionTokens: 2000,
  ),
  KnownModel(
    providerModelId: 'claude-3-5-haiku-20241022',
    name: 'Claude Haiku 3.5',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description: 'Intelligence at blazing speeds',
    maxCompletionTokens: 2000,
  ),
];

/// Generic OpenAI-compatible models (for custom endpoints like AI proxies)
///
/// These models work with any OpenAI-compatible API endpoint, including:
/// - AI Proxy (our Gemini proxy with billing tracking)
/// - Local LLM servers (LM Studio, LocalAI, etc.)
/// - Other cloud providers with OpenAI-compatible APIs
const List<KnownModel> genericOpenAiModels = [
  KnownModel(
    providerModelId: 'gemini-pro',
    name: 'Gemini Pro (via Proxy)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Gemini 2.5 Pro via AI Proxy with billing tracking',
  ),
  KnownModel(
    providerModelId: 'gemini-flash',
    name: 'Gemini Flash (via Proxy)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Gemini 2.5 Flash via AI Proxy with billing tracking',
  ),
  KnownModel(
    providerModelId: 'gpt-4',
    name: 'GPT-4 Compatible',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'OpenAI GPT-4 or compatible model (maps to Gemini 2.5 Pro in AI Proxy)',
  ),
  KnownModel(
    providerModelId: 'gpt-3.5-turbo',
    name: 'GPT-3.5 Compatible',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'OpenAI GPT-3.5 or compatible model (maps to Gemini 2.5 Flash in AI Proxy)',
  ),
];

/// OpenRouter models - Advanced language and multimodal models
const List<KnownModel> openRouterModels = [
  KnownModel(
    providerModelId: 'anthropic/claude-opus-4',
    name: 'Anthropic: Claude Opus 4',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Highest level of intelligence and capability',
  ),
  KnownModel(
    providerModelId: 'anthropic/claude-sonnet-4',
    name: 'Anthropic: Claude Sonnet 4',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'High intelligence and balanced performance',
  ),
  KnownModel(
    providerModelId: 'openai/o4-mini',
    name: 'OpenAI: o4 Mini',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'OpenAI o4-mini is a compact reasoning model in the o-series.',
  ),
  KnownModel(
    providerModelId: 'openai/o4-mini-high',
    name: 'OpenAI: o4 Mini High',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'OpenAI o4-mini-high is the same model as o4-mini with reasoning_effort set to high',
  ),
  KnownModel(
    providerModelId: 'openai/gpt-4.1',
    name: 'OpenAI: GPT-4.1',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'GPT-4.1 is a flagship large language model optimized for advanced instruction following, real-world software engineering, and long-context reasoning.',
  ),
];

/// Whisper models (running locally)
const List<KnownModel> whisperModels = [
  KnownModel(
    providerModelId: 'whisper-small',
    name: 'Whisper Local Small',
    inputModalities: [Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description: 'Relatively accurate for simple audio',
  ),
  KnownModel(
    providerModelId: 'whisper-medium',
    name: 'Whisper Local Medium',
    inputModalities: [Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description: 'Balanced Whisper model, good for general use',
  ),
  KnownModel(
    providerModelId: 'whisper-large',
    name: 'Whisper Local Large',
    inputModalities: [Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description: 'Most accurate local Whisper model',
  ),
];

/// Generates a unique model ID based on provider ID and model ID
String generateModelId(String inferenceProviderId, String providerModelId) {
  // Create a deterministic ID by combining provider and model IDs
  final combined = '${inferenceProviderId}_$providerModelId';
  // Replace problematic characters for IDs
  return combined.replaceAll(RegExp(r'[/:\-.]'), '_').toLowerCase();
}
