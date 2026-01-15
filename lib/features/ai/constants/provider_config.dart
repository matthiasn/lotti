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

/// Configuration for the local Whisper transcription service
///
/// This class provides constants and utilities for the whisper.cpp
/// server integration used in Flatpak builds.
class WhisperConfig {
  const WhisperConfig._();

  /// Default host for the whisper server
  static const String defaultHost = '127.0.0.1';

  /// Default port for the whisper server
  static const int defaultPort = 8084;

  /// Default model to use for transcription
  /// Using quantized base model for good balance of speed and accuracy
  static const String defaultModel = 'ggml-base-q5_1.bin';

  /// Timeout for server startup in seconds
  static const int serverStartupTimeoutSeconds = 30;

  /// Timeout for health checks in seconds
  static const int healthCheckTimeoutSeconds = 5;

  /// Base URL for the local whisper server
  static String get defaultBaseUrl => 'http://$defaultHost:$defaultPort';

  /// Available model names that can be used with whisper.cpp
  /// These map to the GGML format models from Hugging Face
  static const List<String> availableModels = [
    'ggml-tiny-q5_1.bin',
    'ggml-tiny.en.bin',
    'ggml-base-q5_1.bin',
    'ggml-base.en.bin',
    'ggml-small-q5_1.bin',
    'ggml-small.en.bin',
    'ggml-medium-q5_0.bin',
    'ggml-medium.bin',
    'ggml-large-v3-q5_0.bin',
    'ggml-large-v3.bin',
  ];

  /// Check if a model name is valid
  static bool isValidModel(String modelName) {
    return availableModels.contains(modelName);
  }
}
