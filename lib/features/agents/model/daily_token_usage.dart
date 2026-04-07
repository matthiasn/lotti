import 'package:meta/meta.dart';

/// Token usage aggregated for a single calendar day.
///
/// Supports the iOS battery-style chart by tracking both the full-day total
/// and the tokens consumed up to a specific cutoff time (typically the current
/// hour of day), enabling two-tone bar rendering. Also carries the
/// input/output/thoughts/cached breakdown and wake count for detail panels.
@immutable
class DailyTokenUsage {
  const DailyTokenUsage({
    required this.date,
    required this.totalTokens,
    required this.tokensByTimeOfDay,
    required this.isToday,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.thoughtsTokens = 0,
    this.cachedInputTokens = 0,
    this.wakeCount = 0,
  });

  /// The calendar day (time component is midnight local).
  final DateTime date;

  /// Total tokens consumed across the entire day.
  final int totalTokens;

  /// Tokens consumed up to the cutoff time of day (for past days, this is
  /// the tokens used before the same hour as "now"; for today, this equals
  /// [totalTokens]).
  final int tokensByTimeOfDay;

  final bool isToday;
  final int inputTokens;
  final int outputTokens;
  final int thoughtsTokens;

  /// Subset of [inputTokens] served from cache.
  final int cachedInputTokens;

  final int wakeCount;

  /// Cache hit rate as a fraction (0.0–1.0).
  double get cacheRate => inputTokens > 0 ? cachedInputTokens / inputTokens : 0;

  /// Average tokens per wake, or 0 if no wakes.
  int get tokensPerWake => wakeCount > 0 ? totalTokens ~/ wakeCount : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTokenUsage &&
          date == other.date &&
          totalTokens == other.totalTokens &&
          tokensByTimeOfDay == other.tokensByTimeOfDay &&
          isToday == other.isToday &&
          inputTokens == other.inputTokens &&
          outputTokens == other.outputTokens &&
          thoughtsTokens == other.thoughtsTokens &&
          cachedInputTokens == other.cachedInputTokens &&
          wakeCount == other.wakeCount;

  @override
  int get hashCode => Object.hash(
    date,
    totalTokens,
    tokensByTimeOfDay,
    isToday,
    inputTokens,
    outputTokens,
    thoughtsTokens,
    cachedInputTokens,
    wakeCount,
  );
}

/// A single source (agent template) in the token usage breakdown list.
@immutable
class TokenSourceBreakdown {
  const TokenSourceBreakdown({
    required this.templateId,
    required this.displayName,
    required this.totalTokens,
    required this.percentage,
    required this.wakeCount,
    required this.totalDuration,
    required this.isHighUsage,
    this.isTemplate = true,
  });

  final String templateId;
  final String displayName;
  final int totalTokens;

  /// Percentage of today's total token usage (0.0-100.0).
  final double percentage;

  final int wakeCount;
  final Duration totalDuration;
  final bool isHighUsage;

  /// Whether the source ID refers to a template (vs an agent instance).
  final bool isTemplate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenSourceBreakdown &&
          templateId == other.templateId &&
          displayName == other.displayName &&
          totalTokens == other.totalTokens &&
          percentage == other.percentage &&
          wakeCount == other.wakeCount &&
          totalDuration == other.totalDuration &&
          isHighUsage == other.isHighUsage;

  @override
  int get hashCode => Object.hash(
    templateId,
    displayName,
    totalTokens,
    percentage,
    wakeCount,
    totalDuration,
    isHighUsage,
  );
}

/// Aggregated stats for the comparison summary.
@immutable
class TokenUsageComparison {
  const TokenUsageComparison({
    required this.averageTokensByTimeOfDay,
    required this.todayTokens,
  });

  final int averageTokensByTimeOfDay;
  final int todayTokens;

  bool get isAboveAverage => todayTokens > averageTokensByTimeOfDay;
  bool get hasBaseline => averageTokensByTimeOfDay > 0;
  bool get isAtAverage => todayTokens == averageTokensByTimeOfDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenUsageComparison &&
          averageTokensByTimeOfDay == other.averageTokensByTimeOfDay &&
          todayTokens == other.todayTokens;

  @override
  int get hashCode => Object.hash(averageTokensByTimeOfDay, todayTokens);
}
