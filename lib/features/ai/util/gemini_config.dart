import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';

GeminiThinkingConfig getDefaultThinkingConfig(String modelId) {
  switch (modelId) {
    case 'models/gemini-3.1-pro-preview':
    case 'gemini-3.1-pro-preview':
    // Backwards-compat: configs created before the 3→3.1 rename.
    case 'models/gemini-3-pro-preview':
    case 'gemini-3-pro-preview':
      // Maps to thinkingLevel: MEDIUM for Gemini 3.x via _budgetToLevel().
      return const GeminiThinkingConfig(thinkingBudget: 4096);
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
