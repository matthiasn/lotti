import 'package:collection/collection.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
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

  /// Total tokens (input + output + thoughts).
  ///
  /// Note: [cachedInputTokens] is a subset of [inputTokens] (the portion
  /// served from cache), so it is not added separately.
  int get totalTokens => inputTokens + outputTokens + thoughtsTokens;

  /// Share of [inputTokens] served from the provider's prompt cache, from 0
  /// to 1, or null when there was no input to measure it against.
  ///
  /// Cached input is billed below fresh input, so this is the number that
  /// says how much a model's repeated context is saving. Clamped because a
  /// provider reporting more cached than prompt tokens is a provider bug,
  /// not a hit rate above 100%.
  double? get cacheHitRate => inputTokens > 0
      ? (cachedInputTokens / inputTokens).clamp(0.0, 1.0)
      : null;

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

/// Per-instance token usage with full per-model breakdown.
///
/// Used by the template stats view to show each instance's contribution
/// to the aggregate token expenditure, with the same per-model detail
/// as the aggregate table.
@immutable
class InstanceTokenBreakdown {
  const InstanceTokenBreakdown({
    required this.agentId,
    required this.displayName,
    required this.lifecycle,
    required this.summaries,
  });

  final String agentId;
  final String displayName;
  final AgentLifecycle lifecycle;
  final List<AgentTokenUsageSummary> summaries;

  /// Total tokens across all models.
  int get totalTokens =>
      summaries.fold<int>(0, (sum, s) => sum + s.totalTokens);

  static const _listEquality = ListEquality<AgentTokenUsageSummary>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstanceTokenBreakdown &&
          agentId == other.agentId &&
          displayName == other.displayName &&
          lifecycle == other.lifecycle &&
          _listEquality.equals(summaries, other.summaries);

  @override
  int get hashCode => Object.hash(
    agentId,
    displayName,
    lifecycle,
    _listEquality.hash(summaries),
  );

  @override
  String toString() =>
      'InstanceTokenBreakdown(agent: <redacted>, name: <redacted>, '
      'lifecycle: $lifecycle, totalTokens: $totalTokens)';
}
