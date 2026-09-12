import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/ui/chat/thinking_parser.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:openai_dart/openai_dart.dart';

class QueryCancelled implements Exception {
  const QueryCancelled();
}

/// One request owns its subscriptions. Cancelling a chat does not cancel a
/// sibling chat, and a stream that has not emitted yet is still cancellable.
class QueryCancellation {
  bool _cancelled = false;
  final _callbacks = <void Function()>{};

  bool get isCancelled => _cancelled;

  void check() {
    if (_cancelled) throw const QueryCancelled();
  }

  void cancel() {
    _cancelled = true;
    for (final callback in _callbacks.toList()) {
      callback();
    }
  }

  /// Attaches owned resources (for example an HTTP client) to this request's
  /// lifetime. The returned callback detaches a resource after normal cleanup.
  void Function() onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
    return () => _callbacks.remove(callback);
  }

  Future<String> collect(
    Stream<String> stream, {
    void Function(String)? onText,
  }) async {
    check();
    final result = Completer<String>();
    final buffer = StringBuffer();
    late StreamSubscription<String> subscription;
    void cancel() {
      if (!result.isCompleted) result.completeError(const QueryCancelled());
      unawaited(subscription.cancel());
    }

    subscription = stream.listen(
      (text) {
        if (result.isCompleted || _cancelled) return;
        buffer.write(text);
        if (buffer.length > 64000 && !result.isCompleted) {
          result.completeError(
            const FormatException('Query response too large'),
          );
          unawaited(subscription.cancel());
          return;
        }
        try {
          onText?.call(buffer.toString());
        } catch (error, stack) {
          if (!result.isCompleted) result.completeError(error, stack);
          unawaited(subscription.cancel());
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
      onDone: () {
        if (!result.isCompleted) result.complete(buffer.toString());
      },
    );
    _callbacks.add(cancel);
    try {
      final text = await result.future.timeout(const Duration(minutes: 2));
      check();
      return text;
    } finally {
      _callbacks.remove(cancel);
      await subscription.cancel();
    }
  }
}

typedef QueryTextStream = Stream<String> Function(String system, String prompt);

/// Each completion has a fresh context. Inference accounting records hashes
/// and usage through the existing capture boundary, never a second chat log.
class QueryTextInference {
  const QueryTextInference({
    required this._generate,
    this._generateSynthesis,
  });

  factory QueryTextInference.forProfile({
    required CloudInferenceRepository cloud,
    required ResolvedProfile profile,
    required String agentId,
    required String chatId,
    String? categoryId,
    String? taskId,
    AiInteractionCapture? capture,
  }) {
    if (profile.chatModelUnavailable) {
      throw StateError('Query chat model unavailable');
    }
    Stream<String> generate(
      String system,
      String prompt, {
      bool synthesis = false,
    }) {
      final provider = profile.effectiveChatProvider;
      final model = profile.effectiveChatModel;
      final impact = InferenceImpactCollector();
      Stream<CreateChatCompletionStreamResponse> raw() => cloud.generate(
        prompt,
        model: profile.effectiveChatModelId,
        temperature: 0.2,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        provider: provider,
        systemMessage: system,
        maxCompletionTokens: model?.maxCompletionTokens,
        geminiThinkingMode: model?.geminiThinkingMode,
        impactCollector: impact,
        preferStreaming: synthesis,
      );
      final stream = capture == null
          ? raw()
          : capture.captureStream(
              workType: AiWorkType.textGeneration,
              interactionKind: AiInteractionKind.chatCompletion,
              responseType: AiConsumptionResponseType.textGeneration,
              providerType: provider.inferenceProviderType,
              modelId: profile.effectiveChatModelId,
              requestText: '$system\n$prompt',
              invoke: raw,
              responseText: (chunk) =>
                  chunk.choices?.firstOrNull?.delta?.content ?? '',
              usageForChunk: (chunk) {
                final usage = chunk.usage;
                return usage == null
                    ? null
                    : AiCapturedUsage(
                        inputTokens: usage.promptTokens,
                        outputTokens: usage.completionTokens,
                        cachedInputTokens:
                            usage.promptTokensDetails?.cachedTokens,
                        thoughtsTokens:
                            usage.completionTokensDetails?.reasoningTokens,
                        totalTokens: usage.totalTokens,
                      );
              },
              impact: () => impact.impact,
              interactionContext: AiCapturedContext(
                agentId: agentId,
                threadId: chatId,
                providerConfigId: provider.id,
                modelConfigId: model?.id,
              ),
              taskId: taskId,
              categoryId: categoryId,
            );
      return stream.map(
        (chunk) => chunk.choices?.firstOrNull?.delta?.content ?? '',
      );
    }

    return QueryTextInference(
      generate: generate,
      generateSynthesis: (system, prompt) =>
          generate(system, prompt, synthesis: true),
    );
  }

  final QueryTextStream _generate;
  final QueryTextStream? _generateSynthesis;

  static const _clockGuidance =
      ' The top-level currentTime is the device clock for this request. '
      'Use its localDate and localTimestamp to resolve today, yesterday, '
      'tomorrow and other relative dates. Dates in sources, reports and prior '
      'conversation are historical; never use them as the current date. '
      'The clock is request metadata, not source evidence or a durable task '
      'conclusion. Do not invent a different current date.';

  /// Includes the same clock guidance and metadata sent to the provider, so
  /// retrieval budgets still bound the complete request. Timestamps use seconds
  /// and a fixed-width UTC offset, keeping their size stable across calls.
  static int requestBytes(String system, Map<String, Object?> input) =>
      utf8.encode('$system$_clockGuidance').length +
      utf8.encode(jsonEncode(_withCurrentTime(input))).length;

  static Map<String, Object?> _withCurrentTime(Map<String, Object?> input) {
    final now = clock.now();
    final local = now.toIso8601String().split('.').first;
    final minutes = now.timeZoneOffset.inMinutes;
    final hours = (minutes.abs() ~/ 60).toString().padLeft(2, '0');
    final remainder = (minutes.abs() % 60).toString().padLeft(2, '0');
    final offset = '${minutes < 0 ? '-' : '+'}$hours:$remainder';
    return {
      for (final entry in input.entries)
        if (entry.key != 'currentTime') entry.key: entry.value,
      // Append volatile clock data after stable sources and replace any stale
      // caller-supplied clock. Never cache this at profile/chat construction.
      'currentTime': {
        'localDate': local.split('T').first,
        'localTimestamp': '$local$offset',
      },
    };
  }

  Future<Map<String, dynamic>> complete({
    required String system,
    required Map<String, Object?> input,
    required QueryCancellation cancellation,
    void Function(String)? onAnswerText,
    void Function()? onFirstToken,
  }) async {
    cancellation.check();
    var shown = '';
    var received = false;
    final response = await cancellation.collect(
      (onAnswerText == null ? _generate : _generateSynthesis ?? _generate)(
        '$system$_clockGuidance',
        jsonEncode(_withCurrentTime(input)),
      ),
      onText: (raw) {
        if (!received && raw.isNotEmpty) {
          received = true;
          onFirstToken?.call();
        }
        if (onAnswerText == null) return;
        final prefix = _answerPrefix(raw);
        if (prefix == null || prefix == shown) return;
        if (!prefix.startsWith(shown)) {
          throw const FormatException('Query draft changed');
        }
        shown = prefix;
        onAnswerText(prefix);
      },
    );
    var text = splitThinkingSegments(response)
        .where((segment) => !segment.isThinking)
        .map((segment) => segment.text)
        .join()
        .trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected query object');
    }
    if (decoded['answer'] case final String answer when onAnswerText != null) {
      if (!answer.startsWith(shown)) {
        throw const FormatException('Query draft changed');
      }
      if (answer != shown) onAnswerText(answer);
    }
    return decoded;
  }
}

/// Only the first top-level answer string is rendered incrementally. Other
/// field orders remain buffered. Incomplete escapes and surrogate pairs stay
/// buffered too, so visible text never needs an in-place correction.
String? _answerPrefix(String response) {
  var text = splitThinkingSegments(response)
      .where((part) => !part.isThinking)
      .map((part) => part.text)
      .join()
      .trimLeft();
  text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
  final start = RegExp(r'^\{\s*"answer"\s*:\s*"').firstMatch(text);
  if (start == null) return null;
  var end = start.end;
  while (end < text.length) {
    final unit = text.codeUnitAt(end);
    if (unit == 34) break;
    if (unit == 92) {
      if (end + 1 >= text.length) break;
      if (text.codeUnitAt(end + 1) == 117) {
        if (end + 6 > text.length) break;
        end += 6;
      } else {
        end += 2;
      }
    } else {
      end++;
    }
  }
  var answer = jsonDecode('"${text.substring(start.end, end)}"') as String;
  if (answer.isNotEmpty) {
    final last = answer.codeUnitAt(answer.length - 1);
    if (last >= 0xd800 && last <= 0xdbff) {
      answer = answer.substring(0, answer.length - 1);
    }
  }
  return answer;
}
