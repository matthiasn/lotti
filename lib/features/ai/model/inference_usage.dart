/// Usage statistics from AI inference responses.
///
/// Contains token counts for tracking API usage and costs.
/// All fields are nullable to support providers that don't report usage.
class InferenceUsage {
  const InferenceUsage({
    this.inputTokens,
    this.outputTokens,
    this.thoughtsTokens,
    this.cachedInputTokens,
  });

  /// Empty usage when no data is available
  static const empty = InferenceUsage();

  /// Number of tokens in the input/prompt
  final int? inputTokens;

  /// Number of tokens in the output/response
  final int? outputTokens;

  /// Number of tokens used for thinking/reasoning (Gemini-specific)
  final int? thoughtsTokens;

  /// Number of input tokens served from cache
  final int? cachedInputTokens;

  /// Total tokens used (input + output)
  int get totalTokens => (inputTokens ?? 0) + (outputTokens ?? 0);

  /// Whether any usage data is available
  bool get hasData =>
      inputTokens != null ||
      outputTokens != null ||
      thoughtsTokens != null ||
      cachedInputTokens != null;

  /// Merges this usage with another, summing the token counts.
  /// Useful for aggregating usage across multiple API calls.
  InferenceUsage merge(InferenceUsage other) {
    return InferenceUsage(
      inputTokens: _addNullable(inputTokens, other.inputTokens),
      outputTokens: _addNullable(outputTokens, other.outputTokens),
      thoughtsTokens: _addNullable(thoughtsTokens, other.thoughtsTokens),
      cachedInputTokens:
          _addNullable(cachedInputTokens, other.cachedInputTokens),
    );
  }

  static int? _addNullable(int? a, int? b) {
    if (a == null && b == null) return null;
    return (a ?? 0) + (b ?? 0);
  }

  @override
  String toString() {
    final parts = <String>[];
    if (inputTokens != null) parts.add('input: $inputTokens');
    if (outputTokens != null) parts.add('output: $outputTokens');
    if (thoughtsTokens != null) parts.add('thoughts: $thoughtsTokens');
    if (cachedInputTokens != null) parts.add('cached: $cachedInputTokens');
    return 'InferenceUsage(${parts.join(', ')})';
  }
}
