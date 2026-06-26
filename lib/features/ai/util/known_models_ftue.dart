import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:lotti/features/ai/util/known_models.dart';

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
const ftueMeliousCategoryName = 'Test Category Melious Enabled';
const ftueOllamaCategoryName = 'Test Category Ollama Enabled';
const ftueOpenAiCategoryName = 'Test Category OpenAI Enabled';
const ftueMistralCategoryName = 'Test Category Mistral Enabled';

/// Brand colors for FTUE test categories (hex format)
const ftueAlibabaCategoryColor = '#FF6D00'; // Alibaba Orange
const ftueAnthropicCategoryColor = '#D97757'; // Anthropic Cinnamon
const ftueGeminiCategoryColor = '#4285F4'; // Google Blue
const ftueMeliousCategoryColor = '#14B8A6'; // Melious Teal
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
// Melious FTUE (First Time User Experience) Model Constants
// =============================================================================

/// Model IDs used for Melious FTUE automation.
const String ftueMeliousThinkingModelId =
    meliousMistralSmall4119BInstructModelId;
const String ftueMeliousAdvancedThinkingModelId = meliousDeepseekV4ProModelId;
const String ftueMeliousImageGenerationModelId = meliousFlux2DevModelId;
const String ftueMeliousWhisperModelId = meliousWhisperLargeV3ModelId;
const String ftueMeliousWhisperTurboModelId = meliousWhisperLargeV3TurboModelId;

/// Finds a KnownModel by its provider model ID from the meliousModels list.
/// Returns null if not found.
KnownModel? findMeliousKnownModel(String providerModelId) {
  return meliousModels.firstWhereOrNull(
    (model) => model.providerModelId == providerModelId,
  );
}

/// Returns the KnownModel configurations needed for Melious FTUE.
/// - Thinking/vision model for the default Melious profile
/// - Advanced thinking model for the high-end slot
/// - Flux image generation model for cover art
/// - Whisper Large v3 and Turbo for speech-to-text testing
({
  KnownModel thinking,
  KnownModel advancedThinking,
  KnownModel imageGeneration,
  KnownModel whisper,
  KnownModel whisperTurbo,
})?
getMeliousFtueKnownModels() {
  final thinking = findMeliousKnownModel(ftueMeliousThinkingModelId);
  final advancedThinking = findMeliousKnownModel(
    ftueMeliousAdvancedThinkingModelId,
  );
  final imageGeneration = findMeliousKnownModel(
    ftueMeliousImageGenerationModelId,
  );
  final whisper = findMeliousKnownModel(ftueMeliousWhisperModelId);
  final whisperTurbo = findMeliousKnownModel(ftueMeliousWhisperTurboModelId);

  if (thinking == null ||
      advancedThinking == null ||
      imageGeneration == null ||
      whisper == null ||
      whisperTurbo == null) {
    return null;
  }

  return (
    thinking: thinking,
    advancedThinking: advancedThinking,
    imageGeneration: imageGeneration,
    whisper: whisper,
    whisperTurbo: whisperTurbo,
  );
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
