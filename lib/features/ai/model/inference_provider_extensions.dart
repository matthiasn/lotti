import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Presentation helpers for [InferenceProviderType] — localized labels, the
/// settings icon, and provider-specific request quirks.
extension InferenceProviderTypeExtension on InferenceProviderType {
  /// Localized human-readable name for this provider (e.g. "OpenAI",
  /// "Gemini"). Requires a [BuildContext] to reach the l10n messages.
  String displayName(BuildContext context) {
    switch (this) {
      case InferenceProviderType.alibaba:
        return context.messages.aiProviderAlibabaName;
      case InferenceProviderType.anthropic:
        return context.messages.aiProviderAnthropicName;
      case InferenceProviderType.gemini:
        return context.messages.aiProviderGeminiName;
      case InferenceProviderType.genericOpenAi:
        return context.messages.aiProviderGenericOpenAiName;
      case InferenceProviderType.melious:
        return context.messages.aiProviderMeliousName;
      case InferenceProviderType.mistral:
        return context.messages.aiProviderMistralName;
      case InferenceProviderType.mlxAudio:
        return context.messages.aiProviderMlxAudioName;
      case InferenceProviderType.omlx:
        return context.messages.aiProviderOmlxName;
      case InferenceProviderType.openAi:
        return context.messages.aiProviderOpenAiName;
      case InferenceProviderType.nebiusAiStudio:
        return context.messages.aiProviderNebiusAiStudioName;
      case InferenceProviderType.openRouter:
        return context.messages.aiProviderOpenRouterName;
      case InferenceProviderType.ollama:
        return context.messages.aiProviderOllamaName;
      case InferenceProviderType.whisper:
        return context.messages.aiProviderWhisperName;
      case InferenceProviderType.voxtral:
        return context.messages.aiProviderVoxtralName;
    }
  }

  /// Material icon used to represent this provider in legacy settings rows.
  /// (The v2 cards use `aiProviderIcon` from `ai_provider_visual.dart`.)
  IconData get icon {
    switch (this) {
      case InferenceProviderType.alibaba:
        return LottiIcons.cloud;
      case InferenceProviderType.anthropic:
        return LottiIcons.aiSpark;
      case InferenceProviderType.openAi:
        return LottiIcons.reasoning;
      case InferenceProviderType.gemini:
        return LottiIcons.gem;
      case InferenceProviderType.melious:
        return LottiIcons.eco;
      case InferenceProviderType.mistral:
        return LottiIcons.voice;
      case InferenceProviderType.mlxAudio:
        return LottiIcons.memory;
      case InferenceProviderType.omlx:
        return LottiIcons.memory;
      case InferenceProviderType.openRouter:
        return LottiIcons.hub;
      case InferenceProviderType.ollama:
        return LottiIcons.computer;
      case InferenceProviderType.genericOpenAi:
        return LottiIcons.cloud;
      case InferenceProviderType.nebiusAiStudio:
        return LottiIcons.rocket;
      case InferenceProviderType.whisper:
        return LottiIcons.mic;
      case InferenceProviderType.voxtral:
        return LottiIcons.waveform;
    }
  }

  /// Whether this provider requires audio data wrapped in a data URI
  /// (`data:;base64,...`) instead of raw base64.
  ///
  /// DashScope (Alibaba) requires this format with an intentionally empty
  /// MIME type. See: https://github.com/pydantic/pydantic-ai/issues/3530
  bool get requiresDataUriForAudio => this == InferenceProviderType.alibaba;
}
