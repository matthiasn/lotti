/// Known model configurations for different inference providers.
///
/// This file contains predefined model configurations that are automatically
/// populated when a new inference provider is created. Each model includes
/// its provider-specific ID, capabilities, and a brief description.
///
/// The models are organized by provider:
/// - Alibaba Cloud: Qwen and Wan models via DashScope
/// - Gemini: Google's models with multi-modal capabilities
/// - LLMBase: European OpenAI-compatible inference models
/// - Local providers: Ollama, MLX Audio, Voxtral, and Whisper
/// - Mistral, Nebius, OpenAI, OpenRouter, and Anthropic cloud models
library;

import 'dart:ui';

import 'package:collection/collection.dart';
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
  InferenceProviderType.alibaba: alibabaModels,
  InferenceProviderType.gemini: geminiModels,
  InferenceProviderType.llmBase: llmBaseModels,
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

/// LLMBase models - European/GDPR-focused OpenAI-compatible inference.
///
/// LLMBase's model registry advertises capabilities per model and returns a
/// 400 response when a request includes unsupported advanced features such as
/// `tools`. Keep the tool-calling flags conservative so agent profiles only
/// offer models that LLMBase documents for agent/tool workflows.
const List<KnownModel> llmBaseModels = [
  KnownModel(
    providerModelId: 'deepseek/deepseek-v4-flash',
    name: 'DeepSeek V4 Flash',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Efficient long-context model recommended by LLMBase for coding '
        'agents and tool-calling workflows.',
  ),
  KnownModel(
    providerModelId: 'z-ai/glm-5.1',
    name: 'GLM 5.1',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Next-generation GLM model recommended by LLMBase for agentic '
        'engineering, coding performance, and long-context repository work.',
  ),
  KnownModel(
    providerModelId: 'qwen/qwen3-coder',
    name: 'Qwen3 Coder',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Qwen coding model recommended by LLMBase for coding agents and '
        'tool-calling workloads.',
  ),
  KnownModel(
    providerModelId: 'moonshotai/kimi-k2.6',
    name: 'Kimi K2.6',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'MoonshotAI multimodal model on LLMBase for image understanding, '
        'coding-driven UI work, and long-horizon reasoning.',
  ),
  KnownModel(
    providerModelId: 'qwen/qwen3.6-35b-a3b',
    name: 'Qwen3.6 35B A3B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'Qwen3.6 MoE model for text reasoning, coding, multilingual tasks, '
        'and everyday inference on LLMBase. LLMBase does not advertise tools '
        'for this model, so it is not offered as an agent thinking model.',
  ),
  KnownModel(
    providerModelId: 'qwen/qwen3.5-35b-a3b',
    name: 'Qwen3.5 35B A3B',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description:
        'Mid-sized Qwen MoE model for fast everyday inference on LLMBase.',
  ),
];

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

/// MLX Audio models embedded via the Apple Swift SDK.
///
/// These run in-process on Apple Silicon through `mlx-audio-swift` rather than
/// through a localhost service. x86 macOS can keep the provider configured, but
/// the native bridge reports the models as unsupported on that architecture.
const List<KnownModel> mlxAudioModels = [
  KnownModel(
    providerModelId: mlxAudioQwenAsr17B8BitModelId,
    name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Recommended local STT model for MLX Audio. Larger multilingual '
        'Qwen3-ASR checkpoint converted for MLX, with category '
        'speech-dictionary terms passed through the prompt context.',
  ),
  KnownModel(
    providerModelId: mlxAudioQwenAsr17B4BitModelId,
    name: 'Qwen3 ASR 1.7B (MLX 4-bit)',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Larger multilingual Qwen3-ASR checkpoint converted for MLX. Lower '
        'memory footprint than the 8-bit variant while retaining the '
        'same post-recording speech-dictionary prompt context path.',
  ),
  KnownModel(
    providerModelId: mlxAudioQwenAsrModelId,
    name: 'Qwen3 ASR 0.6B (MLX 8-bit)',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Compact multilingual ASR model. Lotti passes category speech-dictionary '
        'terms through the Qwen prompt context for post-recording transcription.',
  ),
  KnownModel(
    providerModelId: mlxAudioVoxtralRealtime4BitModelId,
    name: 'Voxtral Mini Realtime 4B (MLX 4-bit)',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'On-device Voxtral Realtime transcription via MLX Audio Swift. '
        'Quantized checkpoint kept as an explicit comparison target for '
        'multilingual local transcription.',
  ),
  KnownModel(
    providerModelId: mlxAudioVoxtralRealtimeFp16ModelId,
    name: 'Voxtral Mini Realtime 4B (MLX fp16)',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Full-precision MLX conversion of Voxtral Realtime for Apple Silicon. '
        'Use this larger checkpoint when comparing quality against the '
        'quantized default.',
  ),
  KnownModel(
    providerModelId: mlxAudioParakeetModelId,
    name: 'Parakeet TDT 0.6B v3 (MLX)',
    inputModalities: [Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Efficient NVIDIA Parakeet ASR checkpoint converted for MLX. Useful as '
        'a smaller local transcription baseline against Voxtral and Qwen3-ASR.',
  ),
  KnownModel(
    providerModelId: mlxAudioDefaultTtsModelId,
    name: 'Qwen3 TTS 0.6B Base (MLX 8-bit)',
    inputModalities: [Modality.text],
    outputModalities: [Modality.audio],
    isReasoningModel: false,
    description:
        'On-device text-to-speech model for reading AI summaries locally via '
        'MLX Audio Swift.',
  ),
];

/// Alibaba Cloud models - Qwen family via DashScope (OpenAI-compatible)
///
/// These models run on Alibaba Cloud's DashScope API, which is fully
/// OpenAI-compatible. They include text, vision, and reasoning models.
/// API keys are obtained from the Alibaba Cloud Model Studio console.
const List<KnownModel> alibabaModels = [
  KnownModel(
    providerModelId: 'qwen3-max',
    name: 'Qwen3 Max',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Top-tier Qwen3 MoE model with 1T parameters. Best for complex '
        'reasoning, analysis, and generation tasks.',
  ),
  KnownModel(
    providerModelId: 'qwen3.5-plus',
    name: 'Qwen 3.5 Plus',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Advanced multimodal reasoning model with text and image '
        'understanding, strong analytical capabilities, and '
        'support for complex coding, math, and generation tasks.',
  ),
  KnownModel(
    providerModelId: 'qwen-flash',
    name: 'Qwen Flash',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'Fast and affordable model optimized for speed. Great for quick '
        'tasks, summaries, and high-throughput workloads.',
  ),
  KnownModel(
    providerModelId: 'qwen3-vl-plus',
    name: 'Qwen3 VL Plus',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'Top vision-language model with image understanding. Supports '
        'multiple images per request via standard OpenAI vision format.',
  ),
  KnownModel(
    providerModelId: 'qwen3-vl-flash',
    name: 'Qwen3 VL Flash',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'Fast vision-language model for efficient image analysis and '
        'visual question answering.',
  ),
  KnownModel(
    providerModelId: 'qwen3-omni-flash',
    name: 'Qwen3 Omni Flash',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'Multimodal model with audio understanding. Supports up to '
        '20 minutes of audio for transcription and analysis. '
        'Accepts AMR, WAV, AAC, and MP3 formats.',
  ),
  KnownModel(
    providerModelId: 'wan2.6-image',
    name: 'Wan 2.6 Image',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text, Modality.image],
    isReasoningModel: false,
    description:
        'Image generation model from the Wan family. Generates '
        'high-quality images from text prompts via DashScope native API. '
        'Supports sizes up to 1920x1080 with 16:9 aspect ratio.',
  ),
];

/// Gemini models - Google's multimodal AI models
const List<KnownModel> geminiModels = [
  KnownModel(
    providerModelId: 'models/gemini-3-pro-image-preview',
    name: 'Gemini 3 Pro Image (Nano Banana Pro)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text, Modality.image],
    isReasoningModel: false,
    description:
        'High-quality image generation model for cover art and visual mnemonics. '
        'Generates images directly from task context and voice descriptions.',
  ),
  KnownModel(
    providerModelId: 'models/gemini-3.1-pro-preview',
    name: 'Gemini 3.1 Pro Preview',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Latest Gemini 3.1 with enhanced reasoning, multimodal capabilities, '
        'and function calling support for agentic workflows',
  ),
  KnownModel(
    providerModelId: 'models/gemini-3-flash-preview',
    name: 'Gemini 3 Flash Preview',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Fast and efficient Gemini 3 model optimized for speed and cost-effectiveness with multimodal capabilities',
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
  // Qwen 3.5 — native multimodal with reasoning and tool calling
  KnownModel(
    providerModelId: 'qwen3.5:9b',
    name: 'Qwen 3.5 9B',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Native multimodal model with reasoning and tool calling. '
        '6.6GB download, ~10GB RAM. 256K context. '
        'Best local model for lower-end devices.',
  ),
  KnownModel(
    providerModelId: 'qwen3.5:27b',
    name: 'Qwen 3.5 27B',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Native multimodal model with reasoning and tool calling. '
        '17GB download, ~22GB RAM. 256K context. '
        'Best local model for higher-end devices (22GB+ RAM).',
  ),
  // Qwen 3.6 — MoE reasoning/coding model, text-only. Pair with
  // Qwen 3.5 27B for image recognition in the Local Power profile.
  KnownModel(
    providerModelId: 'qwen3.6:35b-a3b-coding-nvfp4',
    name: 'Qwen 3.6 35B-A3B Coding (NVFP4)',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'MoE reasoning/coding model: 35B total, ~3B active. '
        '22GB download (NVFP4 quant). 256K context. '
        'Text-only — pair with Qwen 3.5 27B for image recognition.',
  ),

  // Gemma 4 — multimodal with reasoning and tool calling
  KnownModel(
    providerModelId: 'gemma4:e4b',
    name: 'Gemma 4 E4B',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Efficient edge model with 4.5B effective parameters. '
        '9.6GB download, ~12GB RAM. 128K context. '
        'Vision, reasoning, and tool calling.',
  ),
  KnownModel(
    providerModelId: 'gemma4:26b',
    name: 'Gemma 4 26B MoE',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Sparse MoE model with only 3.8B active parameters out of 25.2B total. '
        '18GB download, ~22GB RAM. 256K context. '
        'Near-frontier quality at efficient inference speed.',
  ),
  KnownModel(
    providerModelId: 'gemma4:31b',
    name: 'Gemma 4 31B',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Dense 30.7B model with best benchmark scores. '
        '20GB download, ~24GB RAM. 256K context. '
        'Vision, reasoning, and tool calling.',
  ),

  // Embeddings
  KnownModel(
    providerModelId: 'mxbai-embed-large',
    name: 'mxbai-embed-large (Embeddings)',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Text embedding model with 1024 dimensions for semantic search. '
        'Used for finding related entries and improving search results.',
  ),
];

/// OpenAI models - Advanced language and multimodal models
const List<KnownModel> openaiModels = [
  KnownModel(
    providerModelId: 'gpt-5-nano',
    name: 'GPT-5 Nano',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'Fastest and most affordable GPT-5 model. Great for summarization and classification.',
  ),
  KnownModel(
    providerModelId: 'gpt-5.2',
    name: 'GPT-5.2',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Flagship model for coding and agentic tasks. Best for complex work requiring broad knowledge.',
  ),
  KnownModel(
    providerModelId: 'gpt-4o-transcribe',
    name: 'GPT-4o Transcribe',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Premium transcription model with best-in-class word error rate.',
  ),
  KnownModel(
    providerModelId: 'gpt-image-1.5',
    name: 'GPT Image 1.5',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text, Modality.image],
    isReasoningModel: false,
    description:
        'Latest image generation with better instruction following, text rendering, and 4x faster.',
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

/// Voxtral models - Mistral's speech-to-text models (running locally)
///
/// These models run locally using the Voxtral service and provide high-quality
/// audio transcription with support for up to 30 minutes of audio and 9 languages.
/// They use an OpenAI-compatible chat completions API with context support,
/// allowing speech dictionaries and task context to be passed for improved accuracy.
///
/// Note: Users must download these models using the service's model pull endpoint
/// before they can be used in the application.
const List<KnownModel> voxtralModels = [
  KnownModel(
    providerModelId: 'mistralai/Voxtral-Mini-3B-2507',
    name: 'Voxtral Mini 3B',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Efficient local transcription model designed for edge deployment. '
        'Supports up to 30 minutes of audio with 9 languages (auto-detected). '
        'Requires approximately 9.5GB VRAM.',
  ),
  KnownModel(
    providerModelId: 'mistralai/Voxtral-Small-24B-2507',
    name: 'Voxtral Small 24B',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'High-accuracy transcription model for production use. '
        'Supports up to 30 minutes of audio with 9 languages (auto-detected). '
        'Requires approximately 55GB VRAM (multi-GPU recommended).',
  ),
];

/// Mistral models - Mistral AI cloud models
///
/// These models run on Mistral's cloud API (api.mistral.ai) and include
/// language models, reasoning models, and audio transcription capabilities.
/// Audio files (M4A, MP3, WAV, FLAC, OGG) are sent natively without conversion.
const List<KnownModel> mistralModels = [
  // Fast model - efficient for quick tasks
  KnownModel(
    providerModelId: 'mistral-small-2501',
    name: 'Mistral Small 3.1',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    description:
        'Fast and efficient model with vision capabilities. '
        'Great for summaries, image analysis, and quick tasks.',
  ),
  // Reasoning model - for complex tasks
  KnownModel(
    providerModelId: 'magistral-medium-2509',
    name: 'Magistral Medium 1.2',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Frontier-class multimodal reasoning model with 128k context. '
        'Supports function calling, vision, and document AI.',
  ),
  // Audio transcription model — uses /v1/audio/transcriptions endpoint
  KnownModel(
    providerModelId: 'voxtral-mini-latest',
    name: 'Voxtral Mini Transcribe',
    inputModalities: [Modality.text, Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'High-accuracy cloud transcription model. '
        'Supports M4A, MP3, WAV, FLAC, and OGG up to 1 GB. '
        'Up to 3 hours of audio with 13 languages, speaker diarization, '
        'and context biasing.',
  ),
  // Real-time transcription model — uses WebSocket streaming endpoint
  KnownModel(
    providerModelId: 'voxtral-mini-transcribe-realtime-2602',
    name: 'Voxtral Realtime',
    inputModalities: [Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    description:
        'Real-time streaming transcription via WebSocket. '
        'Low-latency live subtitles (~2s delay). No diarization.',
  ),
];

/// Generates a unique model ID based on provider ID and model ID
String generateModelId(String inferenceProviderId, String providerModelId) {
  // Create a deterministic ID by combining provider and model IDs
  final combined = '${inferenceProviderId}_$providerModelId';
  // Replace problematic characters for IDs
  return combined.replaceAll(RegExp(r'[/:\-.]'), '_').toLowerCase();
}

// =============================================================================
// FTUE (First Time User Experience) Model Constants
// =============================================================================

/// Model IDs used for Gemini FTUE automation
const ftueFlashModelId = 'models/gemini-3-flash-preview';
const ftueProModelId = 'models/gemini-3.1-pro-preview';
const ftueImageModelId = 'models/gemini-3-pro-image-preview';

/// Finds a KnownModel by its provider model ID from the geminiModels list.
/// Returns null if not found.
KnownModel? findGeminiKnownModel(String providerModelId) {
  for (final model in geminiModels) {
    if (model.providerModelId == providerModelId) {
      return model;
    }
  }
  return null;
}

/// Returns the three KnownModel configurations needed for Gemini FTUE.
/// - Flash model for fast text/audio/image input tasks
/// - Pro model for reasoning tasks
/// - Image model (Nano Banana Pro) for image generation output
({KnownModel flash, KnownModel pro, KnownModel image})? getFtueKnownModels() {
  final flash = findGeminiKnownModel(ftueFlashModelId);
  final pro = findGeminiKnownModel(ftueProModelId);
  final image = findGeminiKnownModel(ftueImageModelId);

  if (flash == null || pro == null || image == null) {
    return null;
  }

  return (flash: flash, pro: pro, image: image);
}

// =============================================================================
// OpenAI FTUE (First Time User Experience) Model Constants
// =============================================================================

/// Model IDs used for OpenAI FTUE automation
const ftueOpenAiReasoningModelId = 'gpt-5.2';
const ftueOpenAiFlashModelId = 'gpt-5-nano';
const ftueOpenAiAudioModelId = 'gpt-4o-transcribe';
const ftueOpenAiImageModelId = 'gpt-image-1.5';

/// Finds a KnownModel by its provider model ID from the openaiModels list.
/// Returns null if not found.
KnownModel? findOpenAiKnownModel(String providerModelId) {
  for (final model in openaiModels) {
    if (model.providerModelId == providerModelId) {
      return model;
    }
  }
  return null;
}

/// Returns the four KnownModel configurations needed for OpenAI FTUE.
/// - Flash model (GPT-5 Nano) for fast processing tasks
/// - Reasoning model (GPT-5.2) for complex reasoning tasks
/// - Audio model (GPT-4o Transcribe) for transcription
/// - Image model (GPT Image 1.5) for image generation output
({
  KnownModel flash,
  KnownModel reasoning,
  KnownModel audio,
  KnownModel image,
})?
getOpenAiFtueKnownModels() {
  final flash = findOpenAiKnownModel(ftueOpenAiFlashModelId);
  final reasoning = findOpenAiKnownModel(ftueOpenAiReasoningModelId);
  final audio = findOpenAiKnownModel(ftueOpenAiAudioModelId);
  final image = findOpenAiKnownModel(ftueOpenAiImageModelId);

  if (flash == null || reasoning == null || audio == null || image == null) {
    return null;
  }

  return (flash: flash, reasoning: reasoning, audio: audio, image: image);
}

// =============================================================================
// FTUE Category Constants (shared across all providers)
// =============================================================================

/// Category names for FTUE test categories
const ftueAlibabaCategoryName = 'Test Category Alibaba Enabled';
const ftueAnthropicCategoryName = 'Test Category Anthropic Enabled';
const ftueGeminiCategoryName = 'Test Category Gemini Enabled';
const ftueOllamaCategoryName = 'Test Category Ollama Enabled';
const ftueOpenAiCategoryName = 'Test Category OpenAI Enabled';
const ftueMistralCategoryName = 'Test Category Mistral Enabled';

/// Brand colors for FTUE test categories (hex format)
const ftueAlibabaCategoryColor = '#FF6D00'; // Alibaba Orange
const ftueAnthropicCategoryColor = '#D97757'; // Anthropic Cinnamon
const ftueGeminiCategoryColor = '#4285F4'; // Google Blue
const ftueOllamaCategoryColor = '#0F172A'; // Ollama Charcoal
const ftueOpenAiCategoryColor = '#10A37F'; // OpenAI Green
const ftueMistralCategoryColor = '#FF7000'; // Mistral Orange

/// Brand colors as Color constants for UI usage.
///
/// New UI surfaces should prefer `tokens.colors.aiProvider.*` from the
/// design-system tokens. These constants remain only because
/// `ai_provider_selection_modal.dart` has not migrated yet.
const ftueGeminiColor = Color(0xFF4285F4);
const ftueMlxAudioColor = Color(0xFF00BCD4);
const ftueOpenAiColor = Color(0xFF10A37F);
const ftueMistralColor = Color(0xFFFF7000);

// =============================================================================
// Alibaba FTUE (First Time User Experience) Model Constants
// =============================================================================

/// Model IDs used for Alibaba FTUE automation
const ftueAlibabaFlashModelId = 'qwen-flash';
const ftueAlibabaReasoningModelId = 'qwen3.5-plus';
const ftueAlibabaAudioModelId = 'qwen3-omni-flash';
const ftueAlibabaVisionModelId = 'qwen3-vl-flash';
const ftueAlibabaImageModelId = 'wan2.6-image';

/// Finds a KnownModel by its provider model ID from the alibabaModels list.
/// Returns null if not found.
KnownModel? findAlibabaKnownModel(String providerModelId) {
  return alibabaModels.firstWhereOrNull(
    (model) => model.providerModelId == providerModelId,
  );
}

/// Returns the five KnownModel configurations needed for Alibaba FTUE.
/// - Flash model (Qwen Flash) for fast processing tasks
/// - Reasoning model (Qwen3 Max) for complex reasoning tasks
/// - Audio model (Qwen3 Omni Flash) for transcription
/// - Vision model (Qwen3 VL Flash) for image analysis
/// - Image model (Wan 2.6 Image) for cover art generation
({
  KnownModel flash,
  KnownModel reasoning,
  KnownModel audio,
  KnownModel vision,
  KnownModel image,
})?
getAlibabaFtueKnownModels() {
  final flash = findAlibabaKnownModel(ftueAlibabaFlashModelId);
  final reasoning = findAlibabaKnownModel(ftueAlibabaReasoningModelId);
  final audio = findAlibabaKnownModel(ftueAlibabaAudioModelId);
  final vision = findAlibabaKnownModel(ftueAlibabaVisionModelId);
  final image = findAlibabaKnownModel(ftueAlibabaImageModelId);

  if (flash == null ||
      reasoning == null ||
      audio == null ||
      vision == null ||
      image == null) {
    return null;
  }

  return (
    flash: flash,
    reasoning: reasoning,
    audio: audio,
    vision: vision,
    image: image,
  );
}

// =============================================================================
// Mistral FTUE (First Time User Experience) Model Constants
// =============================================================================

/// Model IDs used for Mistral FTUE automation
const ftueMistralFlashModelId = 'mistral-small-2501';
const ftueMistralReasoningModelId = 'magistral-medium-2509';
const ftueMistralAudioModelId = 'voxtral-mini-latest';

/// Finds a KnownModel by its provider model ID from the mistralModels list.
/// Returns null if not found.
KnownModel? findMistralKnownModel(String providerModelId) {
  return mistralModels.firstWhereOrNull(
    (model) => model.providerModelId == providerModelId,
  );
}

/// Returns the three KnownModel configurations needed for Mistral FTUE.
/// - Flash model (Mistral Small) for fast processing tasks
/// - Reasoning model (Magistral Medium) for complex reasoning tasks
/// - Audio model (Voxtral Mini Transcribe) for transcription
/// Note: Mistral does not have a native image generation model.
({
  KnownModel flash,
  KnownModel reasoning,
  KnownModel audio,
})?
getMistralFtueKnownModels() {
  final flash = findMistralKnownModel(ftueMistralFlashModelId);
  final reasoning = findMistralKnownModel(ftueMistralReasoningModelId);
  final audio = findMistralKnownModel(ftueMistralAudioModelId);

  if (flash == null || reasoning == null || audio == null) {
    return null;
  }

  return (flash: flash, reasoning: reasoning, audio: audio);
}

// =============================================================================
// Anthropic FTUE (First Time User Experience) Model Constants
// =============================================================================

/// Model IDs used for Anthropic FTUE automation.
/// Pair: Sonnet for reasoning/thinking, Haiku for fast / cheap calls.
const ftueAnthropicReasoningModelId = 'claude-sonnet-4-20250514';
const ftueAnthropicFlashModelId = 'claude-3-5-haiku-20241022';

/// Finds a KnownModel by its provider model ID from the anthropicModels list.
/// Returns null if not found.
KnownModel? findAnthropicKnownModel(String providerModelId) {
  return anthropicModels.firstWhereOrNull(
    (model) => model.providerModelId == providerModelId,
  );
}

/// Returns the two KnownModel configurations needed for Anthropic FTUE.
/// - Reasoning model (Claude Sonnet 4) for complex thinking tasks
/// - Flash model (Claude Haiku 3.5) for fast / cheap calls
///
/// Anthropic does not ship native audio transcription or image generation
/// models, so those skill slots stay unbound on the seeded profile and the
/// user can wire them to a different provider's model later.
({KnownModel reasoning, KnownModel flash})? getAnthropicFtueKnownModels() {
  final reasoning = findAnthropicKnownModel(ftueAnthropicReasoningModelId);
  final flash = findAnthropicKnownModel(ftueAnthropicFlashModelId);

  if (reasoning == null || flash == null) {
    return null;
  }

  return (reasoning: reasoning, flash: flash);
}
