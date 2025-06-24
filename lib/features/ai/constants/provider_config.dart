import 'package:lotti/features/ai/model/ai_config.dart';

/// Configuration constants for different inference providers
class ProviderConfig {
  const ProviderConfig._();

  /// Default base URLs for each provider type
  static const Map<InferenceProviderType, String> defaultBaseUrls = {
    InferenceProviderType.gemini:
        'https://generativelanguage.googleapis.com/v1beta/openai',
    InferenceProviderType.nebiusAiStudio: 'https://api.studio.nebius.com/v1',
    InferenceProviderType.ollama: 'http://localhost:11434/v1',
    InferenceProviderType.openAi: 'https://api.openai.com/v1',
    InferenceProviderType.anthropic: 'https://api.anthropic.com/v1',
    InferenceProviderType.openRouter: 'https://openrouter.ai/api/v1',
    InferenceProviderType.fastWhisper: 'http://localhost:8083',
    InferenceProviderType.whisper: 'http://localhost:8084',
  };

  /// Default names for each provider type
  static const Map<InferenceProviderType, String> defaultNames = {
    InferenceProviderType.gemini: 'Gemini',
    InferenceProviderType.nebiusAiStudio: 'Nebius AI Studio',
    InferenceProviderType.ollama: 'Ollama (local)',
    InferenceProviderType.openAi: 'OpenAI',
    InferenceProviderType.anthropic: 'Anthropic',
    InferenceProviderType.openRouter: 'OpenRouter',
    InferenceProviderType.fastWhisper: 'FastWhisper (local)',
    InferenceProviderType.whisper: 'Whisper (local)',
  };

  /// Provider types that don't require an API key
  static const Set<InferenceProviderType> noApiKeyRequired = {
    InferenceProviderType.ollama,
    InferenceProviderType.fastWhisper,
    InferenceProviderType.whisper,
  };

  /// Get the default base URL for a provider type
  static String getDefaultBaseUrl(InferenceProviderType type) {
    return defaultBaseUrls[type] ?? '';
  }

  /// Get the default name for a provider type
  static String getDefaultName(InferenceProviderType type) {
    return defaultNames[type] ?? '';
  }

  /// Check if a provider type requires an API key
  static bool requiresApiKey(InferenceProviderType type) {
    return !noApiKeyRequired.contains(type);
  }
}
