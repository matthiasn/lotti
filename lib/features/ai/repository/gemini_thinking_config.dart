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
        'thinkingLevel': _thinkingLevel(modelId: modelId),
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
  /// Gemini 3 Flash accepts `minimal`, `low`, `medium`, and `high`. Gemini 3
  /// Pro currently accepts only `low` and `high`, so minimal/low collapse to
  /// `low` and medium/high collapse to `high` for non-Flash Gemini 3 models.
  ///
  /// Budget semantics:
  /// -  -1 (auto/dynamic) → `high` (Gemini 3 default, dynamic reasoning)
  /// -   0 (disabled)     → `minimal` (closest Gemini 3 equivalent)
  /// -   1–4095           → `low`
  /// -   4096–8191        → `medium`
  /// -   8192+            → `high`
  String _thinkingLevel({required String modelId}) {
    final mode = thinkingMode ?? _budgetToMode(thinkingBudget);
    return effectiveMode(modelId, mode).apiValue;
  }

  /// Collapses [mode] to the set of thinking levels supported by [modelId].
  ///
  /// Gemini 3 Flash supports all four levels. Other Gemini 3 models (Pro)
  /// currently accept only `low` and `high`, so minimal/low collapse to
  /// [GeminiThinkingMode.low] and medium/high to [GeminiThinkingMode.high].
  /// Non-Gemini-3 model IDs are returned unchanged.
  static GeminiThinkingMode effectiveMode(
    String modelId,
    GeminiThinkingMode mode,
  ) {
    if (isGemini3(modelId) && !isGemini3Flash(modelId)) {
      return switch (mode) {
        GeminiThinkingMode.minimal ||
        GeminiThinkingMode.low => GeminiThinkingMode.low,
        GeminiThinkingMode.medium ||
        GeminiThinkingMode.high => GeminiThinkingMode.high,
      };
    }
    return mode;
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

  static bool isGemini3Flash(String modelId) {
    final id = modelId.replaceFirst('models/', '').toLowerCase();
    return id.startsWith('gemini-3') && id.contains('flash');
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
