class GeminiThinkingConfig {
  const GeminiThinkingConfig({
    required this.thinkingBudget,
    this.includeThoughts = false,
  });

  /// -1 for auto, 0 to disable, 1-24576 for fixed
  final int thinkingBudget;
  final bool includeThoughts;

  // Presets for common scenarios
  static const auto = GeminiThinkingConfig(thinkingBudget: -1);
  static const disabled = GeminiThinkingConfig(thinkingBudget: 0);
  static const standard = GeminiThinkingConfig(thinkingBudget: 8192);
  static const intensive = GeminiThinkingConfig(thinkingBudget: 16384);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'thinkingBudget': thinkingBudget,
        'includeThoughts': includeThoughts,
      };
}
