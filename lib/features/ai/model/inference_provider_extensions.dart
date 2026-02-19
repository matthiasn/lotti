import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

extension InferenceProviderTypeExtension on InferenceProviderType {
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
      case InferenceProviderType.mistral:
        return context.messages.aiProviderMistralName;
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

  String description(BuildContext context) {
    switch (this) {
      case InferenceProviderType.alibaba:
        return context.messages.aiProviderAlibabaDescription;
      case InferenceProviderType.anthropic:
        return context.messages.aiProviderAnthropicDescription;
      case InferenceProviderType.gemini:
        return context.messages.aiProviderGeminiDescription;
      case InferenceProviderType.genericOpenAi:
        return context.messages.aiProviderGenericOpenAiDescription;
      case InferenceProviderType.mistral:
        return context.messages.aiProviderMistralDescription;
      case InferenceProviderType.openAi:
        return context.messages.aiProviderOpenAiDescription;
      case InferenceProviderType.nebiusAiStudio:
        return context.messages.aiProviderNebiusAiStudioDescription;
      case InferenceProviderType.openRouter:
        return context.messages.aiProviderOpenRouterDescription;
      case InferenceProviderType.ollama:
        return context.messages.aiProviderOllamaDescription;
      case InferenceProviderType.whisper:
        return context.messages.aiProviderWhisperDescription;
      case InferenceProviderType.voxtral:
        return context.messages.aiProviderVoxtralDescription;
    }
  }

  IconData get icon {
    switch (this) {
      case InferenceProviderType.alibaba:
        return Icons.cloud_queue;
      case InferenceProviderType.anthropic:
        return Icons.auto_awesome;
      case InferenceProviderType.openAi:
        return Icons.psychology;
      case InferenceProviderType.gemini:
        return Icons.diamond;
      case InferenceProviderType.mistral:
        return Icons.record_voice_over;
      case InferenceProviderType.openRouter:
        return Icons.hub;
      case InferenceProviderType.ollama:
        return Icons.computer;
      case InferenceProviderType.genericOpenAi:
        return Icons.cloud;
      case InferenceProviderType.nebiusAiStudio:
        return Icons.rocket_launch;
      case InferenceProviderType.whisper:
        return Icons.mic;
      case InferenceProviderType.voxtral:
        return Icons.graphic_eq;
    }
  }

  /// Whether this provider requires audio data wrapped in a data URI
  /// (`data:;base64,...`) instead of raw base64.
  ///
  /// DashScope (Alibaba) requires this format with an intentionally empty
  /// MIME type. See: https://github.com/pydantic/pydantic-ai/issues/3530
  bool get requiresDataUriForAudio => this == InferenceProviderType.alibaba;
}
