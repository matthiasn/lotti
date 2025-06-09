import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

extension InferenceProviderTypeExtension on InferenceProviderType {
  String displayName(BuildContext context) {
    switch (this) {
      case InferenceProviderType.anthropic:
        return context.messages.aiProviderAnthropicName;
      case InferenceProviderType.gemini:
        return context.messages.aiProviderGeminiName;
      case InferenceProviderType.genericOpenAi:
        return context.messages.aiProviderGenericOpenAiName;
      case InferenceProviderType.openAi:
        return context.messages.aiProviderOpenAiName;
      case InferenceProviderType.nebiusAiStudio:
        return context.messages.aiProviderNebiusAiStudioName;
      case InferenceProviderType.openRouter:
        return context.messages.aiProviderOpenRouterName;
      case InferenceProviderType.ollama:
        return context.messages.aiProviderOllamaName;
      case InferenceProviderType.fastWhisper:
        return 'FastWhisper';
    }
  }

  String description(BuildContext context) {
    switch (this) {
      case InferenceProviderType.anthropic:
        return context.messages.aiProviderAnthropicDescription;
      case InferenceProviderType.gemini:
        return context.messages.aiProviderGeminiDescription;
      case InferenceProviderType.genericOpenAi:
        return context.messages.aiProviderGenericOpenAiDescription;
      case InferenceProviderType.openAi:
        return context.messages.aiProviderOpenAiDescription;
      case InferenceProviderType.nebiusAiStudio:
        return context.messages.aiProviderNebiusAiStudioDescription;
      case InferenceProviderType.openRouter:
        return context.messages.aiProviderOpenRouterDescription;
      case InferenceProviderType.ollama:
        return context.messages.aiProviderOllamaDescription;
      case InferenceProviderType.fastWhisper:
        return 'Local speech-to-text transcription using FastWhisper';
    }
  }

  IconData get icon {
    switch (this) {
      case InferenceProviderType.anthropic:
        return Icons.psychology;
      case InferenceProviderType.gemini:
        return Icons.diamond;
      case InferenceProviderType.genericOpenAi:
        return Icons.public;
      case InferenceProviderType.openAi:
        return Icons.smart_toy;
      case InferenceProviderType.nebiusAiStudio:
        return Icons.assistant;
      case InferenceProviderType.openRouter:
        return Icons.assistant;
      case InferenceProviderType.ollama:
        return Icons.assistant;
      case InferenceProviderType.fastWhisper:
        return Icons.mic;
    }
  }
}
