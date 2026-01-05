import 'package:lotti/features/ai/model/ai_config.dart';

/// Configuration constants for different inference providers
///
/// This class provides default configurations for various AI inference providers,
/// including base URLs, display names, and API key requirements.
///
/// Security Note: Local providers (Ollama, Whisper) use localhost URLs and don't
/// require API keys, making them suitable for privacy-focused applications.
class ProviderConfig {
  const ProviderConfig._();

  /// Default base URLs for each provider type
  ///
  /// These URLs are used as defaults when creating new provider configurations.
  /// Users can override these URLs in their provider settings.
  static const Map<InferenceProviderType, String> defaultBaseUrls = {
    InferenceProviderType.gemini:
        'https://generativelanguage.googleapis.com/v1beta/openai',
    InferenceProviderType.gemma3n: 'http://localhost:11343',
    InferenceProviderType.genericOpenAi: 'http://localhost:8002/v1',
    InferenceProviderType.nebiusAiStudio: 'https://api.studio.nebius.com/v1',
    InferenceProviderType.ollama: 'http://localhost:11434',
    InferenceProviderType.openAi: 'https://api.openai.com/v1',
    InferenceProviderType.anthropic: 'https://api.anthropic.com/v1',
    InferenceProviderType.openRouter: 'https://openrouter.ai/api/v1',
    InferenceProviderType.whisper: 'http://localhost:8084',
  };

  /// Default names for each provider type
  ///
  /// These names are displayed in the UI when creating or editing provider configurations.
  static const Map<InferenceProviderType, String> defaultNames = {
    InferenceProviderType.gemini: 'Gemini',
    InferenceProviderType.gemma3n: 'Gemma 3n (local)',
    InferenceProviderType.genericOpenAi: 'AI Proxy (local)',
    InferenceProviderType.nebiusAiStudio: 'Nebius AI Studio',
    InferenceProviderType.ollama: 'Ollama (local)',
    InferenceProviderType.openAi: 'OpenAI',
    InferenceProviderType.anthropic: 'Anthropic',
    InferenceProviderType.openRouter: 'OpenRouter',
    InferenceProviderType.whisper: 'Whisper (local)',
  };

  /// Provider types that don't require an API key
  ///
  /// These providers run locally and don't require authentication.
  /// They are suitable for privacy-focused applications.
  static const Set<InferenceProviderType> noApiKeyRequired = {
    InferenceProviderType.gemma3n,
    InferenceProviderType.ollama,
    InferenceProviderType.whisper,
  };

  /// Get the default base URL for a provider type
  ///
  /// Returns an empty string if the provider type is not configured.
  static String getDefaultBaseUrl(InferenceProviderType type) {
    return defaultBaseUrls[type] ?? '';
  }

  /// Get the default name for a provider type
  ///
  /// Returns an empty string if the provider type is not configured.
  static String getDefaultName(InferenceProviderType type) {
    return defaultNames[type] ?? '';
  }

  /// Check if a provider type requires an API key
  ///
  /// Local providers (Ollama, Whisper) don't require API keys.
  static bool requiresApiKey(InferenceProviderType type) {
    return !noApiKeyRequired.contains(type);
  }
}
