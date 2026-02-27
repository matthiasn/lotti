import 'package:meta/meta.dart';

/// Aggregated token usage summary for a single model.
///
/// Produced by grouping `WakeTokenUsageEntity` records by `modelId` and
/// summing their token counts.
@immutable
class AgentTokenUsageSummary {
  const AgentTokenUsageSummary({
    required this.modelId,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.thoughtsTokens = 0,
    this.cachedInputTokens = 0,
    this.wakeCount = 0,
  });

  final String modelId;
  final int inputTokens;
  final int outputTokens;
  final int thoughtsTokens;
  final int cachedInputTokens;
  final int wakeCount;

  /// Total tokens across all categories.
  int get totalTokens => inputTokens + outputTokens + thoughtsTokens;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentTokenUsageSummary &&
          modelId == other.modelId &&
          inputTokens == other.inputTokens &&
          outputTokens == other.outputTokens &&
          thoughtsTokens == other.thoughtsTokens &&
          cachedInputTokens == other.cachedInputTokens &&
          wakeCount == other.wakeCount;

  @override
  int get hashCode => Object.hash(
        modelId,
        inputTokens,
        outputTokens,
        thoughtsTokens,
        cachedInputTokens,
        wakeCount,
      );

  @override
  String toString() =>
      'AgentTokenUsageSummary(model: $modelId, in: $inputTokens, '
      'out: $outputTokens, thoughts: $thoughtsTokens, '
      'cached: $cachedInputTokens, wakes: $wakeCount)';
}
