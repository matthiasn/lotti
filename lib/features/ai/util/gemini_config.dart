import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';

GeminiThinkingConfig getDefaultThinkingConfig(String modelId) {
  switch (modelId) {
    case 'models/gemini-3-pro-preview':
    case 'gemini-3-pro-preview':
      return GeminiThinkingConfig.auto; // Advanced reasoning capabilities
    case 'models/gemini-2.5-flash':
    case 'gemini-2.5-flash':
      // Default: standard budget; thoughts off by default handled elsewhere.
      return GeminiThinkingConfig.standard;
    case 'models/gemini-2.5-flash-lite':
    case 'gemini-2.5-flash-lite':
      return const GeminiThinkingConfig(thinkingBudget: 4096);
    case 'models/gemini-2.5-pro':
    case 'gemini-2.5-pro':
      return GeminiThinkingConfig.auto; // Can't be disabled
    case 'models/gemini-2.0-flash':
    case 'gemini-2.0-flash':
      return GeminiThinkingConfig.disabled; // No thinking support
    default:
      return GeminiThinkingConfig.auto;
  }
}
