import 'package:lotti/features/ai/model/ai_config.dart';

class GeminiThinkingConfig {
  const GeminiThinkingConfig({
    required this.thinkingBudget,
    this.thinkingMode,
    this.includeThoughts = false,
  });

  factory GeminiThinkingConfig.fromMode(
    GeminiThinkingMode mode, {
    bool includeThoughts = false,
  }) {
    return GeminiThinkingConfig(
      thinkingBudget: _modeToBudget(mode),
      thinkingMode: mode,
      includeThoughts: includeThoughts,
    );
  }

  /// -1 for auto, 0 to disable, positive values for fixed budgets.
  final int thinkingBudget;
  final GeminiThinkingMode? thinkingMode;
  final bool includeThoughts;

  // Presets for common scenarios
  static const auto = GeminiThinkingConfig(thinkingBudget: -1);
  static const disabled = GeminiThinkingConfig(thinkingBudget: 0);
  static const standard = GeminiThinkingConfig(thinkingBudget: 8192);
  static const minimal = GeminiThinkingConfig(
    thinkingBudget: 0,
    thinkingMode: GeminiThinkingMode.minimal,
  );
  static const low = GeminiThinkingConfig(
    thinkingBudget: 1024,
    thinkingMode: GeminiThinkingMode.low,
  );
  static const medium = GeminiThinkingConfig(
    thinkingBudget: 4096,
    thinkingMode: GeminiThinkingMode.medium,
  );
  static const high = GeminiThinkingConfig(
    thinkingBudget: -1,
    thinkingMode: GeminiThinkingMode.high,
  );

  /// Serializes the thinking config for the Gemini API.
  ///
  /// When [modelId] identifies a Gemini 3.x model, emits `thinkingLevel`.
  /// Other model IDs keep the legacy numeric `thinkingBudget` shape.
  Map<String, dynamic> toJson({String? modelId}) {
    if (modelId != null && isGemini3(modelId)) {
      return <String, dynamic>{
        'thinkingLevel': _thinkingLevel(),
        'includeThoughts': includeThoughts,
      };
    }
    return <String, dynamic>{
      'thinkingBudget': _thinkingBudget(),
      'includeThoughts': includeThoughts,
    };
  }

  /// Maps the numeric [thinkingBudget] to a Gemini 3.x `thinkingLevel` value.
  ///
  /// Budget semantics:
  /// -  -1 (auto/dynamic) → `high` (Gemini 3 default, dynamic reasoning)
  /// -   0 (disabled)     → `minimal` (closest Gemini 3 equivalent)
  /// -   1–4095           → `low`
  /// -   4096–8191        → `medium`
  /// -   8192+            → `high`
  String _thinkingLevel() {
    final mode = thinkingMode ?? _budgetToMode(thinkingBudget);
    return mode.apiValue;
  }

  int _thinkingBudget() {
    if (thinkingMode == null) return thinkingBudget;
    return thinkingMode!.toThinkingBudget();
  }

  /// Returns `true` when [modelId] matches a Gemini 3.x model variant.
  static bool isGemini3(String modelId) {
    final id = modelId.replaceFirst('models/', '');
    return id.startsWith('gemini-3');
  }
}

extension GeminiThinkingModeApi on GeminiThinkingMode {
  String get apiValue {
    return switch (this) {
      GeminiThinkingMode.minimal => 'minimal',
      GeminiThinkingMode.low => 'low',
      GeminiThinkingMode.medium => 'medium',
      GeminiThinkingMode.high => 'high',
    };
  }

  int toThinkingBudget() {
    return switch (this) {
      GeminiThinkingMode.minimal => 0,
      GeminiThinkingMode.low => 1024,
      GeminiThinkingMode.medium => 4096,
      GeminiThinkingMode.high => -1,
    };
  }
}

GeminiThinkingMode _budgetToMode(int budget) {
  if (budget == -1) return GeminiThinkingMode.high;
  if (budget == 0) return GeminiThinkingMode.minimal;
  if (budget < 4096) return GeminiThinkingMode.low;
  if (budget < 8192) return GeminiThinkingMode.medium;
  return GeminiThinkingMode.high;
}

int _modeToBudget(GeminiThinkingMode mode) {
  return switch (mode) {
    GeminiThinkingMode.minimal => 0,
    GeminiThinkingMode.low => 1024,
    GeminiThinkingMode.medium => 4096,
    GeminiThinkingMode.high => -1,
  };
}
