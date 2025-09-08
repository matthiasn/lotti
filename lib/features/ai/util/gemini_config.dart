import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';

GeminiThinkingConfig getDefaultThinkingConfig(String modelId) {
  switch (modelId) {
    case 'models/gemini-2.5-flash':
    case 'gemini-2.5-flash':
      // Flash can interleave thoughts in ways that confuse separation; default
      // to hidden thoughts disabled for clean UX.
      return const GeminiThinkingConfig(
        thinkingBudget: 8192,
        includeThoughts: false,
      );
    case 'models/gemini-2.5-flash-lite':
    case 'gemini-2.5-flash-lite':
      return const GeminiThinkingConfig(
        thinkingBudget: 4096,
        includeThoughts: false,
      );
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
