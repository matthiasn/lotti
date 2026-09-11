import 'package:lotti/features/ai/model/inference_chunk.dart';

/// Parses OpenAI-compatible `usage` payloads into [LottiUsage].
///
/// Providers are not perfectly consistent: streamed chat completions usually
/// report `prompt_tokens`/`completion_tokens`, while a few compatible servers
/// use input/output naming or camelCase keys. Unsupported duration-only usage
/// payloads (for example audio seconds without token counts) return null.
LottiUsage? parseCompletionUsage(Object? raw) {
  if (raw is! Map<dynamic, dynamic>) return null;
  final usage = raw;

  final promptTokens = _integerValue(
    usage['prompt_tokens'] ?? usage['input_tokens'] ?? usage['promptTokens'],
  );
  final completionTokens = _integerValue(
    usage['completion_tokens'] ??
        usage['output_tokens'] ??
        usage['completionTokens'],
  );
  final totalTokens = _integerValue(
    usage['total_tokens'] ?? usage['totalTokens'],
  );
  final cachedTokens =
      _integerValue(usage['cached_tokens'] ?? usage['cachedTokens']) ??
      _integerValue(
        _mapValue(usage['prompt_tokens_details'])?['cached_tokens'] ??
            _mapValue(usage['promptTokensDetails'])?['cachedTokens'] ??
            _mapValue(usage['input_tokens_details'])?['cached_tokens'] ??
            _mapValue(usage['inputTokensDetails'])?['cachedTokens'],
      );
  final reasoningTokens =
      _integerValue(usage['reasoning_tokens'] ?? usage['reasoningTokens']) ??
      _integerValue(
        _mapValue(usage['completion_tokens_details'])?['reasoning_tokens'] ??
            _mapValue(usage['completionTokensDetails'])?['reasoningTokens'] ??
            _mapValue(usage['output_tokens_details'])?['reasoning_tokens'] ??
            _mapValue(usage['outputTokensDetails'])?['reasoningTokens'],
      );

  final hasTokenData =
      promptTokens != null ||
      completionTokens != null ||
      totalTokens != null ||
      cachedTokens != null ||
      reasoningTokens != null;
  if (!hasTokenData) return null;

  final promptTokenCount = promptTokens ?? 0;
  final completionTokenCount = completionTokens ?? 0;

  return LottiUsage(
    promptTokens: promptTokenCount,
    completionTokens: completionTokenCount,
    totalTokens: totalTokens ?? promptTokenCount + completionTokenCount,
    cachedInputTokens: cachedTokens,
    reasoningTokens: reasoningTokens,
  );
}

Map<dynamic, dynamic>? _mapValue(Object? value) {
  if (value is! Map<dynamic, dynamic>) return null;
  return value;
}

int? _integerValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Sums token usage across physical requests belonging to one logical call.
LottiUsage? combineCompletionUsage(LottiUsage? a, LottiUsage? b) {
  if (a == null) return b;
  if (b == null) return a;
  int? sum(int? x, int? y) =>
      x == null && y == null ? null : (x ?? 0) + (y ?? 0);
  // Cached and reasoning counts are carried rather than dropped: the
  // consumption event reads them, so losing them here would report null
  // cached input on exactly the runs that retried.
  return LottiUsage(
    promptTokens: sum(a.promptTokens, b.promptTokens),
    completionTokens: sum(a.completionTokens, b.completionTokens),
    totalTokens: sum(a.totalTokens, b.totalTokens),
    cachedInputTokens: sum(a.cachedInputTokens, b.cachedInputTokens),
    reasoningTokens: sum(a.reasoningTokens, b.reasoningTokens),
    promptAudioTokens: sum(a.promptAudioTokens, b.promptAudioTokens),
    completionAudioTokens: sum(
      a.completionAudioTokens,
      b.completionAudioTokens,
    ),
  );
}
