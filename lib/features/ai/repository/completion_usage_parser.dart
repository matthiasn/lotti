import 'package:openai_dart/openai_dart.dart';

/// Parses OpenAI-compatible `usage` payloads into [CompletionUsage].
///
/// Providers are not perfectly consistent: streamed chat completions usually
/// report `prompt_tokens`/`completion_tokens`, while a few compatible servers
/// use input/output naming or camelCase keys. Unsupported duration-only usage
/// payloads (for example audio seconds without token counts) return null.
CompletionUsage? parseCompletionUsage(Object? raw) {
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

  return CompletionUsage(
    promptTokens: promptTokenCount,
    completionTokens: completionTokenCount,
    totalTokens: totalTokens ?? promptTokenCount + completionTokenCount,
    promptTokensDetails: cachedTokens != null
        ? PromptTokensDetails(cachedTokens: cachedTokens)
        : null,
    completionTokensDetails: reasoningTokens != null
        ? CompletionTokensDetails(reasoningTokens: reasoningTokens)
        : null,
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
CompletionUsage? combineCompletionUsage(
  CompletionUsage? a,
  CompletionUsage? b,
) {
  if (a == null) return b;
  if (b == null) return a;
  int? sum(int? x, int? y) =>
      x == null && y == null ? null : (x ?? 0) + (y ?? 0);
  final aDetails = a.completionTokensDetails;
  final bDetails = b.completionTokensDetails;
  final aPrompt = a.promptTokensDetails;
  final bPrompt = b.promptTokensDetails;
  return CompletionUsage(
    promptTokens: sum(a.promptTokens, b.promptTokens),
    completionTokens: sum(a.completionTokens, b.completionTokens),
    totalTokens: sum(a.totalTokens, b.totalTokens),
    completionTokensDetails: aDetails == null && bDetails == null
        ? null
        : CompletionTokensDetails(
            reasoningTokens: sum(
              aDetails?.reasoningTokens,
              bDetails?.reasoningTokens,
            ),
            audioTokens: sum(aDetails?.audioTokens, bDetails?.audioTokens),
          ),
    // Carried for the same reason as the completion details: the
    // consumption event reads `cachedTokens` off this, so dropping it would
    // report null cached input on exactly the runs that retried.
    promptTokensDetails: aPrompt == null && bPrompt == null
        ? null
        : PromptTokensDetails(
            cachedTokens: sum(aPrompt?.cachedTokens, bPrompt?.cachedTokens),
            audioTokens: sum(aPrompt?.audioTokens, bPrompt?.audioTokens),
          ),
  );
}
