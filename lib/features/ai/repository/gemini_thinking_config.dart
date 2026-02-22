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

  /// Serializes the thinking config for the Gemini API.
  ///
  /// When [modelId] identifies a Gemini 3.x model, emits `thinkingLevel`
  /// (the enum-based control required by Gemini 3). Otherwise emits the
  /// legacy `thinkingBudget` integer used by Gemini 2.5.
  Map<String, dynamic> toJson({String? modelId}) {
    if (modelId != null && isGemini3(modelId)) {
      return <String, dynamic>{
        'thinkingLevel': _budgetToLevel(),
        'includeThoughts': includeThoughts,
      };
    }
    return <String, dynamic>{
      'thinkingBudget': thinkingBudget,
      'includeThoughts': includeThoughts,
    };
  }

  /// Maps the numeric [thinkingBudget] to a Gemini 3.x `thinkingLevel` string.
  ///
  /// Budget semantics:
  /// -  -1 (auto/dynamic) → `HIGH` (Gemini 3 default, dynamic reasoning)
  /// -   0 (disabled)     → `LOW`  (Gemini 3 cannot fully disable thinking)
  /// -   1–4095           → `LOW`
  /// -   4096–8191        → `MEDIUM`
  /// -   8192+            → `HIGH`
  String _budgetToLevel() {
    if (thinkingBudget == -1) return 'HIGH'; // auto → dynamic/highest
    if (thinkingBudget < 4096) return 'LOW'; // 0 (disabled) maps here too
    if (thinkingBudget < 8192) return 'MEDIUM';
    return 'HIGH';
  }

  /// Returns `true` when [modelId] matches a Gemini 3.x model variant.
  static bool isGemini3(String modelId) {
    final id = modelId.replaceFirst('models/', '');
    return id.startsWith('gemini-3');
  }
}
