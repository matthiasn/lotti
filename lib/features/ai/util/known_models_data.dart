import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';

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

/// oMLX models served through the local OpenAI-compatible API.
///
/// Qwen3.6-35B-A3B and Gemma 4 26B A4B are multimodal, so these local MLX
/// variants are cataloged for both thinking and image recognition slots.
const List<KnownModel> omlxModels = [
  KnownModel(
    providerModelId: omlxQwen36A35bA3b4BitModelId,
    name: 'Qwen 3.6 35B-A3B (oMLX 4-bit)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Recommended local oMLX model for thinking, coding, tool use, and '
        'image recognition. 35B total parameters with about 3B active.',
  ),
  KnownModel(
    providerModelId: omlxQwen36A35bA3bTurboQuantMlx4BitModelId,
    name: 'Qwen 3.6 35B-A3B TurboQuant (oMLX 4-bit)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'TurboQuant 4-bit MLX conversion for local oMLX serving. Useful as a '
        'speed and memory comparison against the recommended 4-bit model.',
  ),
  KnownModel(
    providerModelId: omlxQwen36A35bA3bMlx8BitModelId,
    name: 'Qwen 3.6 35B-A3B (oMLX 8-bit)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Higher-precision MLX conversion for oMLX. Keep this explicit when '
        'comparing quality and memory use against the 4-bit variants.',
  ),
  KnownModel(
    providerModelId: omlxGemma426BA4BItQatMlx4BitModelId,
    name: 'Gemma 4 26B A4B QAT (oMLX 4-bit)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'QAT 4-bit MLX conversion for local oMLX serving. 26B total '
        'parameters with about 4B active, cataloged as a separate local '
        'Gemma reasoning and image-recognition option.',
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
  // Qwen 3.6 — MoE reasoning/coding model.
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
  // Default model for the Mistral profile — general tasks, agentic thinking,
  // and vision. Tracks the latest Mistral Medium release via the `-latest`
  // alias.
  KnownModel(
    providerModelId: 'mistral-medium-latest',
    name: 'Mistral Medium',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description:
        'Balanced mid-tier multimodal model. Used as the default for general '
        'tasks, agentic reasoning, and image analysis. Supports function '
        'calling and vision.',
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
