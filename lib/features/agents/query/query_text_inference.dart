import 'dart:async';
import 'dart:convert';

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

  Future<String> collect(Stream<String> stream) async {
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
        buffer.write(text);
        if (buffer.length > 64000 && !result.isCompleted) {
          result.completeError(
            const FormatException('Query response too large'),
          );
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
  const QueryTextInference({required this._generate});

  factory QueryTextInference.forProfile({
    required CloudInferenceRepository cloud,
    required ResolvedProfile profile,
    required String agentId,
    required String chatId,
    String? categoryId,
    String? taskId,
    AiInteractionCapture? capture,
  }) => QueryTextInference(
    generate: (system, prompt) {
      final provider = profile.thinkingProvider;
      final model = profile.thinkingModel;
      final impact = InferenceImpactCollector();
      Stream<CreateChatCompletionStreamResponse> raw() => cloud.generate(
        prompt,
        model: profile.thinkingModelId,
        temperature: 0.2,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        provider: provider,
        systemMessage: system,
        maxCompletionTokens: model?.maxCompletionTokens,
        geminiThinkingMode: model?.geminiThinkingMode,
        impactCollector: impact,
      );
      final stream = capture == null
          ? raw()
          : capture.captureStream(
              workType: AiWorkType.textGeneration,
              interactionKind: AiInteractionKind.chatCompletion,
              responseType: AiConsumptionResponseType.textGeneration,
              providerType: provider.inferenceProviderType,
              modelId: profile.thinkingModelId,
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
    },
  );

  final QueryTextStream _generate;

  Future<Map<String, dynamic>> complete({
    required String system,
    required Map<String, Object?> input,
    required QueryCancellation cancellation,
  }) async {
    cancellation.check();
    final response = await cancellation.collect(
      _generate(system, jsonEncode(input)),
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
    return decoded;
  }
}
