import 'package:openai_dart/openai_dart.dart';

/// Parses OpenAI-compatible `usage` payloads into [CompletionUsage].
///
/// Providers are not perfectly consistent: streamed chat completions usually
/// report `prompt_tokens`/`completion_tokens`, while a few compatible servers
/// use input/output naming or camelCase keys. Unsupported duration-only usage
/// payloads (for example audio seconds without token counts) return null.
CompletionUsage? parseCompletionUsage(Object? raw) {
  if (raw is! Map) return null;
  final usage = raw.cast<String, dynamic>();

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

  return CompletionUsage(
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    totalTokens: totalTokens ?? (promptTokens ?? 0) + (completionTokens ?? 0),
    promptTokensDetails: cachedTokens != null
        ? PromptTokensDetails(cachedTokens: cachedTokens)
        : null,
    completionTokensDetails: reasoningTokens != null
        ? CompletionTokensDetails(reasoningTokens: reasoningTokens)
        : null,
  );
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value is! Map) return null;
  return value.cast<String, dynamic>();
}

int? _integerValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
